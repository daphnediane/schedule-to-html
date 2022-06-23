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
use TimeDecoder qw{ :decode :timepoints};
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
Readonly our $CLASS_DESC_FMT_SUBCLASS        => q{desc%s};
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
Readonly our $CLASS_GRID_CELL_FMT_SUBCLASS   => q{panel%s};
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

my @option_css_styles;
my @option_rooms;
my $option_desc_at_end;
my $option_embed_css;
my $option_file_per_day;
my $option_file_per_guest;
my $option_file_per_presenter;
my $option_file_per_room;
my $option_hide_unused_rooms;
my $option_input_file;
my $option_is_postcard;
my $option_just_premium;
my $option_just_presenter;
my $option_kiosk_mode;
my $option_output;
my $option_show_day_column;
my $option_show_descriptions;
my $option_show_difficulty = 1;
my $option_show_grid;
my $option_split_grids;
my $option_split_per_day;
my $option_title;

my @all_rooms;
my %room_by_idx;
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
        return unless $option_split_grids;
        return unless exists $time_split{ $time };
        if ( $option_split_per_day ) {
            my $prev_time = $prev_region->get_start_seconds();
            my $prev_day  = decode_time( $prev_time, qw{ day } );
            my $new_day   = decode_time( $time, qw{ day } );
            return if $prev_day eq $new_day;
            $time_split{ $time } = $new_day;
        } ## end if ( $option_split_per_day)
    } ## end if ( defined $prev_region)
    elsif ( !$option_split_grids ) {
        $time_split{ $time } //= q{Schedule};
    }
    elsif ( $option_split_per_day ) {
        $time_split{ $time } = decode_time( $time, qw{ day } );
    }
    else {
        $time_split{ $time } //= q{Before Convention};
    }

    my $region = $time_region{ $time } //= TimeRegion->new(
        name => $time_split{ $time }
            // q{From } . decode_time( $time, qw{ both } ),
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
            room_index => $room_data{ $RoomField::INDEX },
            short_name => $short_name,
            long_name  => $long_name,
            hotel_room => $hotel,
        );
        push @all_rooms, $room;
    } ## end if ( !defined $room )

    $room_by_name{ lc $short_name } //= $room;
    $room_by_name{ lc $long_name }  //= $room;
    $room_by_name{ lc $hotel }      //= $room if defined $hotel;

    my $idx = $room->get_num_room_index();
    $room_by_idx{ $idx } //= $room if defined $idx;

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

    my $idx = $panel_data->{ $PanelField::ROOM_INDEX };
    if ( defined $idx && $idx =~ m{\A \d+ \z}xms ) {
        $room = $room_by_idx{ $idx };
        return $room if defined $room;
    }

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
        room_index => $idx,
        short_name => $short_name,
        long_name  => $long_name,
        hotel_room => $hotel,
    );
    push @all_rooms, $room;

    $room_by_name{ lc $short_name } //= $room;
    $room_by_name{ lc $long_name }  //= $room;
    $room_by_name{ lc $hotel }      //= $room if defined $hotel;

    $room_by_idx{ $idx } //= $room if defined $room->get_num_room_index();

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

    if ( !defined $room->get_num_room_index() ) {
        warn
            q{Room },
            $room->get_short_room_name(),
            q{ without index for panel: },
            q{:},
            $panel->get_uniq_id(), q{: },
            $panel->get_name(),    qq{\n};
        return;
    } ## end if ( !defined $room->get_num_room_index...)

    mark_timepoint_seen( $panel->get_start_seconds() );
    mark_timepoint_seen( $panel->get_end_seconds() );

    push @{ $panels_by_start{ $panel->get_start_seconds() } //= [] }, $panel;

    return;
} ## end sub process_spreadsheet_row

