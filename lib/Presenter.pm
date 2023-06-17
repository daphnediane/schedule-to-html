package Presenter;

use Object::InsideOut;

use v5.36.0;
use utf8;

use Readonly;
use List::Util qw{ max uniq };

## no critic (TooMuchCode::ProhibitDuplicateLiteral)
use overload
    q{<=>} => q{compare},
    q{cmp} => q{compare};
## use critic

Readonly our $RANK_GUEST         => 0;
Readonly our $RANK_STAFF         => 1;
Readonly our $RANK_INVITED_GUEST => 2;
Readonly our $RANK_FAN_PANELIST  => 3;

# Presenter headers
Readonly::Hash our %PREFIX_TO_RANK => (
    g => $RANK_GUEST,
    s => $RANK_STAFF,
    i => $RANK_INVITED_GUEST,
    p => $RANK_FAN_PANELIST,
);
Readonly::Array our @RANKS => sort uniq values %PREFIX_TO_RANK;

Readonly our $ANY_GUEST => q{All Guests};

my @presenters;
my @pid_map;

## no critic (ProhibitUnusedVariables)

my @name
    :Field
    :Type(scalar)
    :Arg(Name => q{name}, Mandatory => 1)
    :Get(Name => q{get_presenter_name});

my @rank
    :Field
    :Type(scalar)
    :Arg(Name => q{rank}, Mandatory => 1)
    :Set(Name => q{set_presenter_rank_}, Restricted => 1)
    :Get(Name => q{get_presenter_rank});

my @indices
    :Field
    :Arg(Name => q{index_array})
    :Get(Name => q{get_index_array_}, Restricted => 1);

# Others is not really a presenter, just a key that indicates that heading
# contains a list of presenters.
my @is_other
    :Field
    :Type(scalar)
    :Arg(Name => q{is_other})
    :Get(Name => q{get_is_other});

my @is_meta
    :Field
    :Type(scalar)
    :Arg(Name => q{is_meta})
    :Get(Name => q{get_is_meta});

my @always_show
    :Field
    :Type(scalar)
    :Set(Name => q{set_is_always_shown})
    :Get(Name => q{get_is_always_shown});

my @always_as_group
    :Field
    :Type(scalar)
    :Set(Name => q{set_is_always_grouped})
    :Get(Name => q{get_is_always_grouped});

my @groups
    :Field
    :Set(Name => q{set_groups_}, Restricted => 1)
    :Get(Name => q{get_groups_}, Restricted => 1);

my @members
    :Field
    :Set(Name => q{set_members_}, Restricted => 1)
    :Get(Name => q{get_members_}, Restricted => 1);

## use critic

sub get_pid {
    my ( $self ) = @_;
    return ${ $self };
}

sub find_by_pid {
    my ( $class, $pid ) = @_;

    my $value = $pid_map[ $pid ];
    return $value if defined $value;
    return;
} ## end sub find_by_pid

sub improve_presenter_rank {
    my ( $self, $new_rank ) = @_;

    my $old_rank = $self->get_presenter_rank();
    if ( $new_rank < $old_rank ) {
        $self->set_presenter_rank_( $new_rank );
    }
    return;
} ## end sub improve_presenter_rank

sub decode_array_ {
    my ( @values ) = @_;
    return map { ref $_ ? ( decode_array_( @{ $_ } ) ) : ( $_ ) } @values;
}

sub get_index_array {
    my ( $self ) = @_;
    return decode_array_( $self->get_index_array_() );
}

sub get_groups {
    my ( $self ) = @_;
    my $groups = $self->get_groups_();
    return unless defined $groups;
    return values %{ $groups };
} ## end sub get_groups

sub is_in_group {
    my ( $self ) = @_;
    return 1 if defined $self->get_groups_();
    return;
}

sub is_group {
    my ( $self ) = @_;
    return 1 if defined $self->get_members_();
    return;
}

sub is_individual {
    my ( $self ) = @_;
    return 1 unless defined $self->get_members_();
    return;
}

sub get_members {
    my ( $self ) = @_;
    my $members = $self->get_members_();
    return unless defined $members;
    return values %{ $members };
} ## end sub get_members

sub add_members {
    my ( $self, @new_members ) = @_;

    my $gid      = $self->get_pid();
    my $mem_hash = $self->get_members_();
    if ( !defined $mem_hash ) {
        $mem_hash = {};
        $self->set_members_( $mem_hash );
    }
    foreach my $member ( @new_members ) {
        my $mid = $member->get_pid();
        next if $mem_hash->{ $mid };
        $mem_hash->{ $mid } = $member;
        my $gpr_hash = $member->get_groups_();
        if ( !defined $gpr_hash ) {
            $gpr_hash = {};
            $member->set_groups_( $gpr_hash );
        }
        $gpr_hash->{ $gid } = $self;
    } ## end foreach my $member ( @new_members)
    return;
} ## end sub add_members

