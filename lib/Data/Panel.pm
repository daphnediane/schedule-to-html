package Data::Panel;

use v5.38.0;
use utf8;

use Carp                   qw{ croak };
use Readonly               qw{ Readonly };
use Feature::Compat::Class qw{ :all };
use List::MoreUtils        qw{ all };
use Scalar::Util           qw{ reftype blessed };

use Data::PanelType  qw{};
use Data::Room       qw{};
use PresenterSet     qw{};
use Table::PanelType qw{};

class Data::Panel :isa(TimeRange);

Readonly our $COST_HIDDEN => q{*};
Readonly our $COST_KIDS   => q{Kids};
Readonly our $COST_FREE   => q{$} . q{0};
Readonly our $COST_TBD    => q{$} . q{TBD};
Readonly our $COST_MODEL  => q{model};

## no critic(ProhibitComplexRegexes)
Readonly our $RE_FREE => qr{
    \A (?:  free
    | (?=n) (?: nothing
              | n /? a )
    | [\$]? (?: 0+ (?: [.] 0+ )? | [.] 0+ )
    ) \z
    }xmsi;
Readonly our $RE_TBD   => qr{ \A [\$]? T [.]? B [.]? D[.]? \z }xmsi;
Readonly our $RE_MODEL => qr{ model }xmsi;
## use critic

## no critic(TooMuchCode::ProhibitDuplicateLiteral)
q{free}        =~ $RE_FREE  or croak q{Assertion fail};
q{n/A}         =~ $RE_FREE  or croak q{Assertion fail};
q{nothing}     =~ $RE_FREE  or croak q{Assertion fail};
q{$} . q{0.00} =~ $RE_FREE  or croak q{Assertion fail};
q{$} . q{0.01} !~ $RE_FREE  or croak q{Assertion fail};
q{$} . q{0}    =~ $RE_FREE  or croak q{Assertion fail};
q{$} . q{00}   =~ $RE_FREE  or croak q{Assertion fail};
q{T.B.D.}      =~ $RE_TBD   or croak q{Assertion fail};
q{model}       =~ $RE_MODEL or croak q{Assertion fail};
## use critic

sub _norm_text ( @values ) {
    @values = grep { defined } @values;
    return unless @values;
    my $value = join q{}, @values;
    $value =~ s{\A \s++ }{}xms;
    $value =~ s{\s++ \z}{}xms;
    return if $value eq q{};
    return $value;
} ## end sub _norm_text

sub _norm_cost ( @values ) {
    my $value = _norm_text( @values );
    return unless defined $value;
    return             if $value eq q{};
    return $COST_FREE  if $value =~ $RE_FREE;
    return $COST_TBD   if $value =~ $RE_TBD;
    return $COST_MODEL if $value =~ $RE_MODEL;
    return $value;
} ## end sub _norm_cost

sub _norm_full ( @values ) {
    my $value = _norm_text( @values );
    return unless defined $value;
    return if $value =~ m{\Anot??}xms;
    return if $value eq q{};

    return 1;
} ## end sub _norm_full

sub _uniq_to_base_type_remain ( $id ) {
    if ( $id =~ s{ \A (?<type> [[:alpha:]]{2,}+ ) (?<num> \d++ ) }{}xms ) {
        my $type     = $+{ type };
        my $number   = 0 + $+{ num };
        my $need_len = 2 <= length $type ? 3 : 2;
        if ( $need_len > length $number ) {
            $number = q{000} . $number;
            $number = substr $number, -$need_len;
        }
        return ( $type . $number, $type, $id );
    } ## end if ( $id =~ ...)

    return ( $id, $id, q{} );
} ## end sub _uniq_to_base_type_remain

# MARK: uniq_id field

field $uniq_id :param(uniq_id);
field $id_base;
field $id_type;
field $id_number;
field $id_part_type  = q{};
field $id_part_index = 1;
field $id_remain;

ADJUST {
    $uniq_id = _norm_text( $uniq_id );
    ( $id_base, $id_type, $id_remain )
        = _uniq_to_base_type_remain( $uniq_id );

    if ( $id_remain =~ s{ (?<type> [PS] ) (?<index> \d+ ) }{}xms ) {
        $id_part_type  = $+{ type };
        $id_part_index = 0 + $+{ index };
    }
} ## end ADJUST

method get_uniq_id () {
    return $uniq_id;
}

method get_uniq_id_base () {
    return $id_base;
}

method get_uniq_id_part () {
    return $id_part_index;
}

method get_uniq_id_is_part () {
    return $id_part_type eq q{P} ? 1 : 0;
}

# MARK: href_anchor field

field $href_anchor;

method get_href_anchor () {
    return $href_anchor if defined $href_anchor;

    my $base_anchor = $uniq_id // q{ZZ9999999};
    my $anchor      = $base_anchor;
    state %used_anchors;
    while ( $used_anchors{ $anchor } ) {
        my $id_seen_cnt = ++$used_anchors{ $base_anchor };
        $anchor = $base_anchor . q{Dup} . $id_seen_cnt;
    }
    $used_anchors{ $anchor } = 1;
    return $href_anchor = $anchor;
} ## end sub get_href_anchor

# MARK: name field

field $name :param(name) //= undef;
ADJUST {
    $name = _norm_text( $name );
}

method get_name() {
    return $name if defined $name;
    return;
}

# MARK: rooms field

