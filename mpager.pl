#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Term::ANSIColor qw/colored/;

my $match_null = qr/(?:^NULL\s*)|(?:\s*NULL$)/; # XXX rewrite?
my $match_int  = qr/^\s*-?\d+\.?\d*$/;
my $match_date = qr/^(?:[0-9]{4}-[0-9]{2}-[0-9]{2})|(?:[0-9]{2}:[0-9]{2}:[0-9]{2})/;

# First line with +---+-----+
my $header = <>;
my $columns = [];

print $header;
if ( $header =~ /^\+(?:-+\+)+$/ ) {
    my $start = 2;
    my @cols = split /\+/, $header;
    
    for my $minus ( @cols[1..$#cols-1] ) {
        my $length = length($minus) - 2;
        next if $length < 0;
        
        push @$columns, [$start, $length];

        $start += $length + 3;
    }
} else {
	print <>;
	exit;
}

# XXX bold headers
{
    my $x = <>;
    print $x;
}

while (my $line = <>) {
   if ( $line =~ /^\+/ ) {
		print $line;
		next;
	}

    for my $slice ( reverse(@$columns) ) {
        my $value = substr($line, $slice->[0], $slice->[1]);

		my $color;
		if ( $value =~ $match_null ) {
			$color = ["cyan"];
		} elsif ( $value =~ $match_int ) {
			$color = ["green"];
		} elsif ( $value =~ $match_date ) {
			$color = ["yellow"];
		}
		next unless $color;
		
		substr($line, $slice->[0], $slice->[1]) = colored($color, $value);
    }

    print $line;
}

#print join("..", @$_)."\n" foreach @$columns;
print "\n";
