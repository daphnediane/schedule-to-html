package PresenterSet;

use Object::InsideOut;

use v5.38.0;
use utf8;

use HTML::Tiny qw{};
use Readonly;

use Presenter qw{};

Readonly our $UNLISTED => 1;
Readonly our $LISTED   => 2;

## no critic (ProhibitUnusedVariables)

my @presenter_set
    :Field
    :Default({})
    :Get(Name => q{get_set_}, Private => 1);

my @hide_credits
    :Field
    :Arg(Name => q{are_credits_hidden})
    :Set(Name => q{set_are_credits_hidden})
    :Get(Name => q{get_are_credits_hidden});

my @override_credits
    :Field
    :Arg(Name => q{override_credits})
    :Set(Name => q{set_override_credits})
    :Get(Name => q{get_override_credits});

my @credits
    :Field
    :Set(Name => q{set_credits_}, Private => 1)
    :Get(Name => q{get_credits_}, Private => 1);
## use critic

sub add_presenters_ ( $self, $level, @presenters ) {
    return unless @presenters;

    push @presenters, $UNLISTED if $level >= $LISTED;

    my $p_set = $self->get_set_();
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
        my $old_level = $p_set->{ $pid } || 0;
        if ( $old_level < $level ) {
            $self->set_credits_( undef ) unless $any_seen;
            $any_seen = 1;

            $p_set->{ $pid } = $level;

            push @presenters, $presenter->get_groups();
            if (  !$guest_seen
                && $presenter->get_presenter_rank()
                <= $Presenter::RANK_GUEST ) {
                $guest_seen = 1;
                push @presenters, Presenter->any_guest();
            } ## end if ( !$guest_seen && $presenter...)
        } ## end if ( $old_level < $level)
    } ## end while ( @presenters )

    return;
} ## end sub add_presenters_

sub add_credited_presenters ( $self, @presenters ) {
    return unless @presenters;

    $self->add_presenters_( $LISTED, @presenters );
    return;
} ## end sub add_credited_presenters

sub add_unlisted_presenters ( $self, @presenters ) {
    return unless @presenters;

    $self->add_presenters_( $UNLISTED, @presenters );
    return;
} ## end sub add_unlisted_presenters

sub is_presenter_hosting ( $self, $presenter ) {
    return unless defined $presenter;

    return 1 if exists $self->get_set_()->{ $presenter->get_pid() };
    return;
} ## end sub is_presenter_hosting

sub is_presenter_credited ( $self, $presenter ) {
    return unless defined $presenter;

    return 1 if $self->get_set_()->{ $presenter->get_pid() } >= $LISTED;
    return;
} ## end sub is_presenter_credited

sub is_presenter_unlisted ( $self, $presenter ) {
    return unless defined $presenter;

    return 1 if $self->get_set_()->{ $presenter->get_pid() } == $UNLISTED;
    return;
} ## end sub is_presenter_unlisted

sub _get_credits_shown ( $self ) {
    my %shown;
    my $p_set = $self->get_set_();

PRESENTER:
    while ( my ( $pid, $state ) = each %{ $p_set } ) {
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
                next GROUP unless exists $p_set->{ $member->get_pid() };
            }
            $shown{ $gid } = $group;
            next PRESENTER;
        } ## end GROUP: foreach my $group ( $presenter...)

        $shown{ $pid } = $presenter;
    } ## end PRESENTER: while ( my ( $pid, $state...))

    return values %shown;
} ## end sub _get_credits_shown

sub get_credited_as_ ( $self, $presenter ) {
    my $p_set;

    my $name = $presenter->get_presenter_name();
    if ( $presenter->get_is_always_shown() && $presenter->is_group() ) {
        my $count = 0;
        my @hosting;
        my $not_all;
        foreach my $member ( $presenter->get_members() ) {
            $p_set //= $self->get_set_();
            if ( exists $p_set->{ $member->get_pid() } ) {
                if ( $member->get_is_always_grouped() ) {
                    return $name;
                }
                push @hosting, $member;
            } ## end if ( exists $p_set->{ ...})
            else {
                $not_all = 1;
            }
        } ## end foreach my $member ( $presenter...)
        if ( $not_all && 1 == scalar @hosting ) {
            return $name . q{ (} . $hosting[ 0 ]->get_presenter_name() . q{)};
        }
    } ## end if ( $presenter->get_is_always_shown...)
    return $name;
} ## end sub get_credited_as_

sub get_credits ( $self ) {
    if ( $self->get_are_credits_hidden() ) {
        return;
    }

    my $override = $self->get_override_credits();
    return $override if defined $override;

    my $credits = $self->get_credits_();
    return $credits if defined $credits;

    my @presenters;

    foreach my $presenter ( sort $self->_get_credits_shown() ) {
        push @presenters, $self->get_credited_as_( $presenter );
    }

    # Handle long presenter names
    $credits = q{} if @presenters;
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

    $self->set_credits_( $credits );

    return $credits if defined $credits;
    return;
} ## end sub get_credits

1;
