PREFIX ?= $(HOME)/.local
BIN_DIR = $(PREFIX)/bin

.PHONY: build test typecheck install uninstall sync

build:
	bun run build

test:
	bun run test

typecheck:
	bun run typecheck

install: build
	install -m 755 dist/cali $(BIN_DIR)/cali

uninstall:
	rm -f $(BIN_DIR)/cali

sync:
	bun run scripts/cali-sync.ts
