package WriteLevel;

use base qw{Exporter};

use v5.36.0;
use utf8;

use Carp         qw{ croak cluck };
use Scalar::Util qw{ blessed };
use Readonly;

our @EXPORT_OK = qw {
};

our %EXPORT_TAGS = (
    all => [ @EXPORT_OK ],
);

Readonly our $ERROR_NO_LEVEL => q{No open levels};

sub add_line {
    my ( $self, @content ) = @_;

    croak $ERROR_NO_LEVEL unless @{ $self };

    my $content = join q{}, @content;
    push @{ $self->[ -1 ] }, grep { m{\S}xms } split m{\s*\n+\s*}xms,
        $content;
    return;
} ## end sub add_line

sub embed {
    my ( $self, $embedded ) = @_;
    return unless defined $embedded;
    croak q{WriteLevel can only embed other instances of WriteLevel}
        unless eval { $embedded->isa( __PACKAGE__ ) };

    croak $ERROR_NO_LEVEL unless @{ $self };

    push @{ $self->[ -1 ] }, $embedded;
    return;
} ## end sub embed

sub embed_level {
    my ( $self, $level, $embedded ) = @_;
    return unless defined $embedded;

    croak q{Unexpected level} unless $level eq $#{ $self };
    $self->embed( $embedded );
    return;
} ## end sub embed_level

sub open_level {
    my ( $self, @content ) = @_;

    $self->add_line( @content );
    push @{ $self }, [];
    return;
} ## end sub open_level

sub close_level {
    my ( $self, @content ) = @_;

    my $nested = pop @{ $self };
    croak q{Closed too many levels} unless @{ $self };

    push @{ $self->[ -1 ] }, $nested if defined $nested && @{ $nested };

    $self->add_line( @content );

    return;
} ## end sub close_level

sub write_to_ {
    my ( $self, $fh, $level, $ref ) = @_;

    cluck q{Expeced array ref}
        unless defined $ref && ref $ref && q{ARRAY} eq ref $ref;

    foreach my $val ( @{ $ref } ) {
        if ( blessed $val ) {
            $val->write_to( $fh, $level );
        }
        elsif ( ref $val ) {
            $self->write_to_( $fh, $level + 1, $val );
        }
        else {
            print { $fh } ( ( qq{\t} x $level ), $val, qq{\n} )
                or croak q{Error writing lines to file handle};
        }
    } ## end foreach my $val ( @{ $ref })

    return;
} ## end sub write_to_

sub write_to {
    my ( $self, $fh, $level ) = @_;
    $fh    //= \*STDOUT;
    $level //= 0;

    croak q{Unclosed level} if 0 < $#{ ${ self } };

    for my $idx ( 0 .. $#{ ${ self } } ) {
        $self->write_to_( $fh, $level + $idx, $self->[ $idx ] );
    }

    return;
} ## end sub write_to

sub is_balanced {
    my ( $self ) = @_;

    return 1 if 0 == $#{ ${ self } };
    return;
} ## end sub is_balanced

sub new {
    my ( $class ) = @_;
    $class = ref $class || $class;

    return bless [ [] ], $class;
} ## end sub new

1;
