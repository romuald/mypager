My *(sql)*  Pager
==================

Jump to:

- `Usage, Mysql`_
- `Usage, PostgreSQL`_
- `TODO`_

mypager is a tool meant to be used with the MySQL and PostgreSQL command line clients on unix platforms.

It's goal is to ease the reading of resultsets, doing 2 things:

- coloring data (numbers, dates and NULLs)
- using the less command in case the output don't fit in the terminal

Here is a sample output:

.. image:: http://chivil.com/mysqlpager/sample-colored.png

It currently requires perl 5.8, preferably with the `Term::ReadKey <http://search.cpan.org/dist/TermReadKey/ReadKey.pm>`_ module
(should work without, using the ``stty`` command)


Usage, MySQL
_________________

To use it you'll just have to tell your mysql client to use it as a pager::

  mysql> pager /path/to/mypager.pl

or edit your ``~/.my.cnf`` file::

  [mysql]
      pager = /path/to/mypager.pl

Usage, PostgreSQL
____________________

The script was originaly designed to work with MySQL, but an option exists in PostgreSQL client that format output as mypager expects it.

Unlike the mysql client, there is no specific option for the PostgreSQL pager, you'll have to use the ``PAGER`` environment variable, for example::

    export PAGER=/path/to/mypager.pl
    psql --stuff

Or in your ``.bashrc`` / ``.zshrc``::

    alias psql="PAGER=/path/to/mypager.pl psql"

Then, you'll have to edit your ``.psqlrc`` file to set 2 default options::

    -- Headers and surrounding pipes for columns
    \pset border 2

    -- mypager will decide when to switch to less, but will always add color
    \pset pager always

    -- You may want null to be NULL, at your discretion
    -- \pset null NULL

TODO
__________

- document config options :p
- allow a *--install* like command line option to install default configuration
- be able to force the use (or not use) of less
- be able to disable / change colors