sub read_spreadsheet_file {
    my $wb = Workbook->new( filename => $option_input_file );
    if ( !defined $wb || !$wb->get_is_open() ) {
        die qq{Unable to read ${option_input_file}\n};
    }

    read_spreadsheet_rooms( $wb );
    read_spreadsheet_panel_types( $wb );

    my $main_sheet = $wb->sheet();
    if ( !defined $main_sheet || !$main_sheet->get_is_open() ) {
        die qq{Unable to find schedule sheet for ${option_input_file}\n};
    }

    my $header = $main_sheet->get_next_line()
        or die qq{Missing header in: ${option_input_file}\n};
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

sub make_time_ranges {
    my %time_points
        = map { $_ => 1 } ( keys %time_split, get_timepoints() );
    my @time_points = sort { $a <=> $b } keys %time_points;

    my $region_active;
    my $region_start_time;
    my %panels_active;
    my $last_time;
    my %empty_times;
    my $current_break;

    my $process_time = sub {
        my ( $time ) = @_;

        # Add new panels
        foreach my $panel ( @{ $panels_by_start{ $time } } ) {

            if ( $panel->get_room_is_hidden() ) {
                if ($panel->get_is_break()
                    && ( !defined $current_break
                        || $panel->get_end_seconds()
                        > $current_break->get_end_seconds() )
                ) {
                    $current_break = $panel;
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

            $panels_active{ $panel->get_num_room_index() } = $panel_state;
        } ## end foreach my $panel ( @{ $panels_by_start...})

        if ( defined $current_break
            && $current_break->get_end_seconds() <= $time ) {
            undef $current_break;
        }
        foreach my $room ( @all_rooms ) {
            next if $room->get_room_is_hidden();
            my $room_idx = $room->get_num_room_index();

            my $prev_state = $panels_active{ $room_idx };
            if ( defined $prev_state ) {
                my $prev_end = $prev_state->get_end_seconds();
                next if $prev_end > $time;
            }

            if ( !defined $current_break ) {
                delete $panels_active{ $room_idx };
                next;
            }

            my $panel_state = ActivePanel->new(
                active_panel => $current_break,
                rows         => 0,
                start_time   => $time,
                end_time     => $current_break->get_end_seconds(),
                room         => $room,
                is_break     => 1,
            );
            $panels_active{ $room_idx } = $panel_state;
        } ## end foreach my $room ( @all_rooms)

        my %timeslot_info;
        my @active_room_ids = keys %panels_active;
        while ( my ( $room_idx, $panel_state ) = each %panels_active ) {
            my $panel = $panel_state->get_active_panel();
            $timeslot_info{ $room_idx } = $panel_state;

            $panel_state->increment_rows();
            $region_active->add_active_room( $panel_state->get_room() )
                unless $panel_state->get_is_break();

        } ## end while ( my ( $room_idx, $panel_state...))

        if ( %timeslot_info ) {
            foreach my $empty ( keys %empty_times ) {
                $region_active->get_time_slot( $empty )->init_current( {} );
            }
            %empty_times = ();

            $region_active->get_time_slot( $time )
                ->init_current( \%timeslot_info );

            $last_time = $time;
        } ## end if ( %timeslot_info )
        elsif ( defined $last_time ) {
            $empty_times{ $time } = 1;
        }
        return;
    };

    my $process_half_hours_upto = sub {
        my ( $split_time ) = @_;
        return unless defined $last_time;

        my $time = $last_time + $HALF_HOUR_IN_SEC;
        while ( $time < $split_time ) {
            $process_time->( $time );
            $time += $HALF_HOUR_IN_SEC;
        }

        return;
    };

    my $finish_region = sub {
        return unless defined $region_active;
        return unless $option_kiosk_mode;
        my @times
            = reverse sort { $a <=> $b } $region_active->get_unsorted_times();
        my %next_panels = ();

        foreach my $time ( @times ) {
            my $time_slot = $region_active->get_time_slot( $time );

            # Save current next panels
            $time_slot->init_upcoming( { %next_panels } );

            # Update next panels
            my $current_panels = $time_slot->get_current();
            while ( my ( $room_idx, $panel_state )
                = each %{ $current_panels } ) {
                next
                    unless $panel_state->get_start_seconds() == $time;
                $next_panels{ $room_idx } = $panel_state;
            } ## end while ( my ( $room_idx, $panel_state...))
        } ## end foreach my $time ( @times )
    };

    my $check_for_next_region = sub {
        my ( $split_time ) = @_;

        my $next_range = check_if_new_region( $split_time, $region_active );
        return unless defined $next_range;

        $finish_region->();
        my %new_active = %panels_active;
        while ( my ( $room_idx, $panel_state ) = each %panels_active ) {
            my $new_state = $panel_state->clone();
            $new_state->set_rows( 0 );
            $new_state->set_start_time( $split_time );
            $new_active{ $room_idx } = $new_state;
        } ## end while ( my ( $room_idx, $panel_state...))
        %panels_active     = %new_active;
        $region_active     = $next_range;
        $region_start_time = $split_time;
        undef $last_time;
        %empty_times = ();
    };

    foreach my $split_time ( @time_points ) {
        $process_half_hours_upto->( $split_time ) if %panels_active;
        $check_for_next_region->( $split_time );
        $process_time->( $split_time );
    }
    $finish_region->();

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

    if ( $option_hide_unused_rooms && defined $region ) {
        @rooms = grep { $region->is_room_active( $_ ) } @rooms;
    }

    return @rooms;
} ## end sub get_rooms_for_region

sub get_room_index_focus_map {
    my ( $filter, $region ) = @_;

    my @region_rooms = get_rooms_for_region( $region );

    if ( exists $filter->{ $FILTER_ROOM } ) {
        my %res = map { $_->get_num_room_index() => $FILTER_SET_UNFOCUS }
            @region_rooms;
        $res{ $filter->{ $FILTER_ROOM }->get_room_index() }
            = $FILTER_SET_FOCUS;
        return %res;
    } ## end if ( exists $filter->{...})

    if ( @option_rooms ) {
        my %res;
        my $def_class = [];
    ROOM:
        foreach my $room ( @region_rooms ) {
            my $room_idx = $room->get_num_room_index();
            my $name     = $room->get_long_room_name();
            foreach my $match ( @option_rooms ) {
                if ( $name =~ m{\Q$match\E}xmsi ) {
                    $res{ $room_idx } = $FILTER_SET_FOCUS;
                    next ROOM;
                }
            } ## end foreach my $match ( @option_rooms)
            $res{ $room_idx } = $FILTER_SET_UNFOCUS;
        } ## end ROOM: foreach my $room ( @region_rooms)
        return %res;
    } ## end if ( @option_rooms )

    return
        map { $_->get_num_room_index() => $FILTER_SET_DEFAULT } @region_rooms;
} ## end sub get_room_index_focus_map

sub dump_grid_row_room_names {
    my ( $filter, $kind, $room_focus_map ) = @_;

    if ( $option_show_day_column ) {
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
    } ## end if ( $option_show_day_column)
    out_line $h->th(
        {   out_class(
                $CLASS_GRID_CELL_HEADER,
                $kind eq $HTML_TABLE_HEAD ? $CLASS_GRID_COLUMN_TIME : ()
            )
        },
        $HEADING_TIME
    );

    foreach my $idx ( sort { $a <=> $b } keys %{ $room_focus_map } ) {
        my $hotel = $room_by_idx{ $idx }->get_hotel_room();
        my $name  = $room_by_idx{ $idx }->get_long_room_name();
        if ( $hotel ne $name && !$option_kiosk_mode ) {
            $name = $name . $h->br() . $h->i( $hotel );
        }
        out_line $h->th(
            {   out_class(
                    $CLASS_GRID_CELL_HEADER,
                    $CLASS_GRID_COLUMN_ROOM,
                    $CLASS_GRID_CELL_ROOM_NAME,
                    @{  $room_focus_map->{ $idx }->{ $FILTER_ROOM_CLASSES }
                    },
                    $kind eq $HTML_TABLE_HEAD
                    ? ( sprintf $CLASS_GRID_COLUMN_FMT_ROOM_IDX, $idx )
                    : (),
                )
            },
            $name
        );
    } ## end foreach my $idx ( sort { $a...})

    return;
} ## end sub dump_grid_row_room_names

sub dump_grid_header {
    my ( $filter, $room_focus_map ) = @_;

    out_open $HTML_TABLE, { out_class( $CLASS_GRID_TABLE ) };

    out_open $HTML_COLGROUP;
    if ( $option_show_day_column ) {
        out_line $h->col( { out_class( $CLASS_GRID_COLUMN_DAY ) } );
    }
    out_line $h->col( { out_class( $CLASS_GRID_COLUMN_TIME ) } );

    foreach my $idx ( sort { $a <=> $b } keys %{ $room_focus_map } ) {
        out_line $h->col(
            { out_class( sprintf $CLASS_GRID_COLUMN_FMT_ROOM_IDX, $idx ) } );
    }
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
    my ( $filter, $region, $room_focus_map, $time_slot, $idx ) = @_;

    my $panel_state = $time_slot->get_current()->{ $idx };
    if ( !defined $panel_state ) {
        out_line q{<!--}, $room_by_idx{ $idx }->get_short_room_name(),
            q{-->},
            $h->td( { out_class( $CLASS_GRID_CELL_EMPTY ) } );
        return;
    } ## end if ( !defined $panel_state)

    my $time  = $time_slot->get_start_seconds();
    my $panel = $panel_state->get_active_panel();

    if ( $panel_state->get_start_seconds() != $time ) {
        out_line q{<!--}, $room_by_idx{ $idx }->get_short_room_name(),
            q{ },
            $panel->get_uniq_id(), q{ continued-->};
        return;
    } ## end if ( $panel_state->get_start_seconds...)

    my $name               = $panel->get_name();
    my $credited_presenter = $panel->get_credits();
    my $room               = $panel_state->get_room();

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
        @{ $room_focus_map->{ $idx }->{ $FILTER_ROOM_CLASSES } };

    out_line q{<!--}, $room_by_idx{ $idx }->get_short_room_name(), q{-->};
    out_open $HTML_TABLE_DATA,
        {
        id      => $panel->get_href_anchor() . q{Grid},
        rowspan => $panel_state->get_rows() // 1,
        out_class(
            $CLASS_GRID_COLUMN_ROOM,
            map { sprintf $CLASS_GRID_CELL_FMT_SUBCLASS, $_ } @subclasses
        )
        };

    out_open $HTML_ANCHOR, { href => q{#} . $panel->get_href_anchor() }
        if $option_show_descriptions;

    out_line $h->div(
        {   out_class(
                sprintf $CLASS_GRID_CELL_FMT_SUBCLASS,
                $SUBCLASS_PIECE_ID
            )
        },
        $panel->get_uniq_id()
    );

    if ( $panel->get_is_full() ) {
        out_line $h->div(
            {   out_class(
                    sprintf $CLASS_GRID_CELL_FMT_SUBCLASS,
                    $SUBCLASS_PIECE_FULL
                )
            },
            q{Workshop is Full}
        );
    } ## end if ( $panel->get_is_full...)
    out_line $h->span(
        {   out_class(
                sprintf $CLASS_GRID_CELL_FMT_SUBCLASS,
                $SUBCLASS_PIECE_NAME
            )
        },
        $name
    );

    my $cost = $panel->get_cost();
    if ( defined $cost && $cost !~ m{ \A part }xmsi ) {
        out_line $h->div(
            {   out_class(
                    map { sprintf $CLASS_GRID_CELL_FMT_SUBCLASS, $_ } (
                        $SUBCLASS_PIECE_COST,
                    )
                )
            },
            $cost
        );
    } ## end if ( defined $cost && ...)

    if ( defined $credited_presenter ) {
        out_line $h->span(
            {   out_class(
                    sprintf $CLASS_GRID_CELL_FMT_SUBCLASS,
                    $SUBCLASS_PIECE_PRESENTER
                )
            },
            $credited_presenter
        );
    } ## end if ( defined $credited_presenter)

    out_close $HTML_ANCHOR if $option_show_descriptions;
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

    my $time_id = q{sched_id_} . decode_time_id( $time );
    out_open $HTML_TABLE_ROW,
        { out_class( @time_row_classes ), id => $time_id };

    if ( $option_show_day_column ) {
        out_line $h->th(
            {   out_class(
                    $CLASS_GRID_CELL_HEADER, $CLASS_GRID_CELL_DAY,
                    $CLASS_GRID_COLUMN_DAY
                )
            },
            decode_time( $time, qw{ day } )
        );
        out_line $h->th(
            { out_class( @time_classes ) },
            decode_time( $time, qw{ time } )
        );
    } ## end if ( $option_show_day_column)
    else {
        my ( $day, $tm ) = decode_time( $time );
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
    } ## end else [ if ( $option_show_day_column)]

    foreach my $idx ( sort { $a <=> $b } keys %{ $room_focus_map } ) {
        dump_grid_cell_room(
            $filter, $region, $room_focus_map, $time_slot,
            $idx
        );
    } ## end foreach my $idx ( sort { $a...})
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

    my %room_focus_map = get_room_index_focus_map( $filter, $region );

    dump_grid_header( $filter, \%room_focus_map );
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

        if ( $option_is_postcard ) {
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
        } ## end if ( $option_is_postcard)
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
        if ( $option_is_postcard ) {
            out_close $HTML_TABLE_DATA;
            out_close $HTML_TABLE_ROW;
            out_close $HTML_TABLE_BODY;
            out_close $HTML_TABLE;
        } ## end if ( $option_is_postcard)
    } ## end if ( exists $filter->{...})

    return;
} ## end sub dump_desc_footer

sub dump_desc_time_start {
    my ( $time, @hdr_suffix ) = @_;

    out_open $HTML_TABLE, { out_class( $CLASS_DESC_TIME_TABLE ) };
    out_open $HTML_COLGROUP;
    out_line $h->col( { out_class( $CLASS_DESC_TIME_COLUMN ) } );
    out_close $HTML_COLGROUP;

    out_line $h->thead(
        { out_class( $CLASS_DESC_TIME_HEADER ) },
        $h->tr( $h->th(
            { out_class( $CLASS_DESC_TIME_COLUMN, $CLASS_DESC_TIME_SLOT ) },
            join q{ },
            decode_time( $time, qw{ both } ),
            @hdr_suffix
        ) )
    );

    out_open $HTML_TABLE_BODY;

    return;
} ## end sub dump_desc_time_start

sub dump_desc_time_end {
    my ( $time ) = @_;

    out_close $HTML_TABLE_BODY;
    out_close $HTML_TABLE;

    return;
} ## end sub dump_desc_time_end

sub dump_desc_panel_note {
    my ( $panel, $conflict ) = @_;

    my @note;
    if ( $conflict ) {
        push @note, $h->b( q{Conflicts with one of your panels.} );
    }
    if ( defined $panel->get_cost() && $panel->get_cost() =~ m{model}xms ) {
        push @note, $h->b( q{Premium workshop:} ),
            q{ Requires a separate purchase.};
    }
    if ( defined $panel->get_note() ) {
        push @note, $h->i( $panel->get_note() );
    }
    if ( $panel->get_is_full() ) {
        push @note,
            $h->span(
            {   out_class(
                    sprintf $CLASS_DESC_FMT_SUBCLASS,
                    $SUBCLASS_PIECE_FULL
                )
            },
            q{This workshop is full.}
            );
    } ## end if ( $panel->get_is_full...)
    if ( defined $panel->get_difficulty() && $option_show_difficulty ) {
        push @note, $h->span(
            {   out_class(
                    sprintf $CLASS_DESC_FMT_SUBCLASS,
                    $SUBCLASS_PIECE_DIFFICULTY
                )
            },
            q{Difficulty level: } . $panel->get_difficulty()
        );
    } ## end if ( defined $panel->get_difficulty...)
    if ( @note ) {
        out_line $h->p(
            {   out_class(
                    sprintf $CLASS_DESC_FMT_SUBCLASS,
                    $SUBCLASS_PIECE_NOTE
                )
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

    my $idx = $panel_state->get_num_room_index();
    return if $room_focus_map->{ $idx }->{ $FILTER_ROOM_DESC_HIDE };

    my $panel = $panel_state->get_active_panel();

    return unless $panel->get_start_seconds() == $time;

    return if ( $panel->get_room_is_hidden() );

    my $filter_panelist = $filter->{ $FILTER_PRESENTER };
    if ( defined $filter_panelist ) {
        if ($panel->is_presenter_hosting( $filter_panelist )
            ? !$show_unbusy_panels
            : $show_unbusy_panels
        ) {
            return;
        } ## end if ( $panel->is_presenter_hosting...)
    } ## end if ( defined $filter_panelist)

    return if ( $option_just_premium && !defined $panel->get_post() );
    return 1;
} ## end sub should_panel_desc_be_dumped

sub dump_desc_panel_body {
    my ( $filter, $time_slot, $panel_state, @extra_classes ) = @_;

    if ( !defined $panel_state ) {
        out_line $h->td(
            { out_class( @extra_classes, $CLASS_KIOSK_DESC_CELL_EMPTY ) } );
        return;
    }

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

    out_open $HTML_TABLE_DATA,
        {
        id => $panel->get_href_anchor(),
        out_class(
            @extra_classes,
            map { sprintf $CLASS_DESC_FMT_SUBCLASS, $_ } @subclasses
        )
        };
    out_open $HTML_DIV if $option_kiosk_mode;
    out_line $h->div(
        { out_class( sprintf $CLASS_DESC_FMT_SUBCLASS, $SUBCLASS_PIECE_ID ) },
        $panel->get_uniq_id()
    );
    if ( $option_show_grid ) {
        out_line $h->a(
            {   href => q{#} . $panel->get_href_anchor() . q{Grid},
                out_class(
                    sprintf $CLASS_DESC_FMT_SUBCLASS,
                    $SUBCLASS_PIECE_NAME
                )
            },
            $name
        );
    } ## end if ( $option_show_grid)
    else {
        out_line $h->div(
            {   out_class(
                    sprintf $CLASS_DESC_FMT_SUBCLASS,
                    $SUBCLASS_PIECE_NAME
                )
            },
            $name
        );
    } ## end else [ if ( $option_show_grid)]

    my $cost = $panel->get_cost();
    if ( defined $cost && $cost !~ m{ \A part }xmsi ) {
        out_line $h->div(
            {   out_class(
                    map { sprintf $CLASS_DESC_FMT_SUBCLASS, $_ } (
                        $SUBCLASS_PIECE_COST,
                    )
                )
            },
            $cost
        );
    } ## end if ( defined $cost && ...)
    if ( $option_kiosk_mode ) {
        out_line $h->p(
            {   out_class(
                    sprintf $CLASS_DESC_FMT_SUBCLASS,
                    $SUBCLASS_PIECE_START
                )
            },
            decode_time( $panel->get_start_seconds(), qw{ both } )
        );
    } ## end if ( $option_kiosk_mode)
    else {
        out_line $h->p(
            {   out_class(
                    sprintf $CLASS_DESC_FMT_SUBCLASS,
                    $SUBCLASS_PIECE_ROOM
                )
            },
            $room->get_long_room_name()
        );
    } ## end else [ if ( $option_kiosk_mode)]
    if ( defined $credited_presenter ) {
        out_line $h->p(
            {   out_class(
                    sprintf $CLASS_DESC_FMT_SUBCLASS,
                    $SUBCLASS_PIECE_PRESENTER
                )
            },
            $credited_presenter
        );
    } ## end if ( defined $credited_presenter)

    out_line $h->p(
        {   out_class(
                sprintf $CLASS_DESC_FMT_SUBCLASS,
                $SUBCLASS_PIECE_DESCRIPTION
            )
        },
        $panel->get_description()
    );

    dump_desc_panel_note( $panel, $conflict );

    out_close $HTML_DIV if $option_kiosk_mode;
    out_close $HTML_TABLE_DATA;

    return;
} ## end sub dump_desc_panel_body

sub dump_desc_body {
    my ( $filter, $region, $room_focus_map, $show_unbusy_panels ) = @_;
    my $filter_panelist = $filter->{ $FILTER_PRESENTER };

    $region->set_day_being_output( q{} );
    my @times = sort { $a <=> $b } $region->get_unsorted_times();
    $region->set_last_output_time( $times[ -1 ] );

    foreach my $time ( @times ) {
        my $time_header_seen;
        my $time_slot           = $region->get_time_slot( $time );
        my $panels_for_timeslot = $time_slot->get_current();

        my @panel_states = values %{ $panels_for_timeslot };
        @panel_states = sort { $a->compare_room_index( $b ) } @panel_states;

        foreach my $panel_state ( @panel_states ) {
            next
                unless should_panel_desc_be_dumped(
                $filter, $room_focus_map, $panel_state,
                $show_unbusy_panels,
                $time
                );

            if ( !defined $time_header_seen ) {
                $time_header_seen = 1;

                my @hdr_extra;
                if (   $show_unbusy_panels
                    && $time_slot->is_presenter_hosting( $filter_panelist ) )
                {
                    push @hdr_extra, qw{ Conflict };
                }
                dump_desc_time_start( $time, @hdr_extra );
            } ## end if ( !defined $time_header_seen)

            out_open $HTML_TABLE_ROW,
                { out_class( $CLASS_DESC_PANEL_ROW ) };
            dump_desc_panel_body( $filter, $time_slot, $panel_state );
            out_close $HTML_TABLE_ROW;
        } ## end foreach my $panel_state ( @panel_states)
        if ( $time_header_seen ) {
            dump_desc_time_end( $time );
        }
    } ## end foreach my $time ( @times )

    return;
} ## end sub dump_desc_body

sub dump_desc_timeslice {
    my ( $filter, $region ) = @_;

    my %room_focus_map = get_room_index_focus_map( $filter, $region );

    dump_desc_header( $filter, $region );
    dump_desc_body( $filter, $region, \%room_focus_map );
    dump_desc_footer( $filter, $region );

    if ( exists $filter->{ $FILTER_PRESENTER } && !$option_just_presenter ) {
        dump_desc_header( $filter, $region, 1 );
        dump_desc_body( $filter, $region, \%room_focus_map, 1 );
        dump_desc_footer( $filter, $region, 1 );
    }

    return;
} ## end sub dump_desc_timeslice

sub dump_desc_all_timeslice {
    my ( $filter, $show_unbusy_panels ) = @_;

    dump_desc_header( $filter, undef, $show_unbusy_panels );
    foreach my $region_time ( sort { $a <=> $b } keys %time_region ) {
        my $region         = $time_region{ $region_time };
        my %room_focus_map = get_room_index_focus_map( $filter, $region );
        dump_desc_body(
            $filter, $region, \%room_focus_map,
            $show_unbusy_panels
        );
    } ## end foreach my $region_time ( sort...)
    dump_desc_footer( $filter, undef, $show_unbusy_panels );

    return;
} ## end sub dump_desc_all_timeslice

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

    if ( $option_output eq q{-} ) {
        $output_file_handle = \*STDOUT;
        $output_file_name   = q{<STDOUT>};
        return;
    }

    my @subnames
        = map { canonical_header $_ } @{ $filter->{ $FILTER_OUTPUT_NAME } };

    my $ofname = $option_output;
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
    if ( $option_output ne q{-} && defined $output_file_handle ) {
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

    foreach my $style ( @option_css_styles ) {
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
        elsif ( $option_embed_css ) {
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
        } ## end elsif ( $option_embed_css)
        else {
            close_html_style \%state;

            out_line $h->link( {
                href => $fname,
                rel  => q{stylesheet},
                type => q{text/css},
                ( defined $media ? ( media => $media ) : () )
            } );
        } ## end else [ if ( $is_html ) ]
    } ## end foreach my $style ( @option_css_styles)
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
    my $title    = $option_title;
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

    if ( $option_show_grid ) {
        dump_grid_timeslice(
            $filter,
            $filter->{ $FILTER_SPLIT_TIMESTAMP }
        );
    } ## end if ( $option_show_grid)
    if ( $option_show_descriptions ) {
        dump_desc_timeslice(
            $filter,
            $filter->{ $FILTER_SPLIT_TIMESTAMP }
        );
    } ## end if ( $option_show_descriptions)

    return;
} ## end sub dump_table_one_region

sub dump_table_all_regions {
    my ( $filter ) = @_;

    my $need_all_desc = $option_show_descriptions;

    if ( $option_show_grid ) {
        foreach my $region_time ( sort { $a <=> $b } keys %time_region ) {
            my $region = $time_region{ $region_time };
            dump_grid_timeslice( $filter, $region );
            next unless $option_show_descriptions;
            next if $option_desc_at_end;

            dump_desc_timeslice( $filter, $region );
            undef $need_all_desc;
        } ## end foreach my $region_time ( sort...)
        if ( !$option_desc_at_end ) {
            return;
        }
    } ## end if ( $option_show_grid)

    if ( $need_all_desc ) {
        dump_desc_all_timeslice( $filter );
        if ( exists $filter->{ $FILTER_PRESENTER }
            && !$option_just_presenter ) {
            dump_desc_all_timeslice( $filter, 1 );
        }
    } ## end if ( $need_all_desc )

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
        my $time_id = q{desc_id_} . decode_time_id( $time );
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
            my $idx   = $room->get_num_room_index();
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
                $cur_panels->{ $idx },
                $CLASS_KIOSK_DESC_CELL_CURRENT
            );
            dump_desc_panel_body(
                $DEFAULT_FILTER, $time_slot,
                $next_panels->{ $idx },
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
    out_line $h->title( $option_title );
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

    return @filters unless $option_file_per_day;

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
    my ( @filters ) = @_;

    return @filters
        unless ( $option_file_per_guest || $option_file_per_presenter );

    my @res;
    foreach my $filter ( @filters ) {
        my %new_filter = %{ $filter };
        my @subname    = @{ $new_filter{ $FILTER_OUTPUT_NAME } };
        foreach my $per_info ( Presenter->get_known() ) {
            next if $per_info->get_is_other();

            if ( $per_info->get_presenter_rank() == $Presenter::RANK_GUEST
                && !$option_file_per_presenter ) {
                next;
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

    return @filters unless $option_file_per_room;

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

    GetOptionsFromArray(
        \@args,

        q{embed-css!}         => \$option_embed_css,
        q{file-by-day!}       => \$option_file_per_day,
        q{file-by-guest!}     => \$option_file_per_guest,
        q{file-by-presenter!} => \$option_file_per_presenter,
        q{file-by-room!}      => \$option_file_per_room,
        q{hide-day+}          => sub { $option_show_day_column = 0 },
        q{hide-descriptions+} => sub { $option_show_descriptions = 0 },
        q{hide-grid+}         => sub { $option_show_grid = 0 },
        q{hide-unused-rooms!} => \$option_hide_unused_rooms,
        q{input=s}            => \$option_input_file,
        q{just-premium!}      => \$option_just_premium,
        q{just-presenter!}    => \$option_just_presenter,
        q{mode-kiosk!}        => \$option_kiosk_mode,
        q{mode-postcard!}     => \$option_is_postcard,
        q{output=s}           => \$option_output,
        q{room=s@}            => \@option_rooms,
        q{separate!}          => \$option_desc_at_end,
        q{show-day!}          => \$option_show_day_column,
        q{show-descriptions!} => \$option_show_descriptions,
        q{show-grid|grid!}    => \$option_show_grid,
        q{show-unused-rooms+} => sub { $option_hide_unused_rooms = 0 },
        q{split!}             => \$option_split_grids,
        q{split-day!}         => \$option_split_per_day,
        q{style=s@}           => \@option_css_styles,
        q{title=s}            => \$option_title,

        # Aliases
        q{descriptions!} => \$option_show_descriptions,
        q{inline-css!}   => \$option_embed_css,
        q{just-guest!}   => \$option_just_presenter,
        q{kiosk!}        => \$option_kiosk_mode,
        q{postcard!}     => \$option_is_postcard,
        q{unified+}      => sub { $option_split_grids = 0 },

        # Undocumented
        q{show-difficulty} => \$option_show_difficulty,
    ) or die qq{Usage: desc_tbl -input [file] -output [file]\n};

    $option_embed_css //= 1 if @option_css_styles;
    push @option_css_styles, qw{ index.css } unless @option_css_styles;

    $option_input_file  //= shift @args;
    $option_output      //= shift @args;
    $option_output      //= q{-};
    $option_split_grids //= 1;
    $option_title       //= q{Cosplay America 2022 Schedule};

    if ( $option_kiosk_mode ) {
        @option_css_styles         = ( qw{+color} );
        $option_desc_at_end        = undef;
        $option_embed_css          = undef;
        $option_file_per_day       = undef;
        $option_file_per_guest     = undef;
        $option_file_per_presenter = undef;
        $option_file_per_room      = undef;
        @option_rooms              = ();
        $option_is_postcard        = undef;
        $option_just_presenter     = undef;
        $option_show_day_column    = undef;
        $option_show_descriptions  = 1;
        $option_show_grid          = 1;
        $option_split_per_day      = undef;
        $option_split_grids        = undef;
    } ## end if ( $option_kiosk_mode)
    read_spreadsheet_file( $option_input_file );

    make_time_ranges;

    if ( $option_kiosk_mode ) {
        dump_kiosk;
        return;
    }

    $option_show_grid         //= 0 if $option_show_descriptions;
    $option_show_descriptions //= 0 if $option_show_grid;
    $option_show_grid         //= 1;
    $option_show_descriptions //= 1;
    $option_file_per_guest //= 1 if $option_just_presenter;

    my @filters = ( $DEFAULT_FILTER );
    @filters = split_filter_by_panelist( @filters );
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
