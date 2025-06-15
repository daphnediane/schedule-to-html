use v5.38.0;    ## no critic (Modules::ProhibitExcessMainComplexity)
use utf8;
use Feature::Compat::Class;

class Workbook::Sheet {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage)
    use English qw( -no_match_vars );
    use Carp    qw{ croak };

    field $workbook :param(workbook);
    field $sheet :param(sheet) //= 0;
    field $sheet_handle;
    field $next_row;
    field $last_row;
    field $is_open;

    ADJUST {
        $sheet_handle = $workbook->find_sheet_handle( $sheet )
            if defined $workbook;
        ( $next_row, $last_row ) = $workbook->get_line_range( $sheet_handle )
            if defined $sheet_handle;
        undef $sheet_handle unless defined $last_row;
        undef $workbook     unless defined $sheet_handle;
        $is_open = 1 if defined $sheet_handle;
    } ## end ADJUST

    method get_workbook () {
        return $workbook;
    }

    method get_sheet () {
        return $sheet;
    }

    method release () {
        $workbook     = undef;
        $sheet_handle = undef;
        $is_open      = 0;
        return $self;
    } ## end sub release

    method get_next_line () {
        defined $workbook
            or return;
        defined $sheet_handle
            or return;

        return if $next_row > $last_row;
        my $row = $next_row;
        ++$next_row;
        return $workbook->get_line( $sheet_handle, $row );
    } ## end sub get_next_line

    method get_is_open() {
        return 1 if $is_open;
        return;
    }
} ## end package Workbook::Sheet

1;
