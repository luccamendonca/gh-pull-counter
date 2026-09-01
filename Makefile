APP = GHPullCounter
BUNDLE = build/$(APP).app

.PHONY: build app run clean

build:
	swift build -c release

app: build
	mkdir -p "$(BUNDLE)/Contents/MacOS"
	cp .build/release/$(APP) "$(BUNDLE)/Contents/MacOS/$(APP)"
	cp Support/Info.plist "$(BUNDLE)/Contents/Info.plist"
	codesign --force --sign - "$(BUNDLE)" >/dev/null 2>&1 || true

run: app
	open $(BUNDLE)

clean:
	rm -rf build .build
