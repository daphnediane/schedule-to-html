use v5.38.0;    ## no critic (Modules::ProhibitExcessMainComplexity)
use utf8;
use Feature::Compat::Class;

class PresenterSet {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage)

    package PresenterSet;

    use HTML::Tiny qw{ };
    use Readonly   qw{ Readonly };

    use Presenter qw{};

    Readonly our $UNLISTED => 1;
    Readonly our $LISTED   => 2;

    # MARK: credit_cache field

    field $credit_cache;

    # MARK: pid_set field

    field %pid_set;

    method _add_presenters ( $level, @presenters ) {
        @presenters
            or return;

        push @presenters, $UNLISTED if $level >= $LISTED;

        my $any_seen;
        my $guest_seen;

        while ( @presenters ) {
            my $presenter = shift @presenters;
            next unless defined $presenter;
            if ( !ref $presenter ) {
                $level = $presenter;
                next;
            }

            next if $level < $UNLISTED;

            my $pid       = $presenter->get_pid();
            my $old_level = $pid_set{ $pid } || 0;

            next if $old_level >= $level;

            $any_seen = 1;

            $pid_set{ $pid } = $level;

            push @presenters, $presenter->get_groups();
            if (  !$guest_seen
                && $presenter->get_presenter_rank()
                <= $Presenter::RANK_GUEST ) {
                $guest_seen = 1;
                push @presenters, Presenter->any_guest();
            } ## end if ( !$guest_seen && $presenter...)
        } ## end while ( @presenters )

        $credit_cache = undef if $any_seen;

        return;
    } ## end sub _add_presenters

    method add_credited_presenters ( @presenters ) {
        @presenters
            or return;

        $self->_add_presenters( $LISTED, @presenters );
        return;
    } ## end sub add_credited_presenters

    method add_unlisted_presenters ( @presenters ) {
        @presenters
            or return;

        $self->_add_presenters( $UNLISTED, @presenters );
        return;
    } ## end sub add_unlisted_presenters

    method is_presenter_hosting ( $presenter ) {
        defined $presenter
            or return;

        return 1 if exists $pid_set{ $presenter->get_pid() };
        return;
    } ## end sub is_presenter_hosting

    method is_presenter_credited ( $presenter ) {
        defined $presenter
            or return;

        return 1 if $pid_set{ $presenter->get_pid() } >= $LISTED;
        return;
    } ## end sub is_presenter_credited

    method is_presenter_unlisted ( $presenter ) {
        defined $presenter
            or return;

        return 1 if $pid_set{ $presenter->get_pid() } == $UNLISTED;
        return;
    } ## end sub is_presenter_unlisted

    # MARK: hide_credits field

    field $hide_credits :param(are_credits_hidden) //= undef;

    method get_are_credits_hidden () {
        return $hide_credits ? 1 : 0;
    }

    method set_are_credits_hidden( $new_state = 1 ) {
        $hide_credits = $new_state;
        return $self;
    }

    method clear_are_credits_hidden() {
        $hide_credits = 0;
        return $self;
    }

    # MARK: override_credits field

    field $override_credits :param(override_credits) //= undef;

    method get_override_credits () {
        defined $override_credits
            or return;
        return $override_credits;
    }

    method set_override_credits( $new_credit ) {
        $override_credits = $new_credit;
        return $self;
    }

    method clear_override_credits() {
        $override_credits = undef;
        return $self;
    }

    # MARK: Compute credits

    method _get_credits_shown ( ) {
        my %shown;

    PRESENTER:
        while ( my ( $pid, $state ) = each %pid_set ) {
            next if $state < $LISTED;
            my $presenter = Presenter->find_by_pid( $pid );
            next unless defined $presenter;

            next if defined $shown{ $pid };

            # Check if group should be shown instead
            # Groups will be should if either
            # -- All members are hosting
            # -- Group is listed as always shown
        GROUP:
            foreach my $group ( $presenter->get_groups() ) {
                my $gid = $group->get_pid();
                next PRESENTER if defined $shown{ $gid };

                if ( $group->get_is_always_shown() ) {
                    $shown{ $gid } = $group;
                    next PRESENTER;
                }
                foreach my $member ( $group->get_members() ) {
                    next GROUP unless exists $pid_set{ $member->get_pid() };
                }
                $shown{ $gid } = $group;
                next PRESENTER;
            } ## end GROUP: foreach my $group ( $presenter...)

            $shown{ $pid } = $presenter;
        } ## end PRESENTER: while ( my ( $pid, $state...))

        return values %shown;
    } ## end sub _get_credits_shown ( )

    method _get_credited_as ( $presenter ) {
        my $name = $presenter->get_presenter_name();
        if ( $presenter->get_is_always_shown() && $presenter->is_group() ) {
            my $count = 0;
            my @hosting;
            my $not_all;
            foreach my $member ( $presenter->get_members() ) {
                if ( exists $pid_set{ $member->get_pid() } ) {
                    if ( $member->get_is_always_grouped() ) {
                        return $name;
                    }
                    push @hosting, $member;
                } ## end if ( exists $pid_set{ ...})
                else {
                    $not_all = 1;
                }
            } ## end foreach my $member ( $presenter...)
            if ( $not_all && 1 == scalar @hosting ) {
                return
                      $name . q{ (}
                    . $hosting[ 0 ]->get_presenter_name() . q{)};
            }
        } ## end if ( $presenter->get_is_always_shown...)
        return $name;
    } ## end sub _get_credited_as

    method get_credits ( ) {
        if ( $hide_credits ) {
            return;
        }

        if ( defined $override_credits ) {
            return $override_credits if $override_credits ne q{};
            return;
        }

        if ( defined $credit_cache ) {
            return $credit_cache if $credit_cache ne q{};
            return;
        }

        my @presenters;

        foreach my $presenter ( sort $self->_get_credits_shown() ) {
            push @presenters, $self->_get_credited_as( $presenter );
        }

        my $credits = q{};

        # Handle long presenter names
        while ( @presenters ) {
            my $name = shift @presenters;
            $name .= q{,} if @presenters;

            # Check for 20 characters in a row
            if ( $name =~ m{\S{20}}xms ) {
                state $h = HTML::Tiny->new( mode => q{html} );

                $name = $h->span( { class => q{longPanelist} }, $name );
            }
            $name .= q{ } if @presenters;

            $credits .= $name;
        } ## end while ( @presenters )

        $credit_cache = $credits;
        return $credit_cache if $credit_cache ne q{};
        return;
    } ## end sub get_credits ( )
} ## end package PresenterSet

1;
