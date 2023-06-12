package Table::Room;

use base qw{Exporter};

use strict;
use warnings;
use common::sense;

use Canonical   qw{ :all };
use Data::Room  qw{};
use Field::Room qw{};
use Workbook    qw{};

our @EXPORT_OK = qw {
    all_rooms
    lookup
    register
    read_from
};

our %EXPORT_TAGS = (
    all => [ @EXPORT_OK ],
);

my @rooms_;
my %by_key_;

sub needed_ {
    my ( @names ) = @_;

    foreach my $name ( @names ) {
        next unless defined $name;
        next if $name eq q{};
        next if defined lookup( $name );
        return 1;
    } ## end foreach my $name ( @names )
    return;
} ## end sub needed_

sub read_room_ {
    my ( $header, $san_header, $raw ) = @_;

    my %room_data;

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
        $room_data{ $header_text } = $raw_text;
        $room_data{ $header_alt }  = $raw_text;
    } ## end foreach my $column ( keys @...)

    my $short_name = $room_data{ $Field::Room::NAME };
    my $long_name  = $room_data{ $Field::Room::LONG_NAME } // $short_name;
    $short_name //= $long_name;

    return unless defined $short_name;

    my $hotel = $room_data{ $Field::Room::HOTEL };

    return unless needed_( $long_name, $short_name, $hotel );

    my $room = Data::Room->new(
        sort_key   => $room_data{ $Field::Room::SORT_KEY },
        short_name => $short_name,
        long_name  => $long_name,
        hotel_room => $hotel,
    );
    register( $room );

    return;
} ## end sub read_room_

sub all_rooms {
    return @rooms_;
}

sub lookup {
    my ( $name ) = @_;
    return unless defined $name;
    return if $name eq q{};
    $name = canonical_header( $name );
    $name = lc $name;
    my $room = $by_key_{ $name };
    return $room if defined $room;
    return;
} ## end sub lookup

sub register {
    my ( @rooms ) = @_;

    foreach my $room ( @rooms ) {
        foreach my $key (
            $room->get_short_room_name(),
            $room->get_long_room_name(),
            $room->get_hotel_room()
        ) {
            next unless defined $key;
            $key = canonical_header( $key );
            $key = lc $key;
            $by_key_{ $key } //= $room;
        } ## end foreach my $key ( $room->get_short_room_name...)

        push @rooms_, $room;
    } ## end foreach my $room ( @rooms )

    return;
} ## end sub register

sub read_from {
    my ( $wb ) = @_;
    return unless defined $wb;

    my $sheet = $wb->sheet( q{Rooms} );
    return unless defined $sheet;
    return unless $sheet->get_is_open();

    my $header = $sheet->get_next_line();
    return unless defined $header;
    my @san_header = map { canonical_header( $_ ) } @{ $header };

    while ( my $raw = $sheet->get_next_line() ) {
        last unless defined $raw;

        read_room_( $header, \@san_header, $raw );
    }

    $sheet->release() if defined $sheet;
    undef $sheet;

    return;
} ## end sub read_from

1;
