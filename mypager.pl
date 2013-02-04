#!/usr/bin/env perl
package main;

use strict;
use warnings;

require 5.008_000;

our $VERSION = '0.5.0';

use Module::Load;

use POSIX ":sys_wait_h";
use Encode qw/encode_utf8 decode_utf8/;
use Term::ANSIColor qw/color/;

my $reset = color('reset');

# Different styles for different types

# Try to determine the screen size from module or stty
my ($term_cols, $term_lines) = (0, 0);
eval {
    load Term::ReadKey;
    ($term_cols, $term_lines) = Term::ReadKey::GetTerminalSize();
} or eval {
    ($term_lines, $term_cols) = split /\s+/, `stty -F /dev/stderr size`;
};

# Load (or install) configuration
my %CONF;
{
    no warnings qw/prototype/;

    if ( grep /^--installconf$/, @ARGV ) {
        MyPager::Config::write_defaults();
        exit;
    }

    %CONF = %{ MyPager::Config::get_config() || {} };
}

my $style_int = color($CONF{'style-int'}) || '';
my $style_null = color($CONF{'style-null'}) || '';
my $style_date = color($CONF{'style-date'}) || '';

# Column header in the \G style
# TODO column headers too
my $style_header = color($CONF{'style-header'}) || '';

# Row headers in the \G style
my $style_row = color($CONF{'style-row'}) || '';


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

# Columns ("|") positions for standard input
my @columns;

# First line with +---+-----+ or ******
my $header = <STDIN>;
if ( $header =~ /^\+(?:-+\+)+$/ ) {
    $input_format = "std";

    if ( $CONF{"fix-utf8"} ) {
        my $i = 0;
        for my $char ( split //, $header ) {
            push(@columns, $i) if $char eq "+";
            $i++;
        }
    }
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

=head2 fixutf8

Try to fix mysql utf8 buggy output by balancing n bytes
characters with white spaces at the end of each column

=cut
sub fixutf8($) {
    my $line = $_[0];
    my $uline; # decoded (unicode) version
    eval {
        $uline = decode_utf8($line, Encode::FB_CROAK);
    };

    return $_[0]
      if (
        $@                                      # decode error
        || length($uline) >= length($header)    # no line change
        || length($_[0])  != length($header)    # no line change
        || $uline !~ m/^\|.*\|$/                # probably multiline
      );

    # $line was overwritten by decode
    $line = $_[0];

    my @cells;
    my $i = 0;
    for (; $i < @columns-1; $i++) {
        # For each cell, try to determine if more bytes
        # than chars are used in output
        my $part = substr($line, $columns[$i], $columns[$i+1] - $columns[$i]);
        my $upart = decode_utf8($part);

        my $diff = length($part) - length($upart);
        if ($diff <= 0) {
            push @cells, $part;
            next;
        }

        # Append whitespaces corresponding to the additional bytes
        substr($upart, length($upart)-1, 0, " " x $diff);
        push @cells, encode_utf8($upart);
    }

    return join "", @cells, substr($line, $columns[$i]);
}

# If output to a non-terminal, don't bother sending data to less
my $less;
my $lesspid;
my $useless;

=head2 switch_to_less

Open less in a subprocess, flush the current
output buffer and set the standard output to it

=cut
sub switch_to_less() {
    $lesspid = open($less, '| less -R')
        or die("Can't open less");
    select($less);

    print $outstring;
    close($outhandle);

    $outstring = "";
}

=head2 less_no_more

Called when sure we won't use less so we don't buffer output internally

=cut
sub less_no_more() {
    $useless = 0;

    select STDOUT;
    print $outstring;
    close($outhandle);
    $outstring = "";
}

# Decide whenever to use less or not .. or maybe
if ( !-t STDOUT ) {
    # Output is not a TTY: just colorize
    less_no_more();
} else {
    # Else determine behavior from configuration
    if ( $CONF{'use-less'} eq 'never' ) {
        less_no_more();
    } elsif ( $CONF{'use-less'} eq 'always' ) {
        $useless = 1;
        switch_to_less();
    } else { # auto, or any other setting
        $useless = 1;
    }
}

my $cur_cols = length($header);
my $cur_lines = scalar(grep /\n/, $outstring);

my $count = 0;
while (my $line = <STDIN>) {
    if ( !$less && $useless ) {
        $cur_lines++;
        $cur_cols = max($cur_cols, length($line));

        # adding lines may lead to full terminal height
        # will lead to using less, which will wrap long lines
        if ( not $CONF{"long-lines-to-less"} ) {
            $cur_lines += int(length($line) / $term_cols);
        }

        if ( $cur_lines > $term_lines ||
            ($CONF{"long-lines-to-less"} && $cur_cols - 1 > $term_cols) ) {
            switch_to_less();
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
        $line = fixutf8($line) if $CONF{"fix-utf8"};

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

close($less) if $less;

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

    my @todo = strdata();

    # Config file overwrites defaults
    if ( -f $config_file && -r _ ) {
        open CONF, $config_file;
        push @todo, join("", <CONF>);
        close CONF;
    } else {
        $return{'-defaults'} = 1;
    }

    for my $strconf (@todo) {
        # Remove inline comments
        $strconf =~ s/(?<!\\)\s+#.*//gm;

        # and unescape the non-comments #
        $strconf =~ s/\\#/#/gm;

        # Simple scalars, allow empty values with "varname = "
        while ( $strconf =~ /^[\040\t]*([^#\@\s]+?)[\040\t]*=[\040\t]*(.*?)[\040\t]*$/gm  ) {
            # next if defined($return{$1});

            $return{$1} = $2;
        }

        # Arrays
        while ( $strconf =~ /\@(\S+?)\s*=\s*\((.*?)(?<!\\)\)/gs ) {
            # next if defined($return{$1});

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
    }
    return \%return;
}

sub strdata() {
    # Rewind data handle after reading, in case we'll need to read it again
    my $origin = tell(DATA);
    my $strconf = join "", <DATA>;
    seek(DATA, $origin, SEEK_SET);

    return $strconf;
}

=head2 write_defaults

Try to write default configuration,
may ask permission to overwrite

=cut
sub write_defaults() {
    my $config_file = CONFPATH;

    $config_file = glob($config_file);

    if ( -f $config_file ) {
        local $| = 1; # autoflush
        print STDERR "$config_file already exits, Overwrite? [y/N] ";

        my $response = <STDIN>;

        exit unless $response =~ /^y/i;
    }


    my $ok = open(CONFWRITE, "> $config_file");
    if ( !$ok ) {
        print STDERR "Unable to open $config_file for writing ($!)\n";
        exit 1;
    }
    print CONFWRITE strdata();
    close CONFWRITE;
}

1;

# Bellow is the default config, you can copy its contents to ~/.mypager.conf
# if you wish to configure it.
# Or simply change the values bellow :)
__DATA__
# This is the default configuration file

# Colors for each style
# See Term::ANSIColor documentation for a complete list of available styles
style-int = green
style-null = cyan
style-date = yellow

# Column header in the \G style
style-header = underline

# Row headers in the \G style
style-row = magenta

# NOTE, you can combine multiple styles too, for example:
# style-null = blink bold cyan


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

# Use less .. or not. Valid values are: auto, always, never
use-less = auto


# Fix broken MySQL client output
# Now useless with recent clients
fix-utf8 = 0
