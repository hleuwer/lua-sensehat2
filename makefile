BINDIR=/usr/local/bin
LV=$(shell lua -e 'print(_VERSION)' | cut -d " " -f 2)

.PHONY: install install-app install-mod
install: install-mod install-app
install-app: install-mod
	cp -f examples/ledoff.lua $(BINDIR)/ledoff
	chmod +x $(BINDIR)/ledoff
	cp -f examples/binclock.lua $(BINDIR)/binclock
	chmod +x $(BINDIR)/binclock

install-mod:
	cp -f sensehat.lua /usr/local/share/lua/$(LV)
