#!/usr/bin/perl

use common::sense;
use Carp         qw{verbose croak};
use Date::Parse  qw{ str2time };
use English      qw( -no_match_vars );
use File::Slurp  qw{read_file};
use File::Spec   qw{};
use FindBin      qw{};
use Getopt::Long qw{GetOptionsFromArray};
use HTML::Tiny   qw{};
use Readonly;
use strict;
use utf8;

use lib "${FindBin::Bin}/lib";
use ActivePanel       qw{};
use Canonical         qw{ :all };
use Data::Panel       qw{};
use Data::PanelType   qw{};
use Data::Room        qw{};
use Options           qw{};
use Presenter         qw{};
use Table::Panel      qw{ :all };
use Table::PanelType  qw{ :all };
use Table::Room       qw{ :all };
use Table::TimeRegion qw{ :all };
use TimeDecoder       qw{ :from_text :to_text :timepoints};
use TimeRange         qw{};
use TimeRegion        qw{};
use TimeSlot          qw{};
use Workbook          qw{};
use Workbook::Sheet   qw{};

# HTML Elements
Readonly our $HTML_ANCHOR     => q{a};
Readonly our $HTML_BODY       => q{body};
Readonly our $HTML_COLGROUP   => q{colgroup};
Readonly our $HTML_DIV        => q{div};
Readonly our $HTML_HEAD       => q{head};
Readonly our $HTML_HTML       => q{html};
Readonly our $HTML_STYLE      => q{style};
Readonly our $HTML_TABLE      => q{table};
Readonly our $HTML_TABLE_BODY => q{tbody};
Readonly our $HTML_TABLE_DATA => q{td};
Readonly our $HTML_TABLE_FOOT => q{tfoot};
Readonly our $HTML_TABLE_HEAD => q{thead};
Readonly our $HTML_TABLE_ROW  => q{tr};

# CSS Classes
Readonly our $CLASS_DESC_BASE                => q{desc};
Readonly our $CLASS_DESC_PANEL_ROW           => q{descPanelRow};
Readonly our $CLASS_DESC_SECTION             => q{descriptions};
Readonly our $CLASS_DESC_TIME_COLUMN         => q{descTimeSlotColumn};
Readonly our $CLASS_DESC_TIME_HEADER         => q{descTimeSlotRowHeader};
Readonly our $CLASS_DESC_TIME_SLOT           => q{descTimeSlot};
Readonly our $CLASS_DESC_TIME_TABLE          => q{descTimeSlotTable};
Readonly our $CLASS_DESC_TYPE_COLUMN         => q{descTypeColumn};
Readonly our $CLASS_DESC_TYPE_HEADER         => q{descTypeHeader};
Readonly our $CLASS_DESC_TYPE_TABLE          => q{descTypeTable};
Readonly our $CLASS_GRID_CELL_DAY            => q{schedWeekDay};
Readonly our $CLASS_GRID_CELL_EMPTY          => q{schedRoomEmpty};
Readonly our $CLASS_GRID_CELL_BASE           => q{panel};
Readonly our $CLASS_GRID_CELL_FOCUS          => q{roomFocus};
Readonly our $CLASS_GRID_CELL_HEADER         => q{schedHeader};
Readonly our $CLASS_GRID_CELL_PRESENTER_BUSY => q{schedTimeSlotGuestBusy};
Readonly our $CLASS_GRID_CELL_ROOM_NAME      => q{schedRoomName};
Readonly our $CLASS_GRID_CELL_TIME_SLOT      => q{schedTimeSlot};
Readonly our $CLASS_GRID_CELL_UNFOCUS        => q{roomUnfocus};
Readonly our $CLASS_GRID_COLUMN_DAY          => q{schedColumnDay};
Readonly our $CLASS_GRID_COLUMN_FMT_ROOM_IDX => q{schedColumnRoom%s};
Readonly our $CLASS_GRID_COLUMN_ROOM         => q{schedColumnsRoom};
Readonly our $CLASS_GRID_COLUMN_TIME         => q{schedColumnTime};
Readonly our $CLASS_GRID_ROW_HEADER          => q{schedRowHeaders};
Readonly our $CLASS_GRID_ROW_PRESENTER_BUSY  => q{schedRowTimeSlotGuestBusy};
Readonly our $CLASS_GRID_ROW_TIME_SLOT       => q{schedRowTimeSlot};
Readonly our $CLASS_GRID_TABLE               => q{schedule};
Readonly our $CLASS_KIOSK_BAR                => q{top_bar};
Readonly our $CLASS_KIOSK_COLUMN_CURRENT     => q{descColCurrent};
Readonly our $CLASS_KIOSK_COLUMN_FUTURE      => q{descColNext};
Readonly our $CLASS_KIOSK_COLUMN_ROOM        => q{descColRoom};
Readonly our $CLASS_KIOSK_DESC_BODY          => q{descBody};
Readonly our $CLASS_KIOSK_DESC_CELL_CURRENT  => q{descCurrent};
Readonly our $CLASS_KIOSK_DESC_CELL_EMPTY    => q{descEmpty};
Readonly our $CLASS_KIOSK_DESC_CELL_FUTURE   => q{descNext};
Readonly our $CLASS_KIOSK_DESC_CELL_HEADER   => q{descHeader};
Readonly our $CLASS_KIOSK_DESC_CELL_ROOM     => q{descRoom};
Readonly our $CLASS_KIOSK_DESC_HEAD          => q{descHead};
Readonly our $CLASS_KIOSK_DESC_ROW_HEADERS   => q{descRowHeader};
Readonly our $CLASS_KIOSK_DESC_ROW_ROOM      => q{descRowRoom};
Readonly our $CLASS_KIOSK_DESCRIPTIONS       => q{bottom_half};
Readonly our $CLASS_KIOSK_GRID_HEADERS       => q{table_headers};
Readonly our $CLASS_KIOSK_GRID_ROWS          => q{table_rows};
Readonly our $CLASS_KIOSK_HIDDEN             => q{inactiveDesc};
Readonly our $CLASS_KIOSK_LOGO               => q{logo};
Readonly our $CLASS_KIOSK_TIME               => q{time};

# CSS Subclasses
Readonly our $SUBCLASS_BUSY_PANEL        => q{ConflictGuest};
Readonly our $SUBCLASS_FMT_DIFFICULTY    => q{Difficulty%s};
Readonly our $SUBCLASS_FMT_TYPE          => q{Type%s};
Readonly our $SUBCLASS_FULL              => q{Full};
Readonly our $SUBCLASS_GUEST_PANEL       => q{SelectedGuest};
Readonly our $SUBCLASS_NEED_COST         => q{NeedCost};
Readonly our $SUBCLASS_PIECE_COST        => q{Cost};
Readonly our $SUBCLASS_PIECE_DESCRIPTION => q{Description};
Readonly our $SUBCLASS_PIECE_DIFFICULTY  => q{Difficulty};
Readonly our $SUBCLASS_PIECE_FULL        => q{FullLabel};
Readonly our $SUBCLASS_PIECE_ID          => q{ID};
Readonly our $SUBCLASS_PIECE_NAME        => q{Name};
Readonly our $SUBCLASS_PIECE_NOTE        => q{Note};
Readonly our $SUBCLASS_PIECE_PARTS_LINE  => q{PartsLine};
Readonly our $SUBCLASS_PIECE_PARTS_LIST  => q{ListParts};
Readonly our $SUBCLASS_PIECE_PARTS_NUM   => q{PartsNum};
Readonly our $SUBCLASS_PIECE_PARTS_TIME  => q{PartsTime};
Readonly our $SUBCLASS_PIECE_PRESENTER   => q{Panelist};
Readonly our $SUBCLASS_PIECE_ROOM        => q{RoomName};
Readonly our $SUBCLASS_PIECE_START       => q{Start};

