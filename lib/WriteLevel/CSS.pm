package WriteLevel::CSS;

use base qw{WriteLevel};

use v5.38.0;
use utf8;

use HTML::Tiny qw{};

our @EXPORT_OK = qw {
};

our %EXPORT_TAGS = (
    all => [ @EXPORT_OK ],
);

sub nested_selector ( $self, @content ) {
    my $child = $self->new();
    push @content, q{ } if @content;
    $self->WriteLevel::nested( [ @content, qw[ { ] ], $child, [ qw[ } ] ] );
    return $child;
} ## end sub nested_selector

sub wl_ ( $self ) {
    return $self;
}

1;
