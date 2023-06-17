package ActivePanel;

use Object::InsideOut qw{TimeRange};

use strict;
use warnings;
use common::sense;

use Data::Room qw{};

## no critic (ProhibitUnusedVariables)

my @panel
    :Field
    :Type(Data::Panel)
    :Arg(Name => q{active_panel}, Mandatory => 1)
    :Get(Name => q{get_active_panel});

my @rows
    :Field
    :Type(numeric)
    :Arg(Name => q{rows})
    :Set(Name => q{set_rows})
    :Get(Name => q{get_rows});

my @is_break
    :Field
    :Type(scalar)
    :Arg(Name => q{is_break})
    :Get(Name => q{get_is_break});

my @room
    :Field
    :Type(Data::Room)
    :Arg(Name => q{room}, Mand => 1)
    :Get(Name => q{get_room});

## use critic

sub increment_rows {
    my ( $self, $amount ) = @_;
    my $rows = $self->get_rows() // 0;
    $amount //= 1;
    $rows += $amount;
    $self->set_rows( $rows );
    return;
} ## end sub increment_rows

1;
