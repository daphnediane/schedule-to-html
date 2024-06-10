package Options;

use base qw{Exporter};

use v5.36.0;
use utf8;

use Carp            qw{ croak };
use Data::Dumper    qw{};
use File::ShareDir  qw{};
use File::Slurp     qw{ read_file };
use File::Spec      qw{};
use Getopt::Long    qw{ GetOptionsFromArray };
use List::MoreUtils qw{ apply before };
use List::Util      qw{ any uniq };
use Readonly;

use TimeDecoder qw{ :from_text };
Readonly my $OPTION_PAT => qr{^ [#][#] \s (?= - ) }xms;

my @opt_parse;
my @opt_on_kiosk;
my %opt_gen;

sub unindent_ {
    my ( $chunk, $prefix ) = @_;
    $prefix //= q{};

    my $min_len;
    while ( $chunk =~ m{ ^ (\h*) \H }xmsg ) {
        my $len = length $1;
        $min_len //= $len;
        $min_len = $len if $len < $min_len;
    }
    $chunk =~ s{ ^ (\h*) (?= \H) }{ $prefix . substr $1, $min_len }xmsge;
    $chunk =~ s{ ^ \h* (?= $ ) }{}xmsg;
    return $chunk if $chunk =~ m{\S}xms;
    return;
} ## end sub unindent_

sub parse_internal_doc_ {
    state $option_doc;

    return $option_doc if defined $option_doc;

    my %option_doc;
    $option_doc = \%option_doc;

    my $text   = read_file( __FILE__ );
    my @chunks = split m{ (?= $OPTION_PAT ) }xms, $text;

    foreach my $chunk ( @chunks ) {
        next unless $chunk =~ m{ \A $OPTION_PAT }xms;
        $chunk             =~ s{\n[^#].*}{}xms;
        $chunk             =~ s{^ [#][#]+ \s? }{}xmsg;
        chomp $chunk;
        next unless $chunk =~ m{ \A --?([[:alnum:]-]+)}xms;
        my $opt_name = $1;

        my ( $example, $doc ) = split m{\n}xms, $chunk, 2;
        $example = join qq{\n}, $example, unindent_( $doc, q{  } );

        push @{ $option_doc{ $opt_name } }, $example;
    } ## end foreach my $chunk ( @chunks)

    return $option_doc;
} ## end sub parse_internal_doc_

sub to_str_ {
    my ( $value ) = @_;
    return q{} . $value if ref $value;
    return $value;
}

## List option
Readonly our $MOD_LIST => q{=s@};
$opt_gen{ $MOD_LIST } = sub {
    my ( $self, $opt_name, @rest ) = @_;
    croak q{Too many args for mod_list} if @rest;

    return sub {
        my ( $flag, $opt ) = @_;
        $opt = to_str_ $opt;
        return unless defined $opt;
        push @{ $self->{ $opt_name } }, $opt;
        return;
    };
};

## Value option
Readonly our $MOD_VALUE_STR => q{=s};
$opt_gen{ $MOD_VALUE_STR } = sub {
    my ( $self, $opt_name, @rest ) = @_;
    croak q{Too many args for mod_value_str} if @rest;

    return sub {
        my ( $flag, $opt ) = @_;
        $opt = to_str_ $opt;
        $self->{ $opt_name } = $opt;
    };
};

## Value number option
Readonly our $MOD_VALUE_NUM => q{=i};
$opt_gen{ $MOD_VALUE_NUM } = sub {
    my ( $self, $opt_name, @rest ) = @_;
    croak q{Too many args for mod_value_num} if @rest;

    return sub {
        my ( $flag, $opt ) = @_;
        $self->{ $opt_name } = 0 + $opt;
    };
};

## Sub value option
Readonly our $MOD_SUB_VALUE => q{=s%};
$opt_gen{ $MOD_SUB_VALUE } = sub {
    my ( $self, $opt_name, $opt_sub_name, @rest ) = @_;
    croak q{Too many args for mod_sub_value} if @rest;

    return sub {
        my ( $flag, $opt ) = @_;
        $opt = to_str_ $opt;
        $self->{ $opt_name }->{ $opt_sub_name } = $opt;
    };
};

## Named state option
Readonly our $MOD_NAMED_STATE => q{=s%%};
$opt_gen{ $MOD_NAMED_STATE } = sub {
    my ( $self, $opt_name, $opt_sub_name, @rest ) = @_;
    croak q{Too many args for mod_named_state} if @rest;

    return sub {
        my ( $flag, $opt ) = @_;
        $opt = to_str_ $opt;
        $self->{ $opt_name }->{ $opt } = $opt_sub_name;
    };
};

## Flag option
Readonly our $MOD_FLAG => q{};
$opt_gen{ $MOD_FLAG } = sub {
    my ( $self, $opt_name, $value, @rest ) = @_;
    croak q{Too many args for mod_flag} if @rest;

    if ( defined $value ) {
        return sub {
            $self->{ $opt_name } = $value;
            return;
        }
    } ## end if ( defined $value )
    return sub {
        delete $self->{ $opt_name };
        return;
    }
};

## Sub flag option
Readonly our $MOD_SUB_FLAG => q{%};
$opt_gen{ $MOD_SUB_FLAG } = sub {
    my ( $self, $opt_name, %hash_values ) = @_;

    return sub {
        my $any_deleted;
        foreach my $key ( keys %hash_values ) {
            my $value = $hash_values{ $key };
            $value .= q{} if ref $value;
            if ( defined $value ) {
                $self->{ $opt_name }->{ $key } = $value;
            }
            else {
                delete $self->{ $opt_name }->{ $key };
                $any_deleted = 1;
            }
        } ## end foreach my $key ( keys %hash_values)
        if ( $any_deleted && !%{ $self->{ $opt_name } } ) {
            delete $self->{ $opt_name };
        }

        return;
    }
};

## Special option
Readonly our $MOD_SPECIAL => q{&};
$opt_gen{ $MOD_SPECIAL } = sub {
    my ( $self, $opt_name, $handler, @rest ) = @_;

    return sub {
        $handler->( $self, @rest );
        return;
    };
};

sub get_method_ {
    my ( $self, $mod, @parms ) = @_;

    my $generator = $opt_gen{ $mod } or croak q{Unknown option mod: } . $mod;
    return $generator->( $self, @parms );
} ## end sub get_method_

sub get_getopt_flag_names_ {
    my ( $opt_set ) = @_;
    my ( $opt_name, $flag, $flag_mod, @values ) = @{ $opt_set };
    my @flags = $flag;
    @flags = @{ $flag } if ref $flag;
    for ( @flags ) {
        my ( $prefix, $no_fix ) = ( qw{ - no- } );
        if ( m{\A-}xms ) {
            ( $prefix, $no_fix ) = split m{/}xms, $opt_name, 2;
            $prefix .= q{-};
            $no_fix //= q{no-} . $prefix;
            while ( s{\A--}{-}xms ) {
                $prefix =~ s{-[^-]*}{}xms;
            }
        } ## end if ( m{\A-}xms )
        if ( s{\!}{}xmsg ) {
            $_ = $no_fix . $_;
        }
        else {
            $_ = $prefix . $_;
        }
        s{--+}{-}xmsg;
        s{\A-}{}xms;
    } ## end for ( @flags )

    return @flags;
} ## end sub get_getopt_flag_names_

sub get_getopt_flag_ {
    my ( $self, $opt_set ) = @_;
    my ( $opt_name, $flag, $flag_mod, @values ) = @{ $opt_set };
    my @flags = get_getopt_flag_names_( $opt_set );
    $flag = join q{|}, @flags;
    $flag .= $flag_mod;
    $flag =~ s{[\%/&]+\z}{}xms;
    return $flag => $self->get_method_( $flag_mod, $opt_name, @values );
} ## end sub get_getopt_flag_

sub on_kiosk_ {
    my ( $self, $opt_set ) = @_;
    my ( $opt_name, $flag_mod, @values ) = @{ $opt_set };
    my $method = $self->get_method_( $flag_mod, $opt_name, @values );
    $method->();
    return;
} ## end sub on_kiosk_

## --desc-form-div
##     Output descriptions in paragraphs. _Needs CSS work_
## --desc-form-table
##     Output descriptions in a table. Default
Readonly our $OPT_DESC_FORM_       => q{desc-form};
Readonly our $VAL_DESC_FORM_DIV_   => 1;
Readonly our $VAL_DESC_FORM_TABLE_ => undef;

push @opt_parse,
    [ $OPT_DESC_FORM_, [ qw{ -div } ],   $MOD_FLAG, $VAL_DESC_FORM_DIV_ ],
    [ $OPT_DESC_FORM_, [ qw{ -table } ], $MOD_FLAG, $VAL_DESC_FORM_TABLE_ ];

sub is_desc_form_div {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_DESC_FORM_ };
    return;
}

sub is_desc_form_table {
    my ( $self ) = @_;
    return 1 unless $self->{ $OPT_DESC_FORM_ };
    return;
}

## --desc-loc-mixed
##     Output descriptions between grids. Default
## --desc-loc-last
##     Output descriptions after all grids
Readonly our $OPT_DESC_LOC_       => q{desc-loc};
Readonly our $VAL_DESC_LOC_MIXED_ => undef;
Readonly our $VAL_DESC_LOC_LAST_  => 1;

push @opt_parse,
    [
    $OPT_DESC_LOC_, [ qw{ -mixed !separate } ], $MOD_FLAG,
    $VAL_DESC_LOC_MIXED_
    ],
    [
    $OPT_DESC_LOC_, [ qw{ -last separate } ], $MOD_FLAG,
    $VAL_DESC_LOC_LAST_
    ];

push @opt_on_kiosk,
    [ $OPT_DESC_LOC_, $MOD_FLAG ];

sub is_desc_loc_last {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_DESC_LOC_ };
    return;
}

sub is_desc_loc_mixed {
    my ( $self ) = @_;
    return 1 unless $self->{ $OPT_DESC_LOC_ };
    return;
}

## --desc-by-guest
##     Arrange descriptions by guest, showing just guest, implies --no-desc-by-judge, --no-desc-by-presenter
## --no-desc-by-guest
##     Do not arrange by guest, exclude guest if --desc-by-presenter is given
## --desc-by-judge
##     Arrange descriptions by guest, showing just guest, implies --no-desc-by-guest, --no-desc-by-presenter
## --no-desc-by-judge
##     Do not arrange by guest, exclude judge if --desc-by-presenter is given
## --desc-by-presenter
##     Arrange descriptions by presenters, implies --desc-by-guest, --desc-by-judge
## --no-desc-by-presenter
##     Do not arrange descriptions by presenter
## --desc-everyone-together
##     Do not sort descriptions by guest or presenters, default
## --desc-by-panelist
##     Alias of --desc-by-presenter
## --no-desc-by-panelist
##     Alias of --no-desc-by-presenter
Readonly our $OPT_DESC_BY_          => q{desc-by};
Readonly our $VAL_EVERYONE_TOGETHER => undef;
Readonly our $VAL_BY_GUEST          => q{guest};
Readonly our $VAL_BY_JUDGE          => q{judge};
Readonly our $VAL_BY_PANELIST       => q{panelist};

push @opt_parse,
    [
    $OPT_DESC_BY_, [ qw{ desc-everyone-together } ], $MOD_FLAG,
    $VAL_EVERYONE_TOGETHER
    ],
    [ $OPT_DESC_BY_, [ qw{ -!guest } ], $MOD_SUB_FLAG, $VAL_BY_GUEST => 0 ],
    [ $OPT_DESC_BY_, [ qw{ -guest } ],  $MOD_SUB_FLAG, $VAL_BY_GUEST => 1 ],
    [ $OPT_DESC_BY_, [ qw{ -!judge } ], $MOD_SUB_FLAG, $VAL_BY_JUDGE => 0 ],
    [ $OPT_DESC_BY_, [ qw{ -judge } ],  $MOD_SUB_FLAG, $VAL_BY_JUDGE => 1 ],
    [
    $OPT_DESC_BY_, [ qw{ -!presenter } ], $MOD_SUB_FLAG,
    $VAL_BY_PANELIST => 0
    ],
    [
    $OPT_DESC_BY_, [ qw{ -!panelist } ], $MOD_SUB_FLAG,
    $VAL_BY_PANELIST => 0
    ],
    [
    $OPT_DESC_BY_, [ qw{ -presenter } ], $MOD_SUB_FLAG,
    $VAL_BY_PANELIST => 1
    ],
    [
    $OPT_DESC_BY_, [ qw{ -panelist } ], $MOD_SUB_FLAG,
    $VAL_BY_PANELIST => 1
    ],
    ;

push @opt_on_kiosk,
    [ $OPT_DESC_BY_, $MOD_FLAG, $VAL_EVERYONE_TOGETHER ];

sub is_desc_everyone_together {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_DESC_BY_ };
    return 1 unless defined $hash;
    return if $hash->{ $VAL_BY_GUEST };
    return if $hash->{ $VAL_BY_JUDGE };
    return if $hash->{ $VAL_BY_PANELIST };
    return 1;
} ## end sub is_desc_everyone_together

sub is_desc_by_guest {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_DESC_BY_ };
    return unless defined $hash;
    return 1 if $hash->{ $VAL_BY_GUEST };
    return   if defined $hash->{ $VAL_BY_GUEST };
    return   if $hash->{ $VAL_BY_JUDGE };
    return 1 if $hash->{ $VAL_BY_PANELIST };
    return;
} ## end sub is_desc_by_guest

sub is_desc_by_judge {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_DESC_BY_ };
    return unless defined $hash;
    return 1 if $hash->{ $VAL_BY_JUDGE };
    return   if defined $hash->{ $VAL_BY_JUDGE };
    return   if $hash->{ $VAL_BY_GUEST };
    return 1 if $hash->{ $VAL_BY_PANELIST };
    return;
} ## end sub is_desc_by_judge

sub is_desc_by_panelist {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_DESC_BY_ }->{ $VAL_BY_PANELIST };
    return;
}

