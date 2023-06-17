package Canonical;

use base qw{Exporter};

use v5.36.0;
use utf8;

our @EXPORT_OK = qw {
    canonical_header
    canonical_class
};

our %EXPORT_TAGS = (
    all => [ @EXPORT_OK ],
);

sub canonical_header {
    my ( $hdr ) = @_;
    $hdr =~ s{\s+}{_}xmsg;
    $hdr =~ s{[/:().,]}{_}xmsg;
    $hdr =~ s{_+}{_}xmsg;
    $hdr =~ s{\A_}{}xmsg;
    $hdr =~ s{_\z}{}xmsg;
    return $hdr;
} ## end sub canonical_header

sub canonical_class {
    my ( $class ) = @_;
    $class = canonical_header( $class );
    $class =~ s{_(\w)}{\u$1}xmsg;
    return $class;
} ## end sub canonical_class

1;
