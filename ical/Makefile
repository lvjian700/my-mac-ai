PREFIX ?= ~/.local
SKILL_SRC := $(CURDIR)/.claude/skills/ical
CLAUDE_SKILL_DEST := $(HOME)/.claude/skills/ical

.PHONY: build test install uninstall install-skills uninstall-skills

build:
	swift build -c release

test:
	swift test --parallel -q

install: test build
	cp .build/release/ical $(PREFIX)/bin/ical

uninstall:
	rm -f $(PREFIX)/bin/ical

install-skills:
	mkdir -p "$(HOME)/.claude/skills" "$(HOME)/.codex/skills"
	rm -rf "$(CLAUDE_SKILL_DEST)"
	ln -s "$(SKILL_SRC)" "$(CLAUDE_SKILL_DEST)"

uninstall-skills:
	rm -rf "$(CLAUDE_SKILL_DEST)"
