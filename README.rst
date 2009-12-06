Mysql Pager
===========

Mysql Pager is a tool meant to be used with the mysql command line client on unix platforms.

It's goal is to ease the reading of resultsets, doing 2 things:

- coloring data (numbers, dates and NULLs)
- using the less command in case the output don't fit in the terminal

**TODO**

- better README and examples ;)
- bug when dealing with columns bigger than 32k characters
- be able not to take the columns in account when deciding to switch to less
- be able to force use / not use of less
- works with perl < v5.8.0
- be able to pass options to less
- no color on some big TEXT fields for some reason