# Grid headers
Readonly our $HEADING_DAY  => q{Day};
Readonly our $HEADING_TIME => q{Time};

# Color styles
Readonly our $RE_COLOR_STYLE =>
    qr{ \A (?: all: | print: | screen: )? [+] (?i:(?:panel_)?color) (?: = | \z ) }xms;

# Grid filter
Readonly our $FILTER_SPLIT_TIMESTAMP => q{timestamp};
Readonly our $FILTER_PRESENTER       => q{presenter};
Readonly our $FILTER_ROOM            => q{room};
Readonly our $FILTER_OUTPUT_NAME     => q{subname};
Readonly our $DEFAULT_FILTER         => { $FILTER_OUTPUT_NAME => [], };
Readonly our $FILTER_ROOM_DESC_HIDE  => q{hidden};
Readonly our $FILTER_ROOM_CLASSES    => q{class};

Readonly our $FILTER_SET_UNFOCUS => {
    $FILTER_ROOM_DESC_HIDE => 1,
    $FILTER_ROOM_CLASSES   => [ $CLASS_GRID_CELL_UNFOCUS ]
};

Readonly our $FILTER_SET_FOCUS =>
    { $FILTER_ROOM_CLASSES => [ $CLASS_GRID_CELL_FOCUS ] };

Readonly our $FILTER_SET_DEFAULT => {};

my $options;

my $output_file_handle;
my $output_file_name;
my $level = 0;
my $h     = HTML::Tiny->new( mode => q{html} );

sub join_subclass {
    my ( $base, @subclasses ) = @_;

    $base //= q{};
    foreach my $subclass ( @subclasses ) {
        next unless defined $subclass;
        $subclass =~ s{\A(\w)}{\u$1}xms if ( $base =~ m{\w\z}xms );
        $base .= $subclass;
    }
    return if $base eq q{};
    return $base;
} ## end sub join_subclass

sub read_spreadsheet_file {
    my $wb = Workbook->new( filename => $options->get_input_file() );
    if ( !defined $wb || !$wb->get_is_open() ) {
        die q{Unable to read }, $options->get_input_file(), qq{\n};
    }

    Table::Room::read_from( $wb );

    foreach my $room_name ( $options->get_rooms_shown() ) {
        my $room = Table::Room::lookup( $room_name );
        next unless defined $room;
        $room->set_room_is_shown();
    }
    foreach my $room_name ( $options->get_rooms_hidden() ) {
        my $room = Table::Room::lookup( $room_name );
        next unless defined $room;
        $room->set_room_is_hidden();
    }

    Table::PanelType::read_from( $wb );

    foreach my $paneltype_name ( $options->get_paneltypes_shown() ) {
        my $paneltype = Table::PanelType::lookup( $paneltype_name );
        next unless defined $paneltype;
        $paneltype->make_shown();
    }
    foreach my $paneltype_name ( $options->get_paneltypes_hidden() ) {
        my $paneltype = Table::PanelType::lookup( $paneltype_name );
        next unless defined $paneltype;
        $paneltype->make_hidden();
    }

    Table::Panel::read_from( $wb );

    $wb->release() if defined $wb;
    undef $wb;

    return;
} ## end sub read_spreadsheet_file

sub out_line {
    my ( @content ) = @_;
    my $indent      = join q{}, ( qq{\t} x $level );
    my $content     = join q{}, @content;
    foreach my $line ( split m{\n+}xms, $content ) {
        $line =~ s{\A\s+}{}xms;
        $line =~ s{\s+\Z}{}xms;
        next if $line eq q{};
        say { $output_file_handle } $indent, $line
            or die qq{Error writing ${output_file_name}: ${ERRNO}\n};
    } ## end foreach my $line ( split m{\n+}xms...)

    return;
} ## end sub out_line

sub out_css_open {
    my ( @content ) = @_;
    out_line @content, q[ {];
    ++$level;

    return;
} ## end sub out_css_open

sub out_css_close {
    my ( @content ) = @_;
    unshift @content, q{ } if @content;
    --$level;
    out_line q[}], @content;

    return;
} ## end sub out_css_close

sub out_open {
    my ( @content ) = @_;
    out_line $h->open( @content );
    ++$level;

    return;
} ## end sub out_open

sub out_close {
    my ( @content ) = @_;
    --$level;
    out_line $h->close( @content );

    return;
} ## end sub out_close

sub out_class {
    my ( @fields ) = @_;
    return unless @fields;
    my $res = join q{ }, @fields;
    $res =~ s{\s\s+}{ }xms;
    $res =~ s{\A\s}{}xms;
    $res =~ s{\s\z}{}xms;
    return if $res eq q{};
    return class => $res;
} ## end sub out_class

sub get_rooms_for_region {
    my ( $region ) = @_;

    my @rooms = grep { !$_->get_room_is_hidden() } Table::Room::all_rooms();

    return @rooms if $options->show_all_rooms();
    return @rooms if !defined $region;
    return grep { $region->is_room_active( $_ ) } @rooms;
} ## end sub get_rooms_for_region

sub room_id_focus_map {
    my ( $filter, $region ) = @_;

    my @region_rooms = get_rooms_for_region( $region );

    if ( exists $filter->{ $FILTER_ROOM } ) {
        my %res
            = map { $_->get_room_id() => $FILTER_SET_UNFOCUS } @region_rooms;
        $res{ $filter->{ $FILTER_ROOM }->get_room_id() }
            = $FILTER_SET_FOCUS;
        return %res;
    } ## end if ( exists $filter->{...})

    if ( $options->has_rooms() ) {
        my %res;
        my $def_class = [];
    ROOM:
        foreach my $room ( @region_rooms ) {
            my $room_id = $room->get_room_id();
            my $name    = $room->get_long_room_name();
            foreach my $match ( $options->get_rooms() ) {
                if ( $name =~ m{\Q$match\E}xmsi ) {
                    $res{ $room_id } = $FILTER_SET_FOCUS;
                    next ROOM;
                }
            } ## end foreach my $match ( $options...)
            $res{ $room_id } = $FILTER_SET_UNFOCUS;
        } ## end ROOM: foreach my $room ( @region_rooms)
        return %res;
    } ## end if ( $options->has_rooms...)

    return map { $_->get_room_id() => $FILTER_SET_DEFAULT } @region_rooms;
} ## end sub room_id_focus_map

sub dump_grid_row_room_names {
    my ( $filter, $kind, $room_focus_map ) = @_;

    if ( $options->show_day_column() ) {
        out_line $h->th(
            {   out_class(
                    $CLASS_GRID_CELL_HEADER,
                    $kind eq $HTML_TABLE_HEAD
                    ? $CLASS_GRID_COLUMN_DAY
                    : ()
                )
            },
            $HEADING_DAY
        );
    } ## end if ( $options->show_day_column...)
    out_line $h->th(
        {   out_class(
                $CLASS_GRID_CELL_HEADER,
                $kind eq $HTML_TABLE_HEAD ? $CLASS_GRID_COLUMN_TIME : ()
            )
        },
        $HEADING_TIME
    );

    my @rooms = sort map { Data::Room->find_by_room_id( $_ ) }
        keys %{ $room_focus_map };

    foreach my $room ( @rooms ) {
        my $room_id = $room->get_room_id();
        my $hotel   = $room->get_hotel_room();
        my $name    = $room->get_long_room_name();
        if ( defined $hotel && $hotel ne $name && !$options->is_mode_kiosk() )
        {
            $name = $name . $h->br() . $h->i( $hotel );
        }
        out_line $h->th(
            {   out_class(
                    $CLASS_GRID_CELL_HEADER,
                    $CLASS_GRID_COLUMN_ROOM,
                    $CLASS_GRID_CELL_ROOM_NAME,
                    @{  $room_focus_map->{ $room_id }
                            ->{ $FILTER_ROOM_CLASSES }
                    },
                    $kind eq $HTML_TABLE_HEAD
                    ? ( sprintf $CLASS_GRID_COLUMN_FMT_ROOM_IDX,
                        $room->get_sort_key()
                        )
                    : (),
                )
            },
            $name
        );
    } ## end foreach my $room ( @rooms )

    return;
} ## end sub dump_grid_row_room_names

