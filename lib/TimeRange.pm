package TimeRange;

use Object::InsideOut;

use strict;
use warnings;
use common::sense;

use Date::Parse qw{ str2time };
use Readonly;
use utf8;

Readonly our $SEC_PER_MIN  => 60;
Readonly our $MIN_PER_HOUR => 60;

sub norm_date_time_ {
    my ( $value ) = @_;
    return unless defined $value;
    return        if $value eq q{};
    return $value if $value =~ m{\A \d+ \z}xms;

    # @todo(TimeStamp): This assumes American order
    my $time = str2time( $value );
    return $time if defined $time;
    warn qq{Unable to parse the following time: ${value}\n};
    return;
} ## end sub norm_date_time_

sub pre_init_time_ {
    my ( $class, $param, $spec, $obj, $value ) = @_;
    return norm_date_time_( $value );
}

sub pre_set_time_ {
    my ( $class, $field, @args ) = @_;
    return norm_date_time_( @args );
}

sub norm_dur_ {
    my ( $value ) = @_;
    return unless defined $value;
    return if $value eq q{};

    return unless $value =~ m{ \A \d+ (?: : \d+ )? \z}xms;

    my ( $hour, $min ) = split m{:}xms, $value, $2;
    $min += $hour * $MIN_PER_HOUR;
    return $min * $SEC_PER_MIN;
} ## end sub norm_dur_

sub pre_init_dur_ {
    my ( $class, $param, $spec, $obj, $value ) = @_;
    return norm_dur_( $value );
}

sub pre_set_dur_ {
    my ( $class, $field, @args ) = @_;
    return norm_dur_( @args );
}

my @start_seconds
    :Field
    :Type(scalar)
    :Arg(Name => q{start_time}, Pre => \&TimeRange::pre_init_time_)
    :Set(Name => q{set_start_time}, Pre => \&TimeRange::pre_set_time_)
    :Get(Name => q{get_start_}, Private => 1);

my @end_seconds
    :Field
    :Type(scalar)
    :Arg(Name => q{end_time}, Pre => \&TimeRange::pre_init_time_)
    :Set(Name => q{set_end_time}, Pre => \&TimeRange::pre_set_time_)
    :Get(Name => q{get_end_}, Private => 1);

my @duration
    :Field
    :Type(scalar)
    :Arg(Name => q{duration}, Pre => \&TimeRange::pre_init_dur_)
    :Set( Name => q{set_duration}, Pre => \&TimeRange::pre_set_time_ )
    :Get(Name => q{get_duration_}, Private => 1);

sub get_start_seconds {
    my ( $self ) = @_;
    my $start = $self->get_start_();
    return $start if defined $start;
    my $end = $self->get_end_();
    return unless defined $end;
    my $dur = $self->get_duration_();
    return unless defined $dur;
    return $end - $dur;
} ## end sub get_start_seconds

sub set_start_seconds {
    my ( $self, $seconds ) = @_;
    $self->Object::InsideOut::set( \@start_seconds, $seconds );
    return $seconds;
}

sub get_end_seconds {
    my ( $self ) = @_;
    my $end = $self->get_end_();
    return $end if defined $end;
    my $start = $self->get_start_();
    return unless defined $start;
    my $dur = $self->get_duration_();
    return unless defined $dur;
    return $start + $dur;
} ## end sub get_end_seconds

sub set_end_seconds {
    my ( $self, $seconds ) = @_;
    $self->Object::InsideOut::set( \@end_seconds, $seconds );
    return $seconds;
}

sub get_duration_seconds {
    my ( $self ) = @_;
    my $dur = $self->get_duration_();
    return $dur if defined $dur;
    my $start = $self->get_start_();
    return unless defined $start;
    my $end = $self->get_end_();
    return unless defined $end;
    return $end - $start;
} ## end sub get_duration_seconds

sub set_duraction_seconds {
    my ( $self, $seconds ) = @_;
    $self->Object::InsideOut::set( \@duration, $seconds );
    return $seconds;
}

1;
