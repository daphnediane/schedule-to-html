package Table::PanelType;

use base qw{Exporter};

use strict;
use warnings;
use common::sense;

use Canonical        qw{ :all };
use Data::PanelType  qw{};
use Field::PanelType qw{};
use Workbook         qw{};

our @EXPORT_OK = qw {
    all_types
    lookup
    register
    read_from
    add_color_set
};

our %EXPORT_TAGS = (
    all => [ @EXPORT_OK ],
);

my @types_;
my %by_key_;
my %known_color_sets_ = ( color => 1 );

## no critic (TooMuchCode::ProhibitDuplicateLiteral)
Readonly::Hash our %IS_MAP_ => (
    $Field::PanelType::HIDDEN      => q{is_hidden},
    $Field::PanelType::IS_BREAK    => q{is_break},
    $Field::PanelType::IS_CAFE     => q{is_cafe},
    $Field::PanelType::IS_CAFE2    => q{is_cafe},
    $Field::PanelType::IS_WORKSHOP => q{is_workshop},
);
## use critic

sub read_panel_type_ {
    my ( $header, $san_header, $raw ) = @_;

    my %paneltype_data;
    my %colors;

    foreach my $column ( keys @{ $raw } ) {
        my $header_text = $header->[ $column ];
        my $header_alt  = $san_header->[ $column ];

        my $raw_text = $raw->[ $column ];
        if ( defined $raw_text ) {
            if ( $raw_text =~ m{\s}xms ) {
                $raw_text =~ s{\A \s*}{}xms;
                $raw_text =~ s{\s* \z}{}xms;
            }
            undef $raw_text if $raw_text eq q{};
        } ## end if ( defined $raw_text)
        $paneltype_data{ $header_text } = $raw_text;
        $paneltype_data{ $header_alt }  = $raw_text;

        if ( exists $known_color_sets_{ lc $header_alt }
            && defined $raw_text ) {
            $colors{ $header_alt } = $raw_text;
        }
    } ## end foreach my $column ( keys @...)

    my $prefix = $paneltype_data{ $Field::PanelType::PREFIX } // q{};
    my $kind   = $paneltype_data{ $Field::PanelType::KIND };

    my $panel_type = lookup( $prefix );
    if ( !defined $panel_type ) {
        my @fields;
        foreach my $field ( keys %IS_MAP_ ) {
            my $key = $IS_MAP_{ $field };
            next unless exists $paneltype_data{ $field };
            my $value = $paneltype_data{ $field } ? 1 : 0;
            push @fields, $key => $value;
        } ## end foreach my $field ( keys %IS_MAP_)

        $panel_type = Data::PanelType->new(
            prefix => $prefix,
            kind   => $kind // $prefix,
            @fields,
        );
        register( $panel_type );
    } ## end if ( !defined $panel_type)

    foreach my $color ( keys %colors ) {
        $panel_type->set_color( $colors{ $color }, $color );
    }

    return;
} ## end sub read_panel_type_

sub all_types {
    return @types_;
}

sub lookup {
    my ( $name ) = @_;
    return unless defined $name;

    $name = canonical_header( $name );
    $name = lc $name;
    my $panel_type = $by_key_{ $name };
    return $panel_type if defined $panel_type;
    return;
} ## end sub lookup

sub register {
    my ( @types ) = @_;

    foreach my $panel_type ( @types ) {
        foreach my $key (
            $panel_type->get_prefix(),
        ) {
            next unless defined $key;
            $key = canonical_header( $key );
            $key = lc $key;
            $by_key_{ $key } //= $panel_type;
        } ## end foreach my $key ( $panel_type...)

        push @types_, $panel_type;
    } ## end foreach my $panel_type ( @types)

    return;
} ## end sub register

sub read_from {
    my ( $wb ) = @_;

    my $sheet = $wb->sheet( q{PanelTypes} );
    return unless defined $sheet;
    return unless $sheet->get_is_open();

    my $header = $sheet->get_next_line();
    return unless defined $header;
    my @san_header = map { canonical_header( $_ ) } @{ $header };

    while ( my $raw = $sheet->get_next_line() ) {
        last unless defined $raw;

        read_panel_type_( $header, \@san_header, $raw );
    }

    $sheet->release() if defined $sheet;
    undef $sheet;

    return;
} ## end sub read_from

sub add_color_set {
    my ( @color_sets ) = @_;

    foreach my $color_set ( @color_sets ) {
        next unless defined $color_set;
        next if $color_set eq q{};
        $color_set = canonical_header( $color_set );
        $color_set = lc $color_set;

        $known_color_sets_{ $color_set } = 1;
    } ## end foreach my $color_set ( @color_sets)

    return;
} ## end sub add_color_set
1;