## --embed-css
##     Embed any CSS files in the generated HTML, default if --style
## --inline-css
##     Link to CSS files in the generated HTML, default unless --style

Readonly our $OPT_CSS_LOC_   => q{css-loc};
Readonly our $VAL_EMDED_CSS_ => 1;
Readonly our $VAL_LINK_CSS_  => 0;

push @opt_parse,
    [
    $OPT_CSS_LOC_, [ qw{ embed-css !inline-css } ], $MOD_FLAG,
    $VAL_EMDED_CSS_
    ],
    [
    $OPT_CSS_LOC_, [ qw{ inline-css !embed-css } ], $MOD_FLAG,
    $VAL_LINK_CSS_
    ];

push @opt_on_kiosk,
    [ $OPT_CSS_LOC_, $MOD_FLAG, $VAL_LINK_CSS_ ];

sub is_css_loc_embedded {
    my ( $self ) = @_;
    if ( !defined $self->{ $OPT_CSS_LOC_ } ) {
        return 1 if $self->has_styles();
        return;
    }
    return 1 if $self->{ $OPT_CSS_LOC_ };
    return;
} ## end sub is_css_loc_embedded

sub is_css_loc_linked {
    my ( $self ) = @_;
    if ( !defined $self->{ $OPT_CSS_LOC_ } ) {
        return if $self->has_styles();
        return 1;
    }
    return 1 unless $self->{ $OPT_CSS_LOC_ };
    return;
} ## end sub is_css_loc_linked

