BINDIR=/usr/local/bin
.PHONY: install
install:
	cp -f examples/ledoff.lua $(BINDIR)/ledoff
	chmod +x $(BINDIR)/ledoff
	cp -f examples/binclock.lua $(BINDIR)/binclock
	chmod +x $(BINDIR)/binclock

