package PresenterSet;

use Object::InsideOut;

use strict;
use warnings;
use common::sense;

use Carp qw{croak};
use List::Util;
use Readonly;
use utf8;

use Presenter;

Readonly our $UNLISTED => 1;
Readonly our $LISTED   => 2;

## no critic (ProhibitUnusedVariables)

my @presenter_set
    :Field
    :Default({})
    :Get(Name => q{get_set_}, Private => 1);

my @hide_credits
    :Field
    :Std_All(are_credits_hidden);

my @override_credits
    :Field
    :Std_All(override_credits);

my @credits
    :Field
    :Std(Name => q{credits_}, Private => 1);
## use critic

sub add_credited_presenters {
    my ( $self, @presenters ) = @_;
    return unless @presenters;

    $self->set_credits_( undef );

    my $p_set = $self->get_set_();
    foreach my $presenter ( @presenters ) {
        next unless defined $presenter;
        $p_set->{ $presenter->get_pid() } = $LISTED;
    }
    return;
} ## end sub add_credited_presenters

sub add_unlisted_presenters {
    my ( $self, @presenters ) = @_;
    return unless @presenters;

    $self->set_credits_( undef );

    my $p_set = $self->get_set_();
    foreach my $presenter ( @presenters ) {
        next unless defined $presenter;
        my $pid     = $presenter->get_pid();
        my $current = $p_set->{ $pid } //= $UNLISTED;
    }
    return;
} ## end sub add_unlisted_presenters

sub is_presenter_hosting {
    my ( $self, $presenter ) = @_;
    return unless defined $presenter;

    return 1 if exists $self->get_set_()->{ $presenter->get_pid() };
    return;
} ## end sub is_presenter_hosting

sub is_presenter_credited {
    my ( $self, $presenter ) = @_;
    return unless defined $presenter;

    return 1 if $self->get_set_()->{ $presenter->get_pid() } >= $LISTED;
    return;
} ## end sub is_presenter_credited

sub is_presenter_unlisted {
    my ( $self, $presenter ) = @_;
    return unless defined $presenter;

    return 1 if $self->get_set_()->{ $presenter->get_pid() } == $UNLISTED;
    return;
} ## end sub is_presenter_unlisted

sub get_credits {
    my ( $self ) = @_;

    if ( $self->get_are_credits_hidden() ) {
        return;
    }

    my $override = $self->get_override_credits();
    return $override if defined $override;

    my $credits = $self->get_credits_();
    return $credits if defined $credits;

    my %shown;
    my $p_set = $self->get_set_();

PRESENTER:
    while ( my ( $pid, $state ) = each %{ $p_set } ) {
        next if $state < $LISTED;
        my $presenter = Presenter->find_by_pid( $pid );
        next unless defined $presenter;

        next if $shown{ $pid };

        # Check if group should be shown instead
        # Groups will be should if either
        # -- All members are hosting
        # -- Group is listed as always shown
    GROUP:
        foreach my $group ( $presenter->get_groups() ) {
            if ( $group->get_is_always_shown() ) {
                $shown{ $group->get_pid() } = $group;
                next PRESENTER;
            }
            foreach my $member ( $group->get_members() ) {
                next GROUP unless exists $p_set->{ $member->get_pid() };
            }
            $shown{ $group->get_pid() } = $group;
            next PRESENTER;
        } ## end GROUP: foreach my $group ( $presenter...)

        $shown{ $pid } = $presenter;
    } ## end PRESENTER: while ( my ( $pid, $state...))

    my @presenters = map { $_->get_presenter_name() } sort values %shown;
    $credits = join q{, }, @presenters if @presenters;

    $self->set_credits_( $credits );

    return $credits if defined $credits;
    return;
} ## end sub get_credits

1;
