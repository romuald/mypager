#!/usr/bin/perl
use strict;
use warnings;

require 5.8.0;

use Term::ANSIColor qw/colored :constants/;

my $match_null = qr/(?:^NULL\s*)|(?:\s*NULL$)/; # XXX rewrite?
my $match_int  = qr/^\s*-?\d+\.?\d*$/;
my $match_date = qr/^(?:[0-9]{4}-[0-9]{2}-[0-9]{2})|(?:[0-9]{2}:[0-9]{2}:[0-9]{2})/;

my $reset = RESET;
my $style_int = GREEN;
my $style_null = CYAN;
my $style_date = YELLOW;
# my $style_date = YELLOW . ON_BLUE; # << combinaison example

my ($term_cols, $term_lines) = (0, 0);

# Try to determine the screen size from module or stty
eval {
    require "Term/ReadKey.pm";
    ($term_cols, $term_lines) = Term::ReadKey::GetTerminalSize();
} or eval {
    ($term_lines, $term_cols) = split /\s+/, `stty -F /dev/stderr size`;
};

# Global print "buffer" scalar and filehandle
my $outhandle;
my $outstring = "";

open($outhandle, "+>", \$outstring)
    or die("Can't create temporary buffer");

select($outhandle);
END {
    # If less was used, then outstring will be empty
    print STDOUT $outstring;
}

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

sub max(@) { (sort @_)[-1] }

my $useless;
my $cur_cols = length($header);
my $cur_lines = scalar(grep /\n/, $outstring);

$/ = " | \n";
while (my $line = <>) {
    # since $/ has been changed, $line may contain multiple lines
    if ( ! $useless ) {
        $cur_lines += scalar(grep /\n/, $line);
        $cur_cols = max($cur_cols, map {length} split( /\n/, $line) );

        if ( $cur_lines > $term_lines || $cur_cols - 1 > $term_cols) {
            # Switch to less, and write current buffer
            open($useless, '| less -R -S')
                or die("Can't open less");
            select($useless);

            print $useless $outstring;
            close($outhandle);
            $outstring = "";
        }
    }

    if ( my @values = $line =~ $magic ) {
        print '| ', join( ' | ', map { colcol($_) } @values), $/;
    } else {
        print $line;
    }
}

