PREFIX=/usr/local
BINDIR=$(PREFIX)/bin

all:
	@echo "Run \"sudo make install\" to install ctmg"

install:
	install -m 0755 ctmg.sh $(BINDIR)/ctmg

