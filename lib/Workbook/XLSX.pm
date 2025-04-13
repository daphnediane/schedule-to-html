package Workbook::XLSX;

use Object::InsideOut qw{ Workbook };

use v5.38.0;
use utf8;

use Spreadsheet::ParseXLSX qw{};

## no critic (ProhibitUnusedVariables)

my @wb
    :Field
    :Set(Name => q{set_workbook_}, Restricted => 1)
    :Get(Name => q{get_workbook_}, Restricted => 1);

## use critic

my $parser = Spreadsheet::ParseXLSX->new;

sub release ( $self ) {
    $self->set_workbook_( undef );
    return;
}

sub find_sheet_handle ( $self, $sheet ) {
    $sheet //= 0;

    my $wb = $self->get_workbook_();
    defined $wb
        or return;

    my $handle = $wb->worksheet( $sheet );
    return $handle if defined $handle;

    my $lc_name = lc $sheet;
    foreach my $ws ( $wb->worksheets() ) {
        if ( lc $ws->get_name() eq $lc_name ) {
            return $ws;
        }
    }
    return;
} ## end sub find_sheet_handle

sub get_line_range ( $self, $sheet_handle ) {
    defined $sheet_handle
        or return;
    return $sheet_handle->row_range();
}

sub get_line ( $self, $sheet_handle, $line_no ) {
    defined $sheet_handle
        or return;

    my @columns = $sheet_handle->col_range();
    my ( $first_row, $last_row ) = $sheet_handle->row_range();

    return if $line_no < $first_row;
    return if $line_no > $last_row;

    my @res;
    foreach my $col ( $columns[ 0 ] .. $columns[ 1 ] ) {
        my $cell  = $sheet_handle->get_cell( $line_no, $col );
        my $value = defined $cell ? $cell->value() : undef;
        undef $value unless defined $value && $value =~ m{\S}xms;
        push @res, $value;
    } ## end foreach my $col ( $columns[...])
    return \@res;
} ## end sub get_line

sub init_ :Init {
    my ( $self ) = @_;
    my $fname = $self->get_filename();

    if ( !defined $self->get_default_sheet ) {
        if ( $fname =~ s{:(\d+)\z}{}xms ) {
            $self->set_default_sheet( $1 );
        }
    }

    my $wb = $parser->parse( $fname )
        or die qq{Unable to read: ${fname}\n};

    $self->set_workbook_( $wb );

    $self->set_is_open_( 1 );

    return;
} ## end sub init_

1;