sub dump_grid_header {
    my ( $filter, $region, $room_focus_map ) = @_;

    out_open $HTML_TABLE,
        {
        out_class(
            $CLASS_GRID_TABLE,
            join_subclass(
                $CLASS_GRID_TABLE,
                canonical_class( $region->get_region_name() )
            )
        )
        };

    out_open $HTML_COLGROUP;

    if ( $options->show_day_column() ) {
        out_line $h->col( { out_class( $CLASS_GRID_COLUMN_DAY ) } );
    }
    out_line $h->col( { out_class( $CLASS_GRID_COLUMN_TIME ) } );

    my @rooms = sort map { Data::Room->find_by_room_id( $_ ) }
        keys %{ $room_focus_map };

    foreach my $room ( @rooms ) {
        out_line $h->col( {
            out_class(
                sprintf $CLASS_GRID_COLUMN_FMT_ROOM_IDX,
                $room->get_sort_key()
            )
        } );
    } ## end foreach my $room ( @rooms )

    out_close $HTML_COLGROUP;

    out_open $HTML_TABLE_HEAD;
    out_open $HTML_TABLE_ROW, { out_class( $CLASS_GRID_ROW_HEADER ) };
    dump_grid_row_room_names(
        $filter, $HTML_TABLE_HEAD,
        $room_focus_map
    );
    out_close $HTML_TABLE_ROW;
    out_close $HTML_TABLE_HEAD;

    out_open $HTML_TABLE_BODY;

    return;
} ## end sub dump_grid_header

sub css_subclasses_for_panel {
    my ( $panel ) = @_;

    return q{} unless defined $panel;

    my $panel_type = $panel->get_panel_type();
    my @subclasses = ( q{} );

    push @subclasses, sprintf $SUBCLASS_FMT_TYPE,
        uc $panel_type->get_prefix();

    my $difficulty = $panel->get_difficulty();
    if ( defined $difficulty && $difficulty =~ m{\A[[:alnum:]]+\z}xms ) {
        push @subclasses, sprintf $SUBCLASS_FMT_DIFFICULTY, $difficulty;
    }

    if ( defined $panel->get_cost() ) {
        push @subclasses, $SUBCLASS_NEED_COST;
    }

    if ( $panel->get_is_full() ) {
        push @subclasses, $SUBCLASS_FULL;
    }

    return @subclasses;
} ## end sub css_subclasses_for_panel

