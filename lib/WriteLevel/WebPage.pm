package WriteLevel::WebPage;

use Object::InsideOut;

use v5.40.0;
use utf8;

use Carp       qw{ croak };
use HTML::Tiny qw{};
use List::Util qw{ any };

use WriteLevel       qw{};
use WriteLevel::CSS  qw{};
use WriteLevel::HTML qw{};

## no critic (ProhibitUnusedVariables)

my @html_
    :Field
    :Type(HTML::Tiny)
    :Default(HTML::Tiny->new( mode => q{html} ))
    :Arg(name => q{formatter})
    :Get(Name => q{get_formatter});

my @whole_page_
    :Field
    :Set(Name => q{set_before_}, Restricted => 1)
    :Get(Name => q{get_before_});

my @head_
    :Field
    :Set(Name => q{set_head_}, Restricted => 1)
    :Get(Name => q{get_head_});

my @style_
    :Field
    :Set(Name => q{set_style_field_}, Restricted => 1)
    :Get(Name => q{get_style_field_}, Restircted => 1);

my @style_is_css_
    :Field
    :Set(Name => q{set_style_is_css_}, Restricted => 1)
    :Get(Name => q{get_style_is_css_}, Restircted => 1);

my @style_base_
    :Field
    :Set(Name => q{set_style_base_}, Restricted => 1)
    :Get(Name => q{get_style_base_}, Restircted => 1);

my @active_media_
    :Field
    :Set(Name => q{set_active_media_}, Restricted => 1)
    :Get(Name => q{get_active_media_}, Restircted => 1);

my @active_style_
    :Field
    :Set(Name => q{set_active_style_}, Restricted => 1)
    :Get(Name => q{get_active_style_}, Restircted => 1);

my @body_
    :Field
    :Set(Name => q{set_body_}, Restricted => 1)
    :Get(Name => q{get_body_}, Restircted => 1);

## use critic

sub get_before_html {
    my ( $self ) = @_;
    my $writer = $self->get_before_();
    return $writer if defined $writer;
    my $h = $self->get_formatter();
    $writer = WriteLevel::HTML->new(
        formatter => $h,
        tag       => q{},
    );
    $self->set_before_( $writer );
    return $writer;
} ## end sub get_before_html

sub get_head {
    my ( $self ) = @_;
    my $writer = $self->get_head_();
    return $writer if defined $writer;
    my $h = $self->get_formatter();
    $writer = WriteLevel::HTML->new(
        formatter => $h,
        tag       => qw{ html.head },
    );
    $self->set_head_( $writer );
    return $writer;
} ## end sub get_head

sub get_head_style_ {
    my ( $self ) = @_;
    my $writer = $self->get_style_field_();
    return $writer if defined $writer;
    my $h = $self->get_formatter();
    $writer = WriteLevel::HTML->new(
        formatter => $h,
        tag       => qw{ html.head },
    );
    $self->set_style_field_( $writer );
    return $writer;
} ## end sub get_head_style_

sub get_html_style {
    my ( $self ) = @_;
    my $active = $self->get_active_style_();
    if ( defined $active && !$self->get_style_is_css_() ) {
        return $active;
    }

    $active = $self->get_head_style_()->nested_inline();
    $self->set_style_is_css_( 0 );
    $self->set_style_base_( $active );
    $self->set_active_style_( $active );
    return $active;
} ## end sub get_html_style

sub get_css_style {
    my ( $self, $media ) = @_;
    $media //= q{};

    my $base        = $self->get_style_base_();
    my $media_style = $self->get_active_style_();

    if ( !defined $base || !$self->get_style_is_css_() ) {
        $base = $self->get_head_style_()->nested_style();
        $self->set_style_is_css_( 1 );
        $self->set_active_media_( q{} );
        $self->set_style_base_( $base );
        $self->set_active_style_( $base );
        $media_style = $base;
    } ## end if ( !defined $base ||...)

    if ( $media ne $self->get_active_media_() ) {
        $media_style
            = $media eq q{}
            ? $base
            : $base->nested_selector( q{@}, q{media }, $media );
        $self->set_active_media_( $media );
        $self->set_active_style_( $media_style );
    } ## end if ( $media ne $self->...)

    return $media_style;
} ## end sub get_css_style

sub get_body {
    my ( $self ) = @_;
    my $writer = $self->get_body_();
    return $writer if defined $writer;
    my $h = $self->get_formatter();
    $writer = WriteLevel::HTML->new(
        formatter => $h,
        tag       => qw{ html.body },
    );
    $self->set_body_( $writer );
    return $writer;
} ## end sub get_body

sub write_to {
    my ( $self, $fh, $level ) = @_;
    $fh    //= \*STDOUT;
    $level //= 0;

    my $before = $self->get_before_();
    my $head   = $self->get_head_();
    my $style  = $self->get_head_style_();
    my $body   = $self->get_body_();

    my $need_head_element = any { defined } $head, $style;
    my $need_html         = $need_head_element || defined $body;

    $before->write_to( $fh, $level ) if defined $before;

    return unless $need_html;

    my $h = $self->get_formatter();

    print { $fh } ( ( qq{\t} x $level ), $h->open( qw{ html } ), qq{\n} )
        or croak q{Unable to open html};
    ++$level;

    if ( $need_head_element ) {
        print { $fh } ( ( qq{\t} x $level ), $h->open( qw{ head } ), qq{\n} )
            or croak q{Unable to open html head};
        ++$level;

        $head->write_to( $fh, $level )  if defined $head;
        $style->write_to( $fh, $level ) if defined $style;

        --$level;
        print { $fh } ( ( qq{\t} x $level ), $h->close( qw{ head } ), qq{\n} )
            or croak q{Unable to close html head};

    } ## end if ( $need_head_element)

    if ( defined $body ) {
        print { $fh } ( ( qq{\t} x $level ), $h->open( qw{ body } ), qq{\n} )
            or croak q{Unable to open body};
        ++$level;

        $body->write_to( $fh, $level );

        --$level;
        print { $fh } ( ( qq{\t} x $level ), $h->close( qw{ body } ), qq{\n} )
            or croak q{Unable to close body};
    } ## end if ( defined $body )

    --$level;
    print { $fh } ( ( qq{\t} x $level ), $h->close( qw{ html } ), qq{\n} )
        or croak q{Unable to close html};

    return;
} ## end sub write_to
1;
