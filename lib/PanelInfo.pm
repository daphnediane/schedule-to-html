package PanelInfo;

use Object::InsideOut qw{TimeRange};

use strict;
use warnings;
use common::sense;

use Carp qw{croak};
use Readonly;
use utf8;

use RoomInfo;
use PresenterSet;

Readonly our $CAFE       => q{Café};
Readonly our $COST_FREE  => q{$} . q{0};
Readonly our $COST_TBD   => q{$} . q{TBD};
Readonly our $COST_MODEL => q{model};

## no critic(ProhibitComplexRegexes)
Readonly our $RE_FREE => qr{
    \A (?:  free
    | (?=n) (?: nothing
              | n /? a )
    | [\$]? (?: 0+ (?: [.] 0+ )? | [.] 0+ )
    ) \z
    }xmsi;
Readonly our $RE_TBD         => qr{ \A [\$]? T [.]? B [.]? D[.]? \z }xmsi;
Readonly our $RE_MODEL       => qr{ model }xmsi;
Readonly our $RE_ID_WORKSHOP => qr{ \A . W \z}xmsi;
## use critic

q{free}        =~ $RE_FREE  or croak q{Assertion fail};
q{n/A}         =~ $RE_FREE  or croak q{Assertion fail};
q{nothing}     =~ $RE_FREE  or croak q{Assertion fail};
q{$} . q{0.00} =~ $RE_FREE  or croak q{Assertion fail};
q{$} . q{0.01} !~ $RE_FREE  or croak q{Assertion fail};
q{$} . q{0}    =~ $RE_FREE  or croak q{Assertion fail};
q{$} . q{00}   =~ $RE_FREE  or croak q{Assertion fail};
q{T.B.D.}      =~ $RE_TBD   or croak q{Assertion fail};
q{model}       =~ $RE_MODEL or croak q{Assertion fail};

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
    return             if $value eq q{};
    return $COST_FREE  if $value =~ $RE_FREE;
    return $COST_TBD   if $value =~ $RE_TBD;
    return $COST_MODEL if $value =~ $RE_MODEL;
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

my @id_suffix
    :Field
    :Std(Name => q{id_suffix_}, Restricted => 1 );

my @id_base
    :Field
    :Std(Name => q{id_base_}, Restricted => 1 );

my @id_part
    :Field
    :Std(Name => q{id_part_}, Restricted => 1 );

my @id_instance
    :Field
    :Std(Name => q{id_instance_}, Restricted => 1 );

my @anchor :Field
    :Type(scalar)
    :Std(Name => q{anchor_}, Restricted => 1 );

my @name
    :Field
    :Type(scalar)
    :Arg(Name => q{name}, Pre => \&PanelInfo::pre_init_text_)
    :Get(get_name);

my @rooms
    :Field
    :Type(list(RoomInfo))
    :Arg(Name => q{rooms}, Mand => 1)
    :Get(Name => q{get_rooms_}, Restricted => 1 );

my @desc
    :Field
    :Type(scalar)
    :Arg(Name => q{description}, Pre => \&PanelInfo::pre_init_text_)
    :Get(get_description);

my @note
    :Field
    :Type(scalar)
    :Arg(Name => q{note}, Pre => \&PanelInfo::pre_init_text_)
    :Get(get_note);

my @av_note
    :Field
    :Type(scalar)
    :Arg(Name => q{av_note}, Pre => \&PanelInfo::pre_init_text_)
    :Get(get_av_note);

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
    :Get(Name => q{_get_cost}, Private => 1 );

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

sub get_uniq_id_suffix {
    my ( $self ) = @_;
    my $suffix = $self->get_id_suffix_();
    return $suffix if defined $suffix;
    $suffix = $self->get_uniq_id();
    $suffix =~ s{\d+[[:alpha:]]?\K(?:Dup\d+)?\z}{}xms;
    if ( length $suffix < 2 ) {
        $self->set_id_suffix_( q{} );
        return q{};
    }
    $suffix =~ s{ \A [[:alpha:]]{3,} \d{2,}}{}xms
        or $suffix =~ s{ \A [[:alpha:]]{2,} \d{3,}}{}xms;
    $self->set_id_suffix_( $suffix );
    return $suffix;

} ## end sub get_uniq_id_suffix

sub get_uniq_id_base {
    my ( $self ) = @_;
    my $base = $self->get_id_base_();
    return $base if defined $base;
    $base = $self->get_uniq_id();
    $base =~ s{\d+[[:alpha:]]?\K(?:Dup\d+)?\z}{}xms;
    my $suffix = $self->get_uniq_id_suffix();
    $base =~ s{\Q$suffix\E\z}{}xms;
    $self->set_id_base_( $base );
    return $base;
} ## end sub get_uniq_id_base

sub get_uniq_id_part {
    my ( $self ) = @_;
    my $part = $self->get_id_part_();
    return $part if defined $part;
    my $id = $self->get_uniq_id_suffix();
    if ( $id =~ m{ P (\d+) [[:alpha:]]? \z }xms ) {
        $part = 0 + $1;
    }
    else {
        $part = 1;
    }
    $self->set_id_part_( $part );
    return $part;
} ## end sub get_uniq_id_part

sub get_uniq_id_instance {
    my ( $self ) = @_;
    my $instance = $self->get_id_instance_();
    return $instance if defined $instance;
    my $id = $self->get_uniq_id_suffix();
    if ( $id =~ m{ ([[:alpha:]]) P \d+ \z }xms ) {
        $instance = uc $1;
    }
    elsif ( $id =~ m{ \d ([[:alpha:]]) \z }xms ) {
        $instance = uc $1;
    }
    else {
        $instance = q{};
    }
    $self->set_id_instance_( $instance );
    return $instance;
} ## end sub get_uniq_id_instance

sub get_panel_internal_id {
    my ( $self ) = @_;
    return ${ $self };
}

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

sub get_rooms {
    my ( $self ) = @_;
    my $res = $self->get_rooms_();
    return unless defined $res;
    return @{ $res };
} ## end sub get_rooms

sub get_is_full {
    my ( $self ) = @_;
    return 1 if $self->get_is_full_();

    #TODO(pfister): Check capacity

    return;
} ## end sub get_is_full

sub get_cost {
    my ( $self ) = @_;
    my $cost = $self->_get_cost();
    if ( defined $cost ) {
        return if $cost eq $COST_FREE;
        return $cost;
    }

    return $COST_TBD if $self->get_uniq_id_prefix() =~ $RE_ID_WORKSHOP;

    return;
} ## end sub get_cost

sub get_cost_is_model {
    my ( $self ) = @_;
    return 1 if $self->_get_cost() eq $COST_MODEL;
    return;
}

sub get_cost_is_missing {
    my ( $self ) = @_;
    return   if defined $self->_get_cost();
    return 1 if $self->get_uniq_id_prefix() =~ $RE_ID_WORKSHOP;
    return;
} ## end sub get_cost_is_missing

1;