## --file-by-day
##     Generate separate file for each day
## --file-all-days
##     Do not generate a file for each day, default
## --file-by-guest
##     Generate a file for each guest, implies --no-file-by-judge, --no-file-by-presenter
## --no-file-by-guest
##     Do not generate a file for each guest
## --file-by-judge
##     Generate a file for each judge, implies --no-file-by-guest, --no-file-by-presenter
## --no-file-by-judge
##     Do not generate a file for each judge
## --file-by-presenter
##     Generate a file for each presenter, implies --file-by-guest, --file-by-judge
## --no-file-by-presenter
##     Do not generate a file for each presenter
## --file-everyone-together
##     Do not generate a file for each guest or presenters, default
## --file-by-room
##     Generate a file for each room
## --file-all-rooms
##     Do not generate a file for each room
## --file-by-panelist
##     Alias of --file-by-presenter
## --no-file-by-panelist
##     Alias of --no-file-by-presenter
Readonly our $OPT_FILE_BY_ => q{file-by};
Readonly our $VAL_BY_DAY   => q{/day};
Readonly our $VAL_BY_ROOM  => q{/room};

push @opt_parse,
    [
    $OPT_FILE_BY_, [ qw{ file-everyone-together } ], $MOD_FLAG,
    $VAL_EVERYONE_TOGETHER
    ],
    [
    $OPT_FILE_BY_, [ qw{ --all-days -!day } ], $MOD_SUB_FLAG,
    $VAL_BY_DAY => 0
    ],
    [ $OPT_FILE_BY_, [ qw{ -day } ],    $MOD_SUB_FLAG, $VAL_BY_DAY   => 1 ],
    [ $OPT_FILE_BY_, [ qw{ -!guest } ], $MOD_SUB_FLAG, $VAL_BY_GUEST => 0 ],
    [ $OPT_FILE_BY_, [ qw{ -guest } ],  $MOD_SUB_FLAG, $VAL_BY_GUEST => 1 ],
    [ $OPT_FILE_BY_, [ qw{ -!judge } ], $MOD_SUB_FLAG, $VAL_BY_JUDGE => 0 ],
    [ $OPT_FILE_BY_, [ qw{ -judge } ],  $MOD_SUB_FLAG, $VAL_BY_JUDGE => 1 ],
    [
    $OPT_FILE_BY_, [ qw{ -!presenter } ], $MOD_SUB_FLAG,
    $VAL_BY_PANELIST => 0
    ],
    [
    $OPT_FILE_BY_, [ qw{ -!panelist } ], $MOD_SUB_FLAG,
    $VAL_BY_PANELIST => 0
    ],
    [
    $OPT_FILE_BY_, [ qw{ -presenter } ], $MOD_SUB_FLAG,
    $VAL_BY_PANELIST => 1
    ],
    [
    $OPT_FILE_BY_, [ qw{ -panelist } ], $MOD_SUB_FLAG,
    $VAL_BY_PANELIST => 1
    ],
    [
    $OPT_FILE_BY_, [ qw{ --all-rooms -!room } ], $MOD_SUB_FLAG,
    $VAL_BY_ROOM => 0
    ],
    [ $OPT_FILE_BY_, [ qw{ -room } ], $MOD_SUB_FLAG, $VAL_BY_ROOM => 1 ],
    ;

push @opt_on_kiosk,
    [ $OPT_FILE_BY_, $MOD_FLAG ];

sub is_file_everyone_together {
    my ( $self ) = @_;
    return if $self->is_file_by_panelist();
    return if $self->is_file_by_guest();
    return if $self->is_file_by_judge();
    return 1;
} ## end sub is_file_everyone_together

sub is_file_by_day {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_FILE_BY_ }->{ $VAL_BY_DAY };
    return;
}

sub is_file_by_guest {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_FILE_BY_ };
    if ( !defined $hash ) {
        return 1 if $self->is_just_guest();
        return;
    }
    return 1 if $hash->{ $VAL_BY_GUEST };
    return   if defined $hash->{ $VAL_BY_GUEST };
    return 1 if $self->is_just_guest();
    return   if $hash->{ $VAL_BY_JUDGE };
    return   if $self->is_just_judge();
    return 1 if $hash->{ $VAL_BY_PANELIST };
    return   if defined $hash->{ $VAL_BY_PANELIST };
    return;
} ## end sub is_file_by_guest

sub is_file_by_judge {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_FILE_BY_ };
    if ( !defined $hash ) {
        return 1 if $self->is_just_judge();
        return;
    }
    return 1 if $hash->{ $VAL_BY_JUDGE };
    return   if defined $hash->{ $VAL_BY_JUDGE };
    return 1 if $self->is_just_judge();
    return   if $hash->{ $VAL_BY_GUEST };
    return   if $self->is_just_guest();
    return 1 if $hash->{ $VAL_BY_PANELIST };
    return   if defined $hash->{ $VAL_BY_PANELIST };
    return;
} ## end sub is_file_by_judge

sub is_file_by_panelist {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_FILE_BY_ };
    if ( !defined $hash ) {
        return 1 if $self->is_just_panelist();
        return;
    }
    return 1 if $hash->{ $VAL_BY_PANELIST };
    return   if defined $hash->{ $VAL_BY_PANELIST };
    return 1 if $self->is_just_panelist();
    return;
} ## end sub is_file_by_panelist

sub is_file_by_room {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_FILE_BY_ }->{ $VAL_BY_ROOM };
    return;
}

## --section-by-day
##     Generate separate section for each day
## --section-all-days
##     Do not generate a section for each day, default
## --section-by-guest
##     Generate a section for each guest
## --no-section-by-guest
##     Do not generate a section for each guest
## --section-by-judge
##     Generate a section for each judge
## --no-section-by-judge
##     Do not generate a section for each judge
## --section-by-presenter
##     Generate a section for each presenter, implies --section-by-guest
## --no-section-by-presenter
##     Do not generate a section for each presenter
## --section-everyone-together
##     Do not generate a section for each guest or presenters, default
## --section-by-room
##     Generate a section for each room
## --section-all-rooms
##     Do not generate a section for each room
## --section-by-panelist
##     Alias of --section-by-presenter
## --no-section-by-panelist
##     Alias of --no-section-by-presenter
Readonly our $OPT_SECTION_BY_ => q{section-by};

