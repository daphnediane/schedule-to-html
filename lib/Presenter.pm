package Presenter;

use v5.38.0;
use utf8;

use Carp                   qw{ croak };
use Feature::Compat::Class qw{ :all };
use List::Util             qw{ max uniq };
use Readonly               qw{ Readonly };
use Scalar::Util           qw{ blessed };

class Presenter;

## no critic (TooMuchCode::ProhibitDuplicateLiteral)
use overload
    q{<=>} => q{compare},
    q{cmp} => q{compare};
## use critic

Readonly our $ANY_GUEST => q{All Guests};

# MARK: name field

field $name :param(name);

method get_presenter_name() {
    return $name;
}

# MARK: rank field

Readonly our $RANK_GUEST         => 0;
Readonly our $RANK_JUDGE         => 1;
Readonly our $RANK_STAFF         => 2;
Readonly our $RANK_INVITED_GUEST => 3;
Readonly our $RANK_FAN_PANELIST  => 4;

# Presenter headers
Readonly::Hash our %PREFIX_TO_RANK => (
    g => $RANK_GUEST,
    j => $RANK_JUDGE,
    s => $RANK_STAFF,
    i => $RANK_INVITED_GUEST,
    p => $RANK_FAN_PANELIST,
);
Readonly::Array our @RANKS => sort uniq values %PREFIX_TO_RANK;

field $rank :param(rank);

method get_presenter_rank () {
    return $rank;
}

method set_presenter_rank_ ( $new_rank ) {
    $rank = $new_rank;
    return $self;
}

method improve_presenter_rank ( $new_rank ) {
    if ( $new_rank < $rank ) {
        $rank = $new_rank;
    }
    return;
} ## end sub improve_presenter_rank

# MARK: indices field

sub _decode_indices ( @values ) {
    return map { ref $_ ? ( _decode_indices( @{ $_ } ) ) : ( $_ ) } @values;
}

field $index_array :param(index_array);

method get_index_array ( ) {
    return _decode_indices( $index_array );
}

# MARK: is_other
# Others is not really a presenter, just a key that indicates that heading
# contains a list of presenters.

field $is_other :param(is_other) //= 0;

method get_is_other () {
    return $is_other ? 1 : 0;
}

# MARK: is_meta
# Meta is used for ANY_GUEST

field $is_meta :param(is_meta) //= 0;

method get_is_meta() {
    return $is_meta ? 1 : 0;
}

# MARK: always_show

field $always_show :param(always_show) //= 0;

method set_is_always_shown( $shown = 1 ) {
    $always_show = $shown;
    return $self;
}

method clear_is_always_shown( ) {
    $always_show = 0;
    return $self;
}

method get_is_always_shown() {
    return $always_show ? 1 : 0;
}

# MARK: always_as_group

field $always_as_group = 0;

method set_is_always_grouped( $grouped = 1 ) {
    $always_as_group = $grouped;
    return $self;
}

method clear_is_always_grouped( ) {
    $always_as_group = 0;
    return $self;
}

method get_is_always_grouped() {
    return $always_as_group ? 1 : 0;
}

# MARK: groups and members

field %groups;
field %members;

method get_groups () {
    return values %groups;
}

method is_in_group () {
    return 1 if %groups;
    return 0;
}

method get_members ( ) {
    return values %members;
}

method is_group () {
    return 1 if %members;
    return;
}

method is_individual () {
    return 1 unless %members;
    return;
}

method _link_to_group ( $group ) {
    $groups{ $group->get_pid() } = $group;
}

method _link_to_member ( $member ) {
    $members{ $member->get_pid() } = $member;
}

method add_members ( @new_members ) {
    foreach my $member ( @new_members ) {
        my $mid = $member->get_pid();
        next if $members{ $mid };
        $members{ $mid } = $member;
        $member->_link_to_group( $self );
    } ## end foreach my $member ( @new_members)
    return;
} ## end sub add_members

method add_groups ( @new_groups ) {
    foreach my $group ( @new_groups ) {
        my $gid = $group->get_pid();
        next if $groups{ $gid };
        $groups{ $gid } = $group;
        $group->_link_to_member( $self );
    } ## end foreach my $group ( @new_groups)
    return;
} ## end sub add_groups

