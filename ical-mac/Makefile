PREFIX ?= $(HOME)/.local
APP_DIR ?= $(HOME)/Applications
PROJECT := ical-mac.xcodeproj
SCHEME := ical-mac
DERIVED_DATA := .build/DerivedData
DESTINATION ?= platform=macOS
APP_BUNDLE := .build/ical-mac.app

.PHONY: build test run app dmg install uninstall clean xcode xcode-build xcode-test

build:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Release -derivedDataPath "$(DERIVED_DATA)" -destination '$(DESTINATION)' build

test:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Debug -derivedDataPath "$(DERIVED_DATA)" -destination '$(DESTINATION)' test

run:
	./script/build_and_run.sh

app:
	./scripts/build_app_bundle.sh

dmg:
	./scripts/build_dmg.sh

install: app
	mkdir -p "$(APP_DIR)"
	rm -rf "$(APP_DIR)/ical-mac.app"
	cp -R "$(APP_BUNDLE)" "$(APP_DIR)/ical-mac.app"

uninstall:
	rm -rf "$(APP_DIR)/ical-mac.app" "$(PREFIX)/bin/ical-mac"

clean:
	rm -rf .build DerivedData

xcode:
	./scripts/open_xcode.sh

xcode-build: build

xcode-test: test