push @opt_parse,
    [
    $OPT_SECTION_BY_, [ qw{ section-everyone-together } ], $MOD_FLAG,
    $VAL_EVERYONE_TOGETHER
    ],
    [
    $OPT_SECTION_BY_, [ qw{ --all-days -!day } ], $MOD_SUB_FLAG,
    $VAL_BY_DAY => 0
    ],
    [ $OPT_SECTION_BY_, [ qw{ -day } ], $MOD_SUB_FLAG, $VAL_BY_DAY => 1 ],
    [
    $OPT_SECTION_BY_, [ qw{ -!guest } ], $MOD_SUB_FLAG,
    $VAL_BY_GUEST => 0
    ],
    [ $OPT_SECTION_BY_, [ qw{ -guest } ], $MOD_SUB_FLAG, $VAL_BY_GUEST => 1 ],
    [
    $OPT_SECTION_BY_, [ qw{ -!judge } ], $MOD_SUB_FLAG,
    $VAL_BY_JUDGE => 0
    ],
    [ $OPT_SECTION_BY_, [ qw{ -judge } ], $MOD_SUB_FLAG, $VAL_BY_JUDGE => 1 ],
    [
    $OPT_SECTION_BY_, [ qw{ -!presenter } ], $MOD_SUB_FLAG,
    $VAL_BY_PANELIST => 0
    ],
    [
    $OPT_SECTION_BY_, [ qw{ -!panelist } ], $MOD_SUB_FLAG,
    $VAL_BY_PANELIST => 0
    ],
    [
    $OPT_SECTION_BY_, [ qw{ -presenter } ], $MOD_SUB_FLAG,
    $VAL_BY_PANELIST => 1
    ],
    [
    $OPT_SECTION_BY_, [ qw{ -panelist } ], $MOD_SUB_FLAG,
    $VAL_BY_PANELIST => 1
    ],
    [
    $OPT_SECTION_BY_, [ qw{ --all-rooms -!room } ], $MOD_SUB_FLAG,
    $VAL_BY_ROOM => 0
    ],
    [ $OPT_SECTION_BY_, [ qw{ -room } ], $MOD_SUB_FLAG, $VAL_BY_ROOM => 1 ],
    ;

push @opt_on_kiosk,
    [ $OPT_SECTION_BY_, $MOD_FLAG ];

sub is_section_everyone_together {
    my ( $self ) = @_;
    return if $self->is_section_by_panelist();
    return if $self->is_section_by_guest();
    return if $self->is_section_by_judge();
    return 1;
} ## end sub is_section_everyone_together

sub is_section_by_day {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_SECTION_BY_ }->{ $VAL_BY_DAY };
    return;
}

sub is_section_by_guest {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_SECTION_BY_ };
    if ( !defined $hash ) {
        return 1 if $self->is_just_guest();
        return;
    }
    return 1 if $hash->{ $VAL_BY_GUEST };
    return   if defined $hash->{ $VAL_BY_GUEST };
    return 1 if $self->is_just_guest();
    return   if $hash->{ $VAL_BY_JUDGE };
    return   if $self->is_just_judge();
    return 1 if $hash->{ $VAL_BY_PANELIST };
    return   if defined $hash->{ $VAL_BY_PANELIST };
    return;
} ## end sub is_section_by_guest

sub is_section_by_judge {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_SECTION_BY_ };
    if ( !defined $hash ) {
        return 1 if $self->is_just_judge();
        return;
    }
    return 1 if $hash->{ $VAL_BY_JUDGE };
    return   if defined $hash->{ $VAL_BY_JUDGE };
    return 1 if $self->is_just_judge();
    return   if $hash->{ $VAL_BY_GUEST };
    return   if $self->is_just_guest();
    return 1 if $hash->{ $VAL_BY_PANELIST };
    return   if defined $hash->{ $VAL_BY_PANELIST };
    return;
} ## end sub is_section_by_judge

sub is_section_by_panelist {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_SECTION_BY_ };
    if ( !defined $hash ) {
        return 1 if $self->is_just_panelist();
        return;
    }
    return 1 if $hash->{ $VAL_BY_PANELIST };
    return   if defined $hash->{ $VAL_BY_PANELIST };
    return 1 if $self->is_just_panelist();
    return;
} ## end sub is_section_by_panelist

sub is_section_by_room {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_SECTION_BY_ }->{ $VAL_BY_ROOM };
    return;
}

## --input _file_.txt
##     Source data for schedule, UTF-16 spreadsheet
## --input _file_.xlsx
##     Source data for schedule, xlsx file
## --input _file_.xlsx:_num_
##     May have a _num_ suffix to select a sheet by index

Readonly our $OPT_INPUT_ => q{input};

push @opt_parse,
    [ $OPT_INPUT_, [ qw{ input } ], $MOD_VALUE_STR ];

sub get_input_file {
    my ( $self ) = @_;
    return $self->{ $OPT_INPUT_ };
}

## --just-guest
##     Hide descriptions for other presenters, implies --file-by-guest
## --just-judge
##     Hide descriptions for other presenters, implies --file-by-judge
## --just-presenter
##     Hide descriptions for other presenters, implies --file-by-presenter
## --just-panelist
##     Alias of --just-presenter
## --everyone
##     Show descriptions for all presenters, default
Readonly our $OPT_JUST_ => q{just};

push @opt_parse,
    [ $OPT_JUST_, [ qw{ everyone } ], $MOD_FLAG,     $VAL_EVERYONE_TOGETHER ],
    [ $OPT_JUST_, [ qw{ -guest } ],   $MOD_SUB_FLAG, $VAL_BY_GUEST => 1 ],
    [ $OPT_JUST_, [ qw{ -judge } ],   $MOD_SUB_FLAG, $VAL_BY_JUDGE => 1 ],
    [
    $OPT_JUST_, [ qw{ -presenter } ], $MOD_SUB_FLAG,
    $VAL_BY_PANELIST => 1
    ],
    [ $OPT_JUST_, [ qw{ -panelist } ], $MOD_SUB_FLAG, $VAL_BY_PANELIST => 1 ],
    ;

push @opt_on_kiosk,
    [ $OPT_JUST_, $MOD_FLAG ];

sub is_just_everyone {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_JUST_ };
    return 1 unless defined $hash;
    return if $hash->{ $VAL_BY_GUEST };
    return if $hash->{ $VAL_BY_JUDGE };
    return if $hash->{ $VAL_BY_PANELIST };
    return 1;
} ## end sub is_just_everyone

sub is_just_guest {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_JUST_ };
    return unless defined $hash;
    return 1 if $hash->{ $VAL_BY_GUEST };
    return   if defined $hash->{ $VAL_BY_GUEST };
    return   if $hash->{ $VAL_BY_JUDGE };
    return 1 if $hash->{ $VAL_BY_PANELIST };
    return;
} ## end sub is_just_guest

sub is_just_judge {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_JUST_ };
    return unless defined $hash;
    return 1 if $hash->{ $VAL_BY_JUDGE };
    return   if defined $hash->{ $VAL_BY_JUDGE };
    return   if $hash->{ $VAL_BY_GUEST };
    return 1 if $hash->{ $VAL_BY_PANELIST };
    return;
} ## end sub is_just_judge

sub is_just_panelist {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_JUST_ }->{ $VAL_BY_PANELIST };
    return;
}

## --mode-flyer
##     Generate flyers, default mode
## --mode-kiosk
##     Generate files for use in a realtime kiosk
## --mode-postcard
##     Output for use in schedule postcards

Readonly our $OPT_MODE_           => q{mode};
Readonly our $VAL_MODE_FLYER_     => q{flyer};
Readonly our $VAL_MODE_KIOSK_     => q{kiosk};
Readonly our $VAL_MODE_POSTCACRD_ => q{postcard};

push @opt_parse,
    [ $OPT_MODE_, [ qw{ -flyer flyer } ], $MOD_FLAG, $VAL_MODE_FLYER_ ],
    [ $OPT_MODE_, [ qw{ -kiosk kiosk } ], $MOD_FLAG, $VAL_MODE_KIOSK_ ],
    [
    $OPT_MODE_, [ qw{ -postcard postcard } ], $MOD_FLAG,
    $VAL_MODE_POSTCACRD_
    ];

