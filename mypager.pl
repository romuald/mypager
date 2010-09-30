#!/usr/bin/perl
use strict;
use warnings;

require 5.008_000;

use POSIX ":sys_wait_h";
use Term::ANSIColor qw/:constants/;

my $reset = RESET;

# Different styles for different types

my $style_int = GREEN;
my $style_null = CYAN;
my $style_date = YELLOW;

# Column header in the \G styl
# TODO column headers too
my $style_header = UNDERLINE;

# Row headers in the \G style
my $style_row = MAGENTA;

# Styles can be combined too
# my $style_date = YELLOW . ON_BLUE;

# Try to determine the screen size from module or stty
my ($term_cols, $term_lines) = (0, 0);
eval {
    require "Term/ReadKey.pm";
    ($term_cols, $term_lines) = Term::ReadKey::GetTerminalSize();
} or eval {
    ($term_lines, $term_cols) = split /\s+/, `stty -F /dev/stderr size`;
};

# Global print "buffer" scalar and filehandle
# Used to store data before sending it to `less` or stdout
my $outhandle;
my $outstring = "";

open($outhandle, "+>", \$outstring)
    or die("Can't create temporary buffer");

select($outhandle);
END {
    # If less was used, then outstring will be empty
    print STDOUT $outstring if $outstring;
}

my $input_format = ""; # unknown by default;

# First line with +---+-----+ or ******
my $header = <>;
if ( $header =~ /^\+(?:-+\+)+$/ ) {
    $input_format = "std";
    print $header;
} elsif ( $header =~ /^\*+/ ) {
    $input_format = "vertical";
    print $style_row, $header, $reset;
} else {
    # Unknown format, will proceed without coloring
    print $header;
}

my $date = '\d{4}-\d{2}-\d{2}';
my $time = '\d{2}:\d{2}:\d{2}';

# Quick max function :p
sub max(@) { (sort @_)[-1] }

# If output to a non-terminal, don't bother sending data to less
# TODO should not buffer in $outstring then
my $lesspid;
my $useless = !(-t STDOUT) || undef;
my $cur_cols = length($header);
my $cur_lines = scalar(grep /\n/, $outstring);

my $count = 0;
while (my $line = <>) {
    if ( ! $useless ) {
        $cur_lines++;
        $cur_cols = max($cur_cols, length($line));

        if ( $cur_lines > $term_lines || $cur_cols - 1 > $term_cols) {
            # Switch to less, and write current buffer
            $lesspid = open($useless, '| less -R -S')
                or die("Can't open less");
            select($useless);

            print $useless $outstring;
            close($outhandle);
            $outstring = "";
        }
    } elsif ( $lesspid && $count++ == 300 ) {
        # every 300 rows, check that less didn't exit
        # (don't hang CPU on large resultsets)
        $count = 0;
        if ( -1 == waitpid($lesspid, WNOHANG)) {
            last;
        }
    }

    if ( $input_format eq "std" ) {
        $line =~ s/(\| +)(NULL +)(?=\|)/$1$style_null$2$reset/g;
        $line =~ s/(\| +)(-?\d+\.?\d*(?:e\+\d+)? )(?=\|)/$1$style_int$2$reset/g;
        $line =~ s/\| ((?:$date(?: $time)?|(?:$date )?$time) +)(?=\|)/| $style_date$1$reset/g;
    } elsif ( $input_format eq "vertical" ) {
        $line =~ s/^((\*{27}) \d+\..*? \*{27})/$style_row$1$reset/;

        $line =~ s/^( *)(\S+)(?=: )/$1$style_header$2$reset/;

        $line =~ s/: (NULL)$/: $style_null$1$reset/ ||
        $line =~ s/: (-?\d+\.?\d*)$/: $style_int$1$reset/ ||
        $line =~ s/: K((?:$date(?: $time)?|(?:$date )?$time))$/: $style_date$1$reset/;
    }

    print $line;
}
