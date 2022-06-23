package TimeSlot;

use Object::InsideOut qw{TimeRange};

use strict;
use warnings;
use common::sense;

use Carp qw{croak};
use Readonly;
use utf8;
use ActivePanel;
use PanelInfo;
use PresenterSet;

## no critic (ProhibitUnusedVariables)

my @current_panels
    :Field
    :Std(Name => q{current_}, Restricted => 1);

my @upcoming_panels
    :Field
    :Std( Name => q{upcoming_}, Restricted => 1 );

## use critic

sub get_current {
    my ( $self ) = @_;
    my $res = $self->get_current_();
    return $res if defined $res;
    $res = {};
    $self->set_current_( $res );
    return $res;
} ## end sub get_current

sub init_current {
    my ( $self, $current_map ) = @_;
    my $res = $self->get_current_();
    croak q{Current already set} if defined $res && %{ $res };
    $self->set_current_( $current_map );
    return;
} ## end sub init_current

sub get_upcoming {
    my ( $self ) = @_;
    my $res = $self->get_upcoming_();
    return $res if defined $res;
    $res = {};
    $self->set_upcoming_( $res );
    return $res;
} ## end sub get_upcoming

sub init_upcoming {
    my ( $self, $upcoming_map ) = @_;
    my $res = $self->get_upcoming_();
    croak q{Current already set} if defined $res && %{ $res };
    $self->set_upcoming_( $upcoming_map );
    return;
} ## end sub init_upcoming

sub is_presenter_hosting {
    my ( $self, $presenter ) = @_;
    return unless defined $presenter;

    my $res = $self->get_current_();
    return unless defined $res;

    foreach my $panel_state ( values %{ $res } ) {
        next unless defined $panel_state;
        my $panel = $panel_state->get_active_panel();
        return 1 if $panel->is_presenter_hosting();
    }
    return;
} ## end sub is_presenter_hosting

sub is_presenter_credited {
    my ( $self, $presenter ) = @_;
    return unless defined $presenter;

    my $res = $self->get_current_();
    return unless defined $res;

    foreach my $panel_state ( values %{ $res } ) {
        next unless defined $panel_state;
        my $panel = $panel_state->get_active_panel();
        return 1 if $panel->is_presenter_credited();
    }
    return;
} ## end sub is_presenter_credited

sub is_presenter_unlisted {
    my ( $self, $presenter ) = @_;
    return unless defined $presenter;

    my $res = $self->get_current_();
    return unless defined $res;

    foreach my $panel_state ( values %{ $res } ) {
        next unless defined $panel_state;
        my $panel = $panel_state->get_active_panel();
        return 1 if $panel->is_presenter_unlisted();
    }
    return;
} ## end sub is_presenter_unlisted

1;
