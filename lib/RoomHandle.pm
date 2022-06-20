package RoomHandle;

use Object::InsideOut;

use strict;
use warnings;
use common::sense;

use Readonly;
use utf8;

use RoomInfo;

Readonly our $UNKNOWN_INDEX => 999;

## no critic (ProhibitUnusedVariables)

my @room
    :Field
    :Type(RoomInfo)
    :Std_All(room);

## use critic

sub get_short_room_name {
    my ( $self ) = @_;
    my $room = $self->get_room();
    return unless defined $room;
    return $room->get_short_room_name();
} ## end sub get_short_room_name

sub get_long_room_name {
    my ( $self ) = @_;
    my $room = $self->get_room();
    return unless defined $room;
    return $room->get_long_room_name();
} ## end sub get_long_room_name

sub get_hotel_room {
    my ( $self ) = @_;
    my $room = $self->get_room();
    return unless defined $room;
    return $room->get_hotel_room();
} ## end sub get_hotel_room

sub get_room_index {
    my ( $self ) = @_;
    my $room = $self->get_room();
    return unless defined $room;
    return $room->get_room_index();
} ## end sub get_room_index

sub get_num_room_index {
    my ( $self ) = @_;
    my $room = $self->get_room();
    return unless defined $room;
    return $room->get_num_room_index();
} ## end sub get_num_room_index

sub get_room_is_hidden {
    my ( $self ) = @_;
    my $room = $self->get_room();
    return 1 unless defined $room;
    return $room->get_room_is_hidden();
} ## end sub get_room_is_hidden

sub get_room_is_break {
    my ( $self ) = @_;
    my $room = $self->get_room();
    return unless defined $room;
    return $room->get_room_is_break();
} ## end sub get_room_is_break

sub compare_room_index {
    my ( $self, $other ) = @_;
    return ( $self->get_num_room_index() // $UNKNOWN_INDEX )
        <=> ( $other->get_num_room_index() // $UNKNOWN_INDEX )
        || $self->get_long_room_name() cmp $other->get_long_room_name();
} ## end sub compare_room_index

1;
