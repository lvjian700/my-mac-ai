PREFIX ?= $(HOME)/.local
BIN_DIR = $(PREFIX)/bin
LIBEXEC_DIR = $(PREFIX)/libexec/cali

.PHONY: build test typecheck install uninstall

build:
	bun run build

test:
	bun run test

typecheck:
	bun run typecheck

install: build
	mkdir -p $(LIBEXEC_DIR)
	install -m 755 dist/cali $(BIN_DIR)/cali
	install -m 755 native/voice-audio/.build/release/cali-voice-audio $(LIBEXEC_DIR)/cali-voice-audio

uninstall:
	rm -f $(BIN_DIR)/cali
	rm -f $(LIBEXEC_DIR)/cali-voice-audio
