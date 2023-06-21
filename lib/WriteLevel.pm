package WriteLevel;

use base qw{Exporter};

use v5.36.0;
use utf8;

use Carp qw{ croak cluck };
use Readonly;
use Scalar::Util qw{ reftype };

our @EXPORT_OK = qw {
};

our %EXPORT_TAGS = (
    all => [ @EXPORT_OK ],
);

Readonly our $WRITE_TO_METHOD => q{write_to};

sub add_line {
    my ( $self, @content ) = @_;

    my $content = join q{}, @content;
    push @{ $self }, grep { m{\S}xms } split m{\s*\n+\s*}xms,
        $content;
    return $self;
} ## end sub add_line

sub embed {
    my ( $self, $embedded ) = @_;
    return unless defined $embedded;
    croak q{WriteLevel can only embed WriteLevel based classes}
        unless eval { $embedded->can( $WRITE_TO_METHOD ) };

    push @{ $self }, $embedded;
    return;
} ## end sub embed

sub nested {
    my ( $self, $level_open, $embedded, $level_close ) = @_;
    croak q{WriteLevel can only nest WriteLevel based classes}
        unless eval { $embedded->can( $WRITE_TO_METHOD ) };

    $self->add_line( @{ $level_open } ) if @{ $level_open };
    push @{ $self }, [ $embedded ];
    $self->add_line( @{ $level_close } ) if @{ $level_close };

    return;
} ## end sub nested

sub write_to_ {
    my ( $self, $fh, $level, $ref ) = @_;

    cluck q{Expeced array ref}
        unless defined $ref && reftype $ref && q{ARRAY} eq reftype $ref;

    foreach my $val ( @{ $ref } ) {
        if ( eval { $val->can( $WRITE_TO_METHOD ) } ) {
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

    $self->write_to_( $fh, $level, $self );

    return;
} ## end sub write_to

sub new {
    my ( $class ) = @_;
    $class = ref $class || $class;

    return bless [ [] ], $class;
} ## end sub new

1;
