package Data::RoomId;

use v5.38.0;
use utf8;

use Carp         qw{ croak };
use Exporter     qw{ import };
use Scalar::Util qw{ blessed };

our @EXPORT_OK = qw{
    to_room_id
    to_room_id_checked
};
our %EXPORT_TAGS = [
    all => \@EXPORT_OK,
];
our $VERSION = 1.0;

sub to_room_id ( $room ) {
    return unless defined $room;

    if ( blessed $room ) {
        my $method = $room->can( q{get_room_id} );
        return $room->$method() if defined $method;
        return;
    }

    return if ref $room;

    require Data::Room;

    # Check if already valid number
    return $room
        if $room =~ m{ \A (?: 0 | [1-9]\d* ) \z }xms
        && defined Data::Room->find_by_room_id( $room );

    require Table::Room;

    # Check if valid room name
    my $by_name = Table::Room->lookup( $room );
    return $by_name->get_room_id() if defined $by_name;

    return;
} ## end sub to_room_id

sub to_room_id_checked ( $room ) {
    my $id = to_room_id( $room );
    return $id if defined $id;

    my $room_name = ref $room || $room;

    croak qq{Unable to convert $room_name into a room id};
} ## end sub to_room_id_checked

1;

