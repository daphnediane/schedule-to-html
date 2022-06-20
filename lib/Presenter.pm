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

1;
