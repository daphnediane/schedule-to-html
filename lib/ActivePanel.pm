use v5.38.0;
use utf8;
use Feature::Compat::Class;

class ActivePanel :isa(TimeRange) {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage,CodeLayout::ProhibitParensWithBuiltins)

    package ActivePanel;

    use Carp qw{ croak };

    use Data::Room qw{};

    # MARK: active_panel field

    field $panel :param(active_panel);
    field $panel_uid;
    ADJUST {
        $panel isa Data::Panel
            or croak qq{active_panel must be Data::Panel\n};
    }

    method get_active_panel () {
        return $panel;
    }

    method get_internal_id () {
        return $panel_uid //= $panel->get_panel_internal_id();
    }

    # MARK: is_break field

    field $is_break :param(is_break) //= 0;
    ADJUST {
        ref $is_break
            && croak qq{is_break must be a scalar\n};
    }

    method get_is_break () {
        return 1 if $is_break;
        return;
    }

    # MARK: room field

    field $room :param(room);
    field $room_id;
    ADJUST {
        $room isa Data::Room
            or croak qq{active_panel must be Data::Room\n};
        $room_id = $room->get_room_id();
    }

    method get_room() {
        return $room;
    }

    method get_room_id() {
        return $room_id if defined $room_id;
        return;
    }

    # MARK: Clone

    method clone_args () {
        return (
            $self->SUPER::clone_args(),
            active_panel => $panel,
            ( defined $is_break ? ( is_break => $is_break ) : () ),
            room => $room,
        );
    } ## end sub clone_args

    1;
} ## end package ActivePanel

1;