sub get_mode_ {
    my ( $self ) = @_;
    return $self->{ $OPT_MODE_ } // $VAL_MODE_FLYER_;
}

sub is_mode_flyer {
    my ( $self ) = @_;
    return 1 if $self->get_mode_() eq $VAL_MODE_FLYER_;
    return;
}

sub is_mode_kiosk {
    my ( $self ) = @_;
    return 1 if $self->get_mode_() eq $VAL_MODE_KIOSK_;
    return;
}

sub is_mode_postcard {
    my ( $self ) = @_;
    return 1 if $self->get_mode_() eq $VAL_MODE_POSTCACRD_;
    return;
}

## --output _name_
##     Output filename or directory if any --file-by-... used

Readonly our $OPT_OUTPUT_ => q{output};

push @opt_parse,
    [ $OPT_OUTPUT_, [ qw{ output } ], $MOD_VALUE_STR ];

sub get_output_file {
    my ( $self ) = @_;
    return $self->{ $OPT_OUTPUT_ } // q{-};
}

sub is_output_stdio {
    my ( $self ) = @_;
    my $out = $self->get_output_file();
    return 1 if $out eq q{-};
    return 1 if $out eq q{/dev/stdout};
    return;
} ## end sub is_output_stdio

## --room _name_
##     Focus on matching room, may be given more than once

Readonly our $OPT_ROOM_ => q{room};

push @opt_parse,
    [ $OPT_ROOM_, [ qw{ room } ], $MOD_LIST ];

push @opt_on_kiosk,
    [ $OPT_ROOM_, $MOD_FLAG, undef ];

sub get_rooms {
    my ( $self ) = @_;
    my $rooms = $self->{ $OPT_ROOM_ };
    return @{ $rooms } if ref $rooms;
    return $rooms      if $rooms;
    return;
} ## end sub get_rooms

sub has_rooms {
    my ( $self ) = @_;
    my $rooms = $self->{ $OPT_ROOM_ };
    return 1 if defined $rooms;
    return;
} ## end sub has_rooms

## --show-room _room_
##     Show room, even if normally hidden
## --hide-room _room_
##     Hide room, even if normally shown
## --show-paneltype _paneltype_
##     Show paneltype even if normally hidden
## --hide-paneltype _paneltype_
##     Hide paneltype even if normally shown

Readonly our $OPT_ROOM_VIS      => q{room-vis};
Readonly our $OPT_PANELTYPE_VIS => q{panel-vis};

push @opt_parse,
    [ $OPT_ROOM_VIS,      [ qw{ show-room } ],      $MOD_NAMED_STATE, 1, ],
    [ $OPT_ROOM_VIS,      [ qw{ hide-room } ],      $MOD_NAMED_STATE, 0, ],
    [ $OPT_PANELTYPE_VIS, [ qw{ show-paneltype } ], $MOD_NAMED_STATE, 1, ],
    [ $OPT_PANELTYPE_VIS, [ qw{ hide-paneltype } ], $MOD_NAMED_STATE, 0, ],
    ;

sub get_rooms_shown {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_ROOM_VIS };
    return unless defined $hash;
    return grep { $hash->{ $_ } } keys %{ $hash };
} ## end sub get_rooms_shown

sub get_rooms_hidden {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_ROOM_VIS };
    return unless defined $hash;
    return grep { !$hash->{ $_ } } keys %{ $hash };
} ## end sub get_rooms_hidden

sub get_paneltypes_shown {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_PANELTYPE_VIS };
    return unless defined $hash;
    return grep { $hash->{ $_ } } keys %{ $hash };
} ## end sub get_paneltypes_shown

sub get_paneltypes_hidden {
    my ( $self ) = @_;
    my $hash = $self->{ $OPT_PANELTYPE_VIS };
    return unless defined $hash;
    return grep { !$hash->{ $_ } } keys %{ $hash };
} ## end sub get_paneltypes_hidden

## --show-all-rooms
##     Show rooms even if they have no events scheduled
## --hide-unused-rooms
##     Only include rooms that have events scheduled, default
## --show-av
##     Include notes for Audio Visual
## --hide-av
##     Do not include notes for Audio Visual, default
## --show-breaks
##     Includes descriptions for breaks
## --hide-breaks
##     Hide descriptions for breaks, default
## --show-free
##     Show descriptions for panels that are free, implies --hide-premium, --hide-kids
## --hide-free
##     Hide descriptions for panels that are free
## --show-kids
##     Show descriptions for panels that are kids, implies --hide-premium, --hide-free
## --hide-kids
##     Hide descriptions for panels that are kids
## --show-premium
##     Show descriptions for panels that are premium, implies --hide-free, --hide-kids
## --hide-premium
##     Hide descriptions for panels that are premium
## --show-day
##     Include a column for week day
## --hide-day
##     Does not include a column for week day, default
## --show-difficulty
##     Show difficulty information, default
## --hide-difficulty
##     Hide difficulty information
## --show-descriptions
##     Includes panel descriptions, implies --hide-grid
## --hide-descriptions
##     Does not include description, implies --show-grid
## --show-grid
##     Includes the grid, implies --hide-description
## --hide-grid
##     Does not includes the grid, implies --show-description
## --show-presenter-on-grid
##     Replace "time" with presenter name
## --hide-presenter-on-grid
##     Do not replace "time" with presenter name, default
## --just-descriptions
##     Alias of --show-descriptions --hide-grid
## --just-free
##     Alias of --show-free --hide-premium --hide-kids
## --just-grid
##     Alias of --show-grid --hide-descriptions
## --just-kids
##     Alias of --show-kids --hide-premium --hide-free
## --just-premium
##     Alias of --show-premium --hide-free --hide-kids

Readonly our $OPT_SHOW                 => q{show/hide};
Readonly our $VAL_SHOW_ALL_ROOMS_      => q{/all-rooms};
Readonly our $VAL_SHOW_AV_             => q{/av};
Readonly our $VAL_SHOW_BREAKS_         => q{/breaks};
Readonly our $VAL_SHOW_COST_FREE_      => q{/free};
Readonly our $VAL_SHOW_COST_KIDS_      => q{/kids};
Readonly our $VAL_SHOW_COST_PREMIUM_   => q{/premium};
Readonly our $VAL_SHOW_DAY_COLUMN_     => q{/day-column};
Readonly our $VAL_SHOW_DIFFICULTY_     => q{/difficulty};
Readonly our $VAL_SHOW_SECT_DESC_      => q{/descriptions};
Readonly our $VAL_SHOW_SECT_GRID_      => q{/grid};
Readonly our $VAL_SHOW_TIME_PRESENTER_ => q{/presenter-as-time};

