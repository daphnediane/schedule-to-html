#!/usr/bin/perl

use common::sense;
use Carp qw{verbose};
use Date::Parse qw{ str2time };
use English qw( -no_match_vars );
use FindBin qw{};
use File::Slurp qw{read_file};
use File::Spec;
use Getopt::Long qw{GetOptionsFromArray};
use HTML::Tiny qw{};
use Readonly;
use strict;
use utf8;

use lib "${FindBin::Bin}/lib";
use ActivePanel qw{};
use PanelField qw{};
use PanelInfo qw{};
use Presenter qw{};
use RoomField qw{};
use RoomHandle qw{};
use RoomInfo qw{};
use TimeDecoder qw{ :from_text :to_text :timepoints};
use TimeRange qw{};
use TimeRegion qw{};
use TimeSlot qw{};
use Workbook qw{};
use Workbook::Sheet qw{};

# Global variables
Readonly our $HALF_HOUR_IN_SEC => 30 * 60;

# PanelTypes fields
Readonly our $PANELTYPE_TABLE_PREFIX => q{Prefix};
Readonly our $PANELTYPE_TABLE_KIND   => q{Panel_Kind};

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
Readonly our $SUBCLASS_PIECE_DESCRIPTION => q{Description};
Readonly our $SUBCLASS_PIECE_DIFFICULTY  => q{Difficulty};
Readonly our $SUBCLASS_PIECE_FULL        => q{FullLabel};
Readonly our $SUBCLASS_PIECE_ID          => q{ID};
Readonly our $SUBCLASS_PIECE_NAME        => q{Name};
Readonly our $SUBCLASS_PIECE_NOTE        => q{Note};
Readonly our $SUBCLASS_PIECE_PRESENTER   => q{Panelist};
Readonly our $SUBCLASS_PIECE_ROOM        => q{RoomName};
Readonly our $SUBCLASS_PIECE_START       => q{Start};
Readonly our $SUBCLASS_PIECE_COST        => q{Cost};

# TODO Make this a class
# Time processing state
Readonly our $MTR_ACTIVE_REGION  => q{Region};
Readonly our $MTR_PANEL_STATES   => q{PanelStates};
Readonly our $MTR_LAST_TIME_SEEN => q{LastTime};
Readonly our $MTR_ACTIVE_BREAK   => q{ActiveBreak};
Readonly our $MTR_EMPTY_TIMES    => q{EmptyTimeSlots};

# Grid headers
Readonly our $HEADING_DAY  => q{Day};
Readonly our $HEADING_TIME => q{Time};

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

Readonly our $OPT_DESC_ALT_FORM        => q{desc-alt-form};
Readonly our $OPT_DESC_AT_END          => q{separate};
Readonly our $OPT_DESC_BY_COLUMNS      => q{desc-by-columns};     # Unused
Readonly our $OPT_DESC_BY_GUEST        => q{desc-by-guest};
Readonly our $OPT_DESC_BY_PRESENTER    => q{desc-by-presenter};
Readonly our $OPT_EMBED_CSS            => q{embed-css};
Readonly our $OPT_FILE_BY_DAY          => q{file-by-day};
Readonly our $OPT_FILE_BY_GUEST        => q{file-by-guest};
Readonly our $OPT_FILE_BY_PRESENTER    => q{file-by-presenter};
Readonly our $OPT_FILE_BY_ROOM         => q{file-by-room};
Readonly our $OPT_INPUT                => q{input};
Readonly our $OPT_JUST_PRESENTER       => q{just-presenter};
Readonly our $OPT_MODE_FLYER           => q{mode-flyer};
Readonly our $OPT_MODE_KIOSK           => q{mode-kiosk};
Readonly our $OPT_MODE_POSTCARD        => q{mode-postcard};
Readonly our $OPT_OUTPUT               => q{output};
Readonly our $OPT_ROOM                 => q{room};
Readonly our $OPT_SHOW_AV              => q{show-av};
Readonly our $OPT_SHOW_COST_FREE       => q{show-free};
Readonly our $OPT_SHOW_COST_PREMIUM    => q{show-premium};
Readonly our $OPT_SHOW_DAY_COLUMN      => q{show-day};
Readonly our $OPT_SHOW_DESCRIPTIONS    => q{show-descriptions};
Readonly our $OPT_SHOW_DIFFICULTY      => q{show-difficulty};
Readonly our $OPT_SHOW_ALL_ROOMS       => q{show-all-rooms};
Readonly our $OPT_SHOW_GRID            => q{show-grid};
Readonly our $OPT_SPLIT_NONE           => q{split-none};
Readonly our $OPT_SPLIT_PER_TIMEREGION => q{split-timeregion};
Readonly our $OPT_SPLIT_PER_DAY        => q{split-day};
Readonly our $OPT_STYLE                => q{style};
Readonly our $OPT_TIME_END             => q{end-time};
Readonly our $OPT_TIME_START           => q{start-time};
Readonly our $OPT_TITLE                => q{title};

my %opt = ();

my @all_rooms;
my %room_by_name;

my %panels_by_start;
my %panel_types;

my %time_split;
my %time_region;

my $output_file_handle;
my $output_file_name;
my $level = 0;
my $h     = HTML::Tiny->new( mode => q{html} );

sub register_time_split {
    my ( $time, $name ) = @_;
    $time_split{ $time } = $name;
    return $name;
}

sub check_if_new_region {
    my ( $time, $prev_region ) = @_;
    if ( defined $prev_region ) {
        return if $opt{ $OPT_SPLIT_NONE };
        return unless exists $time_split{ $time };
        if ( $opt{ $OPT_SPLIT_PER_DAY } ) {
            my $prev_time = $prev_region->get_start_seconds();
            my $prev_day  = datetime_to_text( $prev_time, qw{ day } );
            my $new_day   = datetime_to_text( $time, qw{ day } );
            return if $prev_day eq $new_day;
            $time_split{ $time } = $new_day;
        } ## end if ( $opt{ $OPT_SPLIT_PER_DAY...})
    } ## end if ( defined $prev_region)
    elsif ( $opt{ $OPT_SPLIT_NONE } ) {
        $time_split{ $time } //= q{Schedule};
    }
    elsif ( $opt{ $OPT_SPLIT_PER_DAY } ) {
        $time_split{ $time } = datetime_to_text( $time, qw{ day } );
    }
    else {
        $time_split{ $time } //= q{Before Convention};
    }

    my $region = $time_region{ $time } //= TimeRegion->new(
        name => $time_split{ $time }
            // q{From } . datetime_to_text( $time, qw{ both } ),
        start_time => $time,
    );
    return $region;
} ## end sub check_if_new_region

