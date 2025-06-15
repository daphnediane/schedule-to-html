use v5.38.0;    ## no critic (Modules::ProhibitExcessMainComplexity)
use utf8;
use Feature::Compat::Class;

class Workbook::XLSX :isa(Workbook) {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage)
    use Spreadsheet::ParseXLSX qw{};

    my $parser = Spreadsheet::ParseXLSX->new;

    field $wb;
    field $is_initialized;

    method init() {
        return if $is_initialized;
        $is_initialized = 1;
        my $fname = $self->Workbook::get_filename();
        $wb = $parser->parse( $fname )
            or die qq{Unable to read: ${fname}\n};
        return;
    } ## end sub init

    method release () {
        $wb             = undef;
        $is_initialized = 1;
        return;
    }

    method find_sheet_handle ( $sheet //= 0 ) {
        $self->init() unless defined $is_initialized;
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

    method get_line_range ( $sheet_handle ) {
        defined $sheet_handle
            or return;
        my @res = $sheet_handle->row_range();
        return @res;
    } ## end sub get_line_range

    method get_line ( $sheet_handle, $line_no ) {
        defined $sheet_handle
            or return;

        my @columns = $sheet_handle->col_range();
        my ( $first_row, $last_row ) = $sheet_handle->row_range();

        return if $line_no < $first_row;
        return if $line_no > $last_row;

        my @res;
        foreach my $col ( $columns[ 0 ] .. $columns[ 1 ] ) {
            my $cell  = $sheet_handle->get_cell( $line_no, $col );
            my $raw   = defined $cell ? $cell->{ Formula } : undef;
            my $value = defined $cell ? $cell->value()     : undef;
            if ( defined $raw
                && $raw
                =~ m{ \A HYPERLINK \( " (?<url>[^"]+) " (?:, " (?<title>[^"]+) " )? \) \s*\z }xms
            ) {
                $value = $+{ url };
            } ## end if ( defined $raw && $raw...)
            undef $value unless defined $value && $value =~ m{\S}xms;
            push @res, $value;
        } ## end foreach my $col ( $columns[...])
        return \@res;
    } ## end sub get_line

} ## end package Workbook::XLSX

1;
