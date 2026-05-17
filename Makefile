.PHONY: build test install uninstall install-skills uninstall-skills

build:
	$(MAKE) -C ical $@
	$(MAKE) -C ical-mac $@

test:
	$(MAKE) -C ical $@
	$(MAKE) -C ical-mac $@

install uninstall install-skills uninstall-skills:
	$(MAKE) -C ical $@
