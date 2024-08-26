package WriteLevel::CSS;

use base qw{WriteLevel};

use v5.40.0;
use utf8;

use HTML::Tiny qw{};

our @EXPORT_OK = qw {
};

our %EXPORT_TAGS = (
    all => [ @EXPORT_OK ],
);

sub nested_selector {
    my ( $self, @content ) = @_;
    my $child = $self->new();
    push @content, q{ } if @content;
    $self->WriteLevel::nested( [ @content, qw[ { ] ], $child, [ qw[ } ] ] );
    return $child;
} ## end sub nested_selector

sub wl_ {
    my ( $self ) = @_;
    return $self;
}

1;
