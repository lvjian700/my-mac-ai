PREFIX ?= ~/.local

.PHONY: build install uninstall

build:
	swift build -c release

install: build
	cp .build/release/ical $(PREFIX)/bin/ical

uninstall:
	rm -f $(PREFIX)/bin/ical
