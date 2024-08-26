package Data::RegionForTable;

use Object::InsideOut qw{TimeRange};

use v5.40.0;
use utf8;

use Carp qw{croak};

use Data::Room      qw{};
use Table::Room     qw{ :all };
use Table::FocusMap qw{};
use TimeSlot        qw{};

## no critic (ProhibitUnusedVariables)

my @region_name
    :Field
    :Type(scalar)
    :Arg(Name => q{name}, Mandatory => 1)
    :Get(Name => q{get_region_name});

my @active_room
    :Field
    :Default({}) Set(Name => q{set_active_rooms_}, Restricted => 1)
    :Get(Name => q{get_active_rooms_}, Restricted => 1);

my @presenters_at_time
    :Field
    :Default({}) Set(Name=> q{set_presenter_at_time_}, Restricted => 1)
    :Get(Name=> q{get_presenter_at_time_}, Restricted => 1);

my @time_slots
    :Field
    :Default({})
    :Get(Name => q{time_slots_}, Restricted => 1);

my @active_at_time
    :Field
    :Default({}) Set(Name => q{set_active_at_time_}, Restricted => 1)
    :Get(Name => q{get_active_at_time_}, Restricted => 1);

my @upcoming_at_time
    :Field
    :Default({}) Set(Name => q{set_upcoming_at_time_}, Restricted => 1)
    :Get(Name => q{get_upcoming_at_time_}, Restricted => 1);

my @day_being_output
    :Field
    :Default(q{})
    :Set(Name => q{set_day_being_output})
    :Get(Name => q{get_day_being_output});

my @time_last_output_time
    :Field
    :Set(Name => q{set_last_output_time})
    :Get(Name => q{get_last_output_time});

## use critic

sub add_active_room {
    my ( $self, $room ) = @_;
    return unless defined $room;
    croak q{add_active_room requires a Data::Room object}
        unless $room->isa( q{Data::Room} );
    my $map = $self->get_active_rooms_();
    $map->{ $room->get_room_id() } = $room;
    return;
} ## end sub add_active_room

sub is_room_active {
    my ( $self, $room ) = @_;
    return unless defined $room;
    croak q{is_room_active requires a Data::Room object}
        unless $room->isa( q{Data::Room} );
    my $map = $self->get_active_rooms_();
    return unless defined $map;
    return 1 if exists $map->{ $room->get_room_id() };
    return;
} ## end sub is_room_active

sub get_unsorted_times {
    my ( $self ) = @_;
    my $map = $self->time_slots_();
    return unless defined $map;
    return keys %{ $map };
} ## end sub get_unsorted_times

sub get_time_slot {
    my ( $self, $time ) = @_;
    return $self->time_slots_()->{ $time } //= TimeSlot->new(
        start_time => $time,
        end_time   => $time,
    );
} ## end sub get_time_slot

sub room_focus_map_by_id {
    my ( $self, %args ) = @_;
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
1;
