package Table::Room::Focus;

use Object::InsideOut;

use v5.36.0;
use utf8;

## no critic (ProhibitUnusedVariables)

my @focused_
    :Field
    :Arg(Name => q{focused})
    :Get(Name => q{get_focus_}, Restricted => 1);

my @hide_descriptions_
    :Field
    :Arg(Name => q{hide_descriptions})
    :Get(Name => q{get_hide_descriptions_}, Restricted => 1);

## use critic

sub is_focused {
    my ( $self ) = @_;
    return 1 if $self->get_focus_();
    return;
}

sub is_unfocused {
    my ( $self ) = @_;
    return   if $self->get_focus_();
    return 1 if defined $self->get_focus_();
    return;
} ## end sub is_unfocused

sub is_unknown {
    my ( $self ) = @_;
    return 1 unless defined $self->get_focus_();
    return;
}

sub are_descriptions_shown {
    my ( $self ) = @_;
    return 1 unless $self->get_hide_descriptions_();
    return;
}

sub are_descriptions_hidden {
    my ( $self ) = @_;
    return 1 if $self->get_hide_descriptions_();
    return;
}

sub focused_room {
    state $obj = __PACKAGE__->new( focused => 1 );
    return $obj;
}

sub unfocused_room {
    state $obj = __PACKAGE__->new( focused => 0, hide_descriptions => 1 );
    return $obj;
}

sub normal_room {
    state $obj = __PACKAGE__->new();
    return $obj;
}

1;
