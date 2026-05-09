PREFIX ?= /usr/local
BIN_DIR = $(PREFIX)/bin

.PHONY: build install uninstall

build:
	npm run build

install: build
	install -m 755 dist/cali $(BIN_DIR)/cali

uninstall:
	rm -f $(BIN_DIR)/cali
