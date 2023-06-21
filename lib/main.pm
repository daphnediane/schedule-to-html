#!/usr/bin/perl

use v5.36.0;
use utf8;

use Carp         qw{ verbose croak };      ## no critic (ProhibitUnusedImport)
use English      qw{ -no_match_vars };
use File::Slurp  qw{ read_file };
use File::Spec   qw{};
use FindBin      qw{};
use Getopt::Long qw{ GetOptionsFromArray };
use HTML::Tiny   qw{};
use List::Util   qw{ any };
use List::MoreUtils qw{ firstidx };
use Readonly;
use Scalar::Util qw{ blessed };

use lib "${FindBin::Bin}/lib";
use ActivePanel         qw{};
use Canonical           qw{ :all };
use Data::Panel         qw{};
use Data::PanelType     qw{};
use Data::Partion       qw{};
use Data::Room          qw{};
use Options             qw{};
use PartionPanels       qw{ :all };
use Presenter           qw{};
use Table::Panel        qw{ :all };
use Table::PanelType    qw{ :all };
use Table::Room         qw{ :all };
use Table::TimeRegion   qw{ :all };
use TimeDecoder         qw{ :from_text :to_text :timepoints };
use TimeRange           qw{};
use TimeRegion          qw{};
use TimeSlot            qw{};
use Workbook            qw{};
use Workbook::Sheet     qw{};
use WriteLevel          qw{};
use WriteLevel::CSS     qw{};
use WriteLevel::HTML    qw{};
use WriteLevel::WebPage qw{};

# HTML keywoards
Readonly our $HTML_APP_OKAY     => q{apple-mobile-web-app-capable};
Readonly our $HTML_CHARSET_UTF8 => q{UTF-8};
Readonly our $HTML_DOCTYPE_HTML => q{<!doctype html>};
Readonly our $HTML_STYLESHEET   => q{stylesheet};
Readonly our $HTML_SUFFIX_HTML  => q{html};
Readonly our $HTML_TEXT_CSS     => q{text/css};
Readonly our $HTML_YES          => q{yes};

Readonly our $SUBDIR_CSS => q{css};

Readonly our $COMMENT_CONTINUE_START => q{<!--};
Readonly our $COMMENT_CONTINUE_END   => q{ continued-->};
Readonly our $COMMENT_STYLE_START    => q{/* "};
Readonly our $COMMENT_STYLE_END      => q{" */};

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

Readonly our $LINK_SUFFIX_GRID => q{Grid};

# Grid headers
Readonly our $HEADING_DAY  => q{Day};
Readonly our $HEADING_TIME => q{Time};

# Color styles
Readonly our $RE_COLOR_STYLE =>
    qr{ \A (?: all: | print: | screen: )? [+] (?i:(?:panel_)?color) (?: = | \z ) }xms;

my $options;
my $h          = HTML::Tiny->new( mode => $HTML_SUFFIX_HTML );
my $output_idx = 0;

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

sub room_focus_class {
    my ( @focuses ) = @_;
    return $CLASS_GRID_CELL_FOCUS   if any { $_->is_focused() } @focuses;
    return $CLASS_GRID_CELL_UNFOCUS if any { $_->is_unfocused() } @focuses;
    return;
} ## end sub room_focus_class

