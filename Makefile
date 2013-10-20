DC=$(shell which ldc2 || which gdc || which dmd)
PREFIX=/usr/local

BINDIR=bin
DOCDIR=doc
SRCDIR=src
BUILDDIR=build
SOURCES=$(shell find $(SRCDIR) -type f -name '*.d')
DLIBS=curl panel ncursesw

all: $(BINDIR)/dcoincoin-curses

$(BINDIR)/%:
	mkdir -p $(BINDIR)
ifneq (,$(findstring gdc,$(DC)))
	$(DC) $(foreach lib, $(DLIBS), -l$(lib)) \
		-I$(SRCDIR) -O3 \
		-o$@ \
		$(SOURCES)
else
	mkdir -p $(BUILDDIR)
	$(DC) $(foreach lib, $(DLIBS), -L-l$(lib)) \
		-od$(BUILDDIR) \
		-I$(SRCDIR) -O -release \
		-of$@ \
		$(SOURCES)
endif

install: $(BINDIR)/dcoincoin-curses
	install -D $(BINDIR)/dcoincoin-curses $(PREFIX)/bin/dcoincoin-curses
	strip -s $(PREFIX)/bin/dcoincoin-curses
	install -D $(DOCDIR)/dcoincoinrc $(PREFIX)/share/doc/dcoincoin/dcoincoinrc

uninstall:
	rm -f $(PREFIX)/bin/dcoincoin-curses
	rm -rf $(PREFIX)/share/doc/dcoincoin

clean:
	rm -rf $(BUILDDIR)
	rm -rf $(BINDIR)
