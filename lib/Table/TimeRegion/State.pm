use v5.38.0;    ## no critic (Modules::ProhibitExcessMainComplexity)
use utf8;
use Feature::Compat::Class;

class Table::TimeRegion::State {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage)

    package Table::TimeRegion::State;

    use Carp            qw{ croak };
    use List::MoreUtils qw{ uniq };

    use Data::RoomId qw{ to_room_id };

    # MARK: active region field

    field $active_region //= undef;

    method get_active_region () {
        return $active_region if defined $active_region;
        return;
    }

    method set_active_region ( $new_region ) {
        $new_region isa Data::RegionForTable
            or croak q{set_active_region requires Data::RegionForTable};

        $active_region = $new_region;
        return $self;
    } ## end sub set_active_region

    # MARK: last_time field

    field $last_time_used;

    method has_last_time () {
        return 1 if defined $last_time_used;
        return;
    }

    method get_last_time () {
        return $last_time_used if defined $last_time_used;
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
        defined $panel
            or return $self;

        $panel isa TimeRange
            or croak q{add_break needs a time range};

        return $self
            if defined $active_break
            && $active_break->get_end_seconds() >= $panel->get_end_seconds();

        $active_break = $panel;
        return $self;
    } ## end sub add_break

    method get_active_break_clear_if_expired( $time //= undef ) {
        defined $active_break
            or return;

        ( defined $time && $time >= $active_break->get_end_seconds() )
            or return $active_break;

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
        defined $room
            or return;
        my $id = to_room_id( $room );
        defined $id
            or croak q{is_room_active_clear_if_expired requires a room};

        my $active = $active_by_room{ $id };
        defined $active
            or return;

        ( defined $time && $time >= $active->get_end_seconds() )
            or return $active;

        delete $active_by_room{ $id };
        return;
    } ## end sub is_room_active_clear_if_expired

    method add_active_panel ( $new_active //= undef ) {
        defined $new_active
            or return;
        $new_active isa ActivePanel
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
            next if $split_time >= $active->get_end_seconds();
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
} ## end package Table::TimeRegion::State

1;
