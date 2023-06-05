package ActivePanel;

use Object::InsideOut qw{TimeRange};

use strict;
use warnings;
use common::sense;

use Readonly;
use utf8;
use RoomInfo;

## no critic (ProhibitUnusedVariables)

my @panel
    :Field
    :Type(PanelInfo)
    :Arg(Name => q{active_panel}, Mandatory => 1)
    :Get(get_active_panel);

my @rows
    :Field
    :Type(numeric)
    :Std_All(Name => q{rows});

my @is_break
    :Field
    :Type(scalar)
    :Std_All(is_break);

my @room
    :Field
    :Type(RoomInfo)
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
