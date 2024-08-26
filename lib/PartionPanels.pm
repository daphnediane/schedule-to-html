package PartionPanels;

use base qw{Exporter};

use v5.40.0;
use utf8;

use Carp qw{ croak };

use Data::Room qw{};
use Presenter  qw{};

our @EXPORT_OK = qw {
    split_filter_by_timestamp
    split_filter_by_panelist
    split_filter_by_room
};

our %EXPORT_TAGS = (
    all => [ @EXPORT_OK ],
);

sub split_filter_by_timestamp {
    my ( $regions, @filters ) = @_;

    my @res;
    foreach my $filter ( @filters ) {
        foreach my $region ( @{ $regions } ) {
            push @res, $filter->combine(
                region      => $region,
                output_name => $region->get_region_name()
            );
        } ## end foreach my $region ( @{ $regions...})
    } ## end foreach my $filter ( @filters)

    return @res;
} ## end sub split_filter_by_timestamp

sub gen_by_panelist_match_ {
    my ( $flags )  = @_;
    my $ranks      = delete $flags->{ ranks };
    my $is_by_desc = delete $flags->{ is_by_desc };

    croak q{Unrecognized parameter: },
        join q{, }, keys %{ $flags } if %{ $flags };

    return unless defined $ranks;
    return unless @{ $ranks };
    my @shown_rank;
    foreach my $rank ( @{ $ranks } ) {
        $shown_rank[ $rank ] = 1;
    }

    if ( $is_by_desc ) {
        return sub {
            my ( $per_info ) = @_;

            return if $per_info->get_is_other();
            return unless $shown_rank[ $per_info->get_presenter_rank() ];
            return
                if $is_by_desc
                && ( $per_info->get_is_meta() || $per_info->is_in_group() );
            return 1;
        };
    } ## end if ( $is_by_desc )

    return sub {
        my ( $per_info ) = @_;

        return   if $per_info->get_is_other();
        return 1 if $shown_rank[ $per_info->get_presenter_rank() ];
        return;
    };
} ## end sub gen_by_panelist_match_

sub split_filter_by_panelist {
    my ( $flags, @filters ) = @_;
    my $match_panelist = gen_by_panelist_match_( $flags );

    return          unless @filters;
    return @filters unless defined $match_panelist;

    my @res;
    foreach my $filter ( @filters ) {
        if ( defined $filter->get_selected_presenter() ) {
            push @res, $filter
                if $match_panelist->( $filter->get_selected_presenter() );
            next;
        }

        foreach my $per_info ( Presenter->get_known() ) {
            next unless $match_panelist->( $per_info );

            my $name = $per_info->get_presenter_name();
            if ( $per_info->is_in_group() ) {
                $name = [
                    (   map { $_->get_presenter_name() }
                            $per_info->get_groups()
                    ),
                    $name
                ];
            } ## end if ( $per_info->is_in_group...)

            push @res, $filter->combine(
                presenter   => $per_info,
                output_name => $name,
            );
        } ## end foreach my $per_info ( Presenter...)
    } ## end foreach my $filter ( @filters)

    return @res;
} ## end sub split_filter_by_panelist

sub split_filter_by_room {
    my ( $rooms, @filters ) = @_;

    return unless defined $rooms;

    my @res;
    foreach my $filter ( @filters ) {
        foreach my $room ( @{ $rooms } ) {
            push @res, $filter->combine(
                room        => $room,
                output_name => $room->get_short_room_name()
            );
        } ## end foreach my $room ( @{ $rooms...})
    } ## end foreach my $filter ( @filters)

    return @res;
} ## end sub split_filter_by_room

1;
