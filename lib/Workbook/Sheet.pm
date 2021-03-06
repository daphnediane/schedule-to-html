package Workbook::Sheet;

use Object::InsideOut;

use strict;
use warnings;
use common::sense;

use English qw( -no_match_vars );
use File::Slurp qw{read_file};
use Readonly;
use utf8;

## no critic (ProhibitUnusedVariables)

my @workbook
    :Field
    :Arg(Name => q{workbook}, Mandatory => 1)
    :Get(get_workbook)
    :Set(Name => q{set_workbook_}, Restricted => 1);

my @sheet
    :Field
    :Type(scalar)
    :Default(0)
    :Arg(Name => q{sheet})
    :Get(get_sheet);

my @sheet_handle
    :Field
    :Set(Name => q{set_sheet_handle_}, Restricted => 1)
    :Get(get_sheet_handle_);

my @next_row
    :Field
    :Type(scalar)
    :Std(Name=>q{next_row_}, Restricted => 1);

my @last_row
    :Field
    :Type(scalar)
    :Std(Name=>q{last_row_}, Restricted => 1);

my @is_open
    :Field
    :Type(scalar)
    :Get(get_is_open)
    :Set(Name => q{set_is_open_}, Restricted => 1);

## use critic

sub release {
    my ( $self ) = @_;
    $self->set_workbook_( undef );
    $self->set_sheet_handle_( undef );
    return;
} ## end sub release

sub init_ :Init {
    my ( $self ) = @_;

    my $wb = $self->get_workbook();
    if ( !defined $wb ) {
        return;
    }
    my $sheet_handle = $wb->find_sheet_handle( $self->get_sheet() );
    if ( !defined $sheet_handle ) {
        $self->release();
        return;
    }
    $self->set_sheet_handle_( $sheet_handle );

    my ( $first_row, $last_row ) = $wb->get_line_range( $sheet_handle );
    if ( !defined $last_row ) {
        $self->release();
        return;
    }
    $self->set_next_row_( $first_row );
    $self->set_last_row_( $last_row );
    $self->set_is_open_( 1 );

    return;
} ## end sub init_

sub get_next_line {
    my ( $self ) = @_;
    my $wb = $self->get_workbook();
    return unless defined $wb;
    my $sheet_handle = $self->get_sheet_handle_();
    return unless defined $sheet_handle;

    my $row = $self->get_next_row_();
    return if $row > $self->get_last_row_();
    $self->set_next_row_( $row + 1 );
    return $wb->get_line( $sheet_handle, $row );
} ## end sub get_next_line

1;
