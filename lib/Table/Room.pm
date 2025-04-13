package Table::Room;

use base qw{Exporter};

use v5.38.0;
use utf8;

use Canonical       qw{ :all };
use Data::Partition qw{};
use Data::Room      qw{};
use Field::Room     qw{};
use Workbook        qw{};

our @EXPORT_OK = qw {
    all_rooms
    visible_rooms
    lookup
    register
    read_from
};

our %EXPORT_TAGS = (
    all => [ @EXPORT_OK ],
);

my @rooms_;
my $is_sorted_;
my %by_key_;

sub needed_ ( @names ) {
    foreach my $name ( @names ) {
        next unless defined $name;
        next if $name eq q{};
        next if defined lookup( $name );
        return 1;
    } ## end foreach my $name ( @names )
    return;
} ## end sub needed_

sub read_room_ ( $header, $san_header, $raw ) {
    my %room_data;

    canonical_data(
        \%room_data,
        $header,
        $san_header,
        $raw,
        undef,
    );

    my $short_name = $room_data{ $Field::Room::NAME };
    my $long_name  = $room_data{ $Field::Room::LONG_NAME } // $short_name;
    $short_name //= $long_name;

    defined $short_name
        or return;

    my $hotel = $room_data{ $Field::Room::HOTEL };

    needed_( $long_name, $short_name, $hotel )
        or return;

    my $room = Data::Room->new(
        sort_key   => $room_data{ $Field::Room::SORT_KEY } // -1,
        short_name => $short_name,
        long_name  => $long_name,
        hotel_room => $hotel,
    );
    register( $room );

    return;
} ## end sub read_room_

sub all_rooms () {
    @rooms_     = sort { $a->compare( $b ) } @rooms_ unless $is_sorted_;
    $is_sorted_ = 1;
    return @rooms_;
}

sub visible_rooms () {
    return grep { !$_->get_room_is_hidden() } all_rooms();
}

sub lookup ( $name ) {
    defined $name
        or return;
    return if $name eq q{};
    $name = canonical_header( $name );
    $name = lc $name;
    my $room = $by_key_{ $name };
    return $room if defined $room;
    return;
} ## end sub lookup

sub register ( @rooms ) {
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
        $is_sorted_ = undef;
    } ## end foreach my $room ( @rooms )

    return;
} ## end sub register

sub read_from ( $wb ) {
    defined $wb
        or return;

    my $sheet = $wb->sheet( q{Rooms} );
    defined $sheet
        or return;
    $sheet->get_is_open()
        or return;

    my $header = $sheet->get_next_line();
    defined $header
        or return;
    my @san_header = canonical_headers( @{ $header } );

    while ( my $raw = $sheet->get_next_line() ) {
        last unless defined $raw;

        read_room_( $header, \@san_header, $raw );
    }

    $sheet->release() if defined $sheet;
    undef $sheet;

    return;
} ## end sub read_from

1;
