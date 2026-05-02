.PHONY: build test install uninstall install-skills uninstall-skills

build test install uninstall install-skills uninstall-skills:
	$(MAKE) -C ical $@