sub dump_grid_row_cell_group {
    my ( $filter, $room_focus_map, $time_slot, $panel_state, @rooms ) = @_;

    return unless @rooms;

    if ( !defined $panel_state ) {
        foreach ( @rooms ) {
            out_line $h->td( { out_class( $CLASS_GRID_CELL_EMPTY ) } );
        }
        return;
    } ## end if ( !defined $panel_state)

    my $time  = $time_slot->get_start_seconds();
    my $panel = $panel_state->get_active_panel();

    if ( $panel_state->get_start_seconds() != $time ) {
        foreach ( @rooms ) {
            out_line q{<!--}, $panel->get_uniq_id(), q{ continued-->};
        }
        return;
    } ## end if ( $panel_state->get_start_seconds...)

    my $first_room = $rooms[ 0 ];

    my $name               = $panel->get_name();
    my $credited_presenter = $panel->get_credits();
    my $panel_type         = $panel->get_panel_type();

    if ( $panel_type->is_cafe() ) {
        $credited_presenter = $name;
        $name               = q{Café featuring};
    }

    my @subclasses = css_subclasses_for_panel( $panel );
    if ( exists $filter->{ $FILTER_PRESENTER } ) {
        my $presenter = $filter->{ $FILTER_PRESENTER };
        if ( $panel->is_presenter_hosting( $presenter ) ) {
            push @subclasses, $SUBCLASS_GUEST_PANEL;
        }
        elsif ( $time_slot->is_presenter_hosting( $presenter ) ) {
            push @subclasses, $SUBCLASS_BUSY_PANEL;
        }
    } ## end if ( exists $filter->{...})

    push @subclasses,
        @{ $room_focus_map->{ $first_room->get_room_id() }
            ->{ $FILTER_ROOM_CLASSES } };

    my $row_span = $panel_state->get_rows() // 1;
    my $col_span = scalar @rooms            // 1;
    my @spans;
    push @spans, rowspan => $row_span if $row_span > 1;
    push @spans, colspan => $col_span if $col_span > 1;

    out_open $HTML_TABLE_DATA,
        {
        id => $panel->get_href_anchor() . q{Grid},
        @spans,
        out_class(
            $CLASS_GRID_COLUMN_ROOM,
            map { join_subclass( $CLASS_GRID_CELL_BASE, $_ ) } @subclasses
        )
        };

    out_open $HTML_ANCHOR, { href => q{#} . $panel->get_href_anchor() }
        if $options->show_sect_descriptions();

    out_line $h->div(
        {   out_class( join_subclass(
                $CLASS_GRID_CELL_BASE, $SUBCLASS_PIECE_ID ) )
        },
        $panel->get_uniq_id()
    );

    if ( $panel->get_is_full() ) {
        out_line $h->div(
            {   out_class( join_subclass(
                    $CLASS_GRID_CELL_BASE, $SUBCLASS_PIECE_FULL
                ) )
            },
            q{Workshop is Full}
        );
    } ## end if ( $panel->get_is_full...)
    out_line $h->span(
        {   out_class( join_subclass(
                $CLASS_GRID_CELL_BASE, $SUBCLASS_PIECE_NAME
            ) )
        },
        $name
    );

    my $cost = $panel->get_cost();
    if ( defined $cost && $panel->get_uniq_id_part() == 1 ) {
        out_line $h->div(
            {   out_class(
                    map { join_subclass( $CLASS_GRID_CELL_BASE, $_ ) } (
                        $SUBCLASS_PIECE_COST,
                    )
                )
            },
            $cost
        );
    } ## end if ( defined $cost && ...)

    if ( defined $credited_presenter ) {
        out_line $h->span(
            {   out_class( join_subclass(
                    $CLASS_GRID_CELL_BASE, $SUBCLASS_PIECE_PRESENTER
                ) )
            },
            $credited_presenter
        );
    } ## end if ( defined $credited_presenter)

    out_close $HTML_ANCHOR if $options->show_sect_descriptions();
    out_close $HTML_TABLE_DATA;

    shift @rooms;
    foreach ( @rooms ) {
        out_line q{<!--}, $panel->get_uniq_id(), q{ continued-->};
    }

    return;
} ## end sub dump_grid_row_cell_group

sub dump_grid_row_make_cell_groups {
    my ( $filter, $region, $room_focus_map, $time_slot ) = @_;

    my @rooms = sort map { Data::Room->find_by_room_id( $_ ) }
        keys %{ $room_focus_map };

    my $current = $time_slot->get_current();

    my @room_queue;
    my $last_room;
    my $last_state;
    foreach my $room ( @rooms ) {
        next unless defined $room;
        my $state = $current->{ $room->get_room_id() };
        if (   scalar @room_queue
            && defined $state
            && defined $last_state
            && $state->get_active_panel() == $last_state->get_active_panel()
            && $state->get_start_seconds() == $last_state->get_start_seconds()
            && $state->get_end_seconds() == $last_state->get_end_seconds()
            && $last_state->get_rows() == $state->get_rows()
            && $room_focus_map->{ $last_room->get_room_id() }
            == $room_focus_map->{ $room->get_room_id() } ) {
            push @room_queue, $room;
            next;
        } ## end if ( scalar @room_queue...)

        dump_grid_row_cell_group(
            $filter,     $room_focus_map, $time_slot,
            $last_state, @room_queue
        ) if @room_queue;

        @room_queue = ( $room );
        $last_room  = $room;
        $last_state = $state;
    } ## end foreach my $room ( @rooms )

    dump_grid_row_cell_group(
        $filter,     $room_focus_map, $time_slot,
        $last_state, @room_queue
    ) if @room_queue;

    return;
} ## end sub dump_grid_row_make_cell_groups

sub dump_grid_row_time {
    my ( $filter, $region, $room_focus_map, $time_slot ) = @_;

    my $time             = $time_slot->get_start_seconds();
    my @time_row_classes = $CLASS_GRID_ROW_TIME_SLOT;
    my @time_classes     = (
        $CLASS_GRID_CELL_HEADER, $CLASS_GRID_CELL_TIME_SLOT,
        $CLASS_GRID_COLUMN_TIME,
    );

    if ( exists $filter->{ $FILTER_PRESENTER } ) {
        my $presenter = $filter->{ $FILTER_PRESENTER };
        if ( $time_slot->is_presenter_hosting( $presenter ) ) {
            push @time_row_classes, $CLASS_GRID_ROW_PRESENTER_BUSY;
            push @time_classes,     $CLASS_GRID_CELL_PRESENTER_BUSY;
        }
    } ## end if ( exists $filter->{...})

    my $time_id = q{sched_id_} . datetime_to_kiosk_id( $time );
    out_open $HTML_TABLE_ROW,
        { out_class( @time_row_classes ), id => $time_id };

    if ( $options->show_day_column() ) {
        out_line $h->th(
            {   out_class(
                    $CLASS_GRID_CELL_HEADER, $CLASS_GRID_CELL_DAY,
                    $CLASS_GRID_COLUMN_DAY
                )
            },
            datetime_to_text( $time, qw{ day } )
        );
        out_line $h->th(
            { out_class( @time_classes ) },
            datetime_to_text( $time, qw{ time } )
        );
    } ## end if ( $options->show_day_column...)
    else {
        my ( $day, $tm ) = datetime_to_text( $time );
        my @before_time;

        if (   $region->get_last_output_time() == $time
            || $region->get_day_being_output() ne $day ) {
            push @before_time, $day, $h->br();
            $region->set_day_being_output( $day );
        }
        out_line $h->th(
            { out_class( @time_classes ) },
            join q{}, @before_time, $tm
        );
    } ## end else [ if ( $options->show_day_column...)]

    dump_grid_row_make_cell_groups(
        $filter, $region, $room_focus_map,
        $time_slot
    );

    out_close $HTML_TABLE_ROW;

    return;
} ## end sub dump_grid_row_time

sub dump_grid_footer {
    my ( $filter, $room_focus_map ) = @_;

    out_close $HTML_TABLE_BODY;
    out_open $HTML_TABLE_FOOT;
    out_open $HTML_TABLE_ROW, { out_class( $CLASS_GRID_ROW_HEADER ) };
    dump_grid_row_room_names(
        $filter, $HTML_TABLE_FOOT,
        $room_focus_map
    );
    out_close $HTML_TABLE_ROW;
    out_close $HTML_TABLE_FOOT;
    out_close $HTML_TABLE;

    return;
} ## end sub dump_grid_footer

sub dump_grid_timeslice {
    my ( $filter, $region ) = @_;

    $region->set_day_being_output( q{} );
    my @times = sort { $a <=> $b } $region->get_unsorted_times();
    $region->set_last_output_time( $times[ -1 ] );

    return unless @times;

    # todo(dpfister) Filter for times?

    my %room_focus_map = room_id_focus_map( $filter, $region );

    dump_grid_header( $filter, $region, \%room_focus_map );
    foreach my $time ( @times ) {
        dump_grid_row_time(
            $filter, $region, \%room_focus_map,
            $region->get_time_slot( $time )
        );
    } ## end foreach my $time ( @times )
    dump_grid_footer( $filter, \%room_focus_map );

    return;
} ## end sub dump_grid_timeslice

sub dump_desc_header {
    my ( $filter, $region, $show_unbusy_panels ) = @_;

    if ( exists $filter->{ $FILTER_PRESENTER } ) {
        my $presenter = $filter->{ $FILTER_PRESENTER };

        my $hdr_text
            = $show_unbusy_panels
            ? q{Other panels}
            : q{Schedule for } . $presenter->get_presenter_name();

        if ( $options->is_mode_postcard() ) {
            out_open $HTML_TABLE, { out_class( $CLASS_DESC_TYPE_TABLE ) };
            out_open $HTML_COLGROUP;
            out_line $h->col( { out_class( $CLASS_DESC_TYPE_COLUMN ) } );
            out_close $HTML_COLGROUP;

            out_line $h->thead(
                { out_class( $CLASS_DESC_TYPE_HEADER ) },
                $h->tr( $h->th(
                    { out_class( $CLASS_DESC_TYPE_COLUMN ) },
                    $hdr_text
                ) )
            );
            out_open $HTML_TABLE_BODY;
            out_open $HTML_TABLE_ROW;
            out_open $HTML_TABLE_DATA;
        } ## end if ( $options->is_mode_postcard...)
        else {
            out_line $h->h2( $hdr_text );
        }
    } ## end if ( exists $filter->{...})

    state $my_idx = 0;
    my $alt_class = $CLASS_DESC_SECTION . ( ++$my_idx );
    out_open $HTML_DIV, { out_class( $CLASS_DESC_SECTION, $alt_class ) };

    return;
} ## end sub dump_desc_header

sub dump_desc_footer {
    my ( $filter, $region, $show_unbusy_panels ) = @_;

    out_close $HTML_DIV;

    if ( exists $filter->{ $FILTER_PRESENTER } ) {
        if ( $options->is_mode_postcard() ) {
            out_close $HTML_TABLE_DATA;
            out_close $HTML_TABLE_ROW;
            out_close $HTML_TABLE_BODY;
            out_close $HTML_TABLE;
        } ## end if ( $options->is_mode_postcard...)
    } ## end if ( exists $filter->{...})

    return;
} ## end sub dump_desc_footer

sub dump_desc_time_start {
    my ( $time, @hdr_suffix ) = @_;

    if ( $options->is_desc_form_div() ) {
        out_line $h->div(
            { out_class( $CLASS_DESC_TIME_SLOT ) }, join q{ },
            datetime_to_text( $time, qw{ both } ),
            @hdr_suffix
        );
    } ## end if ( $options->is_desc_form_div...)
    else {
        out_open $HTML_TABLE, { out_class( $CLASS_DESC_TIME_TABLE ) };
        out_open $HTML_COLGROUP;
        out_line $h->col( { out_class( $CLASS_DESC_TIME_COLUMN ) } );
        out_close $HTML_COLGROUP;

        out_line $h->thead(
            { out_class( $CLASS_DESC_TIME_HEADER ) },
            $h->tr( $h->th(
                {   out_class(
                        $CLASS_DESC_TIME_COLUMN, $CLASS_DESC_TIME_SLOT
                    )
                },
                join q{ },
                datetime_to_text( $time, qw{ both } ),
                @hdr_suffix
            ) )
        );

        out_open $HTML_TABLE_BODY;
    } ## end else [ if ( $options->is_desc_form_div...)]

    return;
} ## end sub dump_desc_time_start

sub dump_desc_time_end {
    my ( $time ) = @_;

    if ( $options->is_desc_form_table() ) {
        out_close $HTML_TABLE_BODY;
        out_close $HTML_TABLE;
    }

    return;
} ## end sub dump_desc_time_end

sub dump_desc_panel_note {
    my ( $panel, $conflict ) = @_;

    my @note;
    if ( $conflict ) {
        push @note, $h->b( q{Conflicts with one of your panels.} );
    }
    if ( defined $panel->get_cost() ) {
        push @note, $h->b( q{Premium workshop:} ),
            ( $panel->get_capacity()
            ? q{ (Capacity: } . $panel->get_capacity() . q{)}
            : () ),
            $panel->get_cost_is_model()
            ? q{ Requires a model which may be purchased separately.}
            : $panel->get_cost_is_missing()
            ? q{ May require a separate purchase.}
            : q{ Requires a separate purchase.};
    } ## end if ( defined $panel->get_cost...)
    if ( defined $panel->get_note() ) {
        push @note, $h->i( $panel->get_note() );
    }
    if ( $options->show_av() ) {
        push @note,
            $h->b( q{Audio/Visual: } )
            . $h->i( $panel->get_av_note() // $h->b( q{No notes} ) );
    }
    if ( $panel->get_is_full() ) {
        push @note,
            $h->span(
            {   out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_FULL ) )
            },
            q{This workshop is full.}
            );
    } ## end if ( $panel->get_is_full...)
    if ( defined $panel->get_difficulty() && $options->show_difficulty() ) {
        push @note, $h->span(
            {   out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_DIFFICULTY
                ) )
            },
            q{Difficulty level: } . $panel->get_difficulty()
        );
    } ## end if ( defined $panel->get_difficulty...)
    if ( @note ) {
        out_line $h->p(
            {   out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_NOTE ) )
            },
            join q{ },
            @note
        );
    } ## end if ( @note )
    return;
} ## end sub dump_desc_panel_note

