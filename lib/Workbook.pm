use v5.38.0;    ## no critic (Modules::ProhibitExcessMainComplexity)
use utf8;
use Feature::Compat::Class;

class Workbook {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage)
    use Carp qw{ croak };

    # MARK: filename field

    field $filename :param( filename );

    method get_filename () { return $filename; }

    # MARK: default_sheet field

    field $default_sheet :param( default_sheet ) //= undef;

    method get_default_sheet () { return $default_sheet; }

    method set_default_sheet ( $new_default_sheet ) {
        $default_sheet = $new_default_sheet;
        return $self;
    }

    sub create ( $class, %args ) {
        my $filename      = delete $args{ filename };
        my $default_sheet = delete $args{ default_sheet };

        defined $filename
            or croak q{Workbook->create() requires either a filename};

        if ( $filename =~ s{ : (?<sheet> [^:]+ ) \z }{}xms ) {
            $default_sheet //= $+{ sheet };
        }

        if ( $filename =~ m{[.]xlsx\z}xmsi ) {
            require Workbook::XLSX;
            my $res = Workbook::XLSX->new(
                %args,
                filename      => $filename,
                default_sheet => $default_sheet,
            );
            $res->init();
            return $res;
        } ## end if ( $filename =~ m{[.]xlsx\z}xmsi)

        require Workbook::UnicodeText;
        my $res = Workbook::UnicodeText->new(
            %args,
            filename      => $filename,
            default_sheet => $default_sheet,
        );
        $res->init();
        return $res;
    } ## end sub create

    method sheet ( $sheet //= undef ) {
        require Workbook::Sheet;
        return Workbook::Sheet->new(
            workbook => $self,
            sheet    => $sheet // $default_sheet,
        );
    } ## end sub sheet
} ## end package Workbook

1;