sub canonical_header {
    my ( $hdr ) = @_;
    $hdr =~ s{\s+}{_}xmsg;
    $hdr =~ s{[/:().,]}{_}xmsg;
    $hdr =~ s{_+}{_}xmsg;
    $hdr =~ s{\A_}{}xmsg;
    $hdr =~ s{_\z}{}xmsg;
    return $hdr;
} ## end sub canonical_header

sub canonical_class {
    my ( $class ) = @_;
    $class = canonical_header( $class );
    $class =~ s{_(\w)}{\u$1}xmsg;
    return $class;
} ## end sub canonical_class

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

sub to_presenter {
    my ( $per_info, $names ) = @_;

    return unless defined $per_info;
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
} ## end sub to_presenter

sub process_spreadsheet_room_sheet {
    my ( $header, $san_header, $raw ) = @_;

    my %room_data;

    foreach my $column ( keys @{ $raw } ) {
        my $header_text = $header->[ $column ];
        my $header_alt  = $san_header->[ $column ];

        my $raw_text = $raw->[ $column ];
        if ( defined $raw_text ) {
            if ( $raw_text =~ m{\s}xms ) {
                $raw_text =~ s{\A \s*}{}xms;
                $raw_text =~ s{\s* \z}{}xms;
            }
            undef $raw_text if $raw_text eq q{};
        } ## end if ( defined $raw_text)
        $room_data{ $header_text } = $raw_text;
        $room_data{ $header_alt }  = $raw_text;
    } ## end foreach my $column ( keys @...)

    my $short_name = $room_data{ $RoomField::NAME };
    my $long_name  = $room_data{ $RoomField::LONG_NAME } // $short_name;
    $short_name //= $long_name;

    return unless defined $short_name;

    my $room = $room_by_name{ lc $long_name }
        // $room_by_name{ lc $short_name };

    my $hotel = $room_data{ $RoomField::HOTEL };
    if ( !defined $room && defined $hotel ) {
        $room = $room_by_name{ lc $hotel };
    }

    if ( !defined $room ) {
        $room = RoomInfo->new(
            sort_key   => $room_data{ $RoomField::SORT_KEY },
            short_name => $short_name,
            long_name  => $long_name,
            hotel_room => $hotel,
        );
        push @all_rooms, $room;
    } ## end if ( !defined $room )

    $room_by_name{ lc $short_name } //= $room;
    $room_by_name{ lc $long_name }  //= $room;
    $room_by_name{ lc $hotel }      //= $room if defined $hotel;

    return;
} ## end sub process_spreadsheet_room_sheet

sub read_spreadsheet_rooms {
    my ( $wb ) = @_;

    my $sheet = $wb->sheet( q{Rooms} );
    return unless defined $sheet;
    return unless $sheet->get_is_open();

    my $header = $sheet->get_next_line();
    return unless defined $header;
    my @san_header = map { canonical_header( $_ ) } @{ $header };

    while ( my $raw = $sheet->get_next_line() ) {
        last unless defined $raw;

        process_spreadsheet_room_sheet( $header, \@san_header, $raw );
    }

    $sheet->release() if defined $sheet;
    undef $sheet;

    return;
} ## end sub read_spreadsheet_rooms

sub process_spreadsheet_paneltype_sheet {
    my ( $header, $san_header, $raw ) = @_;

    my %paneltype_data;

    foreach my $column ( keys @{ $raw } ) {
        my $header_text = $header->[ $column ];
        my $header_alt  = $san_header->[ $column ];

        my $raw_text = $raw->[ $column ];
        if ( defined $raw_text ) {
            if ( $raw_text =~ m{\s}xms ) {
                $raw_text =~ s{\A \s*}{}xms;
                $raw_text =~ s{\s* \z}{}xms;
            }
            undef $raw_text if $raw_text eq q{};
        } ## end if ( defined $raw_text)
        $paneltype_data{ $header_text } = $raw_text;
        $paneltype_data{ $header_alt }  = $raw_text;

    } ## end foreach my $column ( keys @...)

    my $prefix = $paneltype_data{ $PANELTYPE_TABLE_PREFIX } // q{};
    my $kind   = $paneltype_data{ $PANELTYPE_TABLE_KIND };

    return unless defined $kind;

    if ( exists $panel_types{ lc $prefix } ) {
        return if $prefix eq q{};
        warn q{Panel prefix: }, $prefix, q{ for }, $kind,
            qq{ defined twice\n};
        return;
    } ## end if ( exists $panel_types...)

    $panel_types{ lc $prefix } = \%paneltype_data;

    return;
} ## end sub process_spreadsheet_paneltype_sheet

sub read_spreadsheet_panel_types {
    my ( $wb ) = @_;

    my $sheet = $wb->sheet( q{PanelTypes} );
    return unless defined $sheet;
    return unless $sheet->get_is_open();

    my $header = $sheet->get_next_line();
    return unless defined $header;
    my @san_header = map { canonical_header( $_ ) } @{ $header };

    while ( my $raw = $sheet->get_next_line() ) {
        last unless defined $raw;

        process_spreadsheet_paneltype_sheet( $header, \@san_header, $raw );
    }

    $sheet->release() if defined $sheet;
    undef $sheet;

    return;
} ## end sub read_spreadsheet_panel_types

sub process_spreadsheet_add_presenter {
    my ( $presenter_set, $per_info_index, $raw_text ) = @_;

    return unless defined $raw_text;

    my $unlisted = $raw_text =~ m{\A[*]}xms || $raw_text =~ m{[*]\z}xms;

    my @presenters = to_presenter( $per_info_index, $raw_text );

    my $guest_seen;

    foreach my $per_info ( @presenters ) {
        if ( $unlisted ) {
            $presenter_set->add_unlisted_presenters( $per_info );
        }
        else {
            $presenter_set->add_credited_presenters( $per_info );
        }

        foreach my $grp_info ( $per_info->get_groups() ) {
            $presenter_set->add_unlisted_presenters( $grp_info );
        }

        $guest_seen //= 1
            if $per_info->get_presenter_rank() <= $Presenter::RANK_GUEST;
    } ## end foreach my $per_info ( @presenters)

    if ( $guest_seen ) {
        $presenter_set->add_unlisted_presenters( Presenter->any_guest() );
    }

    return;
} ## end sub process_spreadsheet_add_presenter

