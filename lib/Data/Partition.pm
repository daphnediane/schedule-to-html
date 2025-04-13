use v5.38.0;    ## no critic (Modules::ProhibitExcessMainComplexity)
use utf8;
use Feature::Compat::Class;

class Data::Partition {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage)

    package Data::Partition;

    use Carp qw{ croak };

    field $region :param(region) //= undef;
    ADJUST {
        $region isa Data::RegionForTable
            or ( !defined $region )
            or croak q{region must be a Data::RegionForTable};
    }

    method get_selected_region () {
        return $region if defined $region;
        return;
    }

    field $presenter :param(presenter) //= undef;
    ADJUST {
        $presenter isa Presenter
            or ( !defined $presenter )
            or croak q{presenter must be a Presenter};
    }

    method get_selected_presenter () {
        return $presenter if defined $presenter;
        return;
    }

    field $room :param(room) //= undef;
    ADJUST {
        $room isa Data::Room
            or ( !defined $room )
            or croak q{room must be a Data::Room};
    }

    method get_selected_room () {
        return $room if defined $room;
        return;
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
                return
                    if defined $args->{ $key } && $args->{ $key } == $current;
                $args->{ _conflict } = 1;
                return;
            } ## end if ( exists $args->{ $key...})
            $args->{ $key } = $current;
        } ## end if ( defined $current )

        $args->{ _need_clone } = 1 if exists $args->{ $key };
        return;
    } ## end sub _clone_arg

    method combine ( %args ) {
        %args
            or return $self;

        $self->_clone_arg( \%args, region    => $region );
        $self->_clone_arg( \%args, presenter => $presenter );
        $self->_clone_arg( \%args, room      => $room );

        # Empty list, conflicting filters, allow use in maps
        return if delete $args{ _conflict };

        # No need to add name if filter is identical
        delete $args{ _need_clone }
            or return $self;

        my $add_arg = delete $args{ output_name };
        my @add     = ref $add_arg ? @{ $add_arg } : ( $add_arg );

        return __CLASS__->new( %args )
            ->_init_output_name( @output_name, @add );
    } ## end sub combine
} ## end package Data::Partition

1;
