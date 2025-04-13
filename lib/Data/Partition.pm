package Data::Partition;

use v5.38.0;
use utf8;

use Carp                   qw{ croak };
use Feature::Compat::Class qw{ :all };
use Scalar::Util           qw{ blessed };

class Data::Partition;

field $region :param(region) :reader(get_selected_region) //= undef;
ADJUST {
    blessed $region && $region->isa( q{Data::RegionForTable} )
        or !defined $region
        or croak q{region must be a Data::RegionForTable};
}

field $presenter :param(presenter) :reader(get_selected_presenter) //= undef;
ADJUST {
    blessed $presenter && $presenter->isa( q{Presenter} )
        or !defined $presenter
        or croak q{presenter must be a Presenter};
}

field $room :param(room) :reader(get_selected_room) //= undef;
ADJUST {
    blessed $room && $room->isa( q{Data::Room} )
        or !defined $room
        or croak q{room must be a Data::Room};
}

field @output_name;

method _init_output_name ( @pieces ) {
    0 == scalar @output_name
        or croak q{output_name can only be set once};
    @output_name = @pieces;
    return $self;
} ## end sub _init_output_name

method get_output_name_pieces() {
    return @output_name;
}

sub unfiltered ( $class ) {
    $class = ref $class || $class || __PACKAGE__;
    state %def_filter;
    return $def_filter{ $class } //= $class->new();
}

method _clone_arg ( $args, $key, $current ) {
    if ( defined $current ) {
        if ( exists $args->{ $key } ) {
            return if defined $args->{ $key } && $args->{ $key } == $current;
            $args->{ _conflict } = 1;
            return;
        }
        $args->{ $key } = $current;
    } ## end if ( defined $current )

    $args->{ _need_clone } = 1 if exists $args->{ $key };
    return;
} ## end sub _clone_arg

method combine ( %args ) {

    return $self unless %args;

    $self->_clone_arg( \%args, region    => $region );
    $self->_clone_arg( \%args, presenter => $presenter );
    $self->_clone_arg( \%args, room      => $room );

    # Empty list, conflicting filters, allow use in maps
    return if delete $args{ _conflict };

    # No need to add name if filter is identical
    return $self unless delete $args{ _need_clone };

    my $add_arg = delete $args{ output_name };
    my @add     = ref $add_arg ? @{ $add_arg } : ( $add_arg );

    return __CLASS__->new( %args )->_init_output_name( @output_name, @add );
} ## end sub combine

1;
