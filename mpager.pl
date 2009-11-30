#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Term::ANSIColor qw/colored :constants/;
use FileHandle;
# XXX trycatch
use Term::Readkey ();

my $match_null = qr/(?:^NULL\s*)|(?:\s*NULL$)/; # XXX rewrite?
my $match_int  = qr/^\s*-?\d+\.?\d*$/;
my $match_date = qr/^(?:[0-9]{4}-[0-9]{2}-[0-9]{2})|(?:[0-9]{2}:[0-9]{2}:[0-9]{2})/;

my $reset = RESET;
my $style_int = GREEN;
my $style_null = CYAN;
my $style_date = YELLOW;
# my $style_date = YELLOW . ON_BLUE; # << combinaison example

my ($term_cols, $term_lines) = Term::ReadKey::GetTerminalSize();

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
	my $value = $_[0];

	if ( $value =~ /[a-zA-KMO-TV-Z]/ ) {
		return $value;
	}
	
	if ( $value =~ $match_null ) {
		return  $style_null . $value . $reset;
	}
	if ( $value =~ $match_int ) {
		return $style_int . $value . $reset;
	}
	if ( $value =~ $match_date ) {
		return $style_date . $value . $reset;
	}
	return $value;
}

$/ = " | \n";

#sub max($$) { $_[0] >= $_[1] ? $_[0] : $_[1] }
sub max(@) { (sort @_)[-1] }

my $useless = 0;
my (@local, @data);
my ($columns, $lines) = (0, 0);
while (my $line = <>) {
	@local = ();
	if ( my @truc = $line =~ $magic ) {
		push @local, '| ', join( ' | ', map { colcol($_) } @truc), $/;
	} else {
		push @local, $line;
	}
} continue {
	#	print "$lines $columns \n";
	if ( not $useless ) {
		my $current = join '', @local;
	
		$lines += scalar(grep /\n/, $current);
		
		# XXX remove escapes or store previous value
		$columns = max($columns, map {length} split( /\n/, $current) );
		
		if ( $lines > $term_lines || $columns > $term_cols) {
			$useless = FileHandle->new('| less -r -S');
			print $useless @data, @local;
			@data = ();
		} else {
			push @data, @local;
		}
	} else {
		print $useless @local;
	}
	
}
print join '', @data unless $useless;

