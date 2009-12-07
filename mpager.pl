#!/usr/bin/perl
use strict;
use warnings;

require 5.008_000;

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

# Print the header and next +----+ line
for (1..2) {
    my $x = <>;
    print $x;
}

# Returns a "colored" version of a value
sub coloredvalue($) {
    my $value = $_[0];

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

# Quick max function :p
sub max(@) { (sort @_)[-1] }

my $useless;
my $cur_cols = length($header);
my $cur_lines = scalar(grep /\n/, $outstring);

while (my $line = <>) {
    if ( ! $useless ) {
        $cur_lines += $line =~ tr/\n/\n/;
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
    
    #$line =~ s{\|\s([-. :0-9NUL]+)(?=\s\|)}{
    #    "| " . coloredvalue($1) . "";
    #}gex;

    $line =~ s/(\| +)(NULL +)(?=\|)/$1$style_null$2$reset/g;
    $line =~ s/(\| +)(-?\d+\.?\d* )(?=\|)/$1$style_int$2$reset/g;
    $line =~ s/(\| )(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} +)(?=\|)/$1$style_date$2$reset/g;

    print $line;
}
