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
use Readonly;

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
use TimeDecoder         qw{ :from_text :to_text :timepoints :utility };
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
Readonly our $HTML_TEXT_CSS     => q{text/css};
Readonly our $HTML_YES          => q{yes};

my $options;
my $h = HTML::Tiny->new( mode => qw{ html } );

# Current processing state
## no critic (Variables::ProhibitPackageVars)
our %local_focus_map;
our $local_filter;
our $local_region;
our $local_time_seconds;
our $local_time_slot;
our $local_webpage;
## use critic

# Color styles
Readonly our $RE_COLOR_STYLE =>
    qr{ \A (?: all: | print: | screen: )? [+] (?i:(?:panel_)?color) (?: = | \z ) }xms;

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

sub open_dump_file {
    my ( $def_name ) = @_;
    $def_name //= q{index};

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

sub dump_file_header {
    my ( $writer ) = @_;

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

sub dump_grid_panel {
    my ( $write, $panel_state, @rooms ) = @_;

    return unless defined $panel_state;

    my @classes;
    push @classes, join q{}, qw{ time-start- },
        $panel_state->get_start_seconds();
    push @classes, join q{}, qw{ time-sop- },
        $panel_state->get_start_seconds();

    return;

} ## end sub dump_grid_panel

sub dump_grid_make_groups {
    my ( $writer ) = @_;

    my @rooms = sort map { Data::Room->find_by_room_id( $_ ) }
        keys %local_focus_map;
    my $current = $local_time_slot->get_current();

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
            && $local_focus_map{ $last_room->get_room_id() }
            == $local_focus_map{ $room->get_room_id() } ) {
            push @room_queue, $room;
            next;
        } ## end if ( scalar @room_queue...)

        dump_grid_panel( $writer, $last_state, @room_queue )
            if @room_queue;

        @room_queue = ( $room );
        $last_room  = $room;
        $last_state = $state;
    } ## end foreach my $room ( @rooms )

    dump_grid_panel( $writer, $last_state, @room_queue )
        if @room_queue;

    return;
} ## end sub dump_grid_make_groups

sub dump_grid_time {
    my ( $writer, $same_day ) = @_;

    if ( $options->show_day_column() ) {
        $writer->add_h3(
            { out_class( qw{ time-slot } ) },
            $h->div(
                { out_class( qw{ time-slot-day } ) },
                datetime_to_text( $local_time_seconds, qw{ day } )
                )
                . $h->div(
                { out_class( qw{ time-slot-time } ) },
                datetime_to_text( $local_time_seconds, qw{ time } )
                )
        );
    } ## end if ( $options->show_day_column...)
    else {
        $writer->add_h3(
            { out_class( qw{ time-slot } ) },
            datetime_to_text(
                $local_time_seconds,
                $same_day ? qw{ time } : qw{ both }
            )
        );
    } ## end else [ if ( $options->show_day_column...)]

    dump_grid_make_groups( $writer );
    return;
} ## end sub dump_grid_time

sub dump_grid_timeslice {
    my @times = sort { $a <=> $b } $local_region->get_unsorted_times();
    return unless @times;
    my $is_one_day = same_day( $times[ 0 ], $times[ -1 ] );

    my @name = $local_filter->get_output_name_pieces();
    if ( !defined $local_filter->get_selected_region() ) {
        push @name, $local_region->get_region_name();
    }

    my $writer = $local_webpage->get_body();

    $writer->add_h2( join q{ }, @name, qw{ Schedule } );

    my $sch_class = canonical_class( join q{_}, qw{ schedule }, @name );
    $writer = $writer->nested_div( { out_class( $sch_class ) } );

    my $last_time;
    foreach my $time ( @times ) {
        local $local_time_seconds = $time;
        local $local_time_slot
            = $local_region->get_time_slot( $local_time_seconds );
        my $same_day
            = $is_one_day || same_day( $last_time, $local_time_seconds );
        dump_grid_time( $writer, $same_day );
        $last_time = $local_time_seconds;
    } ## end foreach my $time ( @times )

    return;
} ## end sub dump_grid_timeslice

sub dump_desc_timeslice {
    return;
}

sub dump_grid_regions {
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
            local $local_region = $region;
            local %local_focus_map
                = room_id_focus_map( $options, $local_filter, $local_region );

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
        local $local_region = $region;
        local %local_focus_map
            = room_id_focus_map( $options, $local_filter, $local_region );
        dump_desc_timeslice();
    } ## end foreach my $region ( @regions)

    return;
} ## end sub dump_grid_regions

sub dump_grid {
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

sub main {
    my ( @args ) = @_;

    $options = Options->options_from( @args );

    foreach my $style ( $options->get_styles() ) {
        next unless $style =~ $RE_COLOR_STYLE;
        my ( $unused, $color_set ) = split m{=}xms, $style, 2;
        $color_set //= $Data::PanelType::DEF_COLOR_SET;
        Table::PanelType::add_color_set( $color_set );
    } ## end foreach my $style ( $options...)

    read_spreadsheet_file( $options );

    populate_time_regions( $options );

    if ( $options->is_mode_kiosk() ) {
        dump_kiosk;
        return;
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
        local $local_filter = $filter;
        dump_grid;
    }

    return;
} ## end sub main

main( @ARGV );

POSIX::_exit( 0 );
1;

__END__
