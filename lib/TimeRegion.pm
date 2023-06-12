package TimeRegion;

use Object::InsideOut qw{TimeRange};

use strict;
use warnings;
use common::sense;

use Carp qw{croak};
use Readonly;
use Table::Room;
use TimeSlot;
use utf8;

## no critic (ProhibitUnusedVariables)

my @region_name
    :Field
    :Type(scalar)
    :Arg(Name => q{name}, Mandatory => 1)
    :Get(get_region_name);

my @active_room
    :Field
    :Default({})
    :Std(Name => q{active_rooms_}, Restricted => 1 );

my @presenters_at_time
    :Field
    :Default({})
    :Std(Name=> q{presenter_at_time_}, Restricted => 1 );

my @time_slots
    :Field
    :Default({})
    :Get(Name => q{time_slots_}, Restricted => 1);

my @active_at_time
    :Field
    :Default({})
    :Std(Name => q{active_at_time_}, Restricted => 1 );

my @upcoming_at_time
    :Field
    :Default({})
    :Std(Name => q{upcoming_at_time_}, Restricted => 1 );

my @day_being_output
    :Field
    :Default(q{})
    :Std(day_being_output);

my @time_last_output_time
    :Field
    :Std(last_output_time);

## use critic

sub add_active_room {
    my ( $self, $room ) = @_;
    return              unless defined $room;
    croak q{Not a room} unless $room->isa( q{Table::Room} );
    my $map = $self->get_active_rooms_();
    $map->{ $room->get_room_id() } = $room;
    return;
} ## end sub add_active_room

sub is_room_active {
    my ( $self, $room ) = @_;
    return              unless defined $room;
    croak q{Not a room} unless $room->isa( q{Table::Room} );
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

1;
