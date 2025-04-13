use v5.38.0;
use utf8;
use Feature::Compat::Class;

class TimeSlot :isa(TimeRange) {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage,CodeLayout::ProhibitParensWithBuiltins)

    package TimeSlot;

    use Carp qw{ croak };

    use Data::RoomId qw{ to_room_id };

    # MARK: current panels field

    field %current_panels;

    method get_all_current () {
        return values %current_panels;
    }

    method lookup_current ( $room ) {
        my $id = to_room_id( $room );
        defined $id
            or return;

        my $panel = $current_panels{ $id };
        return $panel if defined $panel;
        return;
    } ## end sub lookup_current

    method init_current( %panels ) {
        ( !%current_panels )
            or croak q{Current already set};
        %current_panels = %panels;
        return $self;
    } ## end sub init_current

    # MARK: upcoming panels field

    field %upcoming_panels;

    method get_all_upcoming () {
        return values %upcoming_panels;
    }

    method lookup_upcoming ( $room ) {
        my $id = to_room_id( $room );
        defined $id
            or return;
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
        defined $presenter
            or return;

        foreach my $panel_state ( values %current_panels ) {
            next unless defined $panel_state;
            my $panel = $panel_state->get_active_panel();
            return 1 if $panel->is_presenter_hosting( $presenter );
        }
        return;
    } ## end sub is_presenter_hosting

    method is_presenter_credited ( $presenter ) {
        defined $presenter
            or return;

        foreach my $panel_state ( values %current_panels ) {
            next unless defined $panel_state;
            my $panel = $panel_state->get_active_panel();
            return 1 if $panel->is_presenter_credited( $presenter );
        }
        return;
    } ## end sub is_presenter_credited

    method is_presenter_unlisted ( $presenter ) {
        defined $presenter
            or return;

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
} ## end package TimeSlot

1;
