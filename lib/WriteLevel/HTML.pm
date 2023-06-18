package WriteLevel::HTML;

use Object::InsideOut;

use v5.36.0;
use utf8;

use HTML::Tiny qw{};

use WriteLevel      qw{};
use WriteLevel::CSS qw{};
use Sub::Name       qw{ subname };

## no critic (ProhibitUnusedVariables)

my @wl_
    :Field
    :Type(WriteLevel)
    :Handles(WriteLevel::)
    :Default(WriteLevel->new())
    :Get(Name => q{wl_}, Restricted => 1);

my @html_
    :Field
    :Type(HTML::Tiny)
    :Default(HTML::Tiny->new( mode => q{html} ))
    :Arg(name => q{formatter})
    :Get(Name => q{get_formatter});

## use critic

sub add_line {
    my ( $self, @args ) = @_;
    $self->wl_()->add_line( @args );
    return;
}

sub add_meta {
    my ( $self, @args ) = @_;
    my $h = $self->get_formatter();
    $self->wl_()->add_line( $h->meta( @args ) );
    return;
} ## end sub add_meta

sub add_tag {
    my ( $self, @args ) = @_;
    my $h = $self->get_formatter();
    $self->wl_()->add_line( $h->tag( @args ) );
    return;
} ## end sub add_tag

sub nested_inline {
    my ( $self ) = @_;
    my $h        = $self->get_formatter();
    my $wl       = $self->wl_();
    my $child    = $self->new( formatter => $h );
    $wl->embed( $child->wl_() );
    return $child;
} ## end sub nested_inline

sub nested_tag {
    my ( $self, $tag, @rest ) = @_;
    my $h     = $self->get_formatter();
    my $wl    = $self->wl_();
    my $child = $self->new( formatter => $h );
    $wl->open_level( $h->open( $tag, @rest ) );
    $wl->embed( $child->wl_() );
    $wl->close_level( $h->close( $tag ) );
    return $child;
} ## end sub nested_tag

sub nested_style {
    my ( $self, @rest ) = @_;
    my $h     = $self->get_formatter();
    my $wl    = $self->wl_();
    my $child = WriteLevel::CSS->new();
    my $tag   = q{style};
    $wl->open_level( $h->open( $tag, @rest ) );
    $wl->embed( $child );
    $wl->close_level( $h->close( $tag ) );
    return $child;
} ## end sub nested_style

sub reg_handler_ {
    my ( $name, $handler ) = @_;

    my $full_name = __PACKAGE__ . q{::} . $name;
    $handler = subname $full_name, $handler;
    {
        no strict q{refs}; ## no critic(TestingAndDebugging::ProhibitNoStrict)
        *{ $full_name } = $handler;
    }
    return $handler;
} ## end sub reg_handler_

sub automethod_ :Automethod {
    my ( $self, @given_args ) = @_;
    my $method = $_;

    my $h_ = $self->get_formatter();

    if ( $method =~ m{\Aadd_(.*)}xms ) {
        my $tag = $1;
        if ( eval { $h_->can( $tag ) } ) {
            my $handler = sub {
                my ( $self, @args ) = @_;
                my $h = $self->get_formatter();
                $self->wl_()->add_line( $h->auto_tag( $tag, @args ) );
                return;
            };

            return reg_handler_( $method, $handler );
        } ## end if
        return;
    } ## end if ( $method =~ m{\Aadd_(.*)}xms)

    if ( $method =~ m{\Anested_(.*)}xms ) {
        my $tag = $1;
        if ( eval { $h_->can( $tag ) } ) {
            my $handler = sub {
                my ( $self, @rest ) = @_;
                my $h     = $self->get_formatter();
                my $wl    = $self->wl_();
                my $child = $self->new( formatter => $h );
                $wl->open_level( $h->open( $tag, @rest ) );
                $wl->embed( $child->wl_() );
                $wl->close_level( $h->close( $tag ) );
                return $child;
            };

            return reg_handler_( $method, $handler );
        } ## end if
        return;
    } ## end if ( $method =~ m{\Anested_(.*)}xms)

    return;
} ## end sub automethod_

1;
