package TimeRegion;

use Object::InsideOut qw{TimeRange};

use strict;
use warnings;
use common::sense;

use Carp qw{croak};
use Readonly;
use utf8;
use RoomInfo;

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
    return unless defined $room;
    croak q{Not a room} unless $room->isa( q{RoomInfo} );
    my $map = $self->get_active_rooms_();
    $map->{ ${ $room } } = $room;
    return;
} ## end sub add_active_room

sub is_room_active {
    my ( $self, $room ) = @_;
    return unless defined $room;
    croak q{Not a room} unless $room->isa( q{RoomInfo} );
    my $map = $self->get_active_rooms_();
    return unless defined $map;
    return 1 if exists $map->{ ${ $room } };
    return;
} ## end sub is_room_active

sub get_unsorted_times {
    my ( $self ) = @_;
    my $map = $self->get_active_at_time_();
    return unless defined $map;
    return keys %{ $map };
} ## end sub get_unsorted_times

sub get_active_at_time {
    my ( $self, $time ) = @_;
    return $self->get_active_at_time_()->{ $time } //= {};
}

sub set_active_at_time {
    my ( $self, $time, $active_map ) = @_;
    my $map = $self->get_active_at_time_();
    croak q{Dup time} if exists $map->{ $time };
    $map->{ $time } = $active_map;
    return;
} ## end sub set_active_at_time

sub get_upcoming_at_time {
    my ( $self, $time ) = @_;
    return $self->get_upcoming_at_time_()->{ $time } //= {};
}

sub set_upcoming_at_time {
    my ( $self, $time, $upcoming_map ) = @_;
    my $map = $self->get_upcoming_at_time_();
    croak q{Dup time} if exists $map->{ $time };
    $map->{ $time } = $upcoming_map;
    return;
} ## end sub set_upcoming_at_time

1;
