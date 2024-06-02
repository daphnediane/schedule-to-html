package Canonical;

use base qw{Exporter};

use v5.36.0;
use utf8;

use Carp qw{ croak };

our @EXPORT_OK = qw {
    canonical_header
    canonical_headers
    canonical_class
    canonical_data
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

sub canonical_headers {
    my ( @hdrs ) = @_;
    return map { defined $_ ? canonical_header( $_ ) : undef } @hdrs;
}

sub canonical_class {
    my ( $class ) = @_;
    $class = canonical_header( $class );
    $class =~ s{_(\w)}{\u$1}xmsg;
    return $class;
} ## end sub canonical_class

# Takes in a hash reference to store the canonicalized data, an array reference containing the header text,
# an array reference containing the sanitized header text, an array reference containing the raw data,
# and an optional callback subroutine.
#
# Iterates over each column in the raw data array reference.
#
# Removes leading and trailing whitespace from the raw text, storing the data into the data record,
# storing an undef if the raw text is empty.
#
# Ignores empty headers, as long as the raw text is also empty.
#
# @param data The hash reference to store the canonicalized data
# @param header The array reference containing the header text
# @param san_header The array reference containing the sanitized header text
# @param raw The array reference containing the raw data
# @param callback The optional callback subroutine, invoked with the raw text, column number, header text, and header alt text
sub canonical_data {
    my ( $data, $header, $san_header, $raw, $callback ) = @_;

    foreach my $column ( keys @{ $raw } ) {
        my $header_text = $header->[ $column ];
        my $header_alt  = $san_header->[ $column ];

        my $raw_text = $raw->[ $column ];
        if ( defined $raw_text ) {
            $raw_text =~ s{\A \s++}{}xms;
            $raw_text =~ s{\s++ \z}{}xms;
            undef $raw_text if $raw_text eq q{};
        }

        if ( !defined $header_text ) {
            croak q{Data without header} if defined $raw_text;
            next;
        }

        $data->{ $header_text } = $raw_text;
        $data->{ $header_alt }  = $raw_text;

        if ( defined $callback ) {
            $callback->( $raw_text, $column, $header_text, $header_alt );
        }
    } ## end foreach my $column ( keys @...)

    return;
} ## end sub canonical_data

1;
