package Data::Room;

use v5.38.0;
use utf8;

use Carp                   qw{ croak confess };
use Feature::Compat::Class qw{ :all };
use List::MoreUtils        qw{ any first_value };
use Readonly               qw{ Readonly };
use Scalar::Util           qw{ blessed };

class Data::Room;

## no critic (TooMuchCode::ProhibitDuplicateLiteral)
use overload
    q{<=>} => q{compare},
    q{cmp} => q{compare};
## use critic

# MARK: name fields

field $short_name :param(short_name) :reader(get_short_room_name) //= undef;
field $long_name :param(long_name) :reader(get_long_room_name)    //= undef;
field $hotel_room :param(hotel_room) :reader(get_hotel_room)      //= undef;

method has_prefix ( $prefix ) {
    return unless defined $prefix;
    my $len = length $prefix;
    $prefix = uc $prefix;

    foreach my $try_name ( $short_name, $long_name ) {
        next unless defined $try_name;
        next     if $try_name eq q{};
        next     if $len > length $try_name;
        return 1 if $prefix eq uc substr $try_name, 0, $len;
    } ## end foreach my $try_name ( $short_name...)
    return;
} ## end sub has_prefix

method name_is_exact ( $name ) {
    $name //= q{};
    $name = uc $name;

    return 1 if any { $name eq uc( $_ // q{} ) } $short_name, $long_name;
    return;
} ## end sub name_is_exact

method name_matches ( @patterns ) {
    my $name = $long_name // q{};
    return 1 if any { $name =~ m{\Q$_\E}xmsi } @patterns;
    return;
}

# MARK: is_split field

field $is_split :param(is_split) :reader(get_is_split) //= undef;
Readonly our $SPLIT_PREFIX => q{SPLIT};
ADJUST {
    $is_split //= $self->has_prefix( $SPLIT_PREFIX ) ? 1 : 0;
}

# MARK: is_break field

field $is_break :param(is_break) :reader(get_room_is_break) //= undef;
Readonly our $BREAK => q{BREAK};
ADJUST {
    $is_break //= $self->name_is_exact( $BREAK );
}

# MARK: sort_key field

Readonly our $HIDDEN_SORT_KEY  => 100;
Readonly our $UNKNOWN_SORT_KEY => 999;

field $sort_key :param(sort_key) //= undef;
my @sort_key_used;

ADJUST {
    !defined $sort_key
        or $sort_key =~ m{ \A (?: 0 | [1-9] \d* ) \z }xms
        or croak q{Invalid room sort key};

    ++$sort_key_used[ $sort_key ]
        if defined $sort_key
        && $sort_key >= 0
        && $sort_key <= $HIDDEN_SORT_KEY;
} ## end ADJUST

method get_sort_key ( ) {
    return $sort_key if defined $sort_key;

    return $sort_key = $HIDDEN_SORT_KEY if $is_split || $is_break;

    $sort_key = first_value { 0 == ( $sort_key_used[ $_ ] // 0 ) }
    ( 0 .. $HIDDEN_SORT_KEY - 1 );

    $sort_key //= $HIDDEN_SORT_KEY - 1;

    ++$sort_key_used[ $sort_key ];

    return $sort_key;
} ## end sub get_sort_key ( )

# MARK: is_hidden field

field $is_hidden_room :param(is_hidden_room) //= undef;
field $override_is_hidden_room;
ADJUST {
    $is_hidden_room //=
        (      defined $sort_key
            && $sort_key =~ m{ \A \d+ \z }xms
            && $sort_key < $HIDDEN_SORT_KEY ) ? 0 : 1;
} ## end ADJUST

method override_room_as_shown ( ) {
    $override_is_hidden_room = 0;
    return $self;
}

method override_room_as_hidden ( ) {
    $override_is_hidden_room = 1;
    return $self;
}

method clear_override_room_as_hidden ( ) {
    $override_is_hidden_room = undef;
    return $self;
}

method get_room_is_hidden () {
    return 1 if $override_is_hidden_room // $is_hidden_room;
    return;
}

# MARK: uid field

my @uid_map;
field $uid :reader(get_room_id);
ADJUST {
    $uid = -1 + push @uid_map, $self;
}

sub find_by_room_id ( $class, $uid ) {
    return unless defined $uid;
    return if $uid < 0;
    my $value = $uid_map[ $uid ];
    return $value if defined $value;
    return;
} ## end sub find_by_room_id

# MARK: compare

method compare ( $other, $swap //= undef ) {
    if ( !defined $other ) {
        my $before = $swap ? 1 : -1;
        return $self <= $UNKNOWN_SORT_KEY ? $before : -$before;
    }

    blessed $other && $other->isa( __PACKAGE__ )
        or croak q{Compare Room with something else }, ( ref $other );

    my $left  = $swap ? $other : $self;
    my $right = $swap ? $self  : $other;

    return
           $left->get_sort_key() <=> $right->get_sort_key()
        || $left->get_long_room_name() cmp $right->get_long_room_name()
        || $left->get_room_id() <=> $right->get_room_id();
} ## end sub compare

1;
