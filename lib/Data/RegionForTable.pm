use v5.38.0;
use utf8;
use Feature::Compat::Class;

class Data::RegionForTable :isa(TimeRange) {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage,CodeLayout::ProhibitParensWithBuiltins)

    package Data::RegionForTable;

    use Carp qw{ croak };

    use Data::RoomId    qw{ to_room_id };
    use Table::FocusMap qw{ };
    use TimeSlot        qw{ };

    # MARK: name field

    field $region_name :param(name);

    method get_region_name () {
        return $region_name;
    }

    # MARK: active_rooms

    field %active_rooms;

    method add_active_room ( $room ) {
        defined $room
            or return $self;

        my $id = to_room_id( $room );
        defined $id
            or croak q{add_active_room requires a Data::Room object};
        $active_rooms{ $id } = $room;

        return $self;
    } ## end sub add_active_room

    method is_room_active ( $room ) {
        defined $room
            or return;

        my $id = to_room_id( $room );
        defined $id
            or croak q{is_room_active requires a Data::Room object};
        return 1 if exists $active_rooms{ $id };

        return;
    } ## end sub is_room_active

    # MARK: time_slots

    field %time_slots;

    method get_unsorted_times () {
        return keys %time_slots;
    }

    method get_time_slot ( $time ) {
        return $time_slots{ $time } //= TimeSlot->new(
            start_time => $time,
            end_time   => $time,
        );
    } ## end sub get_time_slot

    # MARK: day_being_output field

    field $day_being_output = q{};

    method get_day_being_output () {
        return $day_being_output;
    }

    method set_day_being_output ( $new_day //= q{} ) {
        $day_being_output = $new_day;
        return $self;
    }

    # MARK: last_output_time field

    field $last_output_time;

    method get_last_output_time () {
        return $last_output_time;
    }

    method set_last_output_time ( $new_time = undef ) {
        $last_output_time = $new_time;
    }

    # @TODO: Why is this a method of RegionForTable?

    method room_focus_map_by_id ( %args ) {
        my $select_room = delete $args{ select_room };
        my $focus_rooms = delete $args{ focus_rooms };
        croak q{Unsupported arguments: }, keys %args if %args;

        my @focus_rooms;
        @focus_rooms = @{ $focus_rooms } if defined $focus_rooms;

        my $focus_map = Table::FocusMap->new();

        if ( defined $select_room ) {
            $focus_map->set_focused( $select_room );
            return $focus_map;
        }

        if ( @focus_rooms ) {
            $focus_map->set_focused( grep { $_->name_matches( @focus_rooms ) }
                    visible_rooms() );
            return $focus_map;
        }

        return $focus_map;
    } ## end sub room_focus_map_by_id

    method clone_args() {
        croak q{Can not clone};
    }
} ## end package Data::RegionForTable

1;