push @opt_parse,
    [
    $OPT_SHOW, [ qw{ -!unused-rooms } ], $MOD_SUB_FLAG,
    $VAL_SHOW_ALL_ROOMS_ => 0
    ],
    [
    $OPT_SHOW, [ qw{ -all-rooms -unused-rooms} ], $MOD_SUB_FLAG,
    $VAL_SHOW_ALL_ROOMS_ => 1
    ],
    [ $OPT_SHOW, [ qw{ -!av } ],     $MOD_SUB_FLAG, $VAL_SHOW_AV_      => 0 ],
    [ $OPT_SHOW, [ qw{ -av } ],      $MOD_SUB_FLAG, $VAL_SHOW_AV_      => 1 ],
    [ $OPT_SHOW, [ qw{ -!breaks } ], $MOD_SUB_FLAG, $VAL_SHOW_BREAKS_  => 0 ],
    [ $OPT_SHOW, [ qw{ -breaks } ],  $MOD_SUB_FLAG, $VAL_SHOW_BREAKS_  => 1 ],
    [ $OPT_SHOW, [ qw{ -!free } ], $MOD_SUB_FLAG, $VAL_SHOW_COST_FREE_ => 0 ],
    [ $OPT_SHOW, [ qw{ -free } ],  $MOD_SUB_FLAG, $VAL_SHOW_COST_FREE_ => 1 ],
    [
    $OPT_SHOW, [ qw{ just-free } ], $MOD_SUB_FLAG, $VAL_SHOW_COST_FREE_ => 1,
    $VAL_SHOW_COST_KIDS_    => 0,
    $VAL_SHOW_COST_PREMIUM_ => 0
    ],
    [ $OPT_SHOW, [ qw{ -!kids } ], $MOD_SUB_FLAG, $VAL_SHOW_COST_KIDS_ => 0 ],
    [ $OPT_SHOW, [ qw{ -kids } ],  $MOD_SUB_FLAG, $VAL_SHOW_COST_KIDS_ => 1 ],
    [
    $OPT_SHOW, [ qw{ just-kids } ], $MOD_SUB_FLAG, $VAL_SHOW_COST_KIDS_ => 1,
    $VAL_SHOW_COST_FREE_    => 0,
    $VAL_SHOW_COST_PREMIUM_ => 0
    ],
    [
    $OPT_SHOW, [ qw{ -!premium } ], $MOD_SUB_FLAG,
    $VAL_SHOW_COST_PREMIUM_ => 0
    ],
    [
    $OPT_SHOW, [ qw{ -premium } ], $MOD_SUB_FLAG,
    $VAL_SHOW_COST_PREMIUM_ => 1
    ],
    [
    $OPT_SHOW, [ qw{ just-premium } ], $MOD_SUB_FLAG,
    $VAL_SHOW_COST_PREMIUM_ => 1, $VAL_SHOW_COST_FREE_ => 0,
    $VAL_SHOW_COST_KIDS_    => 0
    ],
    [ $OPT_SHOW, [ qw{ -!day } ], $MOD_SUB_FLAG, $VAL_SHOW_DAY_COLUMN_ => 0 ],
    [ $OPT_SHOW, [ qw{ -day } ],  $MOD_SUB_FLAG, $VAL_SHOW_DAY_COLUMN_ => 1 ],
    [
    $OPT_SHOW, [ qw{ -!difficulty } ], $MOD_SUB_FLAG,
    $VAL_SHOW_DIFFICULTY_ => 0
    ],
    [
    $OPT_SHOW, [ qw{ -difficulty } ], $MOD_SUB_FLAG,
    $VAL_SHOW_DIFFICULTY_ => 1
    ],
    [
    $OPT_SHOW, [ qw{ -!descriptions } ], $MOD_SUB_FLAG,
    $VAL_SHOW_SECT_DESC_ => 0
    ],
    [
    $OPT_SHOW, [ qw{ -descriptions descriptions } ], $MOD_SUB_FLAG,
    $VAL_SHOW_SECT_DESC_ => 1
    ],
    [
    $OPT_SHOW, [ qw{ just-descriptions } ], $MOD_SUB_FLAG,
    $VAL_SHOW_SECT_DESC_ => 1,
    $VAL_SHOW_SECT_GRID_ => 0
    ],
    [ $OPT_SHOW, [ qw{ -!grid } ], $MOD_SUB_FLAG, $VAL_SHOW_SECT_GRID_ => 0 ],
    [
    $OPT_SHOW, [ qw{ -grid grid } ], $MOD_SUB_FLAG,
    $VAL_SHOW_SECT_GRID_ => 1
    ],
    [
    $OPT_SHOW, [ qw{ just-grid } ], $MOD_SUB_FLAG,
    $VAL_SHOW_SECT_GRID_ => 1, $VAL_SHOW_SECT_DESC_ => 0
    ],
    [
    $OPT_SHOW, [ qw{ -!presenter-on-grid } ], $MOD_SUB_FLAG,
    $VAL_SHOW_TIME_PRESENTER_ => 0
    ],
    [
    $OPT_SHOW, [ qw{ -presenter-on-grid } ], $MOD_SUB_FLAG,
    $VAL_SHOW_TIME_PRESENTER_ => 1
    ],
    ;

push @opt_on_kiosk,
    [ $OPT_SHOW, $MOD_SUB_FLAG, $VAL_SHOW_BREAKS_       => 1 ],
    [ $OPT_SHOW, $MOD_SUB_FLAG, $VAL_SHOW_COST_FREE_    => 1 ],
    [ $OPT_SHOW, $MOD_SUB_FLAG, $VAL_SHOW_COST_PREMIUM_ => 1 ],
    [ $OPT_SHOW, $MOD_SUB_FLAG, $VAL_SHOW_DAY_COLUMN_   => undef ],
    [ $OPT_SHOW, $MOD_SUB_FLAG, $VAL_SHOW_SECT_DESC_    => 1 ],
    [ $OPT_SHOW, $MOD_SUB_FLAG, $VAL_SHOW_SECT_GRID_    => 1 ],
    ;

sub show_all_rooms {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_SHOW }->{ $VAL_SHOW_ALL_ROOMS_ };
    return;
}

sub hide_unused_rooms {
    my ( $self ) = @_;
    return 1 unless $self->{ $OPT_SHOW }->{ $VAL_SHOW_ALL_ROOMS_ };
    return;
}

sub show_av {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_SHOW }->{ $VAL_SHOW_AV_ };
    return;
}

sub hide_av {
    my ( $self ) = @_;
    return 1 unless $self->{ $OPT_SHOW }->{ $VAL_SHOW_AV_ };
    return;
}

sub show_break {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_SHOW }->{ $VAL_SHOW_BREAKS_ };
    return;
}

sub hide_breaks {
    my ( $self ) = @_;
    return 1 unless $self->{ $OPT_SHOW }->{ $VAL_SHOW_BREAKS_ };
    return;
}

sub show_cost_free {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_SHOW }->{ $VAL_SHOW_COST_FREE_ };
    return   if defined $self->{ $OPT_SHOW }->{ $VAL_SHOW_COST_FREE_ };
    return   if $self->{ $OPT_SHOW }->{ $VAL_SHOW_COST_KIDS_ };
    return   if $self->{ $OPT_SHOW }->{ $VAL_SHOW_COST_PREMIUM_ };
    return 1;
} ## end sub show_cost_free

sub show_cost_kids {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_SHOW }->{ $VAL_SHOW_COST_KIDS_ };
    return   if defined $self->{ $OPT_SHOW }->{ $VAL_SHOW_COST_KIDS_ };
    return   if $self->{ $OPT_SHOW }->{ $VAL_SHOW_COST_FREE_ };
    return   if $self->{ $OPT_SHOW }->{ $VAL_SHOW_COST_PREMIUM_ };
    return 1;
} ## end sub show_cost_kids

sub show_cost_premium {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_SHOW }->{ $VAL_SHOW_COST_PREMIUM_ };
    return   if defined $self->{ $OPT_SHOW }->{ $VAL_SHOW_COST_PREMIUM_ };
    return   if $self->{ $OPT_SHOW }->{ $VAL_SHOW_COST_FREE_ };
    return   if $self->{ $OPT_SHOW }->{ $VAL_SHOW_COST_KIDS_ };
    return 1;
} ## end sub show_cost_premium

