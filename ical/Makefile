PREFIX ?= ~/.local
SKILL_DEST := ~/.claude/skills/ical

.PHONY: build test install uninstall install-skill uninstall-skill

build:
	swift build -c release

test:
	swift test

install: test build
	cp .build/release/ical $(PREFIX)/bin/ical

uninstall:
	rm -f $(PREFIX)/bin/ical

install-skill:
	mkdir -p $(SKILL_DEST)
	cp .claude/skills/ical/SKILL.md $(SKILL_DEST)/SKILL.md

uninstall-skill:
	rm -rf $(SKILL_DEST)
