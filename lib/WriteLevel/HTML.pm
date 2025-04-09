package WriteLevel::HTML;

use Object::InsideOut;

use v5.38.0;
use utf8;

use Carp       qw{ croak};
use HTML::Tiny qw{};
use Readonly;
use Scalar::Util qw{ reftype };
use Sub::Name    qw{ subname };

use WriteLevel      qw{};
use WriteLevel::CSS qw{};

## no critic (ProhibitUnusedVariables)

Readonly::Array my @KNOWN_ELEMENTS => ( qw{
    a abbr address area article aside audio
    b base bdi bdo blockquote body br button
    canvas caption cite code col colgroup
    data datalist dd del details dfn dialog div dl dt
    em embed
    fieldset figcaption figure footer form
    h1 h2 h3 h4 h5 h6 head header hgroup hr html
    i iframe img input ins
    kbd
    label legend li link
    main map mark menu meta meter
    nav noscript
    object ol optgroup option output
    p picture portal pre progress
    q
    rp rt ruby
    s samp script section select slot small source span strong style
    sub summary sup
    table tbody td template textarea tfoot th thead time title tr track
    u ul
    var video
    wbr
} );

Readonly::Array my @OBSOLETE_ELEMENTS => ( qw{
    acronym big center dir font frame frameset image marquee menuitem
    nobr noembed noframes param plaintext rb rtc strike tt xml
} );

my @wl_
    :Field
    :Type(WriteLevel)
    :Handles(WriteLevel::)
    :Default(WriteLevel->new())
    :Get(Name => q{wl_}, Restricted => 1);

my @parent_tag_
    :Field
    :Arg(Name => q{tag}, Mandatory => 1)
    :Get(Name => q{get_tag});

my @html_
    :Field
    :Type(HTML::Tiny)
    :Default(HTML::Tiny->new( mode => q{html} ))
    :Arg(name => q{formatter})
    :Get(Name => q{get_formatter});

## use critic

sub add_line ( $self, @args ) {
    $self->wl_()->add_line( @args );
    return $self;
}

sub add_tag ( $self, @args ) {
    my $h = $self->get_formatter();
    $self->wl_()->add_line( $h->tag( @args ) );
    return $self;
}

sub nested_inline ( $self ) {
    my $h     = $self->get_formatter();
    my $wl    = $self->wl_();
    my $child = $self->new(
        formatter => $h,
        tag       => $self->get_tag(),
    );
    $wl->embed( $child->wl_() );
    return $child;
} ## end sub nested_inline

sub nested_tag ( $self, $tag, @rest ) {
    my $h     = $self->get_formatter();
    my $wl    = $self->wl_();
    my $child = $self->new(
        formatter => $h,
        tag       => $self->get_tag() . q{.} . $tag,
    );
    $wl->nested(
        [ $h->open( $tag, @rest ) ],
        $child->wl_(),
        [ $h->close( $tag ) ],
    );
    return $child;
} ## end sub nested_tag

sub reg_handler_ ( $name, $handler ) {
    my $full_name = __PACKAGE__ . q{::} . $name;
    $handler = subname $full_name, $handler;
    {
        no strict q{refs};    ## no critic(TestingAndDebugging::ProhibitNoStrict)
        *{ $full_name } = $handler;
    }
    return $handler;
} ## end sub reg_handler_

sub get_child_ ( $self, $tag ) {
    return WriteLevel::CSS->new() if $tag eq q{style};
    return $self->new(
        formatter => $self->get_formatter(),
        tag       => $self->get_tag() . q{.} . $tag
    );
} ## end sub get_child_

## Generate methods
foreach my $tag ( @KNOWN_ELEMENTS ) {
    my $add_name      = join q{_},  qw{ add }, $tag;
    my $full_add_name = join q{::}, __PACKAGE__, $add_name;

    my $add_sub = sub ( $self, @args ) {
        $self->wl_()
            ->add_line( $self->get_formatter()->auto_tag( $tag, @args ) );
        return $self;
    }; ## end $add_sub = sub

    {
        ## no critic(TestingAndDebugging::ProhibitNoStrict)
        no strict qw{ refs };
        *{ $full_add_name } = subname $full_add_name, $add_sub;
        ## use critic
    }

    my $nested_name      = join q{_},  qw{ nested }, $tag;
    my $full_nested_name = join q{::}, __PACKAGE__, $nested_name;

    my $nested_sub = sub ( $self, @args ) {
        croak qq{nested_${tag} too many arguments\n}
            if 1 < scalar @args;
        croak qq{nested_${tag} first arg must be a hash\n}
            if 1 == scalar @args && q{HASH} ne reftype( $args[ 0 ] );

        my $h     = $self->get_formatter();
        my $wl    = $self->wl_();
        my $child = $self->get_child_( $tag );

        $wl->nested(
            [ $h->open( $tag, @args ) ],
            $child->wl_(),
            [ $h->close( $tag ) ],
        );
        return $child;
    }; ## end $nested_sub = sub

    {
        ## no critic(TestingAndDebugging::ProhibitNoStrict)
        no strict qw{ refs };
        *{ $full_nested_name } = subname $full_nested_name, $nested_sub;
        ## use critic
    }
} ## end foreach my $tag ( @KNOWN_ELEMENTS)

1;
