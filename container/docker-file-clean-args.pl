#!/usr/bin/perl

use common::sense;
use File::Slurp qw{ read_file };

my $file  = shift // q{-};
my $lines = read_file( $file, { chomp => 1, array_ref => 1 } );

my $chunk = [ q{} ];
my %vars_seen;
my %vars_defined;
my %vars_global;
my %vars_ignore = (
    archBits => 1,
    archFlag => 1,
    gnuArch  => 1,
    runDeps  => 1,
);
my $is_global = 1;

sub dump_chunk() {
    my %old_vars      = %vars_seen;
    my @current_chunk = @{ $chunk };
    $chunk        = [ q{} ];
    %vars_seen    = ();
    %vars_defined = ();
    shift @current_chunk if $current_chunk[ 0 ] eq q{};
    return unless @current_chunk;

    if ( %old_vars ) {
        say q{};
        foreach my $var ( sort keys %old_vars ) {
            say q{ARG }, $var;
        }
    } ## end if ( %old_vars )
    say q{};
    say join qq{\n}, @current_chunk;
} ## end sub dump_chunk

for my $line ( @{ $lines } ) {
    if ( $line =~ m{ \A \s* ARG \s+ ( \w+ ) \s* \z }xms ) {
        $vars_global{ $1 } = 1 if $is_global;
        next;
    }

    if ( $line ne q{} || $chunk->[ -1 ] ne q{} ) {
        push @{ $chunk }, $line;
    }
    if ( $line =~ m{ \A \s* ARG \s+ ( \w+ ) }xms ) {
        $vars_defined{ $1 } = 1;
        $vars_global{ $1 }  = 1 if $is_global;
    }
    while ( $line =~ m{ \$ \{ ( \w* ) \} }xmsg ) {
        next if $vars_ignore{ $1 };
        $vars_seen{ $1 } = 1    unless $vars_defined{ $1 };
        warn qq{No global $1\n} unless defined $vars_global{ $1 };
        $vars_global{ $1 } = 1;
    } ## end while ( $line =~ m{ \$ \{ ( \w* ) \} }xmsg)
    next unless $line =~ m{ \A \s* FROM \b }xms;
    undef $is_global;

    dump_chunk();
} ## end for my $line ( @{ $lines...})

dump_chunk();

1;
