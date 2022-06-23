package PanelInfo;

use Object::InsideOut qw{TimeRange RoomHandle};

use strict;
use warnings;
use common::sense;

use Carp qw{croak};
use Readonly;
use utf8;

use RoomInfo;
use PresenterSet;

Readonly our $CAFE => q{Café};

## no critic(ProhibitComplexRegexes)
Readonly our $RE_FREE => qr{
    \A (?:  free
    | (?=n) (?: nothing
              | n /? a )
    | [\$]? (?: 0+ (?: [.] 0+ )? | [.] 0+ )
    ) \z
    }xmsi;
Readonly our $RE_TBD => qr{ \A T [.]? B [.]? D[.]? \z }xms;
## use critic

q{free}        =~ $RE_FREE or croak q{Assertion fail};
q{n/A}         =~ $RE_FREE or croak q{Assertion fail};
q{nothing}     =~ $RE_FREE or croak q{Assertion fail};
q{$} . q{0.00} =~ $RE_FREE or croak q{Assertion fail};
q{$} . q{0.01} !~ $RE_FREE or croak q{Assertion fail};
q{$} . q{0}    =~ $RE_FREE or croak q{Assertion fail};
q{$} . q{00}   =~ $RE_FREE or croak q{Assertion fail};
q{T.B.D.}      =~ $RE_TBD  or croak q{Assertion fail};

sub norm_text_ {
    my ( @values ) = @_;
    @values = grep { defined } @values;
    return unless @values;
    my $value = join q{}, @values;
    $value =~ s{\A \s++ }{}xms;
    $value =~ s{\s++ \z}{}xms;
    return if $value eq q{};
    return $value;
} ## end sub norm_text_

sub pre_init_text_ {
    my ( $class, $param, $spec, $obj, $value ) = @_;
    return norm_text_( $value );
}

sub pre_set_text_ {
    my ( $class, $field, @args ) = @_;
    return norm_text_( @args );
}

sub norm_cost_ {
    my ( @values ) = @_;
    my $value = norm_text_( @values );
    return unless defined $value;
    return if $value eq q{};
    return if $value =~ $RE_FREE;
    return q{TBD} if $value =~ $RE_TBD;
    return $value;
} ## end sub norm_cost_

sub pre_init_cost_ {
    my ( $class, $param, $spec, $obj, $value ) = @_;
    return norm_cost_( $value );
}

sub pre_set_cost_ {
    my ( $class, $field, @args ) = @_;
    return norm_cost_( @args );
}

sub pre_is_full_ {
    my ( $class, $param, $spec, $obj, $value ) = @_;
    return unless defined $value;
    return if $value =~ m{\Anot??}xms;
    return if $value eq q{};

    return 1;
} ## end sub pre_is_full_

## no critic (ProhibitUnusedVariables)

my @uniq_id
    :Field
    :Type(scalar)
    :Arg(Name => q{uniq_id}, Mand => 1, Pre => \&PanelInfo::pre_init_text_)
    :Get(get_uniq_id);

my @id_prefix
    :Field
    :Std(Name => q{id_prefix_}, Restricted => 1 );

my @anchor :Field
    :Type(scalar)
    :Std(Name => q{anchor_}, Restricted => 1 );

my @name
    :Field
    :Type(scalar)
    :Arg(Name => q{name}, Pre => \&PanelInfo::pre_init_text_)
    :Set(Name => q{set_name}, Pre => \&PanelInfo::pre_set_text_)
    :Get(get_name);

my @desc
    :Field
    :Type(scalar)
    :Arg(Name => q{description}, Pre => \&PanelInfo::pre_init_text_)
    :Set(Name => q{set_description}, Pre => \&PanelInfo::pre_set_text_)
    :Get(get_description);

my @note
    :Field
    :Type(scalar)
    :Arg(Name => q{note}, Pre => \&PanelInfo::pre_init_text_)
    :Set(Name => q{set_note}, Pre => \&PanelInfo::pre_set_text_)
    :Get(get_note);

my @difficulty
    :Field
    :Type(scalar)
    :Std_All(difficulty);

my @panel_kind
    :Field
    :Type(scalar)
    :Arg(Name => q{panel_kind}, Pre => \&PanelInfo::pre_init_text_)
    :Set(Name => q{set_panel_kind}, Pre => \&PanelInfo::pre_set_text_)
    :Get(get_panel_kind);

my @cost
    :Field
    :Type(scalar)
    :Arg(Name => q{cost}, Pre => \&PanelInfo::pre_init_cost_)
    :Set(Name => q{set_cost}, Pre => \&PanelInfo::pre_set_cost_)
    :Get(get_cost);

my @full
    :Field
    :Type(scalar)
    :Arg(Name => q{is_full}, Pre => \&PanelInfo::pre_is_full_)
    :Get(Name => q{get_is_full_}, Private => 1);

my @css_subclasses
    :Field
    :Type(ARRAY_ref(scalar))
    :Std(css_subclasses);

my @presenter_set
    :Field
    :Type(PresenterSet)
    :Arg(presenter_set)
    :Get(get_presenter_set)
    :Set(Name => q{set_presenter_set_}, Private => 1)
    :Default(PresenterSet->new())
    :Handles(PresenterSet::);

## use critic

sub init_ :Init {
    my ( $self, $args ) = @_;
    my $current_set = $self->get_presenter_set();
    if ( !defined $current_set ) {
        $self->set_presenter_set_( PresenterSet->new() );
    }
    return;
} ## end sub init_

sub get_uniq_id_prefix {
    my ( $self ) = @_;
    my $prefix = $self->get_id_prefix_();
    return $prefix if defined $prefix;
    $prefix = $self->get_uniq_id();
    $prefix =~ s{\d+[[:alpha:]]?(?:Dup\d+)?\z}{}xms;
    $prefix = substr $prefix, 0, 2;
    $self->set_id_prefix_( $prefix );
    return $prefix;
} ## end sub get_uniq_id_prefix

sub get_href_anchor {
    my ( $self ) = @_;
    my $anchor = $self->get_anchor_();
    return $anchor if defined $anchor;

    $anchor = $self->get_uniq_id() // q{ZZ9999999};
    state %ids_seen;
    if ( $ids_seen{ $anchor } ) {
        my $indx = ++$ids_seen{ $anchor };
        $anchor .= q{Dup} . $anchor;
    }
    else {
        $ids_seen{ $anchor } = 1;
    }
    $self->set_anchor_( $anchor );
    return $anchor;

} ## end sub get_href_anchor

sub get_panel_is_break {
    my ( $self ) = @_;
    return 1 if uc $self->get_uniq_id_prefix() eq q{BR};
    return;
}

sub get_panel_is_cafe {
    my ( $self ) = @_;
    return $self->get_panel_kind() eq $CAFE;
}

sub get_is_break {
    my ( $self ) = @_;
    return 1 if $self->get_room_is_break();
    return $self->get_panel_is_break();
}

sub get_is_full {
    my ( $self ) = @_;
    return 1 if $self->get_is_full_();

    #TODO(pfister): Check capacity

    return;
} ## end sub get_is_full

1;
