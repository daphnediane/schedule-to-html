use v5.38.0;
use utf8;
use Feature::Compat::Class;

class Table::FocusMap {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage)

    package Table::FocusMap;

    use List::Util qw{ any };

    use Data::RoomId qw{ to_room_id };

    # MARK: room_state

    field %room_state_;
    field $has_focus_;

    method set_focused ( @rooms ) {
        @rooms = map { to_room_id( $_ ) } @rooms;

        foreach my $id ( @rooms ) {
            $room_state_{ $id } = 1;
        }

        $has_focus_ = 1;
        return $self;
    } ## end sub set_focused

    method set_unfocused ( @rooms ) {
        @rooms = map { to_room_id( $_ ) } @rooms;

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
        $has_focus_
            or return;

        @rooms = map { to_room_id( $_ ) } @rooms;
        return 1 if any { $room_state_{ $_ } } @rooms;

        return;
    } ## end sub is_focused

    method is_unfocused ( @rooms ) {
        $has_focus_
            or return;

        @rooms = map { to_room_id( $_ ) } @rooms;
        return if any { $room_state_{ $_ } } @rooms;

        return 1;
    } ## end sub is_unfocused
} ## end package Table::FocusMap
1;
