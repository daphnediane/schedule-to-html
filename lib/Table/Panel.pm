package Table::Panel;

use base qw{Exporter};

use v5.36.0;
use utf8;

use List::Util qw{ any };

use Canonical    qw{ :all };
use Data::Room   qw{};
use Field::Panel qw{};
use Field::Room  qw{};
use Presenter    qw{};
use PresenterSet qw{};
use TimeDecoder  qw{ :from_text :timepoints };
use Workbook     qw{};

our @EXPORT_OK = qw {
    get_split_panels
    get_panels_by_start
    get_related_panels
    read_from
    read_spreadsheet_file
};

our %EXPORT_TAGS = (
    all => [ @EXPORT_OK ],
);

my %by_start_;
my %by_base_uniq_id_;
my @splits_;

sub to_presenters_ {
    my ( $per_info, $names ) = @_;

    return           unless defined $per_info;
    return $per_info unless $per_info->get_is_other();

    my @indices   = $per_info->get_index_array();
    my $sub_index = 0;

    return map {
        Presenter->lookup(
            $_,
            [ @indices, ++$sub_index ],
            $per_info->get_presenter_rank()
        )
        }
        split m{\s*,\s*}xms, $names;
} ## end sub to_presenters_

sub read_presenter_column_ {
    my ( $presenter_set, $per_info_index, $raw_text ) = @_;

    return unless defined $raw_text;

    my $unlisted = $raw_text =~ m{\A[*]}xms || $raw_text =~ m{[*]\z}xms;

    my @presenters = to_presenters_( $per_info_index, $raw_text );

    if ( $unlisted ) {
        $presenter_set->add_unlisted_presenters( @presenters );
    }
    else {
        $presenter_set->add_credited_presenters( @presenters );
    }

    return;
} ## end sub read_presenter_column_

sub to_room_ {
    my ( $panel_data, $room_name ) = @_;

    return unless defined $room_name;
    return if $room_name eq q{};

    my $room = Table::Room::lookup( $room_name );
    return $room if defined $room;

    # Create room, this only works well if there is but a single room
    my $short_name = $room_name;

    my $sort_key  = $panel_data->{ $Field::Panel::ROOM_SORT_KEY };
    my $long_name = $panel_data->{ $Field::Panel::ROOM_REAL_ROOM };
    if ( defined $long_name ) {
        $room = Table::Room::lookup( $long_name );
        return $room if defined $room;
    }
    $short_name //= $long_name;
    $long_name  //= $short_name;

    my $hotel = $panel_data->{ $Field::Panel::ROOM_HOTEL_ROOM };
    if ( defined $hotel ) {
        $room = Table::Room::lookup( $hotel );
        return $room if defined $room;
    }

    return unless defined $short_name;

    my $uniq_id = $panel_data->{ $Field::Panel::UNIQUE_ID };
    $sort_key //= $Data::Room::HIDDEN_SORT_KEY
        if $uniq_id =~ m{\A (?: br | split ) }xmsi;
    $sort_key //= -1;

    $room = Data::Room->new(
        sort_key   => $sort_key,
        short_name => $short_name,
        long_name  => $long_name,
        hotel_room => $hotel,
    );
    warn q{Creating room: }, $long_name, qq{\n};

    Table::Room::register( $room );

    return $room;
} ## end sub to_room_

sub read_room_column_ {
    my ( $panel_data ) = @_;

    my $rooms = $panel_data->{ $Field::Panel::ROOM_NAME };
    return unless defined $rooms;

    my %seen;
    my @rooms;

    foreach my $room (
        map { to_room_( $panel_data, $_ ) }
        split m{\s*[,/;]+\s*}xms,
        $rooms
    ) {
        my $id = $room->get_room_id();
        next if $seen{ $id };
        $seen{ $id } = 1;
        push @rooms, $room;
    } ## end foreach my $room ( map { to_room_...})

    return @rooms;
} ## end sub read_room_column_

