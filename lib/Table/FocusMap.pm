package Table::FocusMap;

use Object::InsideOut;

use v5.40.0;
use utf8;

use Carp       qw{ confess };
use List::Util qw{ any };

## no critic (ProhibitUnusedVariables)

my @room_state_
    :Field
    :Default({})
    :Get(Name => q{map_}, Restricted => 1);

my @has_focus_
    :Field
    :Set(Name => q{set_has_focus_}, Restricted => 1)
    :Get(Name => q{get_has_focus_}, Restricted => 1);

## use critic

sub to_id_ {
    my ( $room ) = @_;

    return $room->get_room_id() if ref $room;
    return $room                if $room =~ m{\A\d+\z}xms;
    confess qq{Not a room: $room \n};
} ## end sub to_id_

sub set_focused {
    my ( $self, @rooms ) = @_;

    my $map = $self->map_();
    @rooms = map { to_id_( $_ ) } @rooms;

    foreach my $id ( @rooms ) {
        $map->{ $id } = 1;
    }

    $self->set_has_focus_( 1 );
    return $self;
} ## end sub set_focused

sub set_unfocused {
    my ( $self, @rooms ) = @_;

    my $map = $self->map_();
    @rooms = map { to_id_( $_ ) } @rooms;

    foreach my $id ( @rooms ) {
        delete $map->{ $id };
    }

    return $self;
} ## end sub set_unfocused

sub unfocus_all {
    my ( $self ) = @_;

    my $map = $self->map_();
    %{ $map } = ();
    $self->set_has_focus_( 0 );

    return $self;
} ## end sub unfocus_all

sub is_focused {
    my ( $self, @rooms ) = @_;

    return unless $self->get_has_focus_();

    my $map = $self->map_();
    @rooms = map { to_id_( $_ ) } @rooms;
    return 1 if any { $map->{ $_ } } @rooms;

    return;
} ## end sub is_focused

sub is_unfocused {
    my ( $self, @rooms ) = @_;

    return unless $self->get_has_focus_();

    my $map = $self->map_();
    @rooms = map { to_id_( $_ ) } @rooms;
    return if any { $map->{ $_ } } @rooms;

    return 1;
} ## end sub is_unfocused

1;
