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
my $magic;
if ( $header =~ /^\+(?:-+\+)+$/ ) {
    my $start = 2;
    my @cols = split /\+/, $header;
    
    for my $minus ( @cols[1..$#cols-1] ) {
        my $length = length($minus) - 2;
        next if $length < 0;
        
        push @$columns, [$start, $length];

        $start += $length + 3;
    }
	my $copy = $header;
	chomp($copy);
	
	my $c = $copy =~ s{(?:\+-)(-+)(?:-(?=\+))}
	{
		"(" . '.{' . length($1) . "}) \Q|\E "
	}gex;

	if ( $c > 0 ) {
		$copy =~ s/\+$//;
		$copy =~ s/(....)$/(?=$1)/;
	}

	$magic = qr/$copy/s;
} else {
	print <>;
	exit;
}
use Data::Dumper;

print Dumper $magic;
# XXX bold headers
for (1..1) {
    my $x = <>;
    print $x;
}

$/ = " | \n";

while (my $line = <>) {

	if ( my @truc = $line =~ $magic ) {
		print $` . join( ' | ', map { colcol($_) } @truc) . $';
	}
	next;
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

sub colcol {
	my $value = shift;
	my $color;
	if ( $value =~ $match_null ) {
		$color = ["cyan"];
	} elsif ( $value =~ $match_int ) {
		$color = ["green"];
	} elsif ( $value =~ $match_date ) {
		$color = ["yellow"];
	}
	return $value unless $color;
	
	return colored($color, $value);
}

#print join("..", @$_)."\n" foreach @$columns;
print "\n";