sub read_panel_ {
    my ( $header, $san_header, $presenters_by_column, $raw ) = @_;

    my %panel_data;
    my $presenter_set = PresenterSet->new();
    foreach my $column ( keys @{ $raw } ) {
        my $header_text = $header->[ $column ];
        my $header_alt  = $san_header->[ $column ];

        my $raw_text = $raw->[ $column ];
        if ( defined $raw_text ) {
            $raw_text =~ s{\A \s++}{}xms;
            $raw_text =~ s{\s++ \z}{}xms;
            undef $raw_text if $raw_text eq q{};
        }
        $panel_data{ $header_text } = $raw_text;
        $panel_data{ $header_alt }  = $raw_text;

        if ( defined $presenters_by_column->[ $column ] && defined $raw_text )
        {
            read_presenter_column_(
                $presenter_set,
                $presenters_by_column->[ $column ], $raw_text
            );
        } ## end if ( defined $presenters_by_column...)
    } ## end foreach my $column ( keys @...)

    $presenter_set->set_are_credits_hidden( 1 )
        if defined $panel_data{ $Field::Panel::PANELIST_HIDE };
    $presenter_set->set_override_credits(
        $panel_data{ $Field::Panel::PANELIST_ALT } )
        if exists $panel_data{ $Field::Panel::PANELIST_ALT };

    my @rooms = read_room_column_( \%panel_data );
    return unless @rooms;

    return Data::Panel->new(
        uniq_id       => $panel_data{ $Field::Panel::UNIQUE_ID },
        cost          => $panel_data{ $Field::Panel::COST },
        description   => $panel_data{ $Field::Panel::DESCRIPTION },
        difficulty    => $panel_data{ $Field::Panel::DIFFICULTY },
        capacity      => $panel_data{ $Field::Panel::CAPACITY },
        duration      => $panel_data{ $Field::Panel::DURATION },
        end_time      => $panel_data{ $Field::Panel::END_TIME },
        is_full       => $panel_data{ $Field::Panel::FULL },
        name          => $panel_data{ $Field::Panel::PANEL_NAME },
        note          => $panel_data{ $Field::Panel::NOTE },
        av_note       => $panel_data{ $Field::Panel::AV_NOTE },
        panel_kind    => $panel_data{ $Field::Panel::PANEL_KIND },
        rooms         => \@rooms,
        start_time    => $panel_data{ $Field::Panel::START_TIME },
        presenter_set => $presenter_set,
    );
} ## end sub read_panel_

sub process_panel_ {
    my ( $panel ) = @_;

    return unless defined $panel;

    return unless defined $panel->get_start_seconds();

    return unless defined $panel->get_name();

    if ( any { $_->get_is_split() } $panel->get_rooms() ) {
        push @splits_, $panel;
        return;
    }

    mark_timepoint_seen( $panel->get_start_seconds() );
    mark_timepoint_seen( $panel->get_end_seconds() );

    my $difficulty = $panel->get_difficulty();
    if ( defined $difficulty && $difficulty =~ m{\A[?]+\z}xms ) {
        undef $difficulty;
        $panel->set_difficulty();
    }

    push @{ $by_start_{ $panel->get_start_seconds() }       //= [] }, $panel;
    push @{ $by_base_uniq_id_{ $panel->get_uniq_id_base() } //= [] }, $panel;
    return;

} ## end sub process_panel_

sub get_split_panels {
    return @splits_;
}

sub get_panels_by_start {
    my ( $time ) = @_;
    my $panels = $by_start_{ $time };
    return unless defined $panels;
    return @{ $panels };
} ## end sub get_panels_by_start

sub get_related_panels {
    my ( $panel ) = @_;

    my $related = $by_base_uniq_id_{ $panel->get_uniq_id_base() };
    return $panel unless defined $related;
    return @{ $related };
} ## end sub get_related_panels

sub read_from {
    my ( $wb ) = @_;

    my $main_sheet = $wb->sheet();
    if ( !defined $main_sheet || !$main_sheet->get_is_open() ) {
        die q{Unable to find schedule sheet for },
            $wb->get_filename(), qq{\n};
    }

    my $header = $main_sheet->get_next_line()
        or die q{Missing header in: }, $wb->get_filename(), qq{\n};
    my @san_header = map { canonical_header( $_ ) } @{ $header };

    my @presenters_by_column = ();

    foreach my $column ( keys @{ $header } ) {
        my $header_text = $header->[ $column ];
        my $info        = Presenter->lookup( $header_text, $column );
        $presenters_by_column[ $column ] = $info if defined $info;
    }

    while ( my $raw = $main_sheet->get_next_line() ) {
        last unless defined $raw;
        my $panel = read_panel_(
            $header, \@san_header, \@presenters_by_column,
            $raw
        );
        process_panel_( $panel );
    } ## end while ( my $raw = $main_sheet...)

    $main_sheet->release() if defined $main_sheet;
    undef $main_sheet;

    return;
} ## end sub read_from

sub read_spreadsheet_file {
    my ( $filename ) = @_;

    my $wb = Workbook->new( filename => $filename );
    if ( !defined $wb || !$wb->get_is_open() ) {
        die q{Unable to read }, $filename, qq{\n};
    }

    Table::Room::read_from( $wb );

    Table::PanelType::read_from( $wb );

    Table::Panel::read_from( $wb );

    $wb->release() if defined $wb;
    undef $wb;

    return;
} ## end sub read_spreadsheet_file

1;
