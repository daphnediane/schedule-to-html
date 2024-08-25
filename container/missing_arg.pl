#!/usr/bin/perl

use common::sense;
use File::Slurp qw{ read_file };

my $file = shift // q{-};
my $lines = read_file( $file, { chomp => 1, array_ref => 1 } );

my $chunk= [ q{} ];
my %vars_seen;
my %vars_defined;

sub dump_chunk() {
    my %old_vars = %vars_seen;
    my @current_chunk = @{ $chunk };
    $chunk = [ q{} ];
    %vars_seen = ();
    %vars_defined = ();
    shift @current_chunk if $current_chunk[0] eq q{};
    return unless @current_chunk;
    
    if ( %old_vars ) {
        say q{};
        foreach my $var ( sort keys %old_vars ) {
            say q{ARG }, $var;
        }
    }
    say q{};
    say join qq{\n}, @current_chunk;
}

for my $line ( @{ $lines } ) {
    next if $line =~ m{ \A \s* ARG \s+ \w+ \s* \z }xms;

    if ( $line ne q{} || $chunk->[-1] ne q{} ) {
        push @{ $chunk }, $line;        
    }
    if ( $line =~ m{ \A \s* ARG \s+ ( \w+ ) }xms ) {
        $vars_defined{ $1 } = 1;
    }
    while ( $line =~ m{ \$ \{ ( \w* ) \} }xmsg ) {
        $vars_seen{ $1 } = 1 unless $vars_defined{ $1 };
    }
    next unless $line =~ m{ \A \s* FROM \b }xms;

    dump_chunk();
}

dump_chunk();

1;
