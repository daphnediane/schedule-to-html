package Data::PanelType;

use Object::InsideOut;

use v5.36.0;
use utf8;

use Carp qw{croak};
use Readonly;

use Canonical qw{ :all };

Readonly our $RE_BREAK       => qr{ \A br }xmsi;
Readonly our $RE_CAFE        => qr{ \A caf[eé] \z }xmsi;
Readonly our $RE_ID_WORKSHOP => qr{ \A . W \z}xmsi;

Readonly our $DEF_COLOR_SET => q{Color};

## no critic(TooMuchCode::ProhibitDuplicateLiteral)
q{Café}  =~ $RE_CAFE or croak q{Assertion fail};
q{CAFE}  =~ $RE_CAFE or croak q{Assertion fail};
q{CAFET} !~ $RE_CAFE or croak q{Assertion fail};
## use critic

## no critic (ProhibitUnusedVariables)

my @prefix_key
    :Field
    :Type(scalar)
    :Arg(Name => q{prefix}, Mand => 1)
    :Get(Name => q{get_prefix});

my @kind_key
    :Field
    :Type(scalar)
    :Arg(Name => q{kind}, Mand => 1)
    :Get(Name => q{get_kind});

my @is_break_key
    :Field
    :Type(scalar)
    :Arg(Name => q{is_break})
    :Set(Name => q{set_is_break_}, Restricted => 1)
    :Get(Name => q{get_is_break_}, Restricted => 1);

my @is_cafe_key
    :Field
    :Type(scalar)
    :Arg(Name => q{is_cafe})
    :Set(Name => q{set_is_cafe_}, Restricted => 1)
    :Get(Name => q{get_is_cafe_}, Restricted => 1);

my @is_hidden_key
    :Field
    :Type(scalar)
    :Default(0)
    :Arg(Name => q{is_hidden})
    :Set(Name => q{set_is_hidden_}, Restricted => 1)
    :Get(Name => q{get_is_hidden});

my @is_workshop_key
    :Field
    :Type(scalar)
    :Arg(Name => q{is_workshop})
    :Set(Name => q{set_is_workshop_}, Restricted => 1)
    :Get(Name => q{get_is_workshop_}, Restricted => 1);

my @color_sets_key
    :Field
    :Type(scalar)
    :Default({})
    :Get(Name => q{get_color_sets_}, Restricted => 1);

## use critic

sub is_break {
    my ( $self ) = @_;
    my $res = $self->get_is_break_();
    return 1 if $res;
    return   if defined $res;
    if ( $self->get_kind() =~ $RE_BREAK ) {
        $self->set_is_break_( 1 );
        return 1;
    }
    $self->set_is_break_( 0 );
    return;
} ## end sub is_break

sub is_cafe {
    my ( $self ) = @_;
    my $res = $self->get_is_cafe_();
    return 1 if $res;
    return   if defined $res;
    if ( $self->get_kind() =~ $RE_CAFE ) {
        $self->set_is_cafe_( 1 );
        return 1;
    }
    $self->set_is_cafe_( 0 );
    return;
} ## end sub is_cafe

sub make_shown {
    my ( $self ) = @_;
    $self->set_is_hidden_( 0 );
    return;
}

sub make_hidden {
    my ( $self ) = @_;
    $self->set_is_hidden_( 1 );
    return;
}

sub is_workshop {
    my ( $self ) = @_;
    my $res = $self->get_is_workshop_();
    return 1 if $res;
    return   if defined $res;
    if ( $self->get_prefix() =~ $RE_ID_WORKSHOP ) {
        $self->set_is_workshop_( 1 );
        return 1;
    }
    $self->set_is_workshop_( 0 );
    return;
} ## end sub is_workshop

sub set_color {
    my ( $self, $value, $color_set ) = @_;
    $color_set //= $DEF_COLOR_SET;
    $color_set = $DEF_COLOR_SET if $color_set eq q{};
    $color_set = canonical_header( $color_set );
    $color_set = lc $color_set;

    my $sets = $self->get_color_sets_();
    if ( !defined $value || $value eq q{} ) {
        delete $sets->{ $color_set };
        return;
    }

    $sets->{ $color_set } = $value;
    return $value;
} ## end sub set_color

sub get_color {
    my ( $self, $color_set ) = @_;
    $color_set //= $DEF_COLOR_SET;
    $color_set = $DEF_COLOR_SET if $color_set eq q{};
    $color_set = canonical_header( $color_set );
    $color_set = lc $color_set;

    my $sets  = $self->get_color_sets_();
    my $value = $sets->{ $color_set };
    return unless defined $value;
    return if $value eq q{};
    return $value;
} ## end sub get_color

1;
