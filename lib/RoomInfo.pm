package RoomInfo;

use Object::InsideOut;

use strict;
use warnings;
use common::sense;

use Readonly;
use utf8;

Readonly our $SPLIT_PREFIX => q{SPLIT};
Readonly our $BREAK        => q{BREAK};
Readonly our $HIDE_IDX     => 100;

## no critic (ProhibitUnusedVariables)

my @index
    :Field
    :Type(scalar)
    :Std_All(room_index);

my @short_name
    :Field
    :Type(scalar)
    :Arg(short_name)
    :Std(short_room_name);

my @long_name
    :Field
    :Type(scalar)
    :Arg(long_name)
    :Std(long_room_name);

my @hotel
    :Field
    :Type(scalar)
    :Std_All(hotel_room);

## use critic

sub has_prefix {
    my ( $self, $prefix ) = @_;
    return unless defined $prefix;
    my $len = length $prefix;
    $prefix = uc $prefix;

    return 1 if $prefix eq uc substr $self->get_short_room_name(), 0, $len;
    return 1 if $prefix eq uc substr $self->get_long_room_name(),  0, $len;
    return;
} ## end sub has_prefix

sub get_is_split {
    my ( $self ) = @_;
    return $self->has_prefix( $SPLIT_PREFIX );
}

sub get_num_room_index {
    my ( $self ) = @_;
    my $idx = $self->get_room_index();
    return unless defined $idx;
    return $idx if $idx =~ m{ \A \d+ \z }xms;
    return;
} ## end sub get_num_room_index

sub get_room_is_hidden {
    my ( $self ) = @_;
    my $idx = $self->get_room_index();
    return 1 unless defined $idx;
    return 1 unless $idx =~ m{ \A \d+ \z }xms;
    return 1 if $idx >= $HIDE_IDX;
    return;
} ## end sub get_room_is_hidden

sub get_room_is_break {
    my ( $self ) = @_;
    return 1 if $BREAK eq uc $self->get_short_room_name();
    return 1 if $BREAK eq uc $self->get_long_room_name();
    return;
} ## end sub get_room_is_break

1;