sub process_spreadsheet_workshop {
    my ( $panel ) = @_;
    my @subclasses;

    my $difficulty = $panel->get_difficulty();
    if ( defined $difficulty && $difficulty =~ m{\A[?]+\z}xms ) {
        undef $difficulty;
        $panel->set_difficulty();
    }
    if ( defined $difficulty && $difficulty =~ m{\A\d+\z}xms ) {
        push @subclasses, sprintf $SUBCLASS_FMT_DIFFICULTY, $difficulty;
    }

    if ( defined $panel->get_cost() ) {
        push @subclasses, $SUBCLASS_NEED_COST;
    }

    if ( $panel->get_is_full() ) {
        push @subclasses, $SUBCLASS_FULL;
    }

    return @subclasses;
} ## end sub process_spreadsheet_workshop

sub get_room_from_panel_data {
    my ( $panel_data ) = @_;

    my $room;
    my $short_name = $panel_data->{ $PanelField::ROOM_NAME };
    if ( defined $short_name ) {
        $room = $room_by_name{ lc $short_name };
        return $room if defined $room;
    }

    my $sort_key  = $panel_data->{ $PanelField::ROOM_SORT_KEY };
    my $long_name = $panel_data->{ $PanelField::ROOM_REAL_ROOM };
    if ( defined $long_name ) {
        $room = $room_by_name{ lc $long_name };
        return $room if defined $room;
    }
    $short_name //= $long_name;
    $long_name  //= $short_name;

    my $hotel = $panel_data->{ $PanelField::ROOM_HOTEL_ROOM };
    if ( defined $hotel ) {
        $room = $room_by_name{ lc $hotel };
        return $room if defined $room;
    }

    return unless defined $short_name;

    $room = RoomInfo->new(
        sort_key   => $sort_key,
        short_name => $short_name,
        long_name  => $long_name,
        hotel_room => $hotel,
    );
    push @all_rooms, $room;

    $room_by_name{ lc $short_name } //= $room;
    $room_by_name{ lc $long_name }  //= $room;
    $room_by_name{ lc $hotel }      //= $room if defined $hotel;

    return $room;
} ## end sub get_room_from_panel_data

sub process_spreadsheet_row {
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
            process_spreadsheet_add_presenter(
                $presenter_set,
                $presenters_by_column->[ $column ], $raw_text
            );
        } ## end if ( defined $presenters_by_column...)
    } ## end foreach my $column ( keys @...)

    $presenter_set->set_are_credits_hidden( 1 )
        if defined $panel_data{ $PanelField::PANELIST_HIDE };
    $presenter_set->set_override_credits(
        $panel_data{ $PanelField::PANELIST_ALT } );

    my $room = get_room_from_panel_data( \%panel_data );
    return unless defined $room;

    my $panel = PanelInfo->new(
        uniq_id       => $panel_data{ $PanelField::UNIQUE_ID },
        cost          => $panel_data{ $PanelField::COST },
        description   => $panel_data{ $PanelField::DESCRIPTION },
        difficulty    => $panel_data{ $PanelField::DIFFICULTY },
        duration      => $panel_data{ $PanelField::DURATION },
        end_time      => $panel_data{ $PanelField::END_TIME },
        is_full       => $panel_data{ $PanelField::FULL },
        name          => $panel_data{ $PanelField::PANEL_NAME },
        note          => $panel_data{ $PanelField::NOTE },
        av_note       => $panel_data{ $PanelField::AV_NOTE },
        panel_kind    => $panel_data{ $PanelField::PANEL_KIND },
        room          => $room,
        start_time    => $panel_data{ $PanelField::START_TIME },
        presenter_set => $presenter_set,
    );

    return unless defined $panel->get_start_seconds();

    return unless defined $panel->get_name();

    my $short_kind_id = lc $panel->get_uniq_id_prefix();

    if ( !defined $panel->get_panel_kind() ) {
        $panel->set_panel_kind(
            $panel_types{ $short_kind_id }->{ $PANELTYPE_TABLE_KIND } );
    }

    if ( $room->get_is_split() ) {
        register_time_split $panel->get_start_seconds(), $panel->get_name();
        return;
    }

    my @subclasses = sprintf $SUBCLASS_FMT_TYPE, uc $short_kind_id;

    push @subclasses, process_spreadsheet_workshop( $panel );

    $panel->set_css_subclasses( \@subclasses );

    mark_timepoint_seen( $panel->get_start_seconds() );
    mark_timepoint_seen( $panel->get_end_seconds() );

    push @{ $panels_by_start{ $panel->get_start_seconds() } //= [] }, $panel;

    return;
} ## end sub process_spreadsheet_row

sub read_spreadsheet_file {
    my $wb = Workbook->new( filename => $opt{ $OPT_INPUT } );
    if ( !defined $wb || !$wb->get_is_open() ) {
        die qq{Unable to read ${opt{ $OPT_INPUT }}\n};
    }

    read_spreadsheet_rooms( $wb );
    read_spreadsheet_panel_types( $wb );

    my $main_sheet = $wb->sheet();
    if ( !defined $main_sheet || !$main_sheet->get_is_open() ) {
        die qq{Unable to find schedule sheet for ${opt{ $OPT_INPUT }}\n};
    }

    my $header = $main_sheet->get_next_line()
        or die qq{Missing header in: ${opt{ $OPT_INPUT }}\n};
    my @san_header = map { canonical_header( $_ ) } @{ $header };

    my @presenters_by_column = ();

    foreach my $column ( keys @{ $header } ) {
        my $header_text = $header->[ $column ];
        my $info        = Presenter->lookup( $header_text, $column );
        $presenters_by_column[ $column ] = $info if defined $info;
    }

    while ( my $raw = $main_sheet->get_next_line() ) {
        last unless defined $raw;
        process_spreadsheet_row(
            $header, \@san_header, \@presenters_by_column,
            $raw
        );
    } ## end while ( my $raw = $main_sheet...)

    $main_sheet->release() if defined $main_sheet;
    $wb->release()         if defined $wb;

    undef $main_sheet;
    undef $wb;

    return;
} ## end sub read_spreadsheet_file

