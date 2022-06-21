package Presenter;

use Object::InsideOut;

use strict;
use warnings;
use common::sense;

use Readonly;
use utf8;

use overload
    q{<=>} => q{compare},
    q{cmp} => q{compare};

Readonly our $RANK_GUEST         => 0;
Readonly our $RANK_STAFF         => 1;
Readonly our $RANK_INVITED_GUEST => 2;
Readonly our $RANK_FAN_PANELIST  => 3;
Readonly our $RANK_UNKNOWN       => 999;

# Presenter headers
Readonly our $PREFIX_TO_RANK => {
    g => $RANK_GUEST,
    s => $RANK_STAFF,
    i => $RANK_INVITED_GUEST,
    p => $RANK_FAN_PANELIST,
};

Readonly our $ANY_GUEST => q{All Guests};

my @presenters;

## no critic (ProhibitUnusedVariables)

my @name
    :Field
    :Type(scalar)
    :Arg(Name => q{name}, Mandatory => 1)
    :Get(get_presenter_name);

my @rank
    :Field
    :Type(scalar)
    :Arg(Name => q{rank}, Mandatory => 1)
    :Get(get_presenter_rank)
    :Set(Name => q{set_presenter_rank_}, Restricted => 1);

my @indices
    :Field
    :Arg(index_array)
    :Get(Name => q{get_index_array_}, Restricted => 1);

# Others is not really a panelist, just a key that indicates that heading
# contains a list of panelist.
my @is_other
    :Field
    :Type(scalar)
    :Arg(is_other)
    :Get(get_is_other);

my @is_meta
    :Field
    :Type(scalar)
    :Arg(is_meta)
    :Get(get_is_meta);

my @groups
    :Field
    :Std(Name => q{groups_}, Restricted => 1);

my @members
    :Field
    :Std(Name => q{members_}, Restricted => 1);

## use critic

sub improve_presenter_rank {
    my ( $self, $new_rank ) = @_;

    my $old_rank = $self->get_presenter_rank();
    if ( $new_rank < $old_rank ) {
        $self->set_presenter_rank_( $new_rank );
    }
    return;
} ## end sub improve_presenter_rank

sub decode_array_ :Private {
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

    my $gid      = ${ $self };
    my $mem_hash = $self->get_members_();
    if ( !defined $mem_hash ) {
        $mem_hash = {};
        $self->set_members_( $mem_hash );
    }
    foreach my $member ( @new_members ) {
        my $mid = ${ $member };
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

    my $mid      = ${ $self };
    my $gpr_hash = $self->get_groups_();
    if ( !defined $gpr_hash ) {
        $gpr_hash = {};
        $self->set_groups_( $gpr_hash );
    }
    foreach my $group ( @new_groups ) {
        my $gid = ${ $group };
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
        unless q{Presenter} eq ref $other;

    ( $self, $other ) = ( $other, $self ) if $swap;

    my $res = $self->get_presenter_rank() <=> $other->get_presenter_rank();
    return $res if $res;

    # Compare indices from major to minor
    my @self_ind      = $self->get_index_array();
    my @other_ind     = $other->get_index_array();
    my $self_num_ind  = scalar @self_ind;
    my $other_num_ind = scalar @other_ind;
    my $largest_ind
        = $self_num_ind >= $other_num_ind ? \@self_ind : \@other_ind;
    for my $ind ( keys @{ $largest_ind } ) {
        $res = ( $self_ind[ $ind ] // 0 ) <=> ( $other_ind[ $ind ] // 0 );
        return $res if $res;
    }

    return $self->get_presenter_name() cmp $other->get_presenter_name()
        || ${ $self } <=> ${ $other };
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
    $self->get_map_(
        $self->get_presenter_rank(),
        $self->get_is_other(),
        $self->get_is_meta()
    )->{ lc $self->get_presenter_name() } = $self;
    return;
} ## end sub init_

sub lookup {
    my ( $class, $name_with_group, $index, $rank ) = @_;

    return unless defined $name_with_group;
    return if $name_with_group eq q{};

    if ( $name_with_group =~ s{\A (?<rank> \w ) : }{}xms ) {
        $rank = $PREFIX_TO_RANK->{ lc $+{ rank } };
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

    my $info = Presenter->new(
        name        => $name,
        rank        => $rank,
        index_array => $index,
    );

    if ( $group ) {
        my $ginfo = Presenter->new(
            name        => $group,
            rank        => $rank,
            index_array => $index,
        );
        $ginfo->add_members( $info );
    } ## end if ( $group )

    return;
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

sub get_known() {
    my ( $class ) = @_;

    $class->any_guest();
    return @presenters;
} ## end sub get_known

1;