sub dump_desc_panel_parts {
    my ( $panel ) = @_;

    my $part   = $panel->get_uniq_id_part();
    my @series = grep {
        defined $_->get_start_seconds() && $_->get_uniq_id_part() != $part
    } get_related_panels( $panel );

    return unless @series;

    @series = sort {
               $a->get_uniq_id_part()  <=> $b->get_uniq_id_part()
            || $a->get_start_seconds() <=> $b->get_start_seconds()
    } @series;

    out_line $h->ul(
        {   out_class( join_subclass(
                $CLASS_DESC_BASE, $SUBCLASS_PIECE_PARTS_LIST
            ) )
        },
        join q{ },
        map {
            $h->li(
                {   out_class( join_subclass(
                        $CLASS_DESC_BASE, $SUBCLASS_PIECE_PARTS_LINE
                    ) )
                },
                $h->a(
                    { href => q{#} . $_->get_href_anchor() },
                    join q{ },
                    $h->span(
                        {   out_class( join_subclass(
                                $CLASS_DESC_BASE, $SUBCLASS_PIECE_PARTS_NUM
                            ) )
                        },
                        q{Part } . $_->get_uniq_id_part() . q{: }
                    ),
                    $h->span(
                        {   out_class( join_subclass(
                                $CLASS_DESC_BASE, $SUBCLASS_PIECE_PARTS_TIME
                            ) )
                        },
                        datetime_to_text( $_->get_start_seconds() )
                    )
                )
            )
        } @series
    );

    return;
} ## end sub dump_desc_panel_parts

sub should_panel_desc_be_dumped {
    my ( $filter, $room_focus_map, $panel_state, $show_unbusy_panels, $time )
        = @_;

    my $room = $panel_state->get_room();
    return unless defined $room;
    my $id = $room->get_room_id();
    return if $room_focus_map->{ $id }->{ $FILTER_ROOM_DESC_HIDE };

    my $panel = $panel_state->get_active_panel();

    return unless $panel->get_start_seconds() == $time;

    return if $panel->get_panel_type()->get_is_hidden();

    if ( $panel_state->get_is_break() ) {
        return if $options->hide_breaks();
    }
    else {
        return if $room->get_room_is_hidden();

        # Only worry about presenters for non-break panels
        my $filter_panelist = $filter->{ $FILTER_PRESENTER };
        if ( defined $filter_panelist ) {
            if ( $panel->is_presenter_hosting( $filter_panelist ) ) {
                return if $show_unbusy_panels;
            }
            else {
                return unless $show_unbusy_panels;
            }
        } ## end if ( defined $filter_panelist)
    } ## end else [ if ( $panel_state->get_is_break...)]

    return 1
        if defined $panel->get_cost()
        ? $options->show_cost_premium()
        : $options->show_cost_free();

    return;
} ## end sub should_panel_desc_be_dumped

sub dump_desc_panel_body {
    my ( $filter, $time_slot, $panel_state, @extra_classes ) = @_;

    if ( !defined $panel_state ) {
        return if $options->is_desc_form_div();
        out_line $h->td(
            { out_class( @extra_classes, $CLASS_KIOSK_DESC_CELL_EMPTY ) } );
        return;
    } ## end if ( !defined $panel_state)

    my $panel      = $panel_state->get_active_panel();
    my $panel_type = $panel->get_panel_type();

    my @subclasses = css_subclasses_for_panel( $panel );
    my $conflict;

    if ( exists $filter->{ $FILTER_PRESENTER } ) {
        my $presenter = $filter->{ $FILTER_PRESENTER };
        if ( $panel->is_presenter_hosting( $presenter ) ) {
            push @subclasses, $SUBCLASS_GUEST_PANEL;
        }
        elsif ( $time_slot->is_presenter_hosting( $presenter ) ) {
            push @subclasses, $SUBCLASS_BUSY_PANEL;
            $conflict = 1;
        }
    } ## end if ( exists $filter->{...})

    my $name               = $panel->get_name();
    my $credited_presenter = $panel->get_credits();

    if ( $panel_type->is_cafe() ) {
        $name = q{Cosplay Café Featuring } . $name;
    }

    my $desc_element
        = $options->is_desc_form_div() ? $HTML_DIV : $HTML_TABLE_DATA;

    out_open $desc_element,
        {
        id => $panel->get_href_anchor(),
        out_class(
            @extra_classes,
            map { join_subclass( $CLASS_DESC_BASE, $_ ) } @subclasses
        )
        };
    out_open $HTML_DIV if $options->is_mode_kiosk();
    out_line $h->div(
        {   out_class(
                join_subclass( $CLASS_DESC_BASE, $SUBCLASS_PIECE_ID )
            )
        },
        $panel->get_uniq_id()
    );
    if ( $options->show_sect_grid() ) {
        out_line $h->a(
            {   href => q{#} . $panel->get_href_anchor() . q{Grid},
                out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_NAME ) )
            },
            $name
        );
    } ## end if ( $options->show_sect_grid...)
    else {
        out_line $h->div(
            {   out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_NAME ) )
            },
            $name
        );
    } ## end else [ if ( $options->show_sect_grid...)]

    my $cost = $panel->get_cost();
    if ( defined $cost && $panel->get_uniq_id_part() == 1 ) {
        out_line $h->div(
            {   out_class(
                    map { join_subclass( $CLASS_DESC_BASE, $_ ) } (
                        $SUBCLASS_PIECE_COST,
                    )
                )
            },
            $cost
        );
    } ## end if ( defined $cost && ...)
    if ( $options->is_mode_kiosk() ) {
        out_line $h->p(
            {   out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_START
                ) )
            },
            datetime_to_text( $panel->get_start_seconds(), qw{ both } )
        );
    } ## end if ( $options->is_mode_kiosk...)
    else {
        out_line $h->p(
            {   out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_ROOM ) )
            },
            join q{, },
            map { $_->get_long_room_name() } $panel->get_rooms()
        );
    } ## end else [ if ( $options->is_mode_kiosk...)]
    if ( defined $credited_presenter ) {
        out_line $h->p(
            {   out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_PRESENTER
                ) )
            },
            $credited_presenter
        );
    } ## end if ( defined $credited_presenter)

    out_line $h->p(
        {   out_class( join_subclass(
                $CLASS_DESC_BASE, $SUBCLASS_PIECE_DESCRIPTION
            ) )
        },
        $panel->get_description()
    );

    dump_desc_panel_note( $panel, $conflict );
    dump_desc_panel_parts( $panel );

    out_close $HTML_DIV if $options->is_mode_kiosk();
    out_close $desc_element;

    return;
} ## end sub dump_desc_panel_body

