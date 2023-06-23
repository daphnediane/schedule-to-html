package Data::Partion;

use Object::InsideOut;

use v5.36.0;
use utf8;

use Carp qw{ croak };

use Data::Room        qw{};
use Presenter         qw{};
use Table::TimeRegion qw{};

## no critic (ProhibitUnusedVariables)

my @region_
    :Field
    :Type(Data::RegionForTable)
    :Arg(Name => q{region})
    :Get(Name => q{get_selected_region});

my @presenter_
    :Field
    :Type(Presenter)
    :Arg(Name => q{presenter})
    :Get(Name => q{get_selected_presenter});

my @room_
    :Field
    :Type(Data::Room)
    :Arg(Name => q{room})
    :Get(Name => q{get_selected_room});

my @output_name_
    :Field
    :Type(list)
    :Arg(Name => q{output_name})
    :Get(Name => q{get_output_name_}, Restricted => 1);

## use critic

sub get_output_name_pieces {
    my ( $self ) = @_;
    my $out_name = $self->get_output_name_();
    return           unless defined $out_name;
    return $out_name unless ref $out_name;
    return @{ $out_name };
} ## end sub get_output_name_pieces

sub unfiltered {
    my ( $class ) = @_;
    $class = ref $class || $class || __PACKAGE__;
    state $def_filter = $class->new();
    return $def_filter;
} ## end sub unfiltered

sub clone_arg_ {
    my ( $orig, $args, $key, $current ) = @_;

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
} ## end sub clone_arg_

sub combine :MergeArgs {
    my ( $orig, $args ) = @_;
    croak q{Unsupported clone} unless __PACKAGE__ eq ref $orig;

    return $orig unless %{ $args };

    $orig->clone_arg_( $args, region    => $orig->get_selected_region() );
    $orig->clone_arg_( $args, presenter => $orig->get_selected_presenter() );
    $orig->clone_arg_( $args, room      => $orig->get_selected_room() );

    # Empty list, conflicting filters, allow use in maps
    return if delete $args->{ _conflict };

    # No need to add name if filter is identical
    return $orig unless delete $args->{ _need_clone };

    my @add;
    if ( defined $args->{ output_name } ) {
        my $add = $args->{ output_name };
        @add = ( $add );
        @add = @{ $add } if ref $add;
    }
    if ( @add ) {
        $args->{ output_name } = [ $orig->get_output_name_pieces(), @add ];
    }
    else {
        $args->{ output_name } = $orig->get_output_name_();
    }

    return $orig->new( $args );
} ## end sub combine

1;
