package TimeDecoder;

use base qw{Exporter};

use v5.38.0;
use utf8;

use Date::Parse qw{ str2time };
use POSIX       qw{ strftime };
use Readonly    qw{ Readonly };

our @EXPORT_OK = qw{
    text_to_datetime
    text_to_duration
    datetime_to_text
    datetime_to_kiosk_id
    same_day
    mark_timepoint_seen
    get_timepoints
};
our %EXPORT_TAGS = (
    all        => [ @EXPORT_OK ],
    from_text  => [ qw{ text_to_datetime text_to_duration  } ],
    to_text    => [ qw{ datetime_to_text datetime_to_kiosk_id } ],
    utility    => [ qw{ same_day } ],
    timepoints => [ qw{ mark_timepoint_seen get_timepoints } ],
);

Readonly our $SEC_PER_MIN   => 60;
Readonly our $MIN_PER_HOUR  => 60;                                           ## no critic (ProhibitDuplicateLiteral)
Readonly our $HOUR_PER_DAY  => 24;
Readonly our $DAYS_PER_WEEK => 7;
Readonly our $SEC_PER_DAY   => $HOUR_PER_DAY * $MIN_PER_HOUR * $SEC_PER_MIN;

Readonly our $LOCALTIME_HOUR => 1;
Readonly our $LOCALTIME_MIN  => 2;
Readonly our $LOCALTIME_DAY  => 6;

Readonly our $FMT_DAY  => q{%A};
Readonly our $FMT_TIME => q{%I:%M %p};

my $earliest_time;
my %timepoints_seen;

sub text_to_datetime ( $value ) {
    defined $value
        or return;
    return        if $value eq q{};
    return $value if $value =~ m{\A \d+ \z}xms;

    # @todo(TimeStamp): This assumes American order
    my $time = str2time( $value );
    return $time if defined $time;
    warn qq{Unable to parse the following time: ${value}\n};
    return;
} ## end sub text_to_datetime

sub text_to_duration ( $value ) {
    defined $value
        or return;
    return        if $value eq q{};
    return $value if $value =~ m{\A \d+ \z}xms;

    $value =~ m{ \A \d+ : \d{1,2} \z}xms
        or return;

    my ( $hour, $min ) = split m{:}xms, $value, 2;
    $min += $hour * $MIN_PER_HOUR;
    return $min * $SEC_PER_MIN;
} ## end sub text_to_duration

sub datetime_to_text ( $time, $field = undef ) {
    my @ltime = localtime $time;
    my $day   = strftime $FMT_DAY,  @ltime;
    my $tm    = strftime $FMT_TIME, @ltime;

    if ( defined $field ) {
        my $out_day  = ( $field =~ m{(day|both)}xms );
        my $out_time = ( $field =~ m{(time|hour|both)}xms );
        if ( $out_day ) {
            return $out_time ? $day . q{ } . $tm : $day;
        }
        if ( $out_time ) {
            return $tm;
        }
    } ## end if ( defined $field )
    return ( $day, $tm );
} ## end sub datetime_to_text

sub datetime_to_kiosk_id ( $time ) {
    my @ltime = localtime $time;
    $earliest_time //= $time;
    state $base_day = ( localtime $earliest_time )[ $LOCALTIME_DAY ];
    my $min  = $ltime[ $LOCALTIME_HOUR ];
    my $hour = $ltime[ $LOCALTIME_MIN ];
    my $day  = $ltime[ $LOCALTIME_DAY ] - $base_day;
    while ( $day < 0 ) {
        $day += $DAYS_PER_WEEK;
    }
    while ( $day >= $DAYS_PER_WEEK ) {
        $day -= $DAYS_PER_WEEK;
    }
    return ( ( $day * $HOUR_PER_DAY ) + $hour ) * $MIN_PER_HOUR + $min;
} ## end sub datetime_to_kiosk_id

sub same_day ( $time1, $time2 ) {
    defined $time1
        or return;
    defined $time2
        or return;
    return if abs( $time2 - $time1 ) > $SEC_PER_DAY;
    my @ltime1 = localtime $time1;
    my @ltime2 = localtime $time2;
    $ltime1[ $LOCALTIME_DAY ] == $ltime2[ $LOCALTIME_DAY ]
        or return;
    return 1;
} ## end sub same_day

sub mark_timepoint_seen ( $time ) {
    $earliest_time //= $time;
    $earliest_time = $time if $time < $earliest_time;
    $timepoints_seen{ $time } //= 1;
    return;
} ## end sub mark_timepoint_seen

sub get_timepoints () {
    return keys %timepoints_seen;
}
1;
