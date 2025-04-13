use v5.38.0;    ## no critic (Modules::ProhibitExcessMainComplexity)
use utf8;
use Feature::Compat::Class;

class Data::Room {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage)

    package Data::Room;

    use Carp            qw{ croak };
    use List::MoreUtils qw{ any first_value };
    use Readonly        qw{ Readonly };

## no critic (TooMuchCode::ProhibitDuplicateLiteral)
    use overload
        q{<=>} => q{compare},
        q{cmp} => q{compare};
## use critic

    # MARK: name fields

    field $short_name :param(short_name) //= undef;
    field $long_name :param(long_name)   //= undef;
    field $hotel_room :param(hotel_room) //= undef;

    method get_short_room_name () {
        return $short_name if defined $short_name;
        return;
    }

    method get_long_room_name () {
        return $long_name if defined $long_name;
        return;
    }

    method get_hotel_room () {
        return $hotel_room if defined $hotel_room;
        return;
    }

    method has_prefix ( $prefix ) {
        defined $prefix
            or return;
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

    field $is_split :param(is_split) //= undef;
    Readonly our $SPLIT_PREFIX => q{SPLIT};
    ADJUST {
        $is_split //= $self->has_prefix( $SPLIT_PREFIX ) ? 1 : 0;
    }

    method get_is_split () {
        return $is_split ? 1 : 0;
    }

    # MARK: is_break field

    field $is_break :param(is_break) //= undef;
    Readonly our $BREAK => q{BREAK};
    ADJUST {
        $is_break //= $self->name_is_exact( $BREAK );
    }

    method get_room_is_break () {
        return $is_break ? 1 : 0;
    }

    # MARK: sort_key field

    Readonly our $HIDDEN_SORT_KEY  => 100;
    Readonly our $UNKNOWN_SORT_KEY => 999;

    field $sort_key :param(sort_key) //= undef;
    my @sort_key_used;

    ADJUST {
        ( !defined $sort_key )
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
    field $uid;
    ADJUST {
        $uid = -1 + push @uid_map, $self;
    }

    method get_room_id () {
        return $uid;
    }

    sub find_by_room_id ( $class, $uid ) {
        defined $uid
            or return;
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

        $other isa __PACKAGE__
            or croak q{Compare Room with something else }, ( ref $other );

        my $lhs = $swap ? $other : $self;
        my $rhs = $swap ? $self  : $other;

        return
               $lhs->get_sort_key() <=> $rhs->get_sort_key()
            || $lhs->get_long_room_name() cmp $rhs->get_long_room_name()
            || $lhs->get_room_id() <=> $rhs->get_room_id();
    } ## end sub compare
} ## end package Data::Room

1;