sub dump_desc_body {
    my ( $filter, $region, $room_focus_map, $show_unbusy_panels, $on_dump )
        = @_;
    my $filter_panelist = $filter->{ $FILTER_PRESENTER };

    $region->set_day_being_output( q{} );
    my @times = sort { $a <=> $b } $region->get_unsorted_times();
    $region->set_last_output_time( $times[ -1 ] );

    foreach my $time ( @times ) {
        my $time_header_seen;
        my $time_slot           = $region->get_time_slot( $time );
        my $panels_for_timeslot = $time_slot->get_current();

        my @panel_states = values %{ $panels_for_timeslot };
        @panel_states
            = sort { $a->get_room() <=> $b->get_room() } @panel_states;

        my %panel_dumped;

        foreach my $panel_state ( @panel_states ) {
            next
                unless should_panel_desc_be_dumped(
                $filter, $room_focus_map, $panel_state,
                $show_unbusy_panels,
                $time
                );

            my $panel_uid
                = $panel_state->get_active_panel()->get_panel_internal_id();
            next if $panel_dumped{ $panel_uid };
            $panel_dumped{ $panel_uid } = 1;

            if ( !defined $time_header_seen ) {
                $time_header_seen = 1;

                $on_dump->() if defined $on_dump;

                my @hdr_extra;
                if (   $show_unbusy_panels
                    && $time_slot->is_presenter_hosting( $filter_panelist ) )
                {
                    push @hdr_extra, qw{ Conflict };
                }
                dump_desc_time_start( $time, @hdr_extra );
            } ## end if ( !defined $time_header_seen)

            if ( $options->is_desc_form_table() ) {
                out_open $HTML_TABLE_ROW,
                    { out_class( $CLASS_DESC_PANEL_ROW ) };
            }
            dump_desc_panel_body( $filter, $time_slot, $panel_state );
            if ( $options->is_desc_form_table() ) {
                out_close $HTML_TABLE_ROW;
            }
        } ## end foreach my $panel_state ( @panel_states)
        if ( $time_header_seen ) {
            dump_desc_time_end( $time );
        }
    } ## end foreach my $time ( @times )

    return;
} ## end sub dump_desc_body

sub dump_desc_body_regions {
    my ( $filter, $region, $show_unbusy_panels, $on_dump ) = @_;
    if ( defined $region ) {
        my %room_focus_map = room_id_focus_map( $filter, $region );
        dump_desc_body(
            $filter,             $region, \%room_focus_map,
            $show_unbusy_panels, $on_dump
        );
        return;
    } ## end if ( defined $region )

    foreach my $region ( get_time_regions() ) {
        my %room_focus_map = room_id_focus_map( $filter, $region );
        dump_desc_body(
            $filter,             $region, \%room_focus_map,
            $show_unbusy_panels, $on_dump
        );
    } ## end foreach my $region ( get_time_regions...)

    return;
} ## end sub dump_desc_body_regions

sub dump_desc_timeslice {
    my ( $filter, $region ) = @_;

    my @filters = ( $filter );
    @filters = split_filter_by_panelist(
        {   by_guest    => $options->is_desc_by_guest()    ? 1 : 0,
            by_panelist => $options->is_desc_by_panelist() ? 1 : 0,
            is_by_desc  => 1
        },
        @filters
    );

    foreach my $desc_filter ( @filters ) {
        my $on_dump;
        my $header_dumped;
        $on_dump = sub {
            return if $header_dumped;
            $header_dumped = 1;
            dump_desc_header( $desc_filter, $region );
        };
        dump_desc_body_regions( $desc_filter, $region, 0, $on_dump );
        dump_desc_footer( $desc_filter, $region ) if $header_dumped;
        $header_dumped = undef;

        if (   exists $desc_filter->{ $FILTER_PRESENTER }
            && $options->is_just_everyone()
            && $options->is_desc_everyone_together() ) {
            dump_desc_body_regions( $desc_filter, $region, 1, $on_dump );
            dump_desc_footer( $desc_filter, $region, 1 )
                if $header_dumped;
            $header_dumped = undef;
        } ## end if ( exists $desc_filter...)
    } ## end foreach my $desc_filter ( @filters)

    return;
} ## end sub dump_desc_timeslice

sub cache_inline_style {
    my ( $file ) = @_;
    return unless defined $file;
    state %cache;
    if (   !File::Spec->file_name_is_absolute( $file )
        && !-e $file
        && -e File::Spec->catfile( q{css}, $file ) ) {
        $file = File::Spec->catfile( q{css}, $file );
    }
    return $cache{ $file } //= read_file(
        $file,
        { chomp => 1, array_ref => 1, err_mode => q{carp} }
    );
} ## end sub cache_inline_style

sub open_dump_file {
    my ( $filter, $def_name ) = @_;
    $def_name //= q{index};

    if ( $options->is_output_stdio() ) {
        $output_file_handle = \*STDOUT;
        $output_file_name   = q{<STDOUT>};
        return;
    }

    my @subnames
        = map { canonical_header $_ } @{ $filter->{ $FILTER_OUTPUT_NAME } };

    my $ofname = $options->get_output_file();
    if ( -d $ofname ) {
        push @subnames, $def_name unless @subnames;
        $ofname = File::Spec->catfile(
            $ofname, join q{.}, @subnames,
            q{html}
        );
    } ## end if ( -d $ofname )
    elsif ( @subnames ) {
        my ( $vol, $dir, $base ) = File::Spec->splitpath( $ofname );
        my $suffix = q{html};
        if ( $base =~ s{[.](html?)\z}{}xms ) {
            $suffix = $1;
        }
        $base = join q{.}, $base, @subnames, $suffix;

        $ofname = File::Spec->catpath( $vol, $dir, $base );
    } ## end elsif ( @subnames )

    ## no critic(RequireBriefOpen)

    open $output_file_handle, q{>:encoding(utf8)}, $ofname
        or die qq{Unable to write: ${ofname}\n};

    ## use critic

    $output_file_name = $ofname;
    return;
} ## end sub open_dump_file

sub close_dump_file {
    if ( !$options->is_output_stdio() && defined $output_file_handle ) {
        $output_file_handle->close
            or die qq{Unable to close ${output_file_name}: ${ERRNO}\n};
    }
    undef $output_file_handle;
    undef $output_file_name;

    return;
} ## end sub close_dump_file

sub open_html_style {
    my ( $state ) = @_;

    return if defined $state->{ in_style };

    out_open $HTML_STYLE;
    $state->{ in_style } = 1;
    return;
} ## end sub open_html_style

sub open_media_style {
    my ( $state, $media ) = @_;

    open_html_style $state;

    if ( !defined $media ) {
        if ( defined $state->{ in_media } ) {
            out_css_close;
            delete $state->{ in_media };
        }
        return;
    } ## end if ( !defined $media )

    if ( defined $state->{ in_media } ) {
        return if $state->{ in_media } eq $media;

        # Switching media
        out_css_close;
    } ## end if ( defined $state->{...})

    out_css_open q{@}, q{media }, $media;
    $state->{ in_media } = $media;

    return;
} ## end sub open_media_style

sub close_media_style {
    my ( $state ) = @_;

    my $in_media = delete $state->{ in_media };
    return unless defined $in_media;
    out_css_close;

    return;
} ## end sub close_media_style