sub show_day_column {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_SHOW }->{ $VAL_SHOW_DAY_COLUMN_ };
    return;
}

sub hide_day_column {
    my ( $self ) = @_;
    return 1 unless $self->{ $OPT_SHOW }->{ $VAL_SHOW_DAY_COLUMN_ };
    return;
}

sub show_difficulty {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_SHOW }->{ $VAL_SHOW_DIFFICULTY_ };
    return   if defined $self->{ $OPT_SHOW }->{ $VAL_SHOW_DIFFICULTY_ };
    return 1;
} ## end sub show_difficulty

sub hide_difficulty {
    my ( $self ) = @_;
    return   if $self->{ $OPT_SHOW }->{ $VAL_SHOW_DIFFICULTY_ };
    return 1 if defined $self->{ $OPT_SHOW }->{ $VAL_SHOW_DIFFICULTY_ };
    return;
} ## end sub hide_difficulty

sub show_sect_descriptions {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_SHOW }->{ $VAL_SHOW_SECT_DESC_ };
    return   if defined $self->{ $OPT_SHOW }->{ $VAL_SHOW_SECT_DESC_ };
    return   if $self->{ $OPT_SHOW }->{ $VAL_SHOW_SECT_GRID_ };
    return 1;
} ## end sub show_sect_descriptions

sub show_sect_grid {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_SHOW }->{ $VAL_SHOW_SECT_GRID_ };
    return   if defined $self->{ $OPT_SHOW }->{ $VAL_SHOW_SECT_GRID_ };
    return   if $self->{ $OPT_SHOW }->{ $VAL_SHOW_SECT_DESC_ };
    return 1;
} ## end sub show_sect_grid

sub show_presenter_as_time {
    my ( $self ) = @_;
    return 1 if $self->{ $OPT_SHOW }->{ $VAL_SHOW_TIME_PRESENTER_ };
    return;
}

## --unified
##     Do not split table by SPLIT time segments or days
## --split-timeregion
##     Split the grids by SPLIT time segments, default
## --split-day
##     Only split once per day
## --split
##     Implies --split-timeregion if --split-day not set
## --split-half-day
##     Alias of --split-timeregion

Readonly our $OPT_SPLIT_            => q{split};
Readonly our $VAL_SPLIT_NONE_       => q{none};
Readonly our $VAL_SPLIT_TIMEREGION_ => q{timeregion};
Readonly our $VAL_SPLIT_DAY_        => q{day};

push @opt_parse,
    [ $OPT_SPLIT_, [ qw{ unified no-split } ], $MOD_FLAG, $VAL_SPLIT_NONE_ ],
    [ $OPT_SPLIT_, [ qw{ -timeregion } ], $MOD_FLAG, $VAL_SPLIT_TIMEREGION_ ],
    [ $OPT_SPLIT_, [ qw{ -half-day } ],   $MOD_FLAG, $VAL_SPLIT_TIMEREGION_ ],
    [ $OPT_SPLIT_, [ qw{ -day } ],        $MOD_FLAG, $VAL_SPLIT_DAY_ ],
    [
    $OPT_SPLIT_,
    [ qw{ split } ],
    $MOD_SPECIAL,
    sub {
        my ( $self ) = @_;
        return if $self->{ $OPT_SPLIT_ } eq $VAL_SPLIT_DAY_;
        $self->{ $OPT_SPLIT_ } = $VAL_SPLIT_TIMEREGION_;
        return;
    }
    ];

push @opt_on_kiosk,
    [ $OPT_SPLIT_, $MOD_FLAG, $VAL_SPLIT_NONE_ ];

sub get_split_ {
    my ( $self ) = @_;
    return $self->{ $OPT_SPLIT_ } // $VAL_SPLIT_TIMEREGION_;
}

sub is_split_none {
    my ( $self ) = @_;
    return 1 if $self->get_split_() eq $VAL_SPLIT_NONE_;
    return;
}

sub is_split_timeregion {
    my ( $self ) = @_;
    return 1 if $self->get_split_() eq $VAL_SPLIT_TIMEREGION_;
    return;
}

sub is_split_day {
    my ( $self ) = @_;
    return 1 if $self->get_split_() eq $VAL_SPLIT_DAY_;
    return;
}

## --style _filename_
##     CSS file to include, may be given more than once, implies --embed-css
## --style +color[=_set_]
##     Use colors from the panel type sheet, _set_ is "Color" if not given.
## --style all:_style_
##     Apply style to all media
## --style screen:_style_
##     Apply style to when viewing on a screen, normal web view
## --style print:_style_
##     Apply style to when printing, normal web view

Readonly our $OPT_STYLE_ => q{style};

push @opt_parse,
    [ $OPT_STYLE_, [ qw{ style } ], $MOD_LIST ];

push @opt_on_kiosk,
    [ $OPT_STYLE_, $MOD_FLAG, [ qw{+color} ] ];

sub get_styles {
    my ( $self ) = @_;
    my $styles = $self->{ $OPT_STYLE_ };
    return @{ $styles } if ref $styles;
    return $styles      if $styles;
    return qw{ index.css };
} ## end sub get_styles

sub has_styles {
    my ( $self ) = @_;
    my $styles = $self->{ $OPT_STYLE_ };
    return 1 if defined $styles;
    return;
} ## end sub has_styles

## --end-time _time_
##     Exclude any panels after _time_
## --start-time _time_
##     Exclude any panels before _time_

Readonly our $OPT_TIME_       => q{time};
Readonly our $VAL_TIME_END_   => q{end};
Readonly our $VAL_TIME_START_ => q{start};

push @opt_parse,
    [ $OPT_TIME_, [ qw{ end-time } ],   $MOD_SUB_VALUE, $VAL_TIME_END_ ],
    [ $OPT_TIME_, [ qw{ start-time } ], $MOD_SUB_VALUE, $VAL_TIME_START_ ],
    ;

sub get_time_end {
    my ( $self ) = @_;
    my $time = $self->{ $OPT_TIME_ }->{ $VAL_TIME_END_ };
    $time = text_to_datetime( $time ) if defined $time;
    return $time if defined $time;
    return;
} ## end sub get_time_end

sub get_time_start {
    my ( $self ) = @_;
    my $time = $self->{ $OPT_TIME_ }->{ $VAL_TIME_START_ };
    $time = text_to_datetime( $time ) if defined $time;
    return $time if defined $time;
    return;
} ## end sub get_time_start

## --title _name_
##     Sets the page titles

Readonly our $OPT_TITLE_ => q{title};

push @opt_parse,
    [ $OPT_TITLE_, [ qw{ title } ], $MOD_VALUE_STR ];

sub get_title {
    my ( $self ) = @_;
    return $self->{ $OPT_TITLE_ } // q{Cosplay America 2024 Schedule};
}

## --pre-title _name_
##     Sets the prefix for the title

Readonly our $OPT_TITLE_PREFIX_ => q{title_prefix};

push @opt_parse,
    [ $OPT_TITLE_PREFIX_, [ qw{ pre-title } ], $MOD_VALUE_STR ];

sub get_pre_title {
    my ( $self ) = @_;
    return $self->{ $OPT_TITLE_PREFIX_ } // q{Cosplay America 2024 Schedule};
}

## --copies _number_
##     How many copies in the same html

