use v5.38.0;
use utf8;
use Feature::Compat::Class;

class Data::PanelType {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage)

    package Data::PanelType;

    use Carp     qw{ croak };
    use Readonly qw{ Readonly };

    use Canonical qw{ :all };

    Readonly our $RE_BREAK       => qr{ \A br }xmsi;
    Readonly our $RE_CAFE        => qr{ \A caf[eé] \z }xmsi;
    Readonly our $RE_ID_WORKSHOP => qr{ \A . W \z}xmsi;

    Readonly our $DEF_COLOR_SET => q{Color};

## no critic(TooMuchCode::ProhibitDuplicateLiteral)
    q{Café}        =~ $RE_CAFE or croak q{Assertion fail};
    q{CAFE}        =~ $RE_CAFE or croak q{Assertion fail};
    q{CAFE} . q{T} !~ $RE_CAFE or croak q{Assertion fail};
## use critic

    # MARK: prefix field

    field $prefix :param(prefix);

    method get_prefix () {
        return $prefix if defined $prefix;
        return;
    }

    # MARK: kind field

    field $kind :param(kind);

    method get_kind () {
        return $kind if defined $kind;
        return;
    }

    # MARK: is_break field

    field $is_break :param(is_break) //= $kind =~ $RE_BREAK ? 1 : 0;

    method is_break () {
        return $is_break ? 1 : 0;
    }

    # MARK: is_cafe field

    field $is_cafe :param(is_cafe) //= $kind =~ $RE_CAFE ? 1 : 0;

    method is_cafe () {
        return $is_cafe ? 1 : 0;
    }

    # MARK: is_workshop field

    field $is_workshop :param(is_workshop) //=
        $prefix =~ $RE_ID_WORKSHOP ? 1 : 0;

    method is_workshop () {
        return $is_workshop ? 1 : 0;
    }

    # MARK: is_hidden field

    field $is_hidden :param(is_hidden) //= 0;
    field $is_override_hidden //= undef;

    method override_make_shown ( ) {
        $is_override_hidden = 0;
        return $self;
    }

    method override_make_hidden ( ) {
        $is_override_hidden = 1;
        return $self;
    }

    method clear_override_hidden ( ) {
        $is_override_hidden = undef;
        return $self;
    }

    method get_is_hidden () {
        return 1 if $is_override_hidden // $is_hidden;
        return;
    }

    # MARK: color_sets field

    field %color_sets;

    method set_color ( $value, $color_set //= $DEF_COLOR_SET ) {
        $color_set = $DEF_COLOR_SET if $color_set eq q{};
        $color_set = canonical_header( $color_set );
        $color_set = lc $color_set;

        if ( !defined $value || $value eq q{} ) {
            delete $color_sets{ $color_set };
            return;
        }

        $color_sets{ $color_set } = $value;
        return $value;
    } ## end sub set_color

    method get_color ( $color_set //= $DEF_COLOR_SET ) {
        $color_set = $DEF_COLOR_SET if $color_set eq q{};
        $color_set = canonical_header( $color_set );
        $color_set = lc $color_set;

        my $value = $color_sets{ $color_set };
        defined $value
            or return;
        return if $value eq q{};
        return $value;
    } ## end sub get_color

} ## end package Data::PanelType

1;