sub close_html_style {
    my ( $state ) = @_;

    close_media_style $state;

    my $in_style = delete $state->{ in_style };
    return unless defined $in_style;

    out_close $HTML_STYLE;

    return;
} ## end sub close_html_style

sub dump_styles {
    my %state;

    foreach my $style ( $options->get_styles() ) {
        my $is_html = $style =~ m{.html?\z}xms;
        my $fname   = $style;
        my $media;
        if ( $fname =~ s{\A (all|print|screen) :}{}xms ) {
            $media = $1;
        }
        elsif ( $fname =~ m{(all|print|screen)[.]css\z}xms ) {
            $media = $1;
        }

        if ( $is_html ) {
            close_html_style \%state;

            my $lines = cache_inline_style( $fname );
            foreach my $line ( @{ $lines } ) {
                out_line $line;
            }
        } ## end if ( $is_html )
        elsif ( $fname =~ $RE_COLOR_STYLE ) {
            my ( $unused, $color_set ) = split m{=}xms, $fname, 2;
            $color_set //= q{Color};
            $color_set = canonical_header( $color_set );

            my $line_seen;

            foreach my $panel_type (
                sort { $a->get_prefix() cmp $b->get_prefix() }
                Table::PanelType::all_types() ) {
                my $prefix = $panel_type->get_prefix();
                next unless $prefix =~ m{\S}xms;
                my $color = $panel_type->get_color( $color_set );
                next unless defined $color;
                next
                    unless $color
                    =~ m{\A ( [#] [[:xdigit:]]++ | inherit | black | white | rgba? [\(] .* ) \z}xms;

                open_media_style \%state, $media;
                open_media_style \%state, $media;

                out_line q{/* "}, $style, q{" */} unless $line_seen;
                $line_seen = 1;

                out_line q{.descType}, uc $prefix, q{,};
                out_css_open q{.panelType}, uc $prefix;
                out_line q{background-color: }, $color;
                out_css_close;
            } ## end foreach my $panel_type ( sort...)
        } ## end elsif ( $fname =~ $RE_COLOR_STYLE)
        elsif ( $options->is_css_loc_embedded() ) {
            my $lines = cache_inline_style( $fname );
            my $line_seen;

            foreach my $line ( @{ $lines } ) {
                next unless $line =~ m{\S}xms;
                next if $line     =~ m{[@]charset}xmsi;
                next
                    if $line =~ m{\A \s* /[*] (?:[^*]++:[*][^/])*+ [*]/ }xms;
                open_media_style \%state, $media;
                out_line q{/* "}, $style, q{" */} unless $line_seen;
                $line_seen = 1;
                out_line $line;
            } ## end foreach my $line ( @{ $lines...})
        } ## end elsif ( $options->is_css_loc_embedded...)
        else {
            close_html_style \%state;

            out_line $h->link( {
                href => $fname,
                rel  => q{stylesheet},
                type => q{text/css},
                ( defined $media ? ( media => $media ) : () )
            } );
        } ## end else [ if ( $is_html ) ]
    } ## end foreach my $style ( $options...)
    close_media_style \%state;
    close_html_style \%state;

    return;
} ## end sub dump_styles

sub dump_file_header {
    my ( $filter ) = @_;

    say { $output_file_handle } q{<!doctype html>}
        or die qq{Error writing ${output_file_name}: ${ERRNO}\n};

    out_open $HTML_HTML;
    out_open $HTML_HEAD;
    out_line $h->meta( { charset => q{UTF-8} } );
    out_line $h->meta(
        { name => q{apple-mobile-web-app-capable}, content => q{yes} } );

    my @subnames = @{ $filter->{ $FILTER_OUTPUT_NAME } };
    my $title    = $options->get_title();
    if ( @subnames ) {
        $title .= q{: } . join q{, }, @subnames;
    }

    out_line $h->title( $title );
    out_line $h->link( {
        href =>
            q{https://fonts.googleapis.com/css?family=Nunito+Sans&display=swap},
        rel => q{stylesheet}
    } );

    dump_styles;

    out_close $HTML_HEAD;

    return;
} ## end sub dump_file_header

sub dump_file_footer {
    out_close $HTML_HTML;

    return;
}

sub dump_table_one_region {
    my ( $filter ) = @_;

    if ( $options->show_sect_grid() ) {
        dump_grid_timeslice(
            $filter,
            $filter->{ $FILTER_SPLIT_TIMESTAMP }
        );
    } ## end if ( $options->show_sect_grid...)
    if ( $options->show_sect_descriptions() ) {
        dump_desc_timeslice(
            $filter,
            $filter->{ $FILTER_SPLIT_TIMESTAMP }
        );
    } ## end if ( $options->show_sect_descriptions...)

    return;
} ## end sub dump_table_one_region

sub dump_table_all_regions {
    my ( $filter ) = @_;

    my $need_all_desc = $options->show_sect_descriptions();

    if ( $options->show_sect_grid() ) {
        foreach my $region ( get_time_regions() ) {
            dump_grid_timeslice( $filter, $region );
            next unless $options->show_sect_descriptions();
            next if $options->is_desc_loc_last();

            dump_desc_timeslice( $filter, $region );
            undef $need_all_desc;
        } ## end foreach my $region ( get_time_regions...)
        return if $options->is_desc_loc_mixed();
    } ## end if ( $options->show_sect_grid...)

    if ( $need_all_desc ) {
        dump_desc_timeslice( $filter, undef );
    }

    return;
} ## end sub dump_table_all_regions

sub dump_tables {
    my ( $filter ) = @_;

    open_dump_file( $filter );

    dump_file_header( $filter );

    out_open $HTML_BODY;

    if ( exists $filter->{ $FILTER_SPLIT_TIMESTAMP } ) {
        dump_table_one_region( $filter );
    }
    else {
        dump_table_all_regions( $filter );
    }

    out_close $HTML_BODY;

    dump_file_footer;
    close_dump_file;

    return;
} ## end sub dump_tables

sub dump_kiosk_desc {
    my ( $region ) = @_;

    my @times        = sort { $a <=> $b } $region->get_unsorted_times();
    my @region_rooms = get_rooms_for_region( $region );
    foreach my $time ( @times ) {
        my $time_id = q{desc_id_} . datetime_to_kiosk_id( $time );
        out_open $HTML_DIV,
            {
            out_class( $CLASS_KIOSK_DESCRIPTIONS, $CLASS_KIOSK_HIDDEN ),
            id => $time_id
            };
        out_open $HTML_TABLE, { out_class( $CLASS_DESC_TIME_TABLE ) };
        out_open $HTML_COLGROUP;
        out_line $h->col( { out_class( $CLASS_KIOSK_COLUMN_ROOM ) } );
        out_line $h->col( { out_class( $CLASS_KIOSK_COLUMN_CURRENT ) } );
        out_line $h->col( { out_class( $CLASS_KIOSK_COLUMN_FUTURE ) } );
        out_close $HTML_COLGROUP;
        out_open $HTML_TABLE_HEAD,
            { out_class( $CLASS_KIOSK_DESC_HEAD ) };
        out_open $HTML_TABLE_ROW,
            { out_class( $CLASS_KIOSK_DESC_ROW_HEADERS ) };
        out_line $h->th( {
            out_class(
                $CLASS_KIOSK_COLUMN_ROOM,
                $CLASS_KIOSK_DESC_CELL_HEADER
            )
        } );
        out_line $h->th(
            {   out_class(
                    $CLASS_KIOSK_COLUMN_CURRENT,
                    $CLASS_KIOSK_DESC_CELL_HEADER
                )
            },
            q{Current Panel}
        );
        out_line $h->th(
            {   out_class(
                    $CLASS_KIOSK_COLUMN_FUTURE,
                    $CLASS_KIOSK_DESC_CELL_HEADER
                )
            },
            q{Upcoming Panel}
        );
        out_close $HTML_TABLE_ROW;
        out_close $HTML_TABLE_HEAD;
        out_open $HTML_TABLE_BODY,
            { out_class( $CLASS_KIOSK_DESC_BODY ) };
        my $time_slot   = $region->get_time_slot( $time );
        my $cur_panels  = $time_slot->get_current();
        my $next_panels = $time_slot->get_upcoming();

        foreach my $room ( @region_rooms ) {
            my $id    = $room->get_room_id();
            my $hotel = $room->get_hotel_room();
            my $name  = $room->get_long_room_name();
            if ( $hotel ne $name ) {
                $name = $hotel . $h->br() . $name;
            }
            out_open $HTML_TABLE_ROW,
                { out_class( $CLASS_KIOSK_DESC_ROW_ROOM ) };
            out_line $h->th(
                {   out_class(
                        $CLASS_KIOSK_DESC_CELL_ROOM,
                        $CLASS_KIOSK_DESC_CELL_HEADER
                    )
                },
                $name
            );
            dump_desc_panel_body(
                $DEFAULT_FILTER, $time_slot,
                $cur_panels->{ $id },
                $CLASS_KIOSK_DESC_CELL_CURRENT
            );
            dump_desc_panel_body(
                $DEFAULT_FILTER, $time_slot,
                $next_panels->{ $id },
                $CLASS_KIOSK_DESC_CELL_FUTURE
            );
            out_close $HTML_TABLE_ROW;
        } ## end foreach my $room ( @region_rooms)
        out_close $HTML_TABLE_BODY;
        out_close $HTML_TABLE;
        out_close $HTML_DIV;
    } ## end foreach my $time ( @times )

    return;
} ## end sub dump_kiosk_desc

sub dump_kiosk {
    open_dump_file( $DEFAULT_FILTER, q{kiosk} );

    say { $output_file_handle } q{<!doctype html>}
        or die qq{Error writing ${output_file_name}: ${ERRNO}\n};

    out_open $HTML_HTML;
    out_open $HTML_HEAD;
    out_line $h->meta( { charset => q{UTF-8} } );
    out_line $h->meta(
        { name => q{apple-mobile-web-app-capable}, content => q{yes} } );
    out_line $h->title( $options->get_title() );
    out_line $h->link( {
        href => q{css/kiosk.css},
        rel  => q{stylesheet},
        type => q{text/css}
    } );
    dump_styles;
    out_line $h->script(
        { type => q{text/javascript}, src => q{js/kiosk.js} } );

    out_close $HTML_HEAD;
    out_open $HTML_BODY;

    out_open $HTML_DIV, { out_class( $CLASS_KIOSK_BAR ) };
    out_line $h->img( {
        out_class( $CLASS_KIOSK_LOGO ),
        src => q{images/CosplayAmericaLogoAlt.svg},
        alt => q{Cosplay America}
    } );
    out_open $HTML_DIV,
        { out_class( $CLASS_KIOSK_TIME ), id => q{current_time} };
    out_line q{SOMEDAY ##:## ?M};
    out_close $HTML_DIV;
    out_close $HTML_DIV;

    out_line $h->div( { out_class( $CLASS_KIOSK_GRID_HEADERS ) } );
    out_open $HTML_DIV, { out_class( $CLASS_KIOSK_GRID_ROWS ) };
    foreach my $region ( get_time_regions() ) {
        dump_grid_timeslice( $DEFAULT_FILTER, $region );
    }
    out_close $HTML_DIV;

    foreach my $region ( get_time_regions() ) {
        dump_kiosk_desc( $region );
    }

    out_close $HTML_BODY;
    out_close $HTML_HTML;

    close_dump_file;

    return;
} ## end sub dump_kiosk

sub split_filter_by_timestamp {
    my ( @filters ) = @_;

    return @filters unless $options->is_file_by_day();

    my @res;
    foreach my $filter ( @filters ) {
        my %new_filter = %{ $filter };
        my @subname    = @{ $new_filter{ $FILTER_OUTPUT_NAME } };
        foreach my $region ( get_time_regions() ) {
            push @res,
                {
                %new_filter,
                $FILTER_SPLIT_TIMESTAMP => $region,
                $FILTER_OUTPUT_NAME     =>
                    [ @subname, $region->get_region_name() ],
                };
        } ## end foreach my $region ( get_time_regions...)
    } ## end foreach my $filter ( @filters)

    return @res;
} ## end sub split_filter_by_timestamp

sub split_filter_by_panelist {
    my ( $flags, @filters ) = @_;
    my $by_guest      = delete $flags->{ by_guest };
    my $by_presenters = delete $flags->{ by_panelist };
    my $is_by_desc    = delete $flags->{ is_by_desc };
    use Data::Dumper;
    croak q{Unrecognized parameter: },
        join q{, }, keys %{ $flags } if %{ $flags };

    return @filters
        unless ( $by_guest
        || $by_presenters );

    my @res;
    foreach my $filter ( @filters ) {
        if ( exists $filter->{ $FILTER_PRESENTER } ) {
            push @res, $filter;
            next;
        }
        my %new_filter = %{ $filter };
        my @subname    = @{ $new_filter{ $FILTER_OUTPUT_NAME } };
        foreach my $per_info ( Presenter->get_known() ) {
            next if $per_info->get_is_other();

            if ( $per_info->get_presenter_rank() == $Presenter::RANK_GUEST ) {
                next unless $by_guest;
            }
            else {
                next unless $by_presenters;
            }
            if ( $is_by_desc ) {
                next
                    if $per_info->get_is_meta()
                    || defined $per_info->is_in_group();
            }

            push @res,
                {
                %new_filter,
                $FILTER_PRESENTER   => $per_info,
                $FILTER_OUTPUT_NAME =>
                    [ @subname, $per_info->get_presenter_name() ],
                };
        } ## end foreach my $per_info ( Presenter...)
    } ## end foreach my $filter ( @filters)

    return @res;
} ## end sub split_filter_by_panelist

sub split_filter_by_room {
    my ( @filters ) = @_;

    return @filters unless $options->is_file_by_room();

    my @res;
    foreach my $filter ( @filters ) {
        my %new_filter = %{ $filter };
        my @subname    = @{ $new_filter{ $FILTER_OUTPUT_NAME } };
        foreach my $room ( get_rooms_for_region() ) {
            push @res,
                {
                %new_filter,
                $FILTER_ROOM        => $room,
                $FILTER_OUTPUT_NAME =>
                    [ @subname, $room->get_short_room_name() ],
                };
        } ## end foreach my $room ( get_rooms_for_region...)
    } ## end foreach my $filter ( @filters)

    return @res;
} ## end sub split_filter_by_room

sub main {
    my ( @args ) = @_;

    $options = Options->options_from( @args );

    foreach my $style ( $options->get_styles() ) {
        next unless $style =~ $RE_COLOR_STYLE;
        my ( $unused, $color_set ) = split m{=}xms, $style, 2;
        $color_set //= q{Color};
        Table::PanelType::add_color_set( $color_set );
    } ## end foreach my $style ( $options...)

    read_spreadsheet_file( $options->get_input_file() );

    populate_time_regions( $options );

    if ( $options->is_mode_kiosk() ) {
        dump_kiosk;
        return;
    }

    my @filters = ( $DEFAULT_FILTER );
    @filters = split_filter_by_panelist(
        {   by_guest    => $options->is_file_by_guest()    ? 1 : 0,
            by_panelist => $options->is_file_by_panelist() ? 1 : 0,
            is_by_desc  => undef
        },
        @filters
    );
    @filters = split_filter_by_room( @filters );
    @filters = split_filter_by_timestamp( @filters );

    foreach my $filter ( @filters ) {
        dump_tables( $filter );
    }

    exit 0;
} ## end sub main

main( @ARGV );

1;

__END__