sub add_groups {
    my ( $self, @new_groups ) = @_;

    my $mid      = $self->get_pid();
    my $gpr_hash = $self->get_groups_();
    if ( !defined $gpr_hash ) {
        $gpr_hash = {};
        $self->set_groups_( $gpr_hash );
    }
    foreach my $group ( @new_groups ) {
        my $gid = $group->get_pid();
        next if $gpr_hash->{ $gid };
        $gpr_hash->{ $gid } = $group;
        my $mem_hash = $group->get_members_();
        if ( !defined $mem_hash ) {
            $mem_hash = {};
            $group->get_members_( $mem_hash );
        }
        $mem_hash->{ $mid } = $self;
    } ## end foreach my $group ( @new_groups)
    return;
} ## end sub add_groups

sub compare {
    my ( $self, $other, $swap ) = @_;
    die qq{Compare Presenter with something else\n}
        unless ref $other && $other->isa( q{Presenter} );

    ( $self, $other ) = ( $other, $self ) if $swap;

    my $res = $self->get_presenter_rank() <=> $other->get_presenter_rank();
    return $res if $res;

    # Compare indices from major to minor
    my @self_ind  = $self->get_index_array();
    my @other_ind = $other->get_index_array();
    for my $ind ( 0 .. max $#self_ind, $#other_ind ) {
        $res = ( $self_ind[ $ind ] // 0 ) <=> ( $other_ind[ $ind ] // 0 );
        return $res if $res;
    }

    return $self->get_presenter_name() cmp $other->get_presenter_name()
        || $self->get_pid() <=> $other->get_pid();
} ## end sub compare

sub get_map_ {
    my ( $class, $rank, $other, $meta ) = @_;
    $class = ref $class || $class;

    my $index = 0;
    $index += 1         if $meta;
    $index += 2 + $rank if $other;

    state %maps;
    return $maps{ $class }->[ $index ] //= {};

} ## end sub get_map_

sub check_cache_ :MergeArgs {
    my ( $class, $args ) = @_;

    my $name = $args->{ name };
    my $rank = $args->{ rank };

    return unless defined $name;
    return unless defined $rank;

    my $res = $class->get_map_(
        $rank,
        $args->{ is_other },
        $args->{ is_meta }
    )->{ lc $name };
    return unless defined $res;

    $res->improve_presenter_rank( $rank );
    return $res;
} ## end sub check_cache_

sub new {
    my ( $class, @args ) = @_;

    my $res = $class->check_cache_( @args );
    return $res if defined $res;

    return $class->Object::InsideOut::new( @args );
} ## end sub new

sub init_ :Init {
    my ( $self, $args ) = @_;
    push @presenters, $self unless $self->get_is_other();
    my $pid = $self->get_pid();
    $pid_map[ $pid ] = $self;
    $self->get_map_(
        $self->get_presenter_rank(),
        $self->get_is_other(),
        $self->get_is_meta()
    )->{ lc $self->get_presenter_name() } = $self;
    return;
} ## end sub init_

sub destroy_ :Destroy {
    my ( $self ) = @_;
    my $pid = $self->get_pid();
    $pid_map[ $pid ] = undef;
    return;
} ## end sub destroy_

sub lookup {
    my ( $class, $name_with_group, $index, $rank ) = @_;

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

        return $class->new(
            name        => $name,
            rank        => $rank,
            index_array => $index,
            is_other    => 1,
        );
    } ## end if ( lc $name eq q{other})

    my $ginfo;
    if ( defined $group && $group ne q{} ) {
        my $always_shown = $group =~ s{\A =}{}xms;
        $ginfo = Presenter->new(
            name        => $group,
            rank        => $rank,
            index_array => $index,
        );
        $ginfo->set_is_always_shown( 1 ) if $always_shown;
    } ## end if ( defined $group &&...)

    my $always_grouped = $name =~ s{\A <}{}xms;
    my $info           = Presenter->new(
        name        => $name,
        rank        => $rank,
        index_array => $index,
    );

    if ( defined $ginfo ) {
        $ginfo->add_members( $info );
        $info->set_is_always_grouped() if $always_grouped;
    }

    return $info;
} ## end sub lookup

sub any_guest {
    my ( $class ) = @_;

    state $any_info;
    return $any_info if defined $any_info;

    $any_info = $class->new(
        name        => $ANY_GUEST,
        rank        => $Presenter::RANK_GUEST,
        index_array => [ -1 ],
        is_meta     => 1,
    );
    return $any_info;
} ## end sub any_guest

sub get_known {
    my ( $class ) = @_;

    $class->any_guest();
    return @presenters;
} ## end sub get_known

1;