sub dump_grid_row_room_names {
    my ( $writer, $filter, $room_focus_map ) = @_;

    my $is_head = $writer->get_tag() =~ m{ thead [.] tr \z }xms;

    if ( $options->show_day_column() ) {
        $writer->add_th(
            {   out_class(
                    $CLASS_GRID_CELL_HEADER,
                    $is_head ? $CLASS_GRID_COLUMN_DAY : ()
                )
            },
            $HEADING_DAY
        );
    } ## end if ( $options->show_day_column...)
    $writer->add_th(
        {   out_class(
                $CLASS_GRID_CELL_HEADER,
                $is_head ? $CLASS_GRID_COLUMN_TIME : ()
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
        $writer->add_th(
            {   out_class(
                    $CLASS_GRID_CELL_HEADER,
                    $CLASS_GRID_COLUMN_ROOM,
                    $CLASS_GRID_CELL_ROOM_NAME,
                    room_focus_class( $room_focus_map->{ $room_id } ),
                    $is_head
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
    my ( $writer, $filter, $region, $room_focus_map ) = @_;

    $writer = $writer->nested_table( {
        out_class(
            $CLASS_GRID_TABLE,
            join_subclass(
                $CLASS_GRID_TABLE,
                canonical_class( $region->get_region_name() )
            )
        )
    } );

    my $colgroup = $writer->nested_colgroup();

    if ( $options->show_day_column() ) {
        $colgroup->add_col( { out_class( $CLASS_GRID_COLUMN_DAY ) } );
    }
    $colgroup->add_col( { out_class( $CLASS_GRID_COLUMN_TIME ) } );

    my @rooms = sort map { Data::Room->find_by_room_id( $_ ) }
        keys %{ $room_focus_map };

    foreach my $room ( @rooms ) {
        $colgroup->add_col( {
            out_class(
                sprintf $CLASS_GRID_COLUMN_FMT_ROOM_IDX,
                $room->get_sort_key()
            )
        } );
    } ## end foreach my $room ( @rooms )

    my $head = $writer->nested_thead()
        ->nested_tr( { out_class( $CLASS_GRID_ROW_HEADER ) } );
    dump_grid_row_room_names( $head, $filter, $room_focus_map );

    my $body = $writer->nested_tbody();

    my $footer = $writer->nested_tfoot()
        ->nested_tr( { out_class( $CLASS_GRID_ROW_HEADER ) } );

    dump_grid_row_room_names( $footer, $filter, $room_focus_map );

    return $body;
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

sub dump_grid_row_cell_group {    ## no critic(Subroutines::ProhibitManyArgs)
    my ( $writer, $filter, $room_focus_map, $time_slot, $panel_state, @rooms )
        = @_;

    return unless @rooms;

    if ( !defined $panel_state ) {
        foreach ( @rooms ) {
            $writer->add_td( { out_class( $CLASS_GRID_CELL_EMPTY ) } );
        }
        return;
    } ## end if ( !defined $panel_state)

    my $time  = $time_slot->get_start_seconds();
    my $panel = $panel_state->get_active_panel();

    if ( $panel_state->get_start_seconds() != $time ) {
        foreach ( @rooms ) {
            $writer->add_line(
                $COMMENT_CONTINUE_START, $panel->get_uniq_id(),
                $COMMENT_CONTINUE_END
            );
        } ## end foreach ( @rooms )
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
    if ( defined $filter->get_selected_presenter() ) {
        my $presenter = $filter->get_selected_presenter();
        if ( $panel->is_presenter_hosting( $presenter ) ) {
            push @subclasses, $SUBCLASS_GUEST_PANEL;
        }
        elsif ( $time_slot->is_presenter_hosting( $presenter ) ) {
            push @subclasses, $SUBCLASS_BUSY_PANEL;
        }
    } ## end if ( defined $filter->...)

    push @subclasses,
        room_focus_class( map { $room_focus_map->{ $_->get_room_id() } }
            @rooms );

    my $row_span = $panel_state->get_rows() // 1;
    my $col_span = @rooms                   // 1;
    my @spans;
    push @spans, rowspan => $row_span if $row_span > 1;
    push @spans, colspan => $col_span if $col_span > 1;

    my $tdata = $writer->nested_td( {
        id => $panel->get_href_anchor() . $LINK_SUFFIX_GRID,
        @spans,
        out_class(
            $CLASS_GRID_COLUMN_ROOM,
            map { join_subclass( $CLASS_GRID_CELL_BASE, $_ ) } @subclasses
        )
    } );

    $tdata = $tdata->nested_a( { href => q{#} . $panel->get_href_anchor() } )
        if $options->show_sect_descriptions();

    $tdata->add_div(
        {   out_class( join_subclass(
                $CLASS_GRID_CELL_BASE, $SUBCLASS_PIECE_ID ) )
        },
        $panel->get_uniq_id()
    );

    if ( $panel->get_is_full() ) {
        $tdata->add_div(
            {   out_class( join_subclass(
                    $CLASS_GRID_CELL_BASE, $SUBCLASS_PIECE_FULL
                ) )
            },
            q{Workshop is Full}
        );
    } ## end if ( $panel->get_is_full...)
    $tdata->add_span(
        {   out_class( join_subclass(
                $CLASS_GRID_CELL_BASE, $SUBCLASS_PIECE_NAME
            ) )
        },
        $name
    );

    my $cost = $panel->get_cost();
    if ( defined $cost && $panel->get_uniq_id_part() == 1 ) {
        $tdata->add_div(
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
        $tdata->add_span(
            {   out_class( join_subclass(
                    $CLASS_GRID_CELL_BASE, $SUBCLASS_PIECE_PRESENTER
                ) )
            },
            $credited_presenter
        );
    } ## end if ( defined $credited_presenter)

    shift @rooms;
    foreach ( @rooms ) {
        $writer->add_line(
            $COMMENT_CONTINUE_START, $panel->get_uniq_id(),
            $COMMENT_CONTINUE_END
        );
    } ## end foreach ( @rooms )

    return;
} ## end sub dump_grid_row_cell_group

sub dump_grid_row_make_cell_groups {
    my ( $writer, $filter, $region, $room_focus_map, $time_slot ) = @_;

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
            $writer,     $filter, $room_focus_map, $time_slot,
            $last_state, @room_queue
        ) if @room_queue;

        @room_queue = ( $room );
        $last_room  = $room;
        $last_state = $state;
    } ## end foreach my $room ( @rooms )

    dump_grid_row_cell_group(
        $writer,     $filter, $room_focus_map, $time_slot,
        $last_state, @room_queue
    ) if @room_queue;

    return;
} ## end sub dump_grid_row_make_cell_groups

sub dump_grid_row_time {
    my ( $writer, $filter, $region, $room_focus_map, $time_slot ) = @_;

    my $time             = $time_slot->get_start_seconds();
    my @time_row_classes = $CLASS_GRID_ROW_TIME_SLOT;
    my @time_classes     = (
        $CLASS_GRID_CELL_HEADER, $CLASS_GRID_CELL_TIME_SLOT,
        $CLASS_GRID_COLUMN_TIME,
    );

    if ( defined $filter->get_selected_presenter() ) {
        my $presenter = $filter->get_selected_presenter();
        if ( $time_slot->is_presenter_hosting( $presenter ) ) {
            push @time_row_classes, $CLASS_GRID_ROW_PRESENTER_BUSY;
            push @time_classes,     $CLASS_GRID_CELL_PRESENTER_BUSY;
        }
    } ## end if ( defined $filter->...)

    my $time_id = q{sched_id_} . datetime_to_kiosk_id( $time );

    $writer = $writer->nested_tr(
        { out_class( @time_row_classes ), id => $time_id } );

    if ( $options->show_day_column() ) {
        $writer->add_th(
            {   out_class(
                    $CLASS_GRID_CELL_HEADER, $CLASS_GRID_CELL_DAY,
                    $CLASS_GRID_COLUMN_DAY
                )
            },
            datetime_to_text( $time, qw{ day } )
        );
        $writer->add_th(
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
        $writer->add_th(
            { out_class( @time_classes ) },
            join q{}, @before_time, $tm
        );
    } ## end else [ if ( $options->show_day_column...)]

    dump_grid_row_make_cell_groups(
        $writer, $filter, $region, $room_focus_map,
        $time_slot
    );

    return;
} ## end sub dump_grid_row_time

sub dump_grid_timeslice {
    my ( $writer, $filter, $region ) = @_;

    $region->set_day_being_output( q{} );
    my @times = sort { $a <=> $b } $region->get_unsorted_times();
    $region->set_last_output_time( $times[ -1 ] );

    return unless @times;

    # todo(dpfister) Filter for times?

    my %room_focus_map = room_id_focus_map( $options, $filter, $region );

    $writer = dump_grid_header( $writer, $filter, $region, \%room_focus_map );
    foreach my $time ( @times ) {
        dump_grid_row_time(
            $writer, $filter, $region, \%room_focus_map,
            $region->get_time_slot( $time )
        );
    } ## end foreach my $time ( @times )

    return;
} ## end sub dump_grid_timeslice

sub desc_writer {
    my ( $writer, $filter, $region, $show_unbusy_panels ) = @_;

    if ( defined $filter->get_selected_presenter() ) {
        my $presenter = $filter->get_selected_presenter();

        my $hdr_text
            = $show_unbusy_panels
            ? q{Other panels}
            : q{Schedule for } . $presenter->get_presenter_name();

        if ( $options->is_mode_postcard() ) {
            $writer = $writer->nested_table(
                { out_class( $CLASS_DESC_TYPE_TABLE ) } );
            $writer->nested_colgroup(
                { out_class( $CLASS_DESC_TYPE_TABLE ) } )
                ->add_col( { out_class( $CLASS_DESC_TYPE_COLUMN ) } );

            $writer->nested_thead( { out_class( $CLASS_DESC_TYPE_HEADER ) } )
                ->add_tr( $h->th(
                { out_class( $CLASS_DESC_TYPE_COLUMN ) },
                $hdr_text
                ) );

            $writer = $writer->nested_tbody()->nested_tr()->nested_td();
        } ## end if ( $options->is_mode_postcard...)
        else {
            $writer->add_h2( $hdr_text );
        }
    } ## end if ( defined $filter->...)

    my $alt_class = $CLASS_DESC_SECTION . ( ++$output_idx );
    return $writer->nested_div(
        { out_class( $CLASS_DESC_SECTION, $alt_class ) } );
} ## end sub desc_writer

sub dump_desc_time_start {
    my ( $writer, $time, @hdr_suffix ) = @_;

    if ( $options->is_desc_form_div() ) {
        $writer->add_div(
            { out_class( $CLASS_DESC_TIME_SLOT ) }, join q{ },
            datetime_to_text( $time, qw{ both } ),
            @hdr_suffix
        );
        return $writer;
    } ## end if ( $options->is_desc_form_div...)

    $writer
        = $writer->nested_table( { out_class( $CLASS_DESC_TIME_TABLE ) } );
    $writer->nested_colgroup()
        ->add_col( { out_class( $CLASS_DESC_TIME_COLUMN ) } );

    $writer->add_thead(
        { out_class( $CLASS_DESC_TIME_HEADER ) },
        $h->tr( $h->th(
            { out_class( $CLASS_DESC_TIME_COLUMN, $CLASS_DESC_TIME_SLOT ) },
            join q{ },
            datetime_to_text( $time, qw{ both } ),
            @hdr_suffix
        ) )
    );

    $writer = $writer->nested_tbody();
    return $writer;
} ## end sub dump_desc_time_start

sub dump_desc_panel_note {
    my ( $writer, $panel, $conflict ) = @_;

    my @note;
    if ( $conflict ) {
        push @note, $h->b( q{Conflicts with one of your panels.} );
    }
    if ( defined $panel->get_cost() ) {
        push @note, $h->b( q{Premium workshop:} ),
            (
            $panel->get_capacity()
            ? q{ (Capacity: } . $panel->get_capacity() . q{)}
            : ()
            ),
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
        $writer->add_p(
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
    my ( $writer, $panel ) = @_;

    my $part   = $panel->get_uniq_id_part();
    my @series = grep {
        defined $_->get_start_seconds() && $_->get_uniq_id_part() != $part
    } get_related_panels( $panel );

    return unless @series;

    @series = sort {
               $a->get_uniq_id_part()  <=> $b->get_uniq_id_part()
            || $a->get_start_seconds() <=> $b->get_start_seconds()
    } @series;

    $writer->add_ul(
        {   out_class( join_subclass(
                $CLASS_DESC_BASE, $SUBCLASS_PIECE_PARTS_LIST
            ) )
        },
        join q{ },
        map {    ## no critic(TooMuchCode::ProhibitLargeBlock)
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
    return if $room_focus_map->{ $id }->are_descriptions_hidden();

    my $panel = $panel_state->get_active_panel();

    return unless $panel->get_start_seconds() == $time;

    return if $panel->get_panel_type()->get_is_hidden();

    if ( $panel_state->get_is_break() ) {
        return if $options->hide_breaks();
    }
    else {
        return if $room->get_room_is_hidden();

        # Only worry about presenters for non-break panels
        my $filter_panelist = $filter->get_selected_presenter();
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
    my ( $writer, $filter, $time_slot, $panel_state, @extra_classes ) = @_;

    if ( !defined $panel_state ) {
        return if $options->is_desc_form_div();
        $writer->add_td(
            { out_class( @extra_classes, $CLASS_KIOSK_DESC_CELL_EMPTY ) } );
        return;
    } ## end if ( !defined $panel_state)

    my $panel      = $panel_state->get_active_panel();
    my $panel_type = $panel->get_panel_type();

    my @subclasses = css_subclasses_for_panel( $panel );
    my $conflict;

    if ( defined $filter->get_selected_presenter() ) {
        my $presenter = $filter->get_selected_presenter();
        if ( $panel->is_presenter_hosting( $presenter ) ) {
            push @subclasses, $SUBCLASS_GUEST_PANEL;
        }
        elsif ( $time_slot->is_presenter_hosting( $presenter ) ) {
            push @subclasses, $SUBCLASS_BUSY_PANEL;
            $conflict = 1;
        }
    } ## end if ( defined $filter->...)

    my $name               = $panel->get_name();
    my $credited_presenter = $panel->get_credits();

    if ( $panel_type->is_cafe() ) {
        $name = q{Cosplay Café Featuring } . $name;
    }

    my %desc_attributes = (
        id => $panel->get_href_anchor(),
        out_class(
            @extra_classes,
            map { join_subclass( $CLASS_DESC_BASE, $_ ) } @subclasses
        )
    );

    $writer
        = $options->is_desc_form_div()
        ? $writer->nested_div( \%desc_attributes )
        : $writer->nested_td( \%desc_attributes );

    $writer = $writer->nested_div() if $options->is_mode_kiosk();

    $writer->add_div(
        {   out_class(
                join_subclass( $CLASS_DESC_BASE, $SUBCLASS_PIECE_ID )
            )
        },
        $panel->get_uniq_id()
    );
    if ( $options->show_sect_grid() ) {
        $writer->add_a(
            {   href => q{#} . $panel->get_href_anchor() . $LINK_SUFFIX_GRID,
                out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_NAME ) )
            },
            $name
        );
    } ## end if ( $options->show_sect_grid...)
    else {
        $writer->add_div(
            {   out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_NAME ) )
            },
            $name
        );
    } ## end else [ if ( $options->show_sect_grid...)]

    my $cost = $panel->get_cost();
    if ( defined $cost && $panel->get_uniq_id_part() == 1 ) {
        $writer->add_div(
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
        $writer->add_p(
            {   out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_START
                ) )
            },
            datetime_to_text( $panel->get_start_seconds(), qw{ both } )
        );
    } ## end if ( $options->is_mode_kiosk...)
    else {
        $writer->add_p(
            {   out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_ROOM ) )
            },
            join q{, },
            map { $_->get_long_room_name() } $panel->get_rooms()
        );
    } ## end else [ if ( $options->is_mode_kiosk...)]
    if ( defined $credited_presenter ) {
        $writer->add_p(
            {   out_class( join_subclass(
                    $CLASS_DESC_BASE, $SUBCLASS_PIECE_PRESENTER
                ) )
            },
            $credited_presenter
        );
    } ## end if ( defined $credited_presenter)

    $writer->add_p(
        {   out_class( join_subclass(
                $CLASS_DESC_BASE, $SUBCLASS_PIECE_DESCRIPTION
            ) )
        },
        $panel->get_description()
    );

    dump_desc_panel_note( $writer, $panel, $conflict );
    dump_desc_panel_parts( $writer, $panel );

    return;
} ## end sub dump_desc_panel_body

sub dump_desc_body {
    my ($writer_or_code, $filter, $region, $room_focus_map,
        $show_unbusy_panels
    ) = @_;
    my $filter_panelist = $filter->get_selected_presenter();

    $region->set_day_being_output( q{} );
    my @times = sort { $a <=> $b } $region->get_unsorted_times();
    $region->set_last_output_time( $times[ -1 ] );

    foreach my $time ( @times ) {
        my $writer;
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

            if ( !defined $writer ) {
                $writer
                    = blessed $writer_or_code
                    ? $writer_or_code
                    : $writer_or_code->();

                my @hdr_extra;
                if (   $show_unbusy_panels
                    && $time_slot->is_presenter_hosting( $filter_panelist ) )
                {
                    push @hdr_extra, qw{ Conflict };
                }
                $writer = dump_desc_time_start( $writer, $time, @hdr_extra );
            } ## end if ( !defined $writer )

            my $panel_writer = $writer;
            if ( $options->is_desc_form_table() ) {
                $panel_writer = $writer->nested_tr(
                    { out_class( $CLASS_DESC_PANEL_ROW ) } );
            }
            dump_desc_panel_body(
                $panel_writer, $filter, $time_slot,
                $panel_state
            );
        } ## end foreach my $panel_state ( @panel_states)
    } ## end foreach my $time ( @times )

    return;
} ## end sub dump_desc_body

sub dump_desc_body_regions {
    my ( $writer, $filter, $region, $show_unbusy_panels ) = @_;
    if ( defined $region ) {
        my %room_focus_map = room_id_focus_map( $options, $filter, $region );
        dump_desc_body(
            $writer, $filter, $region, \%room_focus_map,
            $show_unbusy_panels
        );
        return;
    } ## end if ( defined $region )

    foreach my $region ( get_time_regions() ) {
        my %room_focus_map = room_id_focus_map( $options, $filter, $region );
        dump_desc_body(
            $writer, $filter, $region, \%room_focus_map,
            $show_unbusy_panels
        );
    } ## end foreach my $region ( get_time_regions...)

    return;
} ## end sub dump_desc_body_regions

sub dump_desc_timeslice {
    my ( $writer, $filter, $region ) = @_;

    my @filters = ( $filter );
    @filters = split_filter_by_panelist(
        {   ranks => [
                (     $options->is_desc_by_guest()
                    ? $Presenter::RANK_GUEST
                    : ()
                ),
                (   $options->is_desc_by_panelist()
                    ? grep { $_ != $Presenter::RANK_GUEST } @Presenter::RANKS
                    : ()
                ),
            ],
            is_by_desc => 1
        },
        @filters
    );

    foreach my $desc_filter ( @filters ) {
        my $on_dump;
        my $region_writer;
        $on_dump = sub {
            $region_writer //= desc_writer( $writer, $desc_filter, $region );
            return $region_writer;
        };
        dump_desc_body_regions( $on_dump, $desc_filter, $region, 0 );
        $region_writer = undef;

        if (   defined $desc_filter->get_selected_presenter()
            && $options->is_just_everyone()
            && $options->is_desc_everyone_together() ) {
            dump_desc_body_regions( $on_dump, $desc_filter, $region, 1 );
            $region_writer = undef;
        } ## end if ( defined $desc_filter...)
    } ## end foreach my $desc_filter ( @filters)

    return;
} ## end sub dump_desc_timeslice

sub cache_inline_style {
    my ( $file ) = @_;
    return unless defined $file;
    state %cache;
    if (   !File::Spec->file_name_is_absolute( $file )
        && !-e $file
        && -e File::Spec->catfile( $SUBDIR_CSS, $file ) ) {
        $file = File::Spec->catfile( $SUBDIR_CSS, $file );
    }
    return $cache{ $file } //= read_file(
        $file,
        { chomp => 1, array_ref => 1, err_mode => q{carp} }
    );
} ## end sub cache_inline_style

sub open_dump_file {
    my ( $filter, $def_name ) = @_;
    $def_name //= q{index};

    my $writer = WriteLevel::WebPage->new( formatter => $h );

    if ( $options->is_output_stdio() ) {
        return ( $writer, undef );
    }

    my @subnames
        = map { canonical_header $_ } $filter->get_output_name_pieces();

    my $ofname = $options->get_output_file();
    if ( -d $ofname ) {
        push @subnames, $def_name unless @subnames;
        $ofname = File::Spec->catfile(
            $ofname, join q{.}, @subnames,
            $HTML_SUFFIX_HTML
        );
    } ## end if ( -d $ofname )
    elsif ( @subnames ) {
        my ( $vol, $dir, $base ) = File::Spec->splitpath( $ofname );
        my $suffix = $HTML_SUFFIX_HTML;
        if ( $base =~ s{[.](html?)\z}{}xms ) {
            $suffix = $1;
        }
        $base = join q{.}, $base, @subnames, $suffix;

        $ofname = File::Spec->catpath( $vol, $dir, $base );
    } ## end elsif ( @subnames )

    return ( $writer, $ofname );
} ## end sub open_dump_file

sub close_dump_file {
    my ( $writer, $ofname ) = @_;
    my $file_name = $ofname // q{<STDIO>};

    if ( $options->is_output_stdio() ) {
        $writer->write_to( \*STDOUT );
    }
    else {
        open my $fh, q{>:encoding(utf8)}, ${ ofname }
            or die qq{Unable to write: ${file_name}\n};
        $writer->write_to( $fh );
        $fh->close
            or die qq{Unable to close ${file_name}: ${ERRNO}\n};
    } ## end else [ if ( $options->is_output_stdio...)]

    return;
} ## end sub close_dump_file

sub dump_styles {
    my ( $writer ) = @_;

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
            my $style_out = $writer->get_html_style();

            my $lines = cache_inline_style( $fname );
            foreach my $line ( @{ $lines } ) {
                $style_out->add_line( $line );
            }
        } ## end if ( $is_html )
        elsif ( $fname =~ $RE_COLOR_STYLE ) {
            my ( $unused, $color_set ) = split m{=}xms, $fname, 2;
            $color_set //= $Data::PanelType::DEF_COLOR_SET;
            $color_set = canonical_header( $color_set );

            my $style_out;

            foreach my $panel_type (
                sort { $a->get_prefix() cmp $b->get_prefix() }
                Table::PanelType::all_types() ) {
                my $prefix = $panel_type->get_prefix();
                next unless $prefix =~ m{\S}xms;
                my $color = $panel_type->get_color( $color_set );
                next unless defined $color;
                next
                    unless $color
                    =~ m{\A ( [#] [[:xdigit:]]++ | inherit | black | white | rgba? [(] .* ) \z}xms;

                if ( !defined $style_out ) {
                    $style_out = $writer->get_css_style( $media );
                    $style_out->add_line(
                        $COMMENT_STYLE_START, $style,
                        $COMMENT_STYLE_END
                    );
                } ## end if ( !defined $style_out)

                $style_out->nested_selector(
                    q{.descType}, uc $prefix,
                    qq{,\n}, q{.panelType}, uc $prefix
                )->add_line( q{background-color: }, $color );
            } ## end foreach my $panel_type ( sort...)
        } ## end elsif ( $fname =~ $RE_COLOR_STYLE)
        elsif ( $options->is_css_loc_embedded() ) {
            my $lines = cache_inline_style( $fname );

            my $style_out;

            foreach my $line ( @{ $lines } ) {
                next unless $line =~ m{\S}xms;
                next if $line     =~ m{[@]charset}xmsi;
                next
                    if $line =~ m{\A \s* /[*] (?:[^*]++:[*][^/])*+ [*]/ }xms;

                if ( !defined $style_out ) {
                    $style_out = $writer->get_css_style( $media );
                    $style_out->add_line(
                        $COMMENT_STYLE_START, $style,
                        $COMMENT_STYLE_END
                    );
                } ## end if ( !defined $style_out)

                $style_out->add_line( $line );
            } ## end foreach my $line ( @{ $lines...})
        } ## end elsif ( $options->is_css_loc_embedded...)
        else {
            my $style_out = $writer->get_html_style();

            $style_out->add_link( {
                href => $fname,
                rel  => $HTML_STYLESHEET,
                type => $HTML_TEXT_CSS,
                ( defined $media ? ( media => $media ) : () )
            } );
        } ## end else [ if ( $is_html ) ]
    } ## end foreach my $style ( $options...)

    return;
} ## end sub dump_styles

sub dump_file_header {
    my ( $writer, $filter ) = @_;

    $writer->get_before_html()->add_line( $HTML_DOCTYPE_HTML );

    $writer->get_head()->add_meta( { charset => $HTML_CHARSET_UTF8 } );
    $writer->get_head()
        ->add_meta( { name => $HTML_APP_OKAY, content => $HTML_YES } );

    my @subnames = $filter->get_output_name_pieces();
    my $title    = $options->get_title();
    if ( @subnames ) {
        $title .= q{: } . join q{, }, @subnames;
    }

    $writer->get_head()->add_title( $title );
    $writer->get_head()->add_link( {
        href =>
            q{https://fonts.googleapis.com/css?family=Nunito+Sans&display=swap},
        rel => $HTML_STYLESHEET
    } );

    return;
} ## end sub dump_file_header

sub dump_table_regions {
    my ( $writer, $filter ) = @_;

    my $need_desc = $options->show_sect_descriptions();
    my $any_desc_shown;
    my $desc_are_last = $options->is_desc_loc_last();

    my @regions;
    my $filter_region = $filter->get_selected_region();
    if ( defined $filter_region ) {
        push @regions, $filter_region;
    }
    else {
        @regions = ( get_time_regions() );
    }
    undef $desc_are_last if 1 == scalar @regions;

    if ( $options->show_sect_grid() ) {
        foreach my $region ( @regions ) {
            dump_grid_timeslice( $writer, $filter, $region );
            next unless $need_desc;
            next if $desc_are_last;

            dump_desc_timeslice( $writer, $filter, $region );
            $any_desc_shown = 1;
        } ## end foreach my $region ( @regions)
        return if $options->is_desc_loc_mixed();
    } ## end if ( $options->show_sect_grid...)

    return if $any_desc_shown;
    return unless $need_desc;

    dump_desc_timeslice( $writer, $filter, $filter_region );

    return;
} ## end sub dump_table_regions

sub dump_tables {
    my ( $filter ) = @_;

    my ( $writer, $ofname ) = open_dump_file( $filter );

    dump_file_header( $writer, $filter );

    dump_styles( $writer );

    my @filters = ( $filter );
    @filters = split_filter_by_panelist(
        {   ranks => [
                (     $options->is_section_by_guest()
                    ? $Presenter::RANK_GUEST
                    : ()
                ),
                (   $options->is_section_by_panelist()
                    ? grep { $_ != $Presenter::RANK_GUEST } @Presenter::RANKS
                    : ()
                ),
            ],
            is_by_desc => undef
        },
        @filters
    );

    @filters = split_filter_by_room(
        [ get_rooms_for_region( $options ) ],
        @filters
    ) if $options->is_section_by_room();

    @filters = split_filter_by_timestamp( @filters )
        if $options->is_section_by_day();

    for my $copy ( 1 .. $options->get_copies() ) {
        foreach my $section_filter ( @filters ) {
            dump_table_regions( $writer->get_body(), $section_filter );
        }

    } ## end for my $copy ( 1 .. $options...)

    close_dump_file( $writer, $ofname );

    return;
} ## end sub dump_tables

sub dump_kiosk_desc {
    my ( $writer, $region ) = @_;

    my @times        = sort { $a <=> $b } $region->get_unsorted_times();
    my @region_rooms = get_rooms_for_region( $options, $region );
    foreach my $time ( @times ) {
        my $time_id    = q{desc_id_} . datetime_to_kiosk_id( $time );
        my $time_table = $writer->nested_div( {
            out_class( $CLASS_KIOSK_DESCRIPTIONS, $CLASS_KIOSK_HIDDEN ),
            id => $time_id
        } )->nested_table( { out_class( $CLASS_DESC_TIME_TABLE ) } );
        my $colgroup = $time_table->nested_colgroup();
        $colgroup->add_col( { out_class( $CLASS_KIOSK_COLUMN_ROOM ) } );
        $colgroup->add_col( { out_class( $CLASS_KIOSK_COLUMN_CURRENT ) } );
        $colgroup->add_col( { out_class( $CLASS_KIOSK_COLUMN_FUTURE ) } );

        my $head_row
            = $time_table->nested_thead(
            { out_class( $CLASS_KIOSK_DESC_HEAD ) } )
            ->nested_tr( { out_class( $CLASS_KIOSK_DESC_ROW_HEADERS ) } );
        $head_row->add_th( {
            out_class(
                $CLASS_KIOSK_COLUMN_ROOM,
                $CLASS_KIOSK_DESC_CELL_HEADER
            )
        } );
        $head_row->add_th(
            {   out_class(
                    $CLASS_KIOSK_COLUMN_CURRENT,
                    $CLASS_KIOSK_DESC_CELL_HEADER
                )
            },
            q{Current Panel}
        );
        $head_row->add_th(
            {   out_class(
                    $CLASS_KIOSK_COLUMN_FUTURE,
                    $CLASS_KIOSK_DESC_CELL_HEADER
                )
            },
            q{Upcoming Panel}
        );

        my $table_body = $time_table->nested_tbody(
            { out_class( $CLASS_KIOSK_DESC_BODY ) } );

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
            my $room_row = $table_body->nested_tr(
                { out_class( $CLASS_KIOSK_DESC_ROW_ROOM ) } );
            $room_row->add_th(
                {   out_class(
                        $CLASS_KIOSK_DESC_CELL_ROOM,
                        $CLASS_KIOSK_DESC_CELL_HEADER
                    )
                },
                $name
            );
            dump_desc_panel_body(
                $room_row,
                Data::Partion->unfiltered(), $time_slot,
                $cur_panels->{ $id },
                $CLASS_KIOSK_DESC_CELL_CURRENT
            );
            dump_desc_panel_body(
                $room_row,
                Data::Partion->unfiltered(), $time_slot,
                $next_panels->{ $id },
                $CLASS_KIOSK_DESC_CELL_FUTURE
            );
        } ## end foreach my $room ( @region_rooms)
    } ## end foreach my $time ( @times )

    return;
} ## end sub dump_kiosk_desc

sub dump_kiosk {
    my ( $writer, $ofname )
        = open_dump_file( Data::Partion->unfiltered(), q{kiosk} );

    $writer->get_before_html()->add_line( $HTML_DOCTYPE_HTML );

    $writer->get_head()->add_meta( { charset => $HTML_CHARSET_UTF8 } );
    $writer->get_head()
        ->add_meta( { name => $HTML_APP_OKAY, content => $HTML_YES } );
    $writer->get_head()->add_title( $options->get_title() );
    $writer->get_head()->add_link( {
        href => q{css/kiosk.css},
        rel  => $HTML_STYLESHEET,
        type => $HTML_TEXT_CSS
    } );

    dump_styles( $writer );

    $writer->get_head()
        ->add_script( { type => q{text/javascript}, src => q{js/kiosk.js} } );

    my $bar
        = $writer->get_body()
        ->nested_div( { out_class( $CLASS_KIOSK_BAR ) } );
    $bar->add_img( {
        out_class( $CLASS_KIOSK_LOGO ),
        src => q{images/CosplayAmericaLogoAlt.svg},
        alt => q{Cosplay America}
    } );
    $bar->nested_div(
        { out_class( $CLASS_KIOSK_TIME ), id => q{current_time} } )
        ->add_line( q{SOMEDAY ##:## ?M} );

    $writer->get_body()
        ->add_div( { out_class( $CLASS_KIOSK_GRID_HEADERS ) } );
    my $regions_div = $writer->get_body()
        ->nested_div( { out_class( $CLASS_KIOSK_GRID_ROWS ) } );

    foreach my $region ( get_time_regions() ) {
        dump_grid_timeslice(
            $regions_div, Data::Partion->unfiltered(),
            $region
        );
    } ## end foreach my $region ( get_time_regions...)

    foreach my $region ( get_time_regions() ) {
        dump_kiosk_desc( $writer->get_body(), $region );
    }

    close_dump_file( $writer, $ofname );

    return;
} ## end sub dump_kiosk

sub update_hide_shown {
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

    return;
} ## end sub update_hide_shown

sub main_arg_set {
    my ( $args, $prev_file ) = @_;

    # Start output idx back from 0
    $output_idx = 0;

    $options = Options->options_from( $args );

    foreach my $style ( $options->get_styles() ) {
        next unless $style =~ $RE_COLOR_STYLE;
        my ( $unused, $color_set ) = split m{=}xms, $style, 2;
        $color_set //= $Data::PanelType::DEF_COLOR_SET;
        Table::PanelType::add_color_set( $color_set );
    } ## end foreach my $style ( $options...)

    if ( defined $options->get_input_file() ) {
        if ( !defined $prev_file ) {
            read_spreadsheet_file( $options->get_input_file() );
            $prev_file = $options->get_input_file();
        }
        elsif ( $prev_file ne $options->get_input_file() ) {
            Options::dump_help( qw{ --input } );
            die
                qq{--input file must all be the same for multiple option groups\n};
        }
    } ## end if ( defined $options->...)
    elsif ( !defined $prev_file ) {
        Options::dump_help( qw{ --input } );
        die qq{Missing --input option\n};
    }

    update_hide_shown();
    populate_time_regions( $options );

    if ( $options->is_mode_kiosk() ) {
        dump_kiosk;
        return $prev_file;
    }

    my @filters = ( Data::Partion->unfiltered() );
    @filters = split_filter_by_panelist(
        {   ranks => [
                (     $options->is_file_by_guest()
                    ? $Presenter::RANK_GUEST
                    : ()
                ),
                (   $options->is_file_by_panelist()
                    ? grep { $_ != $Presenter::RANK_GUEST } @Presenter::RANKS
                    : ()
                ),
            ],
            is_by_desc => undef
        },
        @filters
    );

    @filters = split_filter_by_room(
        [ get_rooms_for_region( $options ) ],
        @filters
    ) if $options->is_file_by_room();

    @filters = split_filter_by_timestamp( @filters )
        if $options->is_file_by_day();

    foreach my $filter ( @filters ) {
        dump_tables( $filter );
    }

    return $prev_file;
} ## end sub main_arg_set

sub main {
    my ( @args ) = @_;

    if ( !@args ) {
        Options::dump_help();
        exit 1;
    }

    my $split_idx = firstidx { $_ eq q{--} } @args;
    my @before;
    if ( defined $split_idx ) {
        @before = @args[ 0 .. $split_idx - 1 ];
        @args   = @args[ $split_idx + 1 .. $#args ];
    }

    my $prev_file;
    do {
        unshift @args, @before;
        $prev_file = main_arg_set( \@args, $prev_file );
    } while ( @args );

    exit 0;
} ## end sub main

main( @ARGV );

1;

__END__
