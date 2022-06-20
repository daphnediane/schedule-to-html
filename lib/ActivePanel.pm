package ActivePanel;

use Object::InsideOut qw{TimeRange RoomHandle};

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

## use critic

sub increment_rows {
    my ( $self, $amount ) = @_;
    $amount //= 1;
    $rows[ ${ $self } ] += $amount;
    return;
} ## end sub increment_rows

1;
