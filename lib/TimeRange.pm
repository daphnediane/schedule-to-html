use v5.38.0;    ## no critic (Modules::ProhibitExcessMainComplexity)
use utf8;
use Feature::Compat::Class;

class TimeRange {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage)

    package TimeRange;

    use TimeDecoder qw{ :from_text };

    # MARK: time fields

    field $start_seconds :param(start_time) //= undef;
    field $end_seconds :param(end_time)     //= undef;
    field $duration :param(duration)        //= undef;

    ADJUST {
        $start_seconds = text_to_datetime( $start_seconds )
            if defined $start_seconds;
        $end_seconds = text_to_datetime( $end_seconds )
            if defined $end_seconds;
        $duration = text_to_duration( $duration ) if defined $duration;
    } ## end ADJUST

    # MARK: start time

    method set_start_time ( $new_time ) {
        $start_seconds = text_to_datetime( $new_time );
        return $start_seconds;
    }

    method set_start_seconds ( $seconds ) {
        $start_seconds = $seconds;
        return $start_seconds;
    }

    method get_start_seconds () {
        return $start_seconds if defined $start_seconds;
        defined $end_seconds
            or return;
        defined $duration
            or return;
        return $end_seconds - $duration;
    } ## end sub get_start_seconds

    # MARK: end time

    method set_end_time ( $new_time ) {
        $end_seconds = text_to_datetime( $new_time );
        return $end_seconds;
    }

    method set_end_seconds ( $seconds ) {
        $end_seconds = $seconds;
        return $end_seconds;
    }

    method get_end_seconds () {
        return $end_seconds if defined $end_seconds;
        defined $start_seconds
            or return;
        defined $duration
            or return;
        return $start_seconds + $duration;
    } ## end sub get_end_seconds

    # MARK: duration

    method set_duration ( $new_time ) {
        $duration = text_to_duration( $new_time );
        return $duration;
    }

    method set_duration_seconds ( $seconds ) {
        $duration = $seconds;
        return $duration;
    }

    method get_duration_seconds () {
        return $duration if defined $duration;
        defined $start_seconds
            or return;
        defined $end_seconds
            or return;
        $start_seconds <= $end_seconds
            or return;
        return $end_seconds - $start_seconds;
    } ## end sub get_duration_seconds

    # MARK: truncation

    method truncate_end_seconds ( $new_end ) {
        my $cur_end = $self->get_end_seconds();
        $new_end //= $cur_end;
        defined $new_end
            or return;
        return $cur_end if defined $cur_end && $cur_end <= $new_end;
        $end_seconds = $new_end;
        $duration -= $cur_end - $new_end
            if defined $cur_end && defined $duration;
        return $new_end;
    } ## end sub truncate_end_seconds

    # MARK: is_active_at

    method is_active_at_seconds ( $check_seconds ) {
        defined $check_seconds
            or return;
        my $cur_start = $self->get_start_seconds();
        defined $cur_start
            or return;
        $cur_start <= $check_seconds
            or return;
        my $cur_end = $self->get_end_seconds();
        defined $cur_end
            or return;
        return 1 if $check_seconds < $cur_end;
        return;
    } ## end sub is_active_at_seconds

    method is_active_at_time( $check_time ) {
        return is_active_at_seconds( text_to_datetime( $check_time ) );
    }

    # MARK: cloning
    method clone_args() {
        return (
            (   defined $start_seconds ? ( start_time => $start_seconds ) : ()
            ),
            ( defined $end_seconds ? ( end_time => $end_seconds ) : () ),
            ( defined $duration    ? ( duration => $duration )    : () )
        );
    } ## end sub clone_args

    method clone() {
        return __CLASS__->new( $self->clone_args() );
    }

} ## end package TimeRange

1;
