Mysql Pager
===========

Mysql Pager is a tool meant to be used with the mysql command line client on unix platforms.

It's goal is to ease the reading of resultsets, doing 2 things:

- coloring data (numbers, dates and NULLs)
- using the less command in case the output don't fit in the terminal

Here is a sample output:

.. image:: http://chivil.com/mysqlpager/sample-colored.png

It currently requires perl 5.8, preferably with the `Term::ReadKey <http://search.cpan.org/dist/TermReadKey/ReadKey.pm>`_ module
(should work without, using the ``stty`` command)

--------

To use it you'll just have to tell your mysql client to use it as a pager:

::

  mysql> pager /path/to/mypager.pl

or edit your ``~/.my.cnf`` file:

::

  [client]
      pager = /path/to/mypager.pl

--------

**TODO**

- be able not to take the columns in account when deciding to switch to less
- be able to force the use (or not use) of less
- be able to pass options to less (like the -i flag)
- works with perl < v5.8.0
