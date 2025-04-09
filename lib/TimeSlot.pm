package TimeSlot;

use v5.38.0;
use utf8;

use Carp                   qw{ croak };
use Feature::Compat::Class qw{ :all };
use Scalar::Util           qw{ blessed };

use ActivePanel  qw{};
use Data::Panel  qw{};
use PresenterSet qw{};

class TimeSlot :isa(TimeRange);

# MARK: current panels field

field %current_panels;

method get_all_current () {
    return values %current_panels;
}

method lookup_current ( $room ) {
    my $id = blessed $room
        && $room->can( q{get_room_id} ) ? $room->get_room_id() : $room;
    my $panel = $current_panels{ $id };
    return $panel if defined $panel;
    return;
} ## end sub lookup_current

method init_current( %panels ) {
    %current_panels
        && croak q{Current already set};
    %current_panels = %panels;
    return $self;
} ## end sub init_current

# MARK: upcoming panels field

field %upcoming_panels;

method get_all_upcoming () {
    return values %upcoming_panels;
}

method lookup_upcoming ( $room ) {
    my $id = blessed $room
        && $room->can( q{get_room_id} ) ? $room->get_room_id() : $room;
    my $panel = $upcoming_panels{ $id };
    return $panel if defined $panel;
    return;
} ## end sub lookup_upcoming

method init_upcoming( %panels ) {
    %upcoming_panels
        && croak q{Upcoming already set};
    %upcoming_panels = %panels;
    return $self;
} ## end sub init_upcoming

# MARK: Queries

method is_presenter_hosting ( $presenter ) {
    return unless defined $presenter;

    foreach my $panel_state ( values %current_panels ) {
        next unless defined $panel_state;
        my $panel = $panel_state->get_active_panel();
        return 1 if $panel->is_presenter_hosting( $presenter );
    }
    return;
} ## end sub is_presenter_hosting

method is_presenter_credited ( $presenter ) {
    return unless defined $presenter;

    foreach my $panel_state ( values %current_panels ) {
        next unless defined $panel_state;
        my $panel = $panel_state->get_active_panel();
        return 1 if $panel->is_presenter_credited( $presenter );
    }
    return;
} ## end sub is_presenter_credited

method is_presenter_unlisted ( $presenter ) {
    return unless defined $presenter;

    foreach my $panel_state ( values %current_panels ) {
        next unless defined $panel_state;
        my $panel = $panel_state->get_active_panel();
        return 1 if $panel->is_presenter_unlisted( $presenter );
    }
    return;
} ## end sub is_presenter_unlisted

method clone_args() {
    croak q{Can not clone};
}

1;