sub mtr_process_time {
    my ( $state, $time ) = @_;

    # Add new panels
    foreach my $panel ( @{ $panels_by_start{ $time } } ) {

        if ( $panel->get_room_is_hidden() ) {
            if ($panel->get_is_break()
                && ( !exists $state->{ $MTR_ACTIVE_BREAK }
                    || $panel->get_end_seconds()
                    > $state->{ $MTR_ACTIVE_BREAK }->get_end_seconds() )
            ) {
                $state->{ $MTR_ACTIVE_BREAK } = $panel;
            } ## end if ( $panel->get_is_break...)
            next;
        } ## end if ( $panel->get_room_is_hidden...)

        my $panel_state = ActivePanel->new(
            active_panel => $panel,
            rows         => 0,
            start_time   => $time,
            end_time     => $panel->get_end_seconds(),
            room         => $panel->get_room(),
        );

        $state->{ $MTR_PANEL_STATES }->{ $panel->get_room_id() }
            = $panel_state;
    } ## end foreach my $panel ( @{ $panels_by_start...})

    if ( exists $state->{ $MTR_ACTIVE_BREAK }
        && $state->{ $MTR_ACTIVE_BREAK }->get_end_seconds() <= $time ) {
        delete $state->{ $MTR_ACTIVE_BREAK };
    }
    foreach my $room ( @all_rooms ) {
        next if $room->get_room_is_hidden();
        my $room_id = $room->get_room_id();

        my $prev_state = $state->{ $MTR_PANEL_STATES }->{ $room_id };
        if ( defined $prev_state ) {
            my $prev_end = $prev_state->get_end_seconds();
            next if $prev_end > $time;
        }

        if ( !exists $state->{ $MTR_ACTIVE_BREAK } ) {
            delete $state->{ $MTR_PANEL_STATES }->{ $room_id };
            next;
        }

        my $panel_state = ActivePanel->new(
            active_panel => $state->{ $MTR_ACTIVE_BREAK },
            rows         => 0,
            start_time   => $time,
            end_time     => $state->{ $MTR_ACTIVE_BREAK }->get_end_seconds(),
            room         => $room,
            is_break     => 1,
        );
        $state->{ $MTR_PANEL_STATES }->{ $room_id } = $panel_state;
    } ## end foreach my $room ( @all_rooms)

    my %timeslot_info;
    while ( my ( $room_id, $panel_state )
        = each %{ $state->{ $MTR_PANEL_STATES } } ) {
        my $panel = $panel_state->get_active_panel();
        $timeslot_info{ $room_id } = $panel_state;

        $panel_state->increment_rows();
        $state->{ $MTR_ACTIVE_REGION }
            ->add_active_room( $panel_state->get_room() )
            unless $panel_state->get_is_break();

    } ## end while ( my ( $room_id, $panel_state...))

    if ( %timeslot_info ) {
        if ( exists $state->{ $MTR_EMPTY_TIMES } ) {
            foreach my $empty ( keys %{ $state->{ $MTR_EMPTY_TIMES } } ) {
                $state->{ $MTR_ACTIVE_REGION }->get_time_slot( $empty )
                    ->init_current( {} );
            }
            delete $state->{ $MTR_EMPTY_TIMES };
        } ## end if ( exists $state->{ ...})

        $state->{ $MTR_ACTIVE_REGION }->get_time_slot( $time )
            ->init_current( \%timeslot_info );

        $state->{ $MTR_LAST_TIME_SEEN } = $time;
    } ## end if ( %timeslot_info )
    elsif ( defined $state->{ $MTR_LAST_TIME_SEEN } ) {
        $state->{ $MTR_EMPTY_TIMES }->{ $time } = 1;
    }
    return;
} ## end sub mtr_process_time

sub mtr_process_half_hours_upto {
    my ( $state, $split_time ) = @_;
    return unless defined $state->{ $MTR_LAST_TIME_SEEN };

    my $time = $state->{ $MTR_LAST_TIME_SEEN } + $HALF_HOUR_IN_SEC;
    while ( $time < $split_time ) {
        mtr_process_time( $state, $time );
        $time += $HALF_HOUR_IN_SEC;
    }

    return;
} ## end sub mtr_process_half_hours_upto

sub mtr_finish_region {
    my ( $state ) = @_;

    return unless defined $state->{ $MTR_ACTIVE_REGION };
    return unless $opt{ $OPT_MODE_KIOSK };
    my @times
        = reverse sort { $a <=> $b }
        $state->{ $MTR_ACTIVE_REGION }->get_unsorted_times();
    my %next_panels = ();

    foreach my $time ( @times ) {
        my $time_slot
            = $state->{ $MTR_ACTIVE_REGION }->get_time_slot( $time );

        # Save current next panels
        $time_slot->init_upcoming( { %next_panels } );

        # Update next panels
        my $current_panels = $time_slot->get_current();
        while ( my ( $room_id, $panel_state ) = each %{ $current_panels } ) {
            next
                unless $panel_state->get_start_seconds() == $time;
            $next_panels{ $room_id } = $panel_state;
        }
    } ## end foreach my $time ( @times )

    return;
} ## end sub mtr_finish_region

sub mtr_check_for_next_region {
    my ( $state, $split_time ) = @_;

    my $next_range = check_if_new_region(
        $split_time,
        $state->{ $MTR_ACTIVE_REGION }
    );
    return unless defined $next_range;

    mtr_finish_region( $state );
    $state->{ $MTR_ACTIVE_REGION } = $next_range;
    delete $state->{ $MTR_EMPTY_TIMES };
    delete $state->{ $MTR_LAST_TIME_SEEN };

    return unless defined $state->{ $MTR_PANEL_STATES };

    my %new_active;
    while ( my ( $room_id, $panel_state )
        = each %{ $state->{ $MTR_PANEL_STATES } } ) {
        my $new_state = $panel_state->clone();
        $new_state->set_rows( 0 );
        $new_state->set_start_time( $split_time );
        $new_active{ $room_id } = $new_state;
    } ## end while ( my ( $room_id, $panel_state...))
    $state->{ $MTR_PANEL_STATES } = \%new_active;

    return;
} ## end sub mtr_check_for_next_region

sub make_time_ranges {
    my %time_points
        = map { $_ => 1 } ( keys %time_split, get_timepoints() );
    my $state = {};

    my @time_points = keys %time_points;
    my $first_time  = text_to_datetime( $opt{ $OPT_TIME_START } );
    @time_points = grep { $first_time <= $_ } @time_points
        if defined $first_time;
    my $final_time = text_to_datetime( $opt{ $OPT_TIME_END } );
    @time_points = grep { $final_time >= $_ } @time_points
        if defined $final_time;
    @time_points = sort { $a <=> $b } @time_points;

    foreach my $split_time ( @time_points ) {
        mtr_process_half_hours_upto( $state, $split_time )
            if defined $state->{ $MTR_PANEL_STATES }
            && %{ $state->{ $MTR_PANEL_STATES } };
        mtr_check_for_next_region( $state, $split_time );
        mtr_process_time( $state, $split_time );
    } ## end foreach my $split_time ( @time_points)
    mtr_finish_region( $state );

    return;
} ## end sub make_time_ranges

