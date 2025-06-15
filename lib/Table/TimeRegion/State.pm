use v5.38.0;    ## no critic (Modules::ProhibitExcessMainComplexity)
use utf8;
use Feature::Compat::Class;

class Table::TimeRegion::State {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage)

    package Table::TimeRegion::State;

    use Carp            qw{ croak };
    use List::MoreUtils qw{ any uniq };

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

    # MARK: current_break field

    field $current_break;

    method add_break ( $panel ) {
        defined $panel
            or return $self;

        $panel isa TimeRange
            or croak q{add_break needs a time range};

        return $self
            if defined $current_break
            && $current_break->get_end_seconds() >= $panel->get_end_seconds();

        $current_break = $panel;
        return $self;
    } ## end sub add_break

    method get_active_break_clear_if_expired( $time //= undef ) {
        defined $current_break
            or return;

        ( defined $time && $time >= $current_break->get_end_seconds() )
            or return $current_break;

        $current_break = undef;
        return;
    } ## end sub get_active_break_clear_if_expired

    # MARK: active by room field

    field @active_panels;

    method has_any_active () {
        return 1 if @active_panels;
        return;
    }

    method get_all_active () {
        return @active_panels;
    }

    method clear_expired_panels( $time ) {
        return unless defined $time;

        $current_break = undef
            if defined $current_break
            && $time >= $current_break->get_end_seconds();

        @active_panels
            = grep { $time < $_->get_end_seconds() } @active_panels;
        return $self;
    } ## end sub clear_expired_panels

    method get_inactive_rooms_among ( @rooms ) {
        my @res;
        foreach my $room ( @rooms ) {
            my $id = to_room_id( $room );
            next if any { $_->get_room_id() == $id } @active_panels;
            push @res, $room;
        }
        return @res;
    } ## end sub get_inactive_rooms_among

    method get_inactive_rooms () {
        require Table::Room;
        return get_inactive_rooms_among( Table::Room::all_rooms() );
    }

    method add_active_panel ( $new_active //= undef ) {
        defined $new_active
            or return;
        $new_active isa ActivePanel
            or croak q{add_active_panel requires ActivePanel};

        my $id   = $new_active->get_room_id();
        my $time = $new_active->get_start_seconds();

        $_->truncate_end_seconds( $time )
            for grep { $_->get_room_id() == $id && $_->get_is_break() }
            @active_panels;

        @active_panels = grep {
                   $_->get_room_id() != $id
                || $_->get_end_seconds()
                <= $time
        } @active_panels;
        push @active_panels, $new_active;
        return $self;
    } ## end sub add_active_panel

    method split_active_panels ( $split_time ) {
        my @prior = @active_panels;
        @active_panels = ();

        foreach my $active ( @prior ) {
            next unless defined $active;
            next if $split_time >= $active->get_end_seconds();
            my $new_state = $active->clone();
            $new_state->set_start_time( $split_time );
            $active->truncate_end_seconds( $split_time );
            push @active_panels, $new_state;
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
