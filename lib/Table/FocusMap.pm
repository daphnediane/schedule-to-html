package Table::FocusMap;

use v5.38.0;
use utf8;

use Carp                   qw{ confess };
use Feature::Compat::Class qw{ :all };
use List::Util             qw{ any };

class Table::FocusMap;

sub _to_room_id ( $room ) {
    return $room->get_room_id() if ref $room;
    return $room                if $room =~ m{\A\d+\z}xms;
    confess qq{Not a room: $room \n};
}

# MARK: room_state

field %room_state_;
field $has_focus_;

method set_focused ( @rooms ) {
    @rooms = map { _to_room_id( $_ ) } @rooms;

    foreach my $id ( @rooms ) {
        $room_state_{ $id } = 1;
    }

    $has_focus_ = 1;
    return $self;
} ## end sub set_focused

method set_unfocused ( @rooms ) {
    @rooms = map { _to_room_id( $_ ) } @rooms;

    foreach my $id ( @rooms ) {
        delete $room_state_{ $id };
    }

    return $self;
} ## end sub set_unfocused

method unfocus_all ( ) {
    %room_state_ = ();
    $has_focus_  = 0;

    return $self;
} ## end sub unfocus_all ( )

method is_focused ( @rooms ) {
    return unless $has_focus_;

    @rooms = map { _to_room_id( $_ ) } @rooms;
    return 1 if any { $room_state_{ $_ } } @rooms;

    return;
} ## end sub is_focused

method is_unfocused ( @rooms ) {
    return unless $has_focus_;

    @rooms = map { _to_room_id( $_ ) } @rooms;
    return if any { $room_state_{ $_ } } @rooms;

    return 1;
} ## end sub is_unfocused

1;
