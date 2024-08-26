## no critic(ProhibitExcessMainComplexity) FALSE POSITIVE
package Data::Room;

use v5.40.0;
use utf8;

use Feature::Compat::Class;
use feature      qw{ signatures };
use List::Util   qw{ any };
use Scalar::Util qw{ weaken };
use Readonly;

## no critic(RequireEndWithOne) FALSE POSITIVE
class Data::Room {

## no critic (TooMuchCode::ProhibitDuplicateLiteral)
    use overload
        q{<=>} => q{compare},
        q{cmp} => q{compare};
## use critic

## MARK: Constants

    Readonly our $SPLIT_PREFIX     => q{SPLIT};
    Readonly our $BREAK            => q{BREAK};
    Readonly our $HIDDEN_SORT_KEY  => 100;
    Readonly our $UNKNOWN_SORT_KEY => 999;

    Readonly my $ROOM_SHOWN_   => q{S};
    Readonly my $ROOM_HIDDEN_  => q{H};
    Readonly my $ROOM_UNKNOWN_ => undef;

## MARK: Private globals

    my $next_id_ = 0;    # Sequence number for instance
    my @uid_map_;        # Map sequence number to weak instance
    my @sort_key_used_;

## MARK: Fields

    field $id_ :reader(get_room_id) = $next_id_++;

    field $sort_key_
        :param(sort_key);

    field $short_name_
        :param(short_name)
        :reader(get_short_room_name);

    field $long_name_
        :param(long_name)
        :reader(get_long_room_name);

    field $hotel_
        :param(hotel_room)
        :reader(get_hotel_room);

    field $hide_room_override_ = $ROOM_UNKNOWN_;
    field $hide_room_computed_ = $ROOM_UNKNOWN_;

## MARK: Lifetime

    method init_ () {
        $uid_map_[ $id_ ] = $self;
        weaken $uid_map_[ $id_ ];

        my $key = $sort_key_;
        if ( defined $key && $key >= 0 && $key < $HIDDEN_SORT_KEY ) {
            ++$sort_key_used_[ $key ];
        }
        return;
    } ## end sub init_

    method DESTROY {
        if (   defined $sort_key_
            && $sort_key_ >= 0
            && $sort_key_ < $HIDDEN_SORT_KEY
            && $sort_key_used_[ $sort_key_ ] >= 0 ) {
            --$sort_key_used_[ $sort_key_ ];
        } ## end if ( defined $sort_key_...)
        $uid_map_[ $id_ ] = undef;
        return;
    } ## end sub DESTROY

## MARK: Methods

## no critic(RequireInterpolationOfMetachars) FALSE POSITIVE
    sub find_by_room_id ( $class, $uid ) {
        return unless $uid =~ m{ \A \d+ \z}xms;
        my $value = $uid_map_[ $uid ];
        return $value if defined $value;
        return;
    } ## end sub find_by_room_id

    method get_sort_key () {
        return $sort_key_ if defined $sort_key_ && $sort_key_ >= 0;

        if ( $self->get_is_split() || $self->get_room_is_break() ) {
            $sort_key_ = $HIDDEN_SORT_KEY;
            return $HIDDEN_SORT_KEY;
        }

        foreach my $try_key ( 0 .. $HIDDEN_SORT_KEY - 1 ) {
            next if $sort_key_used_[ $try_key ];
            $sort_key_ = $try_key;
            ++$sort_key_used_[ $try_key ];
            return $try_key;
        } ## end foreach my $try_key ( 0 .. ...)

        $sort_key_ = $HIDDEN_SORT_KEY - 1;
        ++$sort_key_used_[ $sort_key_ ];
        return $sort_key_;
    } ## end sub get_sort_key

    method name_matches ( @patterns ) {
        return 1 if any { $long_name_ =~ m{\Q$_\E}xmsi } @patterns;
        return;
    }

    method has_prefix ( $prefix ) {
        return unless defined $prefix;
        my $len = length $prefix;
        $prefix = uc $prefix;

        return 1
            if $prefix eq uc substr $short_name_ // q{}, 0, $len;
        return 1
            if $prefix eq uc substr $long_name_ // q{}, 0, $len;
        return;
    } ## end sub has_prefix

    method get_is_split () {
        return $self->has_prefix( $SPLIT_PREFIX );
    }

    method get_room_is_break () {
        return 1 if $BREAK eq uc( $short_name_ // q{} );
        return 1 if $BREAK eq uc( $long_name_  // q{} );
        return;
    }

    method override_room_as_hidden () {
        $hide_room_override_ = $ROOM_HIDDEN_;
        return $self;
    }

    method override_room_as_shown () {
        $hide_room_override_ = $ROOM_SHOWN_;
        return $self;
    }

    method clear_override_room_as_hidden () {
        $hide_room_override_ = $ROOM_UNKNOWN_;
        return $self;
    }

    method get_room_is_hidden() {
        my $hidden = $hide_room_override_ // $hide_room_computed_;

        return 1 if $hidden eq $ROOM_HIDDEN_;
        return   if $hidden eq $ROOM_SHOWN_;

        if (   !defined $sort_key_
            || $sort_key_ !~ m{ \A \d+ \z }xms
            || $sort_key_ >= $HIDDEN_SORT_KEY ) {
            $hide_room_computed_ = $ROOM_HIDDEN_;
            return 1;
        } ## end if ( !defined $sort_key_...)

        $hide_room_computed_ = $ROOM_SHOWN_;
        return;
    } ## end sub get_room_is_hidden

    method compare( $right_room, $swap //= 0 ) {
        if ( !defined $right_room ) {
            my $before = $swap ? 1 : -1;
            my $key    = $sort_key_ // 0;
            return $key <= $UNKNOWN_SORT_KEY ? $before : -$before;
        }

        die q{Compare Room with something else:}, ( ref $right_room ), qq{\n}
            unless ref $right_room && $right_room->isa( q{Data::Room} );

        my $left_room = $self;
        ( $left_room, $right_room ) = ( $right_room, $left_room ) if $swap;

        return $left_room->get_sort_key() <=> $right_room->get_sort_key()
            || $left_room->get_long_room_name()
            cmp $right_room->get_long_room_name()
            || $left_room->get_room_id() <=> $right_room->get_room_id();
    } ## end sub compare

## MARK: Adjustment

    # perl critic doesn't handle adjustments well
    # So disable for the adjustment and move the code where it can be checked

    ADJUST { $self->init_(); }
} ## end package Data::Room

1;
