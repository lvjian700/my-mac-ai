PREFIX ?= ~/.local
SKILL_SRC := $(CURDIR)/.claude/skills/ical
CLAUDE_SKILL_DEST := $(HOME)/.claude/skills/ical
CODEX_SKILL_DEST := $(HOME)/.codex/skills/ical

.PHONY: build test install uninstall install-skill install-skills uninstall-skill uninstall-skills

build:
	swift build -c release

test:
	swift test --parallel -q

install: test build
	cp .build/release/ical $(PREFIX)/bin/ical

uninstall:
	rm -f $(PREFIX)/bin/ical

install-skill: install-skills

install-skills:
	mkdir -p "$(HOME)/.claude/skills" "$(HOME)/.codex/skills"
	rm -rf "$(CLAUDE_SKILL_DEST)" "$(CODEX_SKILL_DEST)"
	ln -s "$(SKILL_SRC)" "$(CLAUDE_SKILL_DEST)"

uninstall-skill: uninstall-skills

uninstall-skills:
	rm -rf "$(CLAUDE_SKILL_DEST)"
