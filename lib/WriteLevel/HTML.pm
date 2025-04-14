use v5.38.0;    ## no critic (Modules::ProhibitExcessMainComplexity)
use utf8;
use Feature::Compat::Class;

class WriteLevel::HTML {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage)

    use Carp       qw{ croak};
    use HTML::Tiny qw{};
    use Readonly;
    use Scalar::Util qw{ reftype };
    use Sub::Name    qw{ subname };

    use WriteLevel      qw{};
    use WriteLevel::CSS qw{};

    Readonly::Hash my %KNOWN_ELEMENTS => map { $_ => 1 } ( qw{
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

    # MARK: WriteLevel field

    field $wl //= WriteLevel->new();

    method get_write_level () {
        return $wl;
    }

    # MARK: parent_tag field

    field $parent_tag :param(tag);

    method get_tag () {
        return $parent_tag;
    }

    # MARK: formatter field

    field $formatter :param(formatter) //= HTML::Tiny->new( mode => q{html} );

    method get_formatter () {
        return $formatter;
    }

    # MARK: Explicit methods

    method add_line ( @args ) {
        $wl->add_line( @args );
        return $self;
    }

    method add_tag ( @args ) {
        $wl->add_line( $formatter->tag( @args ) );
        return $self;
    }

    method nested_inline () {
        my $child = $self->new(
            formatter => $formatter,
            tag       => $parent_tag,
        );
        $wl->embed( $child->get_write_level() );
        return $child;
    } ## end sub nested_inline

    method _create_child ( $tag ) {
        return WriteLevel::CSS->new() if $tag eq q{style};
        return $self->new(
            formatter => $formatter,
            tag       => join q{.}, $parent_tag, $tag
        );
    } ## end sub _create_child

    method nested_tag ( $tag, @rest ) {
        my $child = $self->_create_child( $tag );
        $wl->nested(
            [ $formatter->open( $tag, @rest ) ],
            $child->get_write_level(),
            [ $formatter->close( $tag ) ],
        );
        return $child;
    } ## end sub nested_tag

    # MARK: Chaining

    method DESTROY () {    ## no critic (CodeLayout::ProhibitParensWithBuiltins)
        return $self->SUPER::DESTROY() if $self->can( q{SUPER::DESTROY} );
    }

    sub _create_add_impl ( $tag ) {
        my $method_name = join q{_},  qw{ add }, $tag;
        my $full_name   = join q{::}, __PACKAGE__, $method_name;
        my $method      = subname $full_name, sub ( $self, @args ) {
            $self->get_write_level()
                ->add_line( $self->get_formatter()->auto_tag( $tag, @args ) );
            return $self;
        };

        {
            no strict qw{ refs };    ## no critic (TestingAndDebugging::ProhibitNoStrict)
            *{ $full_name } = $method;
        }

        return $method;
    } ## end sub _create_add_impl

    sub _create_add_method ( $tag ) {
        state %func_cache;
        return unless $KNOWN_ELEMENTS{ $tag };
        return $func_cache{ $tag } //= _create_add_impl( $tag );
    }

    sub _create_nested_impl ( $tag ) {
        my $method_name = join q{_},  qw{ nested }, $tag;
        my $full_name   = join q{::}, __PACKAGE__, $method_name;
        my $method      = subname $full_name, sub ( $self, @args ) {
            croak qq{nested_${tag} too many arguments\n}
                if 1 < scalar @args;
            croak qq{nested_${tag} first arg must be a hash\n}
                if 1 == scalar @args && q{HASH} ne reftype( $args[ 0 ] );

            return $self->nested_tag( $tag, @args );
        }; ## end sub

        {
            no strict qw{ refs };    ## no critic (TestingAndDebugging::ProhibitNoStrict
            *{ $full_name } = $method;
        }

        return $method;
    } ## end sub _create_nested_impl

    sub _create_nested_method ( $tag ) {
        state %func_cache;
        return unless $KNOWN_ELEMENTS{ $tag };
        return $func_cache{ $tag } //= _create_nested_impl( $tag );
    }

    our $AUTOLOAD;

    method AUTOLOAD ( @args ) {    ## no critic (CodeLayout::ProhibitParensWithBuiltins)
        ( my $called = $AUTOLOAD ) =~ s{.*::}{}xms;

        my $try_func;

        if ( defined( $try_func = $wl->can( $called ) ) ) {
            return $wl->$try_func( @args );
        }

        if ($called =~ m{\A add_ (?<elem> .*+ ) \z}xms    ## no critic (RegularExpressions::ProhibitUnusedCapture)
            && defined( $try_func = _create_add_method( $+{ elem } ) )
        ) {
            return $self->$try_func( @args );
        }

        if ($called =~ m{\A nested_ (?<elem> .*+ ) \z}xms    ## no critic (RegularExpressions::ProhibitUnusedCapture)
            && defined( $try_func = _create_nested_method( $+{ elem } ) )
        ) {
            return $self->$try_func( @args );
        }

        croak q{Can't locate object method "}, $called, q{" via package "},
            __CLASS__, q{"};
    } ## end sub AUTOLOAD

    sub can ( $class, $method ) {    ## no critic (BuiltinFunctions::ProhibitUniversalCan,CodeLayout::ProhibitParensWithBuiltins)
        $class = ref $class || $class;
        my $res = $class->SUPER::can( $method );
        return $res if defined $res;

        if ( defined( $res = WriteLevel->can( $method ) ) ) {
            return sub ( $self, @method_args ) {
                return $self->get_presenter_set()->$res( @method_args );
                }
                if defined $res;
        } ## end if ( defined( $res = WriteLevel...))

        my $try_func;
        if ($method =~ m{\A add_ (?<elem> .*+ ) \z}xms    ## no critic (RegularExpressions::ProhibitUnusedCapture)
            && defined( $try_func = _create_add_method( $+{ elem } ) )
        ) {
            return $try_func;
        }

        if ($method =~ m{\A nested_ (?<elem> .*+ ) \z}xms    ## no critic (RegularExpressions::ProhibitUnusedCapture)
            && defined( $try_func = _create_nested_method( $+{ elem } ) )
        ) {
            return $try_func;
        }

        return;
    } ## end sub can

} ## end package WriteLevel::HTML

1;