# MARK: pid and cache

field $pid :reader(get_pid);
field $caching :param(caching);
my @pid_map;
my @presenters;

ADJUST {
    $pid = scalar @pid_map;
    push @pid_map,    $self;
    push @presenters, $self unless $is_other;
    defined $caching
        || croak q{Do not call new directly};
    $caching->{ lc $name } = $self;
    $caching = undef;
} ## end ADJUST

sub find_by_pid ( $class, $pid ) {
    my $value = $pid_map[ $pid ];
    return $value if defined $value;
    return;
}

sub cache_or_new ( $class, %args ) {
    $class = ref $class || $class;

    my $name = $args{ name } //= q{Anonymous};
    my $rank = $args{ rank } //= $RANK_FAN_PANELIST;

    my $index = 0;
    $index += 1                 if $args{ is_meta };
    $index += 2 + $args{ rank } if $args{ is_other };

    state %_cache_root;
    my $name_cache = $_cache_root{ $class }->{ $index } //= {};

    my $res = $name_cache->{ lc $name };
    if ( !defined $res ) {
        $res = $class->new( %args, caching => $name_cache );
    }
    $res->improve_presenter_rank( $rank );

    return $res;
} ## end sub cache_or_new

# MARK: todo

method compare ( $other, $swap ) {
    die qq{Compare Presenter with something else\n}
        unless blessed $other && $other->isa( q{Presenter} );

    my $left  = $swap ? $other : $self;
    my $right = $swap ? $self  : $other;

    my $res = $left->get_presenter_rank() <=> $right->get_presenter_rank();
    return $res if $res;

    # Compare indices from major to minor
    my @left_ind  = $left->get_index_array();
    my @right_ind = $right->get_index_array();
    for my $ind ( 0 .. max $#left_ind, $#right_ind ) {
        $res = ( $left_ind[ $ind ] // 0 ) <=> ( $right_ind[ $ind ] // 0 );
        return $res if $res;
    }

    return $left->get_presenter_name() cmp $right->get_presenter_name()
        || $left->get_pid() <=> $right->get_pid();
} ## end sub compare

sub lookup ( $class, $name_with_group, $index = undef, $rank = undef ) {
    return unless defined $name_with_group;
    return if $name_with_group eq q{};

    if ( $name_with_group =~ s{\A (?<rank> \w ) : }{}xms ) {
        $rank = $PREFIX_TO_RANK{ lc $+{ rank } };
    }

    return if $name_with_group eq q{};
    return unless defined $rank;

    my ( $name, $group ) = split m{=}xms, $name_with_group, 2;

    $index //= [];
    $index = [ $index ] unless ref $index;

    if ( lc $name eq q{other} ) {
        $name = $rank . q{:Other};

        return $class->cache_or_new(
            name        => $name,
            rank        => $rank,
            index_array => $index,
            is_other    => 1,
        );
    } ## end if ( lc $name eq q{other})

    my $ginfo;
    if ( defined $group && $group ne q{} ) {
        my $always_shown = $group =~ s{\A =}{}xms;
        $ginfo = Presenter->cache_or_new(
            name        => $group,
            rank        => $rank,
            index_array => $index,
        );
        $ginfo->set_is_always_shown( 1 ) if $always_shown;
    } ## end if ( defined $group &&...)

    my $always_grouped = $name =~ s{\A <}{}xms;
    my $info           = $class->cache_or_new(
        name        => $name,
        rank        => $rank,
        index_array => $index,
    );

    if ( defined $ginfo ) {
        $ginfo->add_members( $info );
        $info->set_is_always_grouped( 1 ) if $always_grouped;
    }

    return $info;
} ## end sub lookup

sub any_guest ( $class //= __PACKAGE__ ) {
    state $any_info;
    return $any_info if defined $any_info;

    $any_info = $class->cache_or_new(
        name        => $ANY_GUEST,
        rank        => $Presenter::RANK_GUEST,
        index_array => [ -1 ],
        is_meta     => 1,
    );
    return $any_info;
} ## end sub any_guest

sub get_known ( $class //= __PACKAGE__ ) {
    $class->any_guest();
    return @presenters;
}

1;
