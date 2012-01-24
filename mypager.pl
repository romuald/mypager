#!/usr/bin/env perl
package main;

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

# Column header in the \G style
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


# Config stuff

my %CONF;
{
    no warnings qw/prototype/;
    %CONF = %{ MyPager::Config::get_config() || {} };
}

$ENV{LESS} ||= "";
$CONF{"less-options"} ||= "";

if ( $CONF{"less-options-overrides-env"} ) {
    $ENV{LESS} = $ENV{LESS} . $CONF{"less-options"};
} else {
    $ENV{LESS} = $CONF{"less-options"} . $ENV{LESS};
}

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
my $time = '\d{2}:\d{2}:\d{2}(?:\.\d+)?';

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

        # adding lines may lead to full terminal height
        # will lead to using less, which will wrap long lines
        if ( not $CONF{"long-lines-to-less"} ) {
            $cur_lines += int(length($line) / $term_cols);
        }

        if ( $cur_lines > $term_lines ||
            ($CONF{"long-lines-to-less"} && $cur_cols - 1 > $term_cols) ) {

            # Switch to less, and write current buffer
            $lesspid = open($useless, '| less -R')
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
        $line =~ s/: ((?:$date(?: $time)?|(?:$date )?$time))$/: $style_date$1$reset/;
    }

    print $line;
}

# this should be placed in another file, but I'd really
# like to keep this utility in one script
package MyPager::Config;

use strict;
use warnings;

use Fcntl qw/SEEK_SET/;

use constant CONFPATH => "~/.mypager.conf";

sub get_config() {
    my %return = ();

    my $config_file = CONFPATH;

    $config_file = glob($config_file);

    my $strconf = undef;

    # Try to read config file, otherwise revert to internal defaults
    if ( -f $config_file && -r _ ) {
        open CONF, $config_file;
        $strconf = join "", <CONF>;
        close CONF;
    } else {
        $strconf = strdata();

        $return{'-defaults'} = 1;
    }

    # Remove inline comments
    $strconf =~ s/(?<!\\)\s+#.*//gm;

    # and unescape the non-comments #
    $strconf =~ s/\\#/#/gm;

    # Simple scalars, allow empty values with "varname = "
    while ( $strconf =~ /^[\040\t]*([^#\@\s]+?)[\040\t]*=[\040\t]*(.*?)[\040\t]*$/gm  ) {
        next if defined($return{$1}); # really ?

        $return{$1} = $2;
    }

    # Arrays
    while ( $strconf =~ /\@(\S+?)\s*=\s*\((.*?)(?<!\\)\)/gs ) {
        next if defined($return{$1});

        my @values =
        # 3. then unescape spaces and parenthesis
        map { s/\\([ )])/$1/g; $_ }
        # 2. remove empty matches
        grep { length }
        # 1. split using non-escaped whitespaces
        split /(?<!\\)\s+/s, $2;

        $return{$1} = \@values
    }
    # and no dict yet

    return \%return;
}

sub strdata() {
    # Rewind data handle after reading, in case we'll need to read it again
    my $origin = tell(DATA);
    my $strconf = join "", <DATA>;
    seek(DATA, $origin, SEEK_SET);

    return $strconf;
}

1;

# Bellow is the default config, you can copy its contents to ~/.mypager.conf
# if you wish to configure it.
# Or simply change the values bellow :)
__DATA__
# This is the default configuration file

# 1: mypager will switch to less if it encounters any line longer than screen
#    width (even if they fit within the height of the screen)
# 0: it will only take the height as variable to switch to less.
long-lines-to-less = 1

# Options passed on to less (as environment variable)
#   default: -S to chop long lines
#   you can add -I for case insensitive searches for example
# `man less` for all options
less-options = -S

# If the $LESS environment variable is already set, the default is to set our
# config options ("less-options") with a lower priority (in case of conflicts)
# Set to 1 to "override" the environment variable options
less-options-overrides-env = 0
