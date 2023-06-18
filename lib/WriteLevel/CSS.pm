package WriteLevel::CSS;

use base qw{WriteLevel};

use v5.36.0;
use utf8;

use HTML::Tiny qw{};

our @EXPORT_OK = qw {
};

our %EXPORT_TAGS = (
    all => [ @EXPORT_OK ],
);

sub open_level {
    my ( $self, @content ) = @_;
    push @content, q{ } if @content;
    $self->WriteLevel::open_level( @content, qw[ { ] );
    return;
} ## end sub open_level

sub close_level {
    my ( $self ) = @_;
    $self->WriteLevel::close_level( qw[ } ] );
    return;
}

sub nested_selector {
    my ( $self, @content ) = @_;
    my $child = $self->new();
    push @content, q{ } if @content;
    $self->WriteLevel::open_level( @content, qw[ { ] );
    $self->WriteLevel::embed( $child );
    $self->WriteLevel::close_level( qw[ } ] );
    return $child;
} ## end sub nested_selector

1;
