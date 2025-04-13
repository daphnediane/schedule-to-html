package Table::TimeRegion::State;

use v5.38.0;
use utf8;

use Carp                   qw{ croak };
use Feature::Compat::Class qw{ :all };
use Scalar::Util           qw{ blessed };
use List::MoreUtils        qw{ uniq };

class Table::TimeRegion::State;

use Data::RoomId qw{ to_room_id };

# MARK: active region field

field $active_region :reader(get_active_region) //= undef;

method set_active_region ( $new_region ) {
    blessed $new_region && $new_region->isa( q{Data::RegionForTable} )
        or croak q{set_active_region requires Data::RegionForTable};

    $active_region = $new_region;
    return $self;
} ## end sub set_active_region

# MARK: last_time field

field $last_time_used :reader(get_last_time);

method has_last_time () {
    return 1 if defined $last_time_used;
    return;
}

method set_last_time ( $new_last ) {
    $last_time_used = $new_last;
    return $self;
}

method clear_last_time () {
    $last_time_used = undef;
    return $self;
}

# MARK: active_break field

field $active_break;

method add_break ( $panel ) {
    return $self unless defined $panel;
    blessed $panel && $panel->isa( q{TimeRange} )
        or die q{add_break needs a time range};

    return $self
        if defined $active_break
        && $active_break->get_end_seconds() >= $panel->get_end_seconds();

    $active_break = $panel;
    return $self;
} ## end sub add_break

method get_active_break_clear_if_expired( $time //= undef ) {
    return unless defined $active_break;

    return $active_break unless defined $time;
    return $active_break if $time < $active_break->get_end_seconds();

    $active_break = undef;
    return;
} ## end sub get_active_break_clear_if_expired

# MARK: active by room field

field %active_by_room;

method has_any_active () {
    return 1 if %active_by_room;
    return;
}

method get_all_active () {
    return values %active_by_room;
}

method is_room_active_clear_if_expired( $room, $time //= undef ) {
    return unless defined $room;
    my $id = to_room_id( $room );
    defined $id
        or croak q{is_room_active_clear_if_expired requires a room};

    my $active = $active_by_room{ $id };
    return         unless defined $active;
    return $active unless defined $time;
    return $active if $time < $active->get_end_seconds();

    delete $active_by_room{ $id };
    return;
} ## end sub is_room_active_clear_if_expired

method add_active_panel ( $new_active //= undef ) {
    return unless defined $new_active;
    blessed $new_active && $new_active->isa( qw{ActivePanel } )
        or croak q{add_active_panel requires ActivePanel};

    my $id    = $new_active->get_room_id();
    my $prior = $active_by_room{ $id };
    $prior->truncate_end_seconds( $new_active->get_start_seconds() )
        if defined $prior;
    $active_by_room{ $id } = $new_active;
    return $self;
} ## end sub add_active_panel

method split_active_panels ( $split_time ) {
    my @prior = values %active_by_room;
    %active_by_room = ();

    foreach my $active ( @prior ) {
        next unless defined $active;
        next unless $split_time <= $active->get_end_seconds();
        my $new_state = $active->clone();
        $new_state->set_rows( 0 );
        $new_state->set_start_time( $split_time );
        $active->truncate_end_seconds( $split_time );
        $active_by_room{ $active->get_room_id() } = $new_state;
    } ## end foreach my $active ( @prior)

    return $self;
} ## end sub split_active_panels

# MARK: empty_times

field @empty_times;

method clear_empty_times () {
    @empty_times = ();
    return $self;
}

method add_empty_times( @add_times ) {
    push @empty_times, @add_times;
    return $self;
}

method get_and_clear_empty_times () {
    my @times = uniq @empty_times;
    @empty_times = ();
    return @times;
}

1;