Readonly our $OPT_COPIES_ => q{copies};

push @opt_parse,
    [ $OPT_COPIES_, [ qw{ copies } ], $MOD_VALUE_NUM ];

sub get_copies {
    my ( $self ) = @_;
    return $self->{ $OPT_COPIES_ } || 1;
}

sub register_option_ {
    my ( $known, @names ) = @_;

    return unless @names;

    my $option_doc = parse_internal_doc_();
    my $first_known;

    foreach my $opt_name ( @names ) {
        my $detail = $option_doc->{ $opt_name };
        next unless defined $detail;
        $known->{ $opt_name } = $detail;
        $first_known //= $opt_name;
    } ## end foreach my $opt_name ( @names)
    foreach my $opt_name ( @names ) {
        next if defined $known->{ $opt_name };
        if ( !defined $first_known ) {
            $known->{ $opt_name }
                = [ q{--} . $opt_name . qq{\n  **Unknown option**} ];
            $first_known = $opt_name;
        }
        else {
            $known->{ $opt_name }
                = [ q{--} . $opt_name . qq{\n  Alias of --} . $first_known ];
        }
    } ## end foreach my $opt_name ( @names)

    return;
} ## end sub register_option_

sub get_known_options_doc_ {
    state $known_opts;
    return $known_opts if defined $known_opts;

    my %known_opts;
    $known_opts = \%known_opts;

    foreach my $opt_set ( @opt_parse ) {
        register_option_(
            \%known_opts,
            get_getopt_flag_names_( $opt_set )
        );
    } ## end foreach my $opt_set ( @opt_parse)

    ## Special options
    register_option_( \%known_opts, qw{ help help-markdown } );

    return $known_opts;
} ## end sub get_known_options_doc_

## --help
##   Display options
Readonly our $OPT_HELP_FLAG => q{--help};

sub dump_help {
    my ( @help ) = @_;
    push @help, q{} unless @help;

    my $option_doc = parse_internal_doc_();
    my $known_opts = get_known_options_doc_();

    my @all_options = keys %{ $known_opts };
    if ( any { $_ eq q{} } @help ) {
        @help = @all_options;
    }
    @help = uniq apply { s{\A--*}{}xmsg } @help;

    foreach my $opt_name ( sort @help ) {
        my $vals = $known_opts->{ $opt_name } // $option_doc->{ $opt_name };
        if ( !defined $vals ) {
            my @possible
                = grep { $opt_name eq substr $_, 0, length $opt_name }
                sort @all_options;
            if ( 1 == scalar @possible ) {
                say q{--}, $opt_name, qq{\n  Abbreviation of --}, @possible
                    or 0;
                next;
            }
            say q{--}, $opt_name, qq{\n  No such option},
                join qq{\n    Did you mean --}, q{}, @possible
                or 0;
            next;
        } ## end if ( !defined $vals )
        say join qq{\n}, @{ $known_opts->{ $opt_name } } or 0;
    } ## end foreach my $opt_name ( sort...)

    foreach my $opt_name ( sort keys %{ $option_doc } ) {
        next if exists $known_opts->{ $opt_name };
        say q{Option not defined: }, $opt_name or 0;
    }

    return;
} ## end sub dump_help

sub dump_help_from_options {
    my ( @args ) = @_;

    my @help;
    my $skip_help = 1;

    foreach my $option ( @args ) {
        if ( $option eq $OPT_HELP_FLAG && $skip_help ) {
            undef $skip_help;
            next;
        }
        next unless $option =~ s{\A --}{}xms;
        $option =~ s{=.*}{}xms;
        next if $option eq q{};
        push @help, $option;
    } ## end foreach my $option ( @args )

    dump_help( @help );
    exit 0;
} ## end sub dump_help_from_options

sub dump_table_ {
    my ( @table ) = @_;

    my @len;

    foreach my $row ( @table ) {
        my @row = @{ $row };
        for my $index ( 0 .. $#row ) {
            my $item_len = length $row[ $index ];
            my $len      = $len[ $index ] // $item_len;
            $len = $item_len if $item_len > $len;
            $len[ $index ] = $len;
        } ## end for my $index ( 0 .. $#row)
    } ## end foreach my $row ( @table )

    foreach my $row ( @table ) {
        my @row = @{ $row };
        my @output;
        for my $index ( 0 .. $#len ) {
            my $len = $len[ $index ];
            my $val;
            if ( @row ) {
                $val = $row[ $index ] // q{};
                my $val_len = length $val;
                my $rem_len = $len - $val_len;
                $val .= q{ } x $rem_len if $rem_len > 0;
            } ## end if ( @row )
            else {
                $val = q{-} x $len;
            }
            push @output, q{ } . $val . q{ };
        } ## end for my $index ( 0 .. $#len)
        say join q{|}, q{}, @output, q{} or 0 if @output;
    } ## end foreach my $row ( @table )

    say q{} or 0;

    return;
} ## end sub dump_table_

## --help-markdown
##   Generate option summary for README.md
Readonly our $OPT_HELP_MD_FLAG => q{--help-markdown};

sub dump_help_markdown {
    my $option_doc = get_known_options_doc_();

    my @main_output;
    my @alias_output;

    foreach my $opt_name ( sort keys %{ $option_doc } ) {
        my $vals = $option_doc->{ $opt_name };
        next unless defined $vals;
        foreach my $val ( @{ $vals } ) {
            my ( $example, $meaning ) = split m{\s*\n\s*}xms, $val, 2;
            $meaning =~ s{\s*\n\s*}{}xmsg;
            $meaning =~ s{\A \s*}{}xmsg;
            if ( $meaning =~ s{\A Alias \s of \s }{}xms ) {
                push @alias_output, [ $example, $meaning ];
            }
            else {
                push @main_output, [ $example, $meaning ];
            }
        } ## end foreach my $val ( @{ $vals ...})
    } ## end foreach my $opt_name ( sort...)

    dump_table_( [ q{Option}, q{Meaning} ], [], @main_output );
    dump_table_(
        [ q{Alias}, q{Equivalent to option} ], [],
        @alias_output
    );

    exit 0;
} ## end sub dump_help_markdown

sub options_from {
    my ( $class, $args ) = @_;
    $class = ref $class || $class;

    my $opt = bless {}, $class;

    my @before_dashes = before { $_ eq q{--} } @{ $args };

    ## Special help option recognize anywhere
    dump_help_from_options( @before_dashes )
        if any { $_ eq $OPT_HELP_FLAG } @before_dashes;
    dump_help_markdown( @before_dashes )
        if any { $_ eq $OPT_HELP_MD_FLAG } @before_dashes;

    GetOptionsFromArray(
        $args,
        $opt,

        map { $opt->get_getopt_flag_( $_ ) } @opt_parse,
    ) or dump_help_from_options( @before_dashes );

    if ( $opt->is_mode_kiosk() ) {
        foreach my $opt_kiosk_set ( @opt_on_kiosk ) {
            $opt->on_kiosk_( $opt_kiosk_set );
        }
    }

    die qq{All free, kids, and premium panels hidden\n}
        unless $opt->show_cost_free()
        || $opt->show_cost_premium()
        || $opt->show_cost_kids();

    die qq{Both grid and descriptions hidden\n}
        unless $opt->show_sect_descriptions() || $opt->show_sect_grid();

    $Data::Dumper::Sortkeys = 1;
    say Data::Dumper->Dump( [ $opt ], [ qw{$opt} ] ) or 0;

    return $opt;
} ## end sub options_from

1;

