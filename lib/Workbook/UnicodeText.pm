package Workbook::UnicodeText;

use Object::InsideOut qw{ Workbook };

use v5.38.0;
use utf8;

use English     qw( -no_match_vars );
use File::Slurp qw{ read_file };

## no critic (ProhibitUnusedVariables)

my @cache
    :Field
    :Default([])
    :Set(Name => q{set_line_cache_}, Restricted => 1)
    :Get(Name => q{get_line_cache_}, Restricted => 1);

## use critic

sub release ( $self ) {
    $self->set_line_cache_( undef );
    return;
}

sub find_sheet_handle ( $self, $sheet ) {
    return 0 unless defined $sheet;
    return 0 if $sheet eq q{0};
    return 0 if $sheet eq q{Schedule};
    return;
} ## end sub find_sheet_handle

sub get_line_range ( $self, $sheet_handle ) {
    my $lines = $self->get_line_cache_();
    my $high  = scalar @{ $lines };
    --$high;
    return ( 0, $high );
} ## end sub get_line_range

sub get_line ( $self, $sheet_handle, $line_no ) {
    my $lines = $self->get_line_cache_();
    return if $line_no >= scalar @{ $lines };

    my $line      = $lines->[ $line_no ];
    my $full_line = $line;
    my @raw       = split m{\t}xms, $line;
    my @res;
    while ( @raw ) {
        my $piece = shift @raw;
        if ( $piece =~ m{ \A " }xms ) {
            my $full = $piece;
            while ( $full
                !~ m{ \A " (?: [^"]++ | (?: "" )++ )* " (?:\n\r?+|\r\n?+)?+ \z }xms
            ) {
                if ( !@raw ) {
                    chomp $full_line;
                    die
                        qq{Unable to process: [${full}]\nin line: ${full_line}\n};
                }
                $full .= shift @raw;
            } ## end while ( $full !~ ...)
            $full =~ s{ \A " }{}xms;
            $full =~ s{ (?:\n\r?+|\r\n?+)?+ \z }{}xms;
            $full =~ s{ " \z }{}xms;
            $full =~ s{ "" }{"}xmsg;
            push @res, $full;
        } ## end if ( $piece =~ m{ \A " }xms)
        else {
            push @res, $piece;
        }
    } ## end while ( @raw )
    return \@res;
} ## end sub get_line

sub init_ :Init {
    my ( $self ) = @_;
    my $fname = $self->get_filename();

    $self->set_line_cache_( read_file(
        $fname,
        { binmode => q{:raw:encoding(utf16):crlf}, array_ref => 1 }
    ) );

    $self->set_is_open_( 1 );

    return;
} ## end sub init_

1;

