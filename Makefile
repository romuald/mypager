whoami := $(shell whoami)

MANBASE = /share/man

# install to home dir if not root
ifeq (root,$(whoami))
prefix := /usr/local
else
prefix := $(HOME)
# Try to guess user local man path
#MANBASE = $(shell manpath | perl -ne 'chomp;  s/^\Q$$ENV{HOME}\\E)// && print && exit for (split /:/)')
endif

MANUAL = MANUAL.pod
INSTALL_BIN = $(DESTDIR)$(prefix)/bin
INSTALL_MAN = $(DESTDIR)$(prefix)$(MANBASE)/man1

default:
	@echo Please use make install
	@echo Will install script in $(INSTALL_BIN)
	@echo Will install man page in $(INSTALL_MAN)

install: install-bin install-doc

install-bin:
	install -m 0755 -d $(INSTALL_BIN)
	install -m 0755 -c mypager $(INSTALL_BIN)

install-doc:
ifneq (,$(wildcard $(MANUAL)))  # for future doc
	install -m 0755 -d $(INSTALL_MAN)
	pod2man -n 'MYPAGER' -r "" $(MANUAL) $(INSTALL_MAN)/mypager.1
endif


uninstall:
	rm -f $(INSTALL_BIN)/mypager
	rm -f $(INSTALL_MAN)/mypager.1
