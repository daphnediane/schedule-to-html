package Table::TimeRegion::State;

use Object::InsideOut;

use v5.36.0;
use utf8;

use ActivePanel qw{};
use TimeRegion  qw{};
use Data::Room  qw{};

## no critic (ProhibitUnusedVariables)

my @active_regions_
    :Field
    :Type(TimeRegion)
    :Set(Name => q{set_active_region})
    :Get(Name => q{get_active_region});

my @active_by_room_
    :Field
    :Default({})
    :Get(Name => q{active_by_room_}, Restricted => 1);

my @active_break_
    :Field
    :Set(Name => q{set_active_break_}, Restricted => 1)
    :Get(Name => q{get_active_break_}, Restricted => 1);

my @last_time_used_
    :Field
    :Set(Name => q{set_last_time})
    :Get(Name => q{get_last_time});

my @empty_times_
    :Field
    :Default({})
    :Set(Name => q{set_empty_times_}, Restricted => 1)
    :Get(Name => q{get_empty_times_}, Restricted => 1);

## use critic

sub get_all_active {
    my ( $self, $room ) = @_;
    return values %{ $self->active_by_room_() };
}

sub is_room_active_clear_if_expired {
    my ( $self, $room, $time ) = @_;
    return unless defined $room;
    $room = $room->get_room_id() if ref $room;
    my $hash   = $self->active_by_room_();
    my $active = $hash->{ $room };
    return unless defined $active;
    return $active if $active && $active->get_end_seconds() > $time;
    delete $hash->{ $room };
    return;
} ## end sub is_room_active_clear_if_expired

sub add_active_panel {
    my ( $self, $active ) = @_;
    return unless $active;
    my $room = $active->get_room()->get_room_id();
    $self->active_by_room_()->{ $room } = $active;
    return;
} ## end sub add_active_panel

sub split_active_panels {
    my ( $self, $time ) = @_;
    my $ref      = $self->active_by_room_();
    my @room_ids = keys %{ $ref };
    foreach my $room_id ( @room_ids ) {
        my $active = $ref->{ $room_id };
        if ( !defined $active || $active->get_end_seconds() <= $time ) {
            delete $ref->{ $room_id };
            next;
        }
        my $new_state = $active->clone();
        $new_state->set_rows( 0 );
        $new_state->set_start_time( $time );
        $ref->{ $room_id } = $new_state;
    } ## end foreach my $room_id ( @room_ids)

    return;
} ## end sub split_active_panels

sub get_active_break_clear_if_expired {
    my ( $self, $time ) = @_;
    my $break = $self->get_active_break_();
    return unless defined $break;
    if ( $break->get_end_seconds() <= $time ) {
        $self->set_active_break_( undef );
        return;
    }
    return $break;
} ## end sub get_active_break_clear_if_expired

sub add_break {
    my ( $self, $panel ) = @_;
    return unless defined $panel;
    my $break = $self->get_active_break_();
    return
        if defined $break
        && $break->get_end_seconds() >= $panel->get_end_seconds();
    $self->set_active_break_( $panel );
    return;
} ## end sub add_break

sub has_any_active {
    my ( $self ) = @_;
    return 1 if %{ $self->active_by_room_() };
    return;
}

sub clear_last_time {
    my ( $self ) = @_;
    $self->set_last_time( undef );
    return;
}

sub has_last_time {
    my ( $self ) = @_;
    return 1 if $self->get_last_time();
    return;
}

sub clear_empty_times {
    my ( $self ) = @_;
    $self->set_empty_times_( {} );
    return;
}

sub add_empty_times {
    my ( $self, @times ) = @_;
    foreach my $time ( @times ) {
        $self->get_empty_times_()->{ $time } = 1;
    }
    return;
} ## end sub add_empty_times

sub get_and_clear_empty_times {
    my ( $self ) = @_;
    my @times = keys %{ $self->get_empty_times_() };
    $self->set_empty_times_( {} );
    return @times;
} ## end sub get_and_clear_empty_times

1;
