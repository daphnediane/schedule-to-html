#!/usr/bin/perl

use v5.38.0;
use utf8;

use Carp            qw{ verbose croak };         ## no critic (ProhibitUnusedImport)
use English         qw{ -no_match_vars };
use File::Slurp     qw{ read_file };
use File::Spec      qw{};
use FindBin         qw{};
use Getopt::Long    qw{ GetOptionsFromArray };
use HTML::Tiny      qw{};
use List::MoreUtils qw{ firstidx };
use List::Util      qw{ any };
use Readonly;

use lib "${FindBin::Bin}/lib";
use ActivePanel          qw{};
use Canonical            qw{ :all };
use Data::Panel          qw{};
use Data::PanelType      qw{};
use Data::Partition      qw{};
use Data::Room           qw{};
use Options              qw{};
use PartitionPanels      qw{ :all };
use Presenter            qw{};
use Table::Panel         qw{ :all };
use Table::PanelType     qw{ :all };
use Table::Room          qw{ :all };
use Table::TimeRegion    qw{ :all };
use TimeDecoder          qw{ :from_text :to_text :timepoints :utility };
use TimeRange            qw{};
use Data::RegionForTable qw{};
use TimeSlot             qw{};
use Workbook             qw{};
use Workbook::Sheet      qw{};
use WriteLevel           qw{};
use WriteLevel::CSS      qw{};
use WriteLevel::HTML     qw{};
use WriteLevel::WebPage  qw{};

# HTML keywoards
Readonly our $HTML_APP_OKAY     => q{apple-mobile-web-app-capable};
Readonly our $HTML_CHARSET_UTF8 => q{UTF-8};
Readonly our $HTML_DOCTYPE_HTML => q{<!doctype html>};
Readonly our $HTML_STYLESHEET   => q{stylesheet};
Readonly our $HTML_TEXT_CSS     => q{text/css};
Readonly our $HTML_YES          => q{yes};

my $options;
my $h = HTML::Tiny->new( mode => qw{ html } );

# Current processing state
## no critic (Variables::ProhibitPackageVars)
our $local_focus_map;
our $local_filter;
our $local_region;
our $local_time_seconds;
our $local_time_slot;
our $local_webpage;
## use critic

# Color styles
Readonly our $RE_COLOR_STYLE =>
    qr{ \A (?: all: | print: | screen: )? [+] (?i:(?:panel_)?color) (?: = | \z ) }xms;

sub join_subclass ( $base, @subclasses ) {
    $base //= q{};
    foreach my $subclass ( @subclasses ) {
        next unless defined $subclass;
        $subclass =~ s{\A(\w)}{\u$1}xms if ( $base =~ m{\w\z}xms );
        $base .= $subclass;
    }
    return if $base eq q{};
    return $base;
} ## end sub join_subclass

sub out_class ( @fields ) {
    return unless @fields;
    my $res = join q{ }, @fields;
    $res =~ s{\s\s+}{ }xms;
    $res =~ s{\A\s}{}xms;
    $res =~ s{\s\z}{}xms;
    return if $res eq q{};
    return class => $res;
} ## end sub out_class

sub open_dump_file ( $def_name //= q{index} ) {
    my $writer = WriteLevel::WebPage->new( formatter => $h );

    if ( $options->is_output_stdio() ) {
        return ( $writer, undef );
    }

    my @subnames
        = map { canonical_header $_ } $local_filter->get_output_name_pieces();

    my $ofname = $options->get_output_file();
    if ( -d $ofname ) {
        push @subnames, $def_name unless @subnames;
        $ofname = File::Spec->catfile(
            $ofname, join q{.}, @subnames,
            qw{ html }
        );
    } ## end if ( -d $ofname )
    elsif ( @subnames ) {
        my ( $vol, $dir, $base ) = File::Spec->splitpath( $ofname );
        my @suffix = qw{ html };
        if ( $base =~ m{[.](html?)\z}xms ) {
            @suffix = ();
        }
        $base = join q{.}, $base, @subnames, @suffix;

        $ofname = File::Spec->catpath( $vol, $dir, $base );
    } ## end elsif ( @subnames )

    return ( $writer, $ofname );
} ## end sub open_dump_file

