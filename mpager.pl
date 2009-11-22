#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Term::ANSIColor qw/colored :constants/;

my $match_null = qr/(?:^NULL\s*)|(?:\s*NULL$)/; # XXX rewrite?
my $match_int  = qr/^\s*-?\d+\.?\d*$/;
my $match_date = qr/^(?:[0-9]{4}-[0-9]{2}-[0-9]{2})|(?:[0-9]{2}:[0-9]{2}:[0-9]{2})/;

my $reset = RESET;
my $style_int = GREEN;
my $style_null = CYAN;
my $style_date = YELLOW;
# my $style_date = YELLOW . ON_BLUE; # << combinaison example

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
	}

	$magic = qr/$copy/s;
} else {
	print <>;
	exit;
}
use Data::Dumper;

# XXX bold headers
for (1..2) {
    my $x = <>;
    print $x;
}

sub colcol($) {
	my $value = shift;

	if ( $value =~ /[a-zA-KMO-TV-Z]/ ) {
		return $value;
	}
	
	my $color;	
	if ( $value =~ $match_null ) {
		$color = $style_null;
	} elsif ( $value =~ $match_int ) {
		$color = $style_int;
	} elsif ( $value =~ $match_date ) {
		$color = $style_date;
	}
	return $value unless $color;

	return $color . $value . $reset;
}

$/ = " | \n";
while (my $line = <>) {
	if ( my @truc = $line =~ $magic ) {
		print '| ', join( ' | ', map { colcol($_) } @truc), $/;
		#print $line =~ m{$/$} ? $/ : "";
	} else {
		print $line;
	}
}

