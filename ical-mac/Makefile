PREFIX ?= $(HOME)/.local
APP_DIR ?= $(HOME)/Applications
BUILD_DIR := .build/release
APP_BUNDLE := .build/ical-mac.app

.PHONY: build test run app install uninstall clean xcode xcode-build xcode-test

build:
	swift build -c release

test:
	swift test --parallel -q

run:
	swift run ical-mac

app: build
	./scripts/build_app_bundle.sh

install: app
	mkdir -p "$(APP_DIR)"
	rm -rf "$(APP_DIR)/ical-mac.app"
	cp -R "$(APP_BUNDLE)" "$(APP_DIR)/ical-mac.app"

uninstall:
	rm -rf "$(APP_DIR)/ical-mac.app" "$(PREFIX)/bin/ical-mac"

clean:
	rm -rf .build

xcode:
	./scripts/open_xcode.sh

xcode-build:
	./scripts/ensure_xcode_workspace.sh
	xcodebuild -quiet -workspace .swiftpm/xcode/package.xcworkspace -scheme ical-mac -destination 'platform=macOS' build

xcode-test:
	./scripts/ensure_xcode_workspace.sh
	xcodebuild -quiet -workspace .swiftpm/xcode/package.xcworkspace -scheme ical-mac-Package -destination 'platform=macOS' test
