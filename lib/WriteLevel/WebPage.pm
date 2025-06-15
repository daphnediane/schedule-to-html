use v5.38.0;    ## no critic (Modules::ProhibitExcessMainComplexity)
use utf8;
use Feature::Compat::Class;

class WriteLevel::WebPage {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage)
    use Carp       qw{ croak };
    use HTML::Tiny qw{};
    use List::Util qw{ any };

    use WriteLevel       qw{};
    use WriteLevel::CSS  qw{};
    use WriteLevel::HTML qw{};

    field $formatter :param(formatter) //=
        HTML::Tiny->new( mode => qw{ html } );

    method get_formatter () {
        return $formatter;
    }

    field $whole_page;

    method get_before_html () {
        return $whole_page //= WriteLevel::HTML->new(
            formatter => $formatter,
            tag       => q{},
        );
    } ## end sub get_before_html

    field $head;

    method get_head () {
        return $head //= WriteLevel::HTML->new(
            formatter => $formatter,
            tag       => qw{ html.head },
        );
    } ## end sub get_head

    field $style;

    method _get_head_style() {
        return $style //= WriteLevel::HTML->new(
            formatter => $formatter,
            tag       => qw{ html.head },
        );
    } ## end sub _get_head_style

    field $style_is_css;
    field $style_base;
    field $active_style;

    method get_html_style () {
        return $active_style if defined $active_style && !$style_is_css;

        $active_style = $self->_get_head_style()->nested_inline();
        $style_is_css = 0;
        $style_base   = $active_style;
        return $active_style;
    } ## end sub get_html_style

    field $active_media;

    method get_css_style ( $media //= q{} ) {
        if ( !defined $style_base || !$style_is_css ) {
            $style_base   = $self->_get_head_style()->nested_style();
            $style_is_css = 1;
            $active_media = q{};
            $active_style = $style_base;
        } ## end if ( !defined $style_base...)

        if ( $media ne $active_media ) {
            $active_style
                = $media eq q{}
                ? $style_base
                : $style_base->nested_selector( q{@}, q{media }, $media );
            $active_media = $media;
        } ## end if ( $media ne $active_media)

        return $active_style;
    } ## end sub get_css_style

    field $body;

    method get_body () {
        return $body //= WriteLevel::HTML->new(
            formatter => $formatter,
            tag       => qw{ html.body },
        );
    } ## end sub get_body

    method _write_head_to ( $fh, $level ) {
        print { $fh }
            ( ( qq{\t} x $level ), $formatter->open( qw{ head } ), qq{\n} )
            or croak q{Unable to open body};

        $head->write_to( $fh, 1 + $level )  if defined $head;
        $style->write_to( $fh, 1 + $level ) if defined $style;

        print { $fh }
            ( ( qq{\t} x $level ), $formatter->close( qw{ head } ), qq{\n} )
            or croak q{Unable to close body};
    } ## end sub _write_head_to

    method _write_body_to ( $fh, $level ) {
        print { $fh }
            ( ( qq{\t} x $level ), $formatter->open( qw{ body } ), qq{\n} )
            or croak q{Unable to open body};

        $body->write_to( $fh, 1 + $level );

        print { $fh }
            ( ( qq{\t} x $level ), $formatter->close( qw{ body } ), qq{\n} )
            or croak q{Unable to close body};
    } ## end sub _write_body_to

    method write_to ( $fh //= \*STDOUT, $level //= 0 ) {
        my $need_head_element = any { defined } $head, $style;
        my $need_html         = $need_head_element || defined $body;

        $whole_page->write_to( $fh, $level ) if defined $whole_page;

        $need_html
            or return;

        print { $fh }
            ( ( qq{\t} x $level ), $formatter->open( qw{ html } ), qq{\n} )
            or croak q{Unable to open html};

        if ( $need_head_element ) {
            $self->_write_head_to( $fh, 1 + $level );
        }

        if ( defined $body ) {
            $self->_write_body_to( $fh, 1 + $level );
        }

        print { $fh }
            ( ( qq{\t} x $level ), $formatter->close( qw{ html } ), qq{\n} )
            or croak q{Unable to close html};

    } ## end sub write_to
} ## end package WriteLevel::WebPage

1;