sub dump_file_header ( $writer ) {
    $writer->get_before_html()->add_line( $HTML_DOCTYPE_HTML );

    $writer->get_head()->add_meta( { charset => $HTML_CHARSET_UTF8 } );
    $writer->get_head()
        ->add_meta( { name => $HTML_APP_OKAY, content => $HTML_YES } );

    my @subnames = $local_filter->get_output_name_pieces();
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

sub dump_grid_panel ( $writer, $panel_state, @rooms ) {
    return unless defined $panel_state;
    my $panel = $panel_state->get_active_panel();
    return unless defined $panel;

    my @classes;
    push @classes, join q{}, qw{ time-start- },
        $panel_state->get_start_seconds();
    push @classes, join q{}, qw{ time-sop- },
        $panel_state->get_start_seconds();

    $writer = $writer->nested_div( { out_class( qw{ panel } ) } );
    $writer->add_h4( { out_class( qw{ panel-title } ) }, $panel->get_name() );
    $writer->add_span(
        { out_class( qw{ panel-time } ) },
        join q{},
        datetime_to_text( $panel->get_start_seconds(), qw{ time } ), q{ — },
        datetime_to_text( $panel->get_end_seconds(),   qw{ time } )
    );
    $writer->add_span(
        { out_class( qw{ panel-room } ) },
        join q{, },
        map { $_->get_long_room_name() } $panel->get_rooms()
    );
    $writer->add_span(
        { out_class( qw{ panel-presenter } ) },
        $panel->get_credits()
    );
    $writer->nested_p(
        { out_class( qw{ panel-description } ) },
    )->add_span( $panel->get_description() );
    ## TODO ( notes, parts, conflict, etc)...
    return;

} ## end sub dump_grid_panel

sub dump_grid_make_groups ( $writer ) {
    my @room_queue;
    my $last_room;
    my $last_state;

    foreach my $room ( visible_rooms() ) {
        next
            unless $options->show_all_rooms()
            || $local_region->is_room_active( $room );

        my $state = $local_time_slot->lookup_current( $room );
        if (   scalar @room_queue
            && defined $state
            && defined $last_state
            && $state->get_active_panel() == $last_state->get_active_panel()
            && $state->get_start_seconds() == $last_state->get_start_seconds()
            && $state->get_end_seconds() == $last_state->get_end_seconds()
            && $last_state->get_rows() == $state->get_rows() ) {
            push @room_queue, $room;
            next;
        } ## end if ( scalar @room_queue...)

        dump_grid_panel( $writer, $last_state, @room_queue )
            if @room_queue;

        @room_queue = ( $room );
        $last_room  = $room;
        $last_state = $state;
    } ## end foreach my $room ( visible_rooms...)

    dump_grid_panel( $writer, $last_state, @room_queue )
        if @room_queue;

    return;
} ## end sub dump_grid_make_groups

sub dump_grid_time ( $writer, $same_day ) {
    my ( $day, $tm ) = datetime_to_text( $local_time_seconds );
    my $is_same_day = $local_region->get_day_being_output() eq $day
        && $local_region->get_last_output_time() != $local_time_seconds;
    $local_region->set_day_being_output( $day );

    if ( $options->show_day_column() ) {
        $writer->add_h3(
            { out_class( qw{ time-slot } ) },
            $h->div(
                { out_class( qw{ time-slot-day } ) },
                datetime_to_text( $local_time_seconds, $day )
                )
                . $h->div(
                { out_class( qw{ time-slot-time } ) },
                datetime_to_text( $local_time_seconds, $tm )
                )
        );
    } ## end if ( $options->show_day_column...)
    else {
        $writer->add_h3(
            { out_class( qw{ time-slot } ) },
            $is_same_day ? $tm : $day . $h->br() . $tm,
        );
    } ## end else [ if ( $options->show_day_column...)]

    dump_grid_make_groups( $writer );
    return;
} ## end sub dump_grid_time

sub dump_grid_timeslice () {
    my @times = sort { $a <=> $b } $local_region->get_unsorted_times();
    return unless @times;

    $local_region->set_day_being_output( q{} );
    $local_region->set_last_output_time( $times[ -1 ] );

    my @name = $local_filter->get_output_name_pieces();
    if ( !defined $local_filter->get_selected_region() ) {
        push @name, $local_region->get_region_name();
    }

    my $writer = $local_webpage->get_body();

    $writer->add_h2( join q{ }, @name, qw{ Schedule } );

    my $sch_class = canonical_class( join q{_}, qw{ schedule }, @name );
    $writer = $writer->nested_div( { out_class( $sch_class ) } );

    foreach my $time ( @times ) {
        local $local_time_seconds = $time;
        local $local_time_slot
            = $local_region->get_time_slot( $local_time_seconds );
        dump_grid_time( $writer );
    } ## end foreach my $time ( @times )

    return;
} ## end sub dump_grid_timeslice

sub dump_desc_timeslice () {
    return;
}

sub dump_grid_regions () {
    my $need_desc = $options->show_sect_descriptions();
    my $any_desc_shown;
    my $desc_are_last = $options->is_desc_loc_last();

    my @regions;
    my $filter_region = $local_filter->get_selected_region();
    if ( defined $filter_region ) {
        push @regions, $filter_region;
    }
    else {
        @regions = ( get_time_regions() );
    }
    undef $desc_are_last if 1 == scalar @regions;

    if ( $options->show_sect_grid() ) {
        foreach my $region ( @regions ) {
            local $local_region    = $region;
            local $local_focus_map = $local_region->room_focus_map_by_id(
                select_room => $local_filter->get_selected_room(),
                $options->has_rooms()
                ? ( focus_rooms => [ $options->get_rooms() ] )
                : ()
            );

            dump_grid_timeslice();
            next unless $need_desc;
            next if $desc_are_last;

            dump_desc_timeslice();
            $any_desc_shown = 1;
        } ## end foreach my $region ( @regions)
        return if $options->is_desc_loc_mixed();
    } ## end if ( $options->show_sect_grid...)

    return if $any_desc_shown;
    return unless $need_desc;

    foreach my $region ( @regions ) {
        local $local_region    = $region;
        local $local_focus_map = $local_region->room_focus_map_by_id(
            select_room => $local_filter->get_selected_room(),
            $options->has_rooms()
            ? ( focus_rooms => [ $options->get_rooms() ] )
            : ()
        );

        dump_desc_timeslice();
    } ## end foreach my $region ( @regions)

    return;
} ## end sub dump_grid_regions

sub dump_grid () {
    my ( $writer, $ofname ) = open_dump_file();

    local $local_webpage = $writer;

    dump_file_header( $writer );

    my @filters = ( $local_filter );
    @filters = split_filter_by_panelist(
        {   ranks => [
                (     $options->is_section_by_guest()
                    ? $Presenter::RANK_GUEST
                    : ()
                ),
                (     $options->is_section_by_judge()
                    ? $Presenter::RANK_JUDGE
                    : ()
                ),
                (   $options->is_section_by_panelist()
                    ? grep {
                               $_ != $Presenter::RANK_GUEST
                            && $_ != $Presenter::RANK_JUDGE
                        } @Presenter::RANKS
                    : ()
                ),
            ],
            is_by_desc => undef
        },
        @filters
    );

    @filters = split_filter_by_room( [ visible_rooms() ], @filters )
        if $options->is_section_by_room();

    @filters = split_filter_by_timestamp( [ get_time_regions() ], @filters )
        if $options->is_section_by_day();

    for my $copy ( 1 .. $options->get_copies() ) {
        foreach my $section_filter ( @filters ) {
            local $local_filter = $section_filter;
            dump_grid_regions();
        }

    } ## end for my $copy ( 1 .. $options...)

    close_dump_file( $writer, $ofname );

    return;
} ## end sub dump_grid

sub dump_kiosk {
    die qq{Not implemented\n};
}

sub close_dump_file ( $writer, $ofname ) {
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

sub update_hide_shown {
    foreach my $room ( Table::Room::all_rooms() ) {
        $room->clear_override_room_as_hidden();
    }

    foreach my $room_name ( $options->get_rooms_shown() ) {
        my $room = Table::Room::lookup( $room_name );
        next unless defined $room;
        $room->override_room_as_shown();
    }
    foreach my $room_name ( $options->get_rooms_hidden() ) {
        my $room = Table::Room::lookup( $room_name );
        next unless defined $room;
        $room->override_room_as_hidden();
    }

    foreach my $panel_type ( Table::PanelType::all_types() ) {
        $panel_type->clear_override_hidden();
    }
    foreach my $paneltype_name ( $options->get_paneltypes_shown() ) {
        my $paneltype = Table::PanelType::lookup( $paneltype_name );
        next unless defined $paneltype;
        $paneltype->override_make_shown();
    }
    foreach my $paneltype_name ( $options->get_paneltypes_hidden() ) {
        my $paneltype = Table::PanelType::lookup( $paneltype_name );
        next unless defined $paneltype;
        $paneltype->override_make_hidden();
    }

    return;
} ## end sub update_hide_shown

sub main_arg_set ( $args, $prev_file ) {
    $options = Options->options_from( $args );

    foreach my $style ( $options->get_styles() ) {
        next unless $style =~ $RE_COLOR_STYLE;
        my ( $unused, $color_set ) = split m{=}xms, $style, 2;
        $color_set //= $Data::PanelType::DEF_COLOR_SET;
        Table::PanelType::add_color_set( $color_set );
    } ## end foreach my $style ( $options...)

    if ( !defined $options->get_input_file() ) {
        print qq{Missing --input option\n} or 0;
        Options::dump_help( qw{ --input } );
        exit 1;
    }

    read_spreadsheet_file( $options->get_input_file() );

    update_hide_shown();
    populate_time_regions( $options );

    if ( $options->is_mode_kiosk() ) {
        dump_kiosk;
        return $prev_file;
    }

    my @filters = ( Data::Partition->unfiltered() );
    @filters = split_filter_by_panelist(
        {   ranks => [
                (     $options->is_file_by_guest()
                    ? $Presenter::RANK_GUEST
                    : ()
                ),
                (     $options->is_file_by_judge()
                    ? $Presenter::RANK_JUDGE
                    : ()
                ),
                (   $options->is_file_by_panelist()
                    ? grep {
                               $_ != $Presenter::RANK_GUEST
                            && $_ != $Presenter::RANK_JUDGE
                        } @Presenter::RANKS
                    : ()
                ),
            ],
            is_by_desc => undef
        },
        @filters
    );

    @filters = split_filter_by_room( [ visible_rooms() ], @filters )
        if $options->is_file_by_room();

    @filters = split_filter_by_timestamp( [ get_time_regions() ], @filters )
        if $options->is_file_by_day();

    foreach my $filter ( @filters ) {
        local $local_filter = $filter;
        dump_grid;
    }

    return $prev_file;
} ## end sub main_arg_set

sub main ( @args ) {
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

POSIX::_exit( 0 );
1;

__END__
