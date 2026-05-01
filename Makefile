.PHONY: build test install uninstall

build test install uninstall:
	$(MAKE) -C ical $@
