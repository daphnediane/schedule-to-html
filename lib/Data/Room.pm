package Data::Room;

use Object::InsideOut;

use strict;
use warnings;
use common::sense;

use Carp qw{ confess };
use Readonly;

## no critic (TooMuchCode::ProhibitDuplicateLiteral)
use overload
    q{<=>} => q{compare},
    q{cmp} => q{compare};
## use critic

Readonly our $SPLIT_PREFIX     => q{SPLIT};
Readonly our $BREAK            => q{BREAK};
Readonly our $HIDDEN_SORT_KEY  => 100;
Readonly our $UNKNOWN_SORT_KEY => 999;

## no critic (ProhibitUnusedVariables)

my @sort_key
    :Field
    :Type(scalar)
    :Arg(Name => q{sort_key})
    :Set(Name => q{set_sort_key_}, Restricted => 1)
    :Get(Name => q{get_sort_key_}, Restricted => 1);

my @short_name
    :Field
    :Type(scalar)
    :Arg(Name => q{short_name})
    :Get(Name => q{get_short_room_name});

my @long_name
    :Field
    :Type(scalar)
    :Arg(Name => q{long_name})
    :Get(Name => q{get_long_room_name});

my @hotel
    :Field
    :Type(scalar)
    :Arg(Name => q{hotel_room})
    :Get(Name => q{get_hotel_room});

my @hide_room
    :Field
    :Type(scalar)
    :Set(Name => q{set_room_is_hidden_}, Restricted => 1, Ret => q{New})
    :Get(Name => q{get_room_is_hidden_}, Restricted => 1);

## use critic

my @uid_map_;
my @sort_key_used_;

sub get_room_id {
    my ( $self ) = @_;
    return ${ $self };
}

sub find_by_room_id {
    my ( $class, $uid ) = @_;

    my $value = $uid_map_[ $uid ];
    return $value if defined $value;
    return;
} ## end sub find_by_room_id

sub init_ :Init {
    my ( $self, $args ) = @_;
    my $uid = $self->get_room_id();
    $uid_map_[ $uid ] = $self;
    my $key = $self->get_sort_key_();
    if ( defined $key && $key >= 0 && $key < $HIDDEN_SORT_KEY ) {
        ++$sort_key_used_[ $key ];
    }
    return;
} ## end sub init_

sub destroy_ :Destroy {
    my ( $self ) = @_;
    my $uid = $self->get_room_id();
    $uid_map_[ $uid ] = undef;
    my $key = $self->get_sort_key_();
    if (   defined $key
        && $key >= 0
        && $key < $HIDDEN_SORT_KEY
        && $sort_key_used_[ $key ] >= 0 ) {
        --$sort_key_used_[ $key ];
    } ## end if ( defined $key && $key...)
    return;
} ## end sub destroy_

sub has_prefix {
    my ( $self, $prefix ) = @_;
    return unless defined $prefix;
    my $len = length $prefix;
    $prefix = uc $prefix;

    return 1 if $prefix eq uc substr $self->get_short_room_name(), 0, $len;
    return 1 if $prefix eq uc substr $self->get_long_room_name(),  0, $len;
    return;
} ## end sub has_prefix

sub get_sort_key {
    my ( $self ) = @_;
    my $key = $self->get_sort_key_();
    return $key if defined $key && $key >= 0;

    if ( $self->get_is_split() || $self->get_is_break() ) {
        $key = $HIDDEN_SORT_KEY;
        $self->set_sort_key_( $key );
        return $key;
    }

    foreach my $try_key ( 0 .. $HIDDEN_SORT_KEY - 1 ) {
        my $value = $sort_key_used_[ $try_key ] //= 0;
        if ( $value == 0 ) {
            $self->set_sort_key_( $try_key );
            ++$sort_key_used_[ $try_key ];
            return $try_key;
        }
    } ## end foreach my $try_key ( 0 .. ...)

    $key = $HIDDEN_SORT_KEY - 1;
    $self->set_sort_key_( $key );
    ++$sort_key_used_[ $key ];
    return $key;
} ## end sub get_sort_key

sub get_is_split {
    my ( $self ) = @_;
    return $self->has_prefix( $SPLIT_PREFIX );
}

sub set_room_is_hidden {
    my ( $self ) = @_;
    my $hidden = $self->get_room_is_hidden_();
    return                           if $hidden;
    confess q{Room is already shown} if defined $hidden;
    $self->set_room_is_hidden_( 1 );
    return;
} ## end sub set_room_is_hidden

sub set_room_is_shown {
    my ( $self ) = @_;
    my $hidden = $self->get_room_is_hidden_();
    if ( defined $hidden ) {
        return unless $hidden;
        confess q{Room is already hidden};
    }
    $self->set_room_is_hidden_( 0 );
    return;
} ## end sub set_room_is_shown

sub get_room_is_hidden {
    my ( $self ) = @_;
    my $hidden = $self->get_room_is_hidden_();
    return 1 if $hidden;
    return   if defined $hidden;

    my $sort_key = $self->get_sort_key();
    return $self->set_room_is_hidden_( 1 ) unless defined $sort_key;
    return $self->set_room_is_hidden_( 1 )
        unless $sort_key =~ m{ \A \d+ \z }xms;
    return $self->set_room_is_hidden_( 1 ) if $sort_key >= $HIDDEN_SORT_KEY;
    $self->set_room_is_hidden_( 0 );
    return;
} ## end sub get_room_is_hidden

sub get_room_is_break {
    my ( $self ) = @_;
    return 1 if $BREAK eq uc $self->get_short_room_name();
    return 1 if $BREAK eq uc $self->get_long_room_name();
    return;
} ## end sub get_room_is_break

sub compare {
    my ( $self, $other, $swap ) = @_;
    if ( !defined $other ) {
        my $before = $swap ? 1 : -1;
        return $self <= $UNKNOWN_SORT_KEY ? $before : -$before;
    }

    die q{Compare Room with something else:}, ( ref $other ), qq{\n}
        unless ref $other && $other->isa( q{Data::Room} );

    ( $self, $other ) = ( $other, $self ) if $swap;

    return
           $self->get_sort_key() <=> $other->get_sort_key()
        || $self->get_long_room_name() cmp $other->get_long_room_name()
        || $self->get_room_id() <=> $other->get_room_id();
} ## end sub compare
1;
