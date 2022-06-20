package PanelInfo;

use Object::InsideOut qw{TimeRange RoomHandle};

use strict;
use warnings;
use common::sense;

use Carp qw{croak};
use Readonly;
use utf8;

use RoomInfo;

Readonly our $CAFE => q{Café};

Readonly our $HOSTING   => 1;
Readonly our $ELSEWHERE => -1;

sub norm_text_ :Private {
    my ( @values ) = @_;
    @values = grep { defined } @values;
    return unless @values;
    my $value = join q{}, @values;
    $value =~ s{\A \s++ }{}xms;
    $value =~ s{\s++ \z}{}xms;
    return if $value eq q{};
    return $value;
} ## end sub norm_text_

sub pre_init_text_ :Private {
    my ( $class, $param, $spec, $obj, $value ) = @_;
    return norm_text_( $value );
}

sub pre_set_text_ :Private {
    my ( $class, $field, @args ) = @_;
    return norm_text_( @args );
}

sub norm_tokens_ :Private {
    my ( @values ) = @_;
    my $value = lc norm_text_( @values );
    return unless defined $value;
    return        if $value == 0;
    return $value if $value =~ m{ \A \d+ \z }xms;
    return        if $value eq q{na};
    return        if $value eq q{n/a};
    return        if $value eq q{free};
    return        if $value eq q{nothing};
    return q{TBD};
} ## end sub norm_tokens_

sub pre_init_tokens_ :Private {
    my ( $class, $param, $spec, $obj, $value ) = @_;
    return norm_tokens_( $value );
}

sub pre_set_tokens_ :Private {
    my ( $class, $field, @args ) = @_;
    return norm_tokens_( @args );
}

sub pre_is_full_ :Private {
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

my @panelist_listed
    :Field
    :Type(scalar)
    :Arg(Name => q{listed_panelist}, Pre => \&PanelInfo::pre_init_text_)
    :Set(Name => q{set_listed_panelist}, Pre => \&PanelInfo::pre_set_text_)
    :Get(get_listed_panelist);

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

my @tokens
    :Field
    :Type(scalar)
    :Arg(Name => q{cost}, Pre => \&PanelInfo::pre_init_tokens_)
    :Set(Name => q{set_cost}, Pre => \&PanelInfo::pre_set_tokens_)
    :Get(get_cost);

my @full
    :Field
    :Type(scalar)
    :Arg(Name => q{is_full}, Pre => \&PanelInfo::pre_is_full_);

my @css_subclasses
    :Field
    :Type(ARRAY_ref(scalar))
    :Std(css_subclasses);

my @panelist_state
    :Field
    :Default({})
    :Std(Name => q{panelist_state_}, Restricted => 1);

## use critic

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
    my $is_full = $full[ ${ $self } ];
    return 1 if $is_full;

    #TODO(pfister): Check capacity

    return;
} ## end sub get_is_full

sub is_panelist_elsewhere {
    my ( $self, $panelist ) = @_;
    return unless defined $panelist;
    croak q{Not presenter} unless $panelist->isa( q{Presenter} );
    my $map = $self->get_panelist_state_();
    my $pid = ${ $panelist };
    return unless exists $map->{ $pid };
    return 1 if $map->{ $pid }->[ 0 ] == $ELSEWHERE;
    return;
} ## end sub is_panelist_elsewhere

sub is_panelist_hosting {
    my ( $self, $panelist ) = @_;
    return unless defined $panelist;
    croak q{Not presenter} unless $panelist->isa( q{Presenter} );
    my $map = $self->get_panelist_state_();
    my $pid = ${ $panelist };
    return unless exists $map->{ $pid };
    return 1 if $map->{ $pid }->[ 0 ] == $HOSTING;
    return;
} ## end sub is_panelist_hosting

sub is_panelist_hosting_or_elsewhere {
    my ( $self, $panelist ) = @_;
    return unless defined $panelist;
    croak q{Not presenter} unless $panelist->isa( q{Presenter} );
    my $map = $self->get_panelist_state_();
    my $pid = ${ $panelist };
    return 1 if exists $map->{ $pid };
    return;
} ## end sub is_panelist_hosting_or_elsewhere

sub set_panelist_elsewhere {
    my ( $self, $panelist ) = @_;
    return unless defined $panelist;
    croak q{Not presenter} unless $panelist->isa( q{Presenter} );
    my $map = $self->get_panelist_state_();
    my $pid = ${ $panelist };
    $map->{ $pid } //= [ $ELSEWHERE => $panelist ];    # Hosting is priority
    return;
} ## end sub set_panelist_elsewhere

sub set_panelist_hosting {
    my ( $self, $panelist ) = @_;
    return unless defined $panelist;
    croak q{Not presenter} unless $panelist->isa( q{Presenter} );
    my $map = $self->get_panelist_state_();
    my $pid = ${ $panelist };
    $map->{ $pid } == [ $HOSTING => $panelist ];
    return;
} ## end sub set_panelist_hosting

sub get_panelists_hosting {
    my ( $self ) = @_;
    my $map = $self->get_panelist_state_();
    return map { $_->[ 1 ] } grep { $_->[ 0 ] == $HOSTING } values %{ $map };
}

1;
