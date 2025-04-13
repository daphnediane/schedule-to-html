package ActivePanel;

use v5.38.0;
use utf8;

use Carp                   qw{ croak };
use Feature::Compat::Class qw{ :all };
use Scalar::Util           qw{ blessed };

use Data::Room qw{};

class ActivePanel :isa(TimeRange);

# MARK: active_panel field

field $panel :param(active_panel);
ADJUST {
    blessed $panel && $panel->isa( q{Data::Panel} )
        or croak qq{active_panel must be Data::Panel\n};
}

method get_active_panel () {
    return $panel;
}

# MARK: rows field

field $rows :param(rows) //= 0;
ADJUST {
    $rows =~ m{^(?:0|[1-9]\d*)\z}xms
        or croak qq{rows must be integer\n};
}

method get_rows () {
    return $rows;
}

method set_rows ( $new_rows ) {
    $rows = $new_rows;
    return $rows;
}

method increment_rows ( $amount //= 1 ) {
    $amount =~ m{^-?(?:0|[1-9]\d*)\z}xms
        or croak qq{amount must be integer\n};
    $rows += $amount;
    return $rows;
} ## end sub increment_rows

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
    blessed $room && $room->isa( q{Data::Room} )
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
        rows         => $rows,
        ( defined $is_break ? ( is_break => $is_break ) : () ),
        room => $room,
    );
} ## end sub clone_args

1;
