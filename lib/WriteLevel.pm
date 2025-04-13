package WriteLevel;

use base qw{Exporter};

use v5.38.0;
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

sub add_line ( $self, @content ) {
    my $content = join q{}, @content;
    push @{ $self }, grep { m{\S}xms } split m{\s*\n+\s*}xms,
        $content;
    return $self;
} ## end sub add_line

sub embed ( $self, $embedded ) {
    defined $embedded
        or return;
    croak q{WriteLevel can only embed WriteLevel based classes}
        unless eval { $embedded->can( $WRITE_TO_METHOD ) };

    push @{ $self }, $embedded;
    return;
} ## end sub embed

sub nested ( $self, $level_open, $embedded, $level_close ) {
    croak q{WriteLevel can only nest WriteLevel based classes}
        unless eval { $embedded->can( $WRITE_TO_METHOD ) };

    $self->add_line( @{ $level_open } ) if @{ $level_open };
    push @{ $self }, [ $embedded ];
    $self->add_line( @{ $level_close } ) if @{ $level_close };

    return;
} ## end sub nested

sub write_to_ ( $self, $fh, $level, $ref ) {
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

sub write_to ( $self, $fh //= \*STDOUT, $level //= 0 ) {
    $self->write_to_( $fh, $level, $self );

    return;
}

sub new ( $class ) {
    $class = ref $class || $class;

    return bless [ [] ], $class;
}

1;
