package Table::TimeRegion;

use base qw{Exporter};

use v5.36.0;
use utf8;

use Readonly;

use ActivePanel              qw{};
use Options                  qw{};
use Table::Panel             qw{ :all };
use Table::TimeRegion::State qw{};
use TimeDecoder              qw{ :to_text :timepoints };
use TimeRegion               qw{ };

our @EXPORT_OK = qw {
    get_time_regions
    populate_time_regions
};

our %EXPORT_TAGS = (
    all => [ @EXPORT_OK ],
);

# Global variables
Readonly our $HALF_HOUR_IN_SEC => 30 * 60;

my %split_points_;
my %regions_;
my @sort_regions_;

# Private

sub add_starting_panels_ {
    my ( $state, $time, $panel ) = @_;

    return unless defined $panel;
    my $panel_type = $panel->get_panel_type();
    return unless defined $panel_type;
    return if $panel_type->get_is_hidden();

    if ( $panel_type->is_break() ) {
        $state->add_break( $panel );
    }

    foreach my $room ( $panel->get_rooms() ) {
        next unless defined $room;

        if ( $room->get_room_is_hidden() ) {
            if ( $room->get_room_is_break() || $panel_type->is_break() ) {
                $state->add_break( $panel );
            }
            next;
        } ## end if ( $room->get_room_is_hidden...)

        $state->add_active_panel( ActivePanel->new(
            active_panel => $panel,
            rows         => 0,
            start_time   => $time,
            end_time     => $panel->get_end_seconds(),
            room         => $room,
        ) );
    } ## end foreach my $room ( $panel->...)

    return;
} ## end sub add_starting_panels_

sub update_ongoig_panels_ {
    my ( $state, $time ) = @_;

    my $active_break = $state->get_active_break_clear_if_expired( $time );

    foreach my $room ( Table::Room::all_rooms() ) {
        next if $room->get_room_is_hidden();
        my $room_id = $room->get_room_id();

        next
            if defined $state->is_room_active_clear_if_expired(
            $room_id,
            $time
            );

        next unless defined $active_break;

        my $panel_state = ActivePanel->new(
            active_panel => $active_break,
            rows         => 0,
            start_time   => $time,
            end_time     => $active_break->get_end_seconds(),
            room         => $room,
            is_break     => 1,
        );
        $state->add_active_panel( $panel_state );
    } ## end foreach my $room ( Table::Room::all_rooms...)

    return;
} ## end sub update_ongoig_panels_

sub process_time_slot_ {
    my ( $state, $time ) = @_;

    # Add new panels
    foreach my $panel ( get_panels_by_start( $time ) ) {
        add_starting_panels_( $state, $time, $panel );
    }

    update_ongoig_panels_( $state, $time );

    my %timeslot_info;
    foreach my $panel_state ( $state->get_all_active() ) {
        my $panel   = $panel_state->get_active_panel();
        my $room_id = $panel_state->get_room()->get_room_id();
        $timeslot_info{ $room_id } = $panel_state;

        $panel_state->increment_rows();

        $state->get_active_region()
            ->add_active_room( $panel_state->get_room() )
            unless $panel_state->get_is_break();
    } ## end foreach my $panel_state ( $state...)

    if ( %timeslot_info ) {
        foreach my $empty ( $state->get_and_clear_empty_times() ) {
            $state->get_active_region()->get_time_slot( $empty )
                ->init_current( {} );
        }

        $state->get_active_region()->get_time_slot( $time )
            ->init_current( \%timeslot_info );

        $state->set_last_time( $time );
    } ## end if ( %timeslot_info )
    elsif ( $state->has_last_time() ) {
        $state->add_empty_times( $time );
    }
    return;
} ## end sub process_time_slot_

sub process_half_hours_upto_ {
    my ( $state, $split_time ) = @_;
    return unless $state->has_last_time();

    my $time = $state->get_last_time() + $HALF_HOUR_IN_SEC;
    while ( $time < $split_time ) {
        process_time_slot_( $state, $time );
        $time += $HALF_HOUR_IN_SEC;
    }

    return;
} ## end sub process_half_hours_upto_

sub check_if_new_region_ {
    my ( $options, $time, $prev_region ) = @_;
    if ( defined $prev_region ) {
        return if $options->is_split_none();
        return unless exists $split_points_{ $time };
        if ( $options->is_split_day() ) {
            my $prev_time = $prev_region->get_start_seconds();
            my $prev_day  = datetime_to_text( $prev_time, qw{ day } );
            my $new_day   = datetime_to_text( $time,      qw{ day } );
            return if $prev_day eq $new_day;
            $split_points_{ $time } = $new_day;
        } ## end if ( $options->is_split_day...)
    } ## end if ( defined $prev_region)
    elsif ( $options->is_split_none() ) {
        $split_points_{ $time } //= q{Schedule};
    }
    elsif ( $options->is_split_day() ) {
        $split_points_{ $time } = datetime_to_text( $time, qw{ day } );
    }
    else {
        $split_points_{ $time } //= q{Before Convention};
    }

    # Remove sort
    @sort_regions_ = ();

    my $region = $regions_{ $time } //= TimeRegion->new(
        name => $split_points_{ $time }
            // q{From } . datetime_to_text( $time, qw{ both } ),
        start_time => $time,
    );
    return $region;
} ## end sub check_if_new_region_

sub finalize_region_ {
    my ( $options, $state ) = @_;

    return unless defined $state->get_active_region();
    return unless $options->is_mode_kiosk();
    my @times
        = reverse sort { $a <=> $b }
        $state->get_active_region()->get_unsorted_times();
    my %next_panels = ();

    foreach my $time ( @times ) {
        my $time_slot = $state->get_active_region()->get_time_slot( $time );

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
} ## end sub finalize_region_

sub handle_region_changes_ {
    my ( $options, $state, $split_time ) = @_;

    my $region = check_if_new_region_(
        $options,
        $split_time,
        $state->get_active_region()
    );
    return unless defined $region;

    finalize_region_( $options, $state );
    $state->set_active_region( $region );
    $state->clear_empty_times();
    $state->clear_last_time();
    $state->split_active_panels( $split_time );

    return;
} ## end sub handle_region_changes_

# Public
sub get_time_regions {
    return @sort_regions_ if @sort_regions_;
    @sort_regions_
        = sort { $a->get_start_seconds() <=> $b->get_start_seconds() }
        values %regions_;
    return @sort_regions_;
} ## end sub get_time_regions

sub populate_time_regions {
    my ( $options ) = @_;

    foreach my $split ( get_split_panels() ) {
        $split_points_{ $split->get_start_seconds() }
            = $split->get_name();
    }

    my %time_points
        = map { $_ => 1 } ( keys %split_points_, get_timepoints() );
    my $state = Table::TimeRegion::State->new();

    my @time_points = keys %time_points;
    my $first_time  = $options->get_time_start();
    @time_points = grep { $first_time <= $_ } @time_points
        if defined $first_time;
    my $final_time = $options->get_time_end();
    @time_points = grep { $final_time >= $_ } @time_points
        if defined $final_time;
    @time_points = sort { $a <=> $b } @time_points;

    foreach my $split_time ( @time_points ) {

        # This handles half hours between last
        process_half_hours_upto_( $state, $split_time )
            if $state->has_any_active();

        handle_region_changes_( $options, $state, $split_time );
        process_time_slot_( $state, $split_time );
    } ## end foreach my $split_time ( @time_points)
    finalize_region_( $options, $state );

    return;
} ## end sub populate_time_regions

1;
