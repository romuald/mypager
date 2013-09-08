whoami := $(shell whoami)

# install to home dir if not root
ifeq (root,$(whoami))
PREFIX := /usr/local
else
PREFIX := $(HOME)
endif

MANUAL = MANUAL.pod
INSTALL_BIN = $(PREFIX)/bin
INSTALL_MAN = $(PREFIX)/man/man1

default:
	@echo Please use make install

install: install-bin install-doc

install-bin:
	install -m 0755 -d $(INSTALL_BIN)
	install -m 0755 -c mypager $(INSTALL_BIN)

install-doc:
ifneq (,$(wildcard $(MANUAL)))  # for future doc
	install -m 0755 -d $(INSTALL_MAN)
	pod2man -r "" $(MANUAL) | gzip -9 > $(INSTALL_MAN)/mypager.1.gz
endif


uninstall:
	rm -f $(INSTALL_BIN)/mypager
	rm -f $(INSTALL_MAN)/mypager.1.gz
