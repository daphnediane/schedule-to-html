package Workbook;

use Object::InsideOut;

use v5.38.0;
use utf8;

## no critic (ProhibitUnusedVariables)

my @filename
    :Field Arg(Name => q{filename}, Mandatory => 1)
    :Get(Name => q{get_filename});

my @default_sheet
    :Field
    :Type(scalar)
    :Arg(Name => q{default_sheet})
    :Set(Name => q{set_default_sheet})
    :Get(Name => q{get_default_sheet});

my @is_open
    :Field
    :Type(scalar)
    :Set(Name => q{set_is_open_}, Restricted => 1)
    :Get(Name => q{get_is_open});

## use critic

sub class_for_args_ :MergeArgs {
    my ( $class, $args ) = @_;

    if ( $args->{ filename } =~ m{[.]xlsx(?: : \d+ )?\z}xms ) {
        return q{Workbook::XLSX};
    }
    return q{Workbook::UnicodeText};
} ## end sub class_for_args_

sub new ( $class, @args ) {
    $class = ref $class || $class;

    if ( $class eq q{Workbook} ) {
        $class = $class->class_for_args_( @args );
        my $class_file = $class;
        $class_file =~ s{::}{/}xmsg;
        $class_file .= q{.pm};
        require $class_file;
    } ## end if ( $class eq q{Workbook})
    return $class->Object::InsideOut::new( @args );
} ## end sub new

sub sheet ( $self, $sheet //= $self->get_default_sheet() ) {
    require Workbook::Sheet;
    return Workbook::Sheet->new( workbook => $self, sheet => $sheet );
}
1;