sub out_line {
    my ( @content ) = @_;
    my $indent = join q{}, ( qq{\t} x $level );
    my $content = join q{}, @content;
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

    my @rooms = grep { !$_->get_room_is_hidden() } @all_rooms;

    return @rooms if $opt{ $OPT_SHOW_ALL_ROOMS };
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

    if ( defined $opt{ $OPT_ROOM } ) {
        my %res;
        my $def_class = [];
    ROOM:
        foreach my $room ( @region_rooms ) {
            my $room_id = $room->get_room_id();
            my $name    = $room->get_long_room_name();
            foreach my $match ( @{ $opt{ $OPT_ROOM } } ) {
                if ( $name =~ m{\Q$match\E}xmsi ) {
                    $res{ $room_id } = $FILTER_SET_FOCUS;
                    next ROOM;
                }
            } ## end foreach my $match ( @{ $opt...})
            $res{ $room_id } = $FILTER_SET_UNFOCUS;
        } ## end ROOM: foreach my $room ( @region_rooms)
        return %res;
    } ## end if ( defined $opt{ $OPT_ROOM...})

    return map { $_->get_room_id() => $FILTER_SET_DEFAULT } @region_rooms;
} ## end sub room_id_focus_map

sub dump_grid_row_room_names {
    my ( $filter, $kind, $room_focus_map ) = @_;

    if ( $opt{ $OPT_SHOW_DAY_COLUMN } ) {
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
    } ## end if ( $opt{ $OPT_SHOW_DAY_COLUMN...})
    out_line $h->th(
        {   out_class(
                $CLASS_GRID_CELL_HEADER,
                $kind eq $HTML_TABLE_HEAD ? $CLASS_GRID_COLUMN_TIME : ()
            )
        },
        $HEADING_TIME
    );

    my @rooms = sort map { RoomInfo->find_by_room_id( $_ ) }
        keys %{ $room_focus_map };

    foreach my $room ( @rooms ) {
        my $room_id = $room->get_room_id();
        my $hotel   = $room->get_hotel_room();
        my $name    = $room->get_long_room_name();
        if ( $hotel ne $name && !$opt{ $OPT_MODE_KIOSK } ) {
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
                        $room->get_room_id()
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

    if ( $opt{ $OPT_SHOW_DAY_COLUMN } ) {
        out_line $h->col( { out_class( $CLASS_GRID_COLUMN_DAY ) } );
    }
    out_line $h->col( { out_class( $CLASS_GRID_COLUMN_TIME ) } );

    my @rooms = sort map { RoomInfo->find_by_room_id( $_ ) }
        keys %{ $room_focus_map };

    foreach my $room ( @rooms ) {
        out_line $h->col( {
            out_class(
                sprintf $CLASS_GRID_COLUMN_FMT_ROOM_IDX,
                $room->get_room_id()
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

sub dump_grid_cell_room {
    my ( $filter, $region, $room_focus_map, $time_slot, $room ) = @_;

    my $panel_state = $time_slot->get_current()->{ $room->get_room_id() };
    if ( !defined $panel_state ) {
        out_line $h->td( { out_class( $CLASS_GRID_CELL_EMPTY ) } );
        return;
    }

    my $time  = $time_slot->get_start_seconds();
    my $panel = $panel_state->get_active_panel();

    if ( $panel_state->get_start_seconds() != $time ) {
        out_line q{<!--}, $panel->get_uniq_id(), q{ continued-->};
        return;
    }

    my $name               = $panel->get_name();
    my $credited_presenter = $panel->get_credits();

    if ( $panel->get_panel_is_cafe() ) {
        $credited_presenter = $name;
        $name               = q{Café featuring};
    }

    my @subclasses = ( q{}, @{ $panel->get_css_subclasses() } );
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
        @{ $room_focus_map->{ $room->get_room_id() }->{ $FILTER_ROOM_CLASSES }
        };

    out_open $HTML_TABLE_DATA,
        {
        id      => $panel->get_href_anchor() . q{Grid},
        rowspan => $panel_state->get_rows() // 1,
        out_class(
            $CLASS_GRID_COLUMN_ROOM,
            map { join_subclass( $CLASS_GRID_CELL_BASE, $_ ) } @subclasses
        )
        };

    out_open $HTML_ANCHOR, { href => q{#} . $panel->get_href_anchor() }
        if $opt{ $OPT_SHOW_DESCRIPTIONS };

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
    if ( defined $cost && $cost !~ m{ \A part }xmsi ) {
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

    out_close $HTML_ANCHOR if $opt{ $OPT_SHOW_DESCRIPTIONS };
    out_close $HTML_TABLE_DATA;

    return;
} ## end sub dump_grid_cell_room

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

    if ( $opt{ $OPT_SHOW_DAY_COLUMN } ) {
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
    } ## end if ( $opt{ $OPT_SHOW_DAY_COLUMN...})
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
    } ## end else [ if ( $opt{ $OPT_SHOW_DAY_COLUMN...})]

    my @rooms = sort map { RoomInfo->find_by_room_id( $_ ) }
        keys %{ $room_focus_map };

    foreach my $room ( @rooms ) {
        dump_grid_cell_room(
            $filter, $region, $room_focus_map, $time_slot,
            $room
        );
    } ## end foreach my $room ( @rooms )
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

        if ( $opt{ $OPT_MODE_POSTCARD } ) {
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
        } ## end if ( $opt{ $OPT_MODE_POSTCARD...})
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
        if ( $opt{ $OPT_MODE_POSTCARD } ) {
            out_close $HTML_TABLE_DATA;
            out_close $HTML_TABLE_ROW;
            out_close $HTML_TABLE_BODY;
            out_close $HTML_TABLE;
        } ## end if ( $opt{ $OPT_MODE_POSTCARD...})
    } ## end if ( exists $filter->{...})

    return;
} ## end sub dump_desc_footer

sub dump_desc_time_start {
    my ( $time, @hdr_suffix ) = @_;

    if ( $opt{ $OPT_DESC_ALT_FORM } ) {
        out_line $h->div(
            { out_class( $CLASS_DESC_TIME_SLOT ) }, join q{ },
            datetime_to_text( $time, qw{ both } ),
            @hdr_suffix
        );
    } ## end if ( $opt{ $OPT_DESC_ALT_FORM...})
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
    } ## end else [ if ( $opt{ $OPT_DESC_ALT_FORM...})]

    return;
} ## end sub dump_desc_time_start

sub dump_desc_time_end {
    my ( $time ) = @_;

    if ( !$opt{ $OPT_DESC_ALT_FORM } ) {
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
    if ( defined $panel->get_cost() && $panel->get_cost() !~ m{model}xmsi ) {
        push @note, $h->b( q{Premium workshop:} ),
            q{ Requires a separate purchase.};
    }
    if ( defined $panel->get_note() ) {
        push @note, $h->i( $panel->get_note() );
    }
    if ( $opt{ $OPT_SHOW_AV } ) {
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
    if ( defined $panel->get_difficulty() && $opt{ $OPT_SHOW_DIFFICULTY } ) {
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

sub should_panel_desc_be_dumped {
    my ( $filter, $room_focus_map, $panel_state, $show_unbusy_panels, $time )
        = @_;

    my $id = $panel_state->get_room_id();
    return if $room_focus_map->{ $id }->{ $FILTER_ROOM_DESC_HIDE };

    my $panel = $panel_state->get_active_panel();

    return unless $panel->get_start_seconds() == $time;

    return if ( $panel->get_room_is_hidden() );

    my $filter_panelist = $filter->{ $FILTER_PRESENTER };
    if ( defined $filter_panelist ) {
        if ( $panel->is_presenter_hosting( $filter_panelist ) ) {
            return if $show_unbusy_panels;
        }
        else {
            return unless $show_unbusy_panels;
        }
    } ## end if ( defined $filter_panelist)

    return 1 if $opt{    #
        defined $panel->get_cost()
        ? $OPT_SHOW_COST_PREMIUM
        : $OPT_SHOW_COST_FREE
    };

    return;
} ## end sub should_panel_desc_be_dumped

sub dump_desc_panel_body {
    my ( $filter, $time_slot, $panel_state, @extra_classes ) = @_;

    if ( !defined $panel_state ) {
        return if $opt{ $OPT_DESC_ALT_FORM };
        out_line $h->td(
            { out_class( @extra_classes, $CLASS_KIOSK_DESC_CELL_EMPTY ) } );
        return;
    } ## end if ( !defined $panel_state)

    my $panel = $panel_state->get_active_panel();

    my @subclasses = ( q{}, @{ $panel->get_css_subclasses() } );
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
    my $room               = $panel->get_room();

    if ( $panel->get_panel_is_cafe() ) {
        $name = q{Cosplay Café Featuring } . $name;
    }

    my $desc_element
        = $opt{ $OPT_DESC_ALT_FORM } ? $HTML_DIV : $HTML_TABLE_DATA;

    out_open $desc_element,
        {
        id => $panel->get_href_anchor(),
        out_class(
            @extra_classes,
            map { join_subclass( $CLASS_DESC_BASE, $_ ) } @subclasses
        )
        };
    out_open $HTML_DIV if $opt{ $OPT_MODE_KIOSK };
    out_line $h->div(
        {   out_class( join_subclass( $CLASS_DESC_BASE, $SUBCLASS_PIECE_ID ) )
        },
        $panel->get_uniq_id()
    );
    if ( $opt{ $OPT_SHOW_GRID } ) {
        out_line $h->a(
            {   href => q{#} . $panel->get_href_anchor() . q{Grid},
                out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_NAME ) )
            },
            $name
        );
    } ## end if ( $opt{ $OPT_SHOW_GRID...})
    else {
        out_line $h->div(
            {   out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_NAME ) )
            },
            $name
        );
    } ## end else [ if ( $opt{ $OPT_SHOW_GRID...})]

    my $cost = $panel->get_cost();
    if ( defined $cost && $cost !~ m{ \A part }xmsi ) {
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
    if ( $opt{ $OPT_MODE_KIOSK } ) {
        out_line $h->p(
            {   out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_START
                ) )
            },
            datetime_to_text( $panel->get_start_seconds(), qw{ both } )
        );
    } ## end if ( $opt{ $OPT_MODE_KIOSK...})
    else {
        out_line $h->p(
            {   out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_ROOM ) )
            },
            $room->get_long_room_name()
        );
    } ## end else [ if ( $opt{ $OPT_MODE_KIOSK...})]
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

    out_close $HTML_DIV if $opt{ $OPT_MODE_KIOSK };
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

        foreach my $panel_state ( @panel_states ) {
            next
                unless should_panel_desc_be_dumped(
                $filter, $room_focus_map, $panel_state,
                $show_unbusy_panels,
                $time
                );

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

            if ( !$opt{ $OPT_DESC_ALT_FORM } ) {
                out_open $HTML_TABLE_ROW,
                    { out_class( $CLASS_DESC_PANEL_ROW ) };
            }
            dump_desc_panel_body( $filter, $time_slot, $panel_state );
            if ( !$opt{ $OPT_DESC_ALT_FORM } ) {
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

    foreach my $region_time ( sort { $a <=> $b } keys %time_region ) {
        $region = $time_region{ $region_time };
        my %room_focus_map = room_id_focus_map( $filter, $region );
        dump_desc_body(
            $filter,             $region, \%room_focus_map,
            $show_unbusy_panels, $on_dump
        );
    } ## end foreach my $region_time ( sort...)

    return;
} ## end sub dump_desc_body_regions

sub dump_desc_timeslice {
    my ( $filter, $region ) = @_;

    my @filters = ( $filter );
    @filters = split_filter_by_panelist(
        $opt{ $OPT_DESC_BY_GUEST },
        $opt{ $OPT_DESC_BY_PRESENTER },
        1,
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
            && !$opt{ $OPT_JUST_PRESENTER }
            && !$opt{ $OPT_DESC_BY_GUEST }
            && !$opt{ $OPT_DESC_BY_PRESENTER } ) {
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

    if ( $opt{ $OPT_OUTPUT } eq q{-} ) {
        $output_file_handle = \*STDOUT;
        $output_file_name   = q{<STDOUT>};
        return;
    }

    my @subnames
        = map { canonical_header $_ } @{ $filter->{ $FILTER_OUTPUT_NAME } };

    my $ofname = $opt{ $OPT_OUTPUT };
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
    if ( $opt{ $OPT_OUTPUT } ne q{-} && defined $output_file_handle ) {
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

    return unless defined $opt{ $OPT_STYLE };

    foreach my $style ( @{ $opt{ $OPT_STYLE } } ) {
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
        elsif ( $fname =~ m{\A [+] (?:panel_)?color }xmsi ) {
            my ( $unused, $field ) = split m{=}xms, $fname, 2;
            $field //= q{Color};

            my $line_seen;

            foreach my $prefix ( sort keys %panel_types ) {
                next unless $prefix =~ m{\S}xms;
                my $color = $panel_types{ $prefix }->{ $field };
                next
                    unless $color
                    =~ m{\A ( [#] [[:xdigit:]]++ | inherit | black | white | rgba? [\(] .* ) \z}xms;

                open_media_style \%state, $media;
                open_media_style \%state, $media;

                out_line q{/* "}, $style, q{" */} unless $line_seen;
                $line_seen = 1;

                out_line q{.descType}, uc $prefix, q{,};
                out_css_open q{.panelType},     uc $prefix;
                out_line q{background-color: }, $color;
                out_css_close;
            } ## end foreach my $prefix ( sort keys...)
        } ## end elsif ( $fname =~ m{\A [+] (?:panel_)?color }xmsi)
        elsif ( $opt{ $OPT_EMBED_CSS } ) {
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
        } ## end elsif ( $opt{ $OPT_EMBED_CSS...})
        else {
            close_html_style \%state;

            out_line $h->link( {
                href => $fname,
                rel  => q{stylesheet},
                type => q{text/css},
                ( defined $media ? ( media => $media ) : () )
            } );
        } ## end else [ if ( $is_html ) ]
    } ## end foreach my $style ( @{ $opt...})
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
    my $title    = $opt{ $OPT_TITLE };
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

    if ( $opt{ $OPT_SHOW_GRID } ) {
        dump_grid_timeslice(
            $filter,
            $filter->{ $FILTER_SPLIT_TIMESTAMP }
        );
    } ## end if ( $opt{ $OPT_SHOW_GRID...})
    if ( $opt{ $OPT_SHOW_DESCRIPTIONS } ) {
        dump_desc_timeslice(
            $filter,
            $filter->{ $FILTER_SPLIT_TIMESTAMP }
        );
    } ## end if ( $opt{ $OPT_SHOW_DESCRIPTIONS...})

    return;
} ## end sub dump_table_one_region

sub dump_table_all_regions {
    my ( $filter ) = @_;

    my $need_all_desc = $opt{ $OPT_SHOW_DESCRIPTIONS };

    if ( $opt{ $OPT_SHOW_GRID } ) {
        foreach my $region_time ( sort { $a <=> $b } keys %time_region ) {
            my $region = $time_region{ $region_time };
            dump_grid_timeslice( $filter, $region );
            next unless $opt{ $OPT_SHOW_DESCRIPTIONS };
            next if $opt{ $OPT_DESC_AT_END };

            dump_desc_timeslice( $filter, $region );
            undef $need_all_desc;
        } ## end foreach my $region_time ( sort...)
        if ( !$opt{ $OPT_DESC_AT_END } ) {
            return;
        }
    } ## end if ( $opt{ $OPT_SHOW_GRID...})

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
    out_line $h->title( $opt{ $OPT_TITLE } );
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
    foreach my $region_time ( sort { $a <=> $b } keys %time_region ) {
        my $region = $time_region{ $region_time };
        dump_grid_timeslice( $DEFAULT_FILTER, $region );
    }
    out_close $HTML_DIV;

    foreach my $region_time ( sort { $a <=> $b } keys %time_region ) {
        my $region = $time_region{ $region_time };
        dump_kiosk_desc( $region );
    }

    out_close $HTML_BODY;
    out_close $HTML_HTML;

    close_dump_file;

    return;
} ## end sub dump_kiosk

sub split_filter_by_timestamp {
    my ( @filters ) = @_;

    return @filters unless $opt{ $OPT_FILE_BY_DAY };

    my @res;
    foreach my $filter ( @filters ) {
        my %new_filter = %{ $filter };
        my @subname    = @{ $new_filter{ $FILTER_OUTPUT_NAME } };
        foreach my $time ( sort { $a <=> $b } keys %time_region ) {
            my $region = $time_region{ $time };
            push @res,
                {
                %new_filter,
                $FILTER_SPLIT_TIMESTAMP => $region,
                $FILTER_OUTPUT_NAME =>
                    [ @subname, $region->get_region_name() ],
                };
        } ## end foreach my $time ( sort { $a...})
    } ## end foreach my $filter ( @filters)

    return @res;
} ## end sub split_filter_by_timestamp

sub split_filter_by_panelist {
    my ( $by_guest, $by_presenters, $is_by_desc, @filters ) = @_;

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
                $FILTER_PRESENTER => $per_info,
                $FILTER_OUTPUT_NAME =>
                    [ @subname, $per_info->get_presenter_name() ],
                };
        } ## end foreach my $per_info ( Presenter...)
    } ## end foreach my $filter ( @filters)

    return @res;
} ## end sub split_filter_by_panelist

sub split_filter_by_room {
    my ( @filters ) = @_;

    return @filters unless $opt{ $OPT_FILE_BY_ROOM };

    my @res;
    foreach my $filter ( @filters ) {
        my %new_filter = %{ $filter };
        my @subname    = @{ $new_filter{ $FILTER_OUTPUT_NAME } };
        foreach my $room ( get_rooms_for_region() ) {
            push @res,
                {
                %new_filter,
                $FILTER_ROOM => $room,
                $FILTER_OUTPUT_NAME =>
                    [ @subname, $room->get_short_room_name() ],
                };
        } ## end foreach my $room ( get_rooms_for_region...)
    } ## end foreach my $filter ( @filters)

    return @res;
} ## end sub split_filter_by_room

sub main {
    my ( @args ) = @_;

    my $mode  = $OPT_MODE_FLYER;
    my $split = $OPT_SPLIT_PER_TIMEREGION;

    GetOptionsFromArray(
        \@args,
        \%opt,

        q{desc-alt-form},
        q{desc-by-columns!},
        q{desc-by-guest!},
        q{desc-by-presenter!},
        q{embed-css|inline-css!},
        q{end-time=s},
        q{file-by-day},
        q{file-by-guest!},
        q{file-by-presenter!},
        q{file-by-room},
        q{input=s},
        q{just-presenter|just-guest!},
        q{output=s},
        q{room=s@},
        q{separate!},
        q{show-all-rooms|show-unused-rooms},
        q{show-av},
        q{show-day},
        q{show-descriptions|descriptions},
        q{show-difficulty},
        q{show-free},
        q{show-grid|grid},
        q{show-premium},
        q{start-time=s},
        q{style=s@},
        q{title=s},

        # Modes
        q{mode-flyer|flyer}       => sub { $mode = $OPT_MODE_FLYER; },
        q{mode-kiosk|kiosk}       => sub { $mode = $OPT_MODE_KIOSK; },
        q{mode-postcard|postcard} => sub { $mode = $OPT_MODE_POSTCARD; },

        # Splitting grid
        q{split-day}         => sub { $split = $OPT_SPLIT_PER_DAY; },
        q{split-half-day}    => sub { $split = $OPT_SPLIT_PER_TIMEREGION; },
        q{split-time-region} => sub { $split = $OPT_SPLIT_PER_TIMEREGION; },
        q{unified|no-split}  => sub { $split = $OPT_SPLIT_NONE; },
        q{split}             => sub {
            $split = $OPT_SPLIT_PER_TIMEREGION if $split eq $OPT_SPLIT_NONE;
        },

        # Negations
        q{file-all-days}     => sub { $opt{ $OPT_FILE_BY_DAY }       = 0; },
        q{file-all-rooms}    => sub { $opt{ $OPT_FILE_BY_ROOM }      = 0; },
        q{desc-table-form}   => sub { $opt{ $OPT_DESC_ALT_FORM }     = 0; },
        q{hide-av}           => sub { $opt{ $OPT_SHOW_AV }           = 0; },
        q{hide-day}          => sub { $opt{ $OPT_SHOW_DAY_COLUMN }   = 0; },
        q{hide-descriptions} => sub { $opt{ $OPT_SHOW_DESCRIPTIONS } = 0; },
        q{hide-difficulty}   => sub { $opt{ $OPT_SHOW_DIFFICULTY }   = 0; },
        q{hide-free}         => sub { $opt{ $OPT_SHOW_COST_FREE }    = 0; },
        q{hide-grid}         => sub { $opt{ $OPT_SHOW_GRID }         = 0; },
        q{hide-premium}      => sub { $opt{ $OPT_SHOW_COST_PREMIUM } = 0; },
        q{hide-unused-rooms} => sub { $opt{ $OPT_SHOW_ALL_ROOMS }    = 0; },
        q{just-free}         => sub { $opt{ $OPT_SHOW_COST_PREMIUM } = 0; },
        q{just-premium}      => sub { $opt{ $OPT_SHOW_COST_FREE }    = 0; },
    ) or die qq{Usage: desc_tbl -input [file] -output [file]\n};

    $opt{ $OPT_INPUT }  //= shift @args;
    $opt{ $OPT_OUTPUT } //= shift @args;
    $opt{ $OPT_OUTPUT } //= q{-};
    $opt{ $mode }  = 1;
    $opt{ $split } = 1;

    $opt{ $OPT_EMBED_CSS }         //= 1 if defined $opt{ $OPT_STYLE };
    $opt{ $OPT_DESC_BY_GUEST }     //= 1 if $opt{ $OPT_DESC_BY_PRESENTER };
    $opt{ $OPT_FILE_BY_GUEST }     //= 1 if $opt{ $OPT_FILE_BY_PRESENTER };
    $opt{ $OPT_FILE_BY_GUEST }     //= 1 if $opt{ $OPT_JUST_PRESENTER };
    $opt{ $OPT_SHOW_COST_FREE }    //= 0 if $opt{ $OPT_SHOW_COST_PREMIUM };
    $opt{ $OPT_SHOW_COST_PREMIUM } //= 0 if $opt{ $OPT_SHOW_COST_FREE };
    $opt{ $OPT_SHOW_DESCRIPTIONS } //= 0 if $opt{ $OPT_SHOW_GRID };
    $opt{ $OPT_SHOW_GRID }         //= 0 if $opt{ $OPT_SHOW_DESCRIPTIONS };

    $opt{ $OPT_SHOW_COST_FREE }    //= 1;
    $opt{ $OPT_SHOW_COST_PREMIUM } //= 1;
    $opt{ $OPT_SHOW_DESCRIPTIONS } //= 1;
    $opt{ $OPT_SHOW_DIFFICULTY }   //= 1;
    $opt{ $OPT_SHOW_GRID }         //= 1;
    $opt{ $OPT_STYLE }             //= [ qw{ index.css } ];
    $opt{ $OPT_TITLE }             //= q{Cosplay America 2023 Schedule};

    die qq{Both free and premium panels hidden\n}
        unless ( $opt{ $OPT_SHOW_COST_FREE }
        || $opt{ $OPT_SHOW_COST_PREMIUM } );

    if ( $opt{ $OPT_MODE_KIOSK } ) {
        $opt{ $OPT_STYLE }             = [ qw{+color} ];
        $opt{ $OPT_DESC_AT_END }       = undef;
        $opt{ $OPT_SHOW_DESCRIPTIONS } = 1;
        $opt{ $OPT_SHOW_GRID }         = 1;
        $opt{ $OPT_SPLIT_NONE }        = 1;
        delete @opt{
            $OPT_DESC_BY_GUEST,
            $OPT_DESC_BY_PRESENTER,
            $OPT_EMBED_CSS,
            $OPT_FILE_BY_DAY,
            $OPT_FILE_BY_GUEST,
            $OPT_FILE_BY_PRESENTER,
            $OPT_FILE_BY_ROOM,
            $OPT_JUST_PRESENTER,
            $OPT_MODE_POSTCARD,
            $OPT_ROOM,
            $OPT_SHOW_DAY_COLUMN,
            $OPT_SPLIT_PER_TIMEREGION,
            $OPT_SPLIT_PER_DAY,
        };
    } ## end if ( $opt{ $OPT_MODE_KIOSK...})

    use Data::Dumper;
    $Data::Dumper::Sortkeys = 1;
    say Data::Dumper->Dump( [ \%opt ], [ qw{opt } ] ) or 0;

    read_spreadsheet_file( $opt{ $OPT_INPUT } );

    make_time_ranges;

    if ( $opt{ $OPT_MODE_KIOSK } ) {
        dump_kiosk;
        return;
    }

    my @filters = ( $DEFAULT_FILTER );
    @filters = split_filter_by_panelist(
        $opt{ $OPT_FILE_BY_GUEST },
        $opt{ $OPT_FILE_BY_PRESENTER },
        undef,
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