# @TODO(class adjust parameters)
# Only Object::Pad supports ADJUST :params, 5.40.0 class does not yet
field $rooms_arg :param(rooms);
field @rooms;
ADJUST {
    if (   blessed $rooms_arg
        || !ref $rooms_arg
        || q{ARRAY} ne reftype $rooms_arg ) {
        @rooms = ( $rooms_arg ) if defined $rooms_arg;
    }
    else {
        @rooms = @{ $rooms_arg };
    }
    $rooms_arg = undef;

    all { blessed $_ && $_->isa( q{Data::Room} ) }
        or croak q{rooms must be rooms};
} ## end ADJUST

method get_rooms() {
    return @rooms;
}

# MARK: description field

field $desc :param(description) //= undef;
ADJUST {
    $desc = _norm_text( $desc );
}

method get_description () {
    return $desc if defined $desc;
    return;
}

# MARK: prereq field

field $prereq_arg :param(prereq) //= undef;
field @prereq;
ADJUST {
    if (   blessed $prereq_arg
        || !ref $prereq_arg
        || q{ARRAY} ne reftype $prereq_arg ) {
        @prereq = ( $prereq_arg ) if defined $prereq_arg;
    }
    else {
        @prereq = @{ $prereq_arg };
    }
    $prereq_arg = undef;
    @prereq     = grep { $_ ne $id_base }
        map  { ( _uniq_to_base_type_remain( $_ ) )[ 0 ] }
        map  { split m{[,;/]\s*}, $_ }
        grep { defined } @prereq;
} ## end ADJUST

method get_base_prereq_ids () {
    return @prereq;
}

# MARK: note field

field $note :param(note) //= undef;
ADJUST {
    $note = _norm_text( $note );
}

method get_note() {
    return $note if defined $note;
    return;
}

## no critic (ProhibitUnusedVariables)

# MARK: av_note field

field $av_note :param(av_note) //= undef;
ADJUST {
    $av_note = _norm_text( $av_note );
}

method get_av_note() {
    return $av_note if defined $av_note;
    return;
}

# MARK: difficulty field

field $difficulty :param(difficulty) //= undef;
ADJUST {
    $difficulty = _norm_text( $difficulty );
}

method get_difficulty () {
    return $difficulty if defined $difficulty;
    return;
}

method set_difficulty ( $new_diff = undef ) {
    $difficulty = _norm_text( $difficulty );
    return $self;
}

# MARK: capacity field

field $capacity :param(capacity) //= undef;

method get_capacity () {
    return $capacity if defined $capacity;
    return;
}

# MARK: ticket_sale (URL) field

field $ticket_sale :param(ticket_sale) //= undef;

method get_ticket_sale () {
    return $ticket_sale;
}

# MARK: panel_kind / panel_type field

field $panel_kind :param(panel_kind) //= undef;
field $panel_type;
ADJUST {
    $panel_kind = _norm_text( $panel_kind );
}

method get_panel_type () {
    return $panel_type if defined $panel_type;

    my $prefix = $id_type;
    $panel_type = Table::PanelType::lookup( $prefix );
    return $panel_type if defined $panel_type;

    return $panel_type = Data::PanelType->new(
        prefix => uc $prefix,
        kind   => $panel_kind // $prefix . q{ Panel}
    );
} ## end sub get_panel_type

# MARK: cost

field $cost :param(cost) //= undef;
ADJUST {
    $cost = _norm_cost( $cost );
}

method get_cost () {
    if ( defined $cost ) {
        return if $cost eq $COST_KIDS;
        return if $cost eq $COST_FREE;
        return if $cost eq $COST_HIDDEN;
        return $cost;
    } ## end if ( defined $cost )

    return $COST_TBD if $self->get_panel_type()->is_workshop();
    return;

} ## end sub get_cost

method get_cost_is_model () {
    return unless defined $cost;
    return 1 if $cost eq $COST_MODEL;
    return;
}

method get_is_free_kid_panel {
    return unless defined $cost;
    return 1 if $cost eq $COST_KIDS;
    return;
}

method get_cost_is_missing {
    return   if defined $cost;
    return 1 if $self->get_panel_type()->is_workshop();
    return;
}

# MARK: is_full field

field $is_full :param(is_full) //= undef;
ADJUST {
    $is_full = _norm_full( $is_full );
}

method get_is_full () {
    return 1 if $is_full;

    #TODO(pfister): Check capacity

    return;
} ## end sub get_is_full

# MARK: presenter_set field

field $presenter_set :param(presenter_set) //= PresenterSet->new();
ADJUST {
    blessed $presenter_set && $presenter_set->isa( q{PresenterSet} )
        || croak q{Presenter set must be of type presenter set};
}

method get_presenter_set () {
    return $presenter_set;
}

# MARK: uuid field

field $uid;

method get_panel_internal_id {
    state $next_uid = 0;
    return $uid //= ++$next_uid;
}

# MARK: Chaining

method DESTROY () {
    return $self->SUPER::DESTROY() if $self->can( q{SUPER::DESTROY} );
}

our $AUTOLOAD;

method AUTOLOAD ( @args ) {
    ( my $called = $AUTOLOAD ) =~ s{.*::}{}xms;

    my $presenter_func = q{PresenterSet::} . $called;
    my $mem_func       = $presenter_set->can( $presenter_func );

    if ( defined $mem_func ) {
        return $presenter_set->$mem_func( @args );
    }

    croak q{Can't locate object method "}, $called, q{" via package "},
        __CLASS__, q{"};
} ## end sub AUTOLOAD

method can ( $method ) {
    my $res = $self->SUPER::can( $method );
    return $res if defined $res;

    if ( defined( $res = PresenterSet->can( $method ) ) ) {
        return sub ( $self, @method_args ) {
            return $self->get_presenter_set()->$res( @method_args );
            }
            if defined $res;
    } ## end if ( defined( $res = PresenterSet...))
    return;
} ## end sub can

method clone_args() {
    croak q{Can not clone};
}

1;
