My *(sql)*  Pager
==================

- `Usage, Mysql`_
- `Usage, PostgreSQL`_
- `Configuration`_
- `TODO`_

mypager is a tool meant to be used with the MySQL and PostgreSQL command line clients on unix platforms.

Its goal is to ease the reading of resultsets, doing 2 things:

- coloring data (numbers, dates, UUIDs and NULLs)
- using the less command in case the output don't fit in the terminal

Here is a sample output:

.. image:: http://chivil.com/mysqlpager/sample-colored.png

It currently requires perl 5.8, preferably with the `Term::ReadKey <http://search.cpan.org/dist/TermReadKey/ReadKey.pm>`_ module
(should work without, using the ``stty`` command)


Installation
_________________


You can either simply copy the script to the location you wish, or use ``make install``

- when run as **user**, the script will be installed in ``~/bin/``
- when run as **root**, the script will be installed in ``/usr/local/bin/``


Usage, MySQL
_________________

To use it you'll just have to tell your mysql client to use it as a pager::

  mysql> pager /path/to/mypager

or edit your ``~/.my.cnf`` file::

  [mysql]
      pager = /path/to/mypager

Usage, PostgreSQL
____________________

The script was originally designed to work with MySQL, but an option exists in PostgreSQL client that format output as mypager expects it.

Unlike the mysql client, there is no specific option in the PostgreSQL client, you'll have to use the ``PAGER`` environment variable, for example::

    export PAGER=/path/to/mypager
    psql --stuff

Or in your ``.bashrc`` / ``.zshrc``::

    alias psql="PAGER=/path/to/mypager psql"

Then, you'll have to edit your ``.psqlrc`` file to set 2 default options::

    -- Headers and surrounding pipes for columns
    \pset border 2

    -- mypager will decide when to switch to less, but will always add color
    \pset pager always

    -- You may want null to be NULL, at your discretion
    -- \pset null NULL


Configuration
_________________


The configuration file is located in ``~/.mypager.conf``.

A default configuration is present at the end of the script itself, should you wish to modify it instead.

You can use ``mypager --installconf`` to write the default configuration to ``~/.mypager.conf``.


Styles
-------

Current available styles are ``style-int``, ``style-null``, ``style-date``, ``style-header``, ``style-row``

*header* and *row* styles are used for the ``\G`` option of the mysql client (vertically formated output)

You can use any recognized value of the `Term::ANSIColor <http://search.cpan.org/dist/Term-ANSIColor/ANSIColor.pm#Function_Interface>`_ module, and combine them as you please.

Some valid examples: ``red``, ``bold blue``, or ``underline white on_black``


Other options
--------------

long-lines-to-less
	0/**1**, with this option set to 1, the pager will switch to less whenever it encounters a line longer than screen width (even if the screen has enough height available)


less-options
	**-S**, these are the options sent to less (check out the *OPTIONS* section of the man page for a complete list). The default is to chop long lines, you can add your own choice here, like *-I* to make searches case insensitive.


less-options-overrides-env
	**0**/1, the default behavior is to add *less-options* before your *$LESS* environment variable so that the options set by your environment take precedence over the script options. Set to *1* to reverse the behavior.

use-less
    **auto**/always/never, will determine whenever or not to switch to less, should you wish to alway use it or just colorize the output

fix-utf8
    **0**/1, try to fix broken UTF-8 output of older (< 5.5 ?) MySQL clients. This option fixes unaligned columns when 2 bytes characters are present in a cell.

uuid-color
    0/**1**, colorize UUIDs. The UUIDs are colorized using a MD5 hash, to more easily identify 2 identical UUIDs in a list. This is especially useful when listing UUID1 created in short amount of time


TODO
__________

probably lots
