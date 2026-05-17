# Determine this makefile's path.
# Be sure to place this BEFORE `include` directives, if any.
THIS_FILE := $(lastword $(MAKEFILE_LIST))

FLAVOR = ""
ENV_FILE = ""
ANDROID_APP_TYPE = ""

# On NixOS the submodule's bundled dart SDK is a dynamically-linked binary that
# cannot run outside a FHS environment. Prefer the system (nix-wrapped) flutter
# over the submodule copy. Override FLUTTER to use a different binary if needed.
FLUTTER_SYSTEM := $(shell which -a flutter 2>/dev/null | grep -v "submodules" | head -1)
FLUTTER ?= $(if $(FLUTTER_SYSTEM),$(FLUTTER_SYSTEM),$(shell pwd)/submodules/flutter/bin/flutter)

build-runner:
	dart run build_runner build --delete-conflicting-outputs
build-runner-watch:
	dart run build_runner watch --delete-conflicting-outputs

splashscreen:
	dart run flutter_native_splash:create --path flutter_native_splash.yaml

# Build a debug APK for Android (split per ABI) and deploy it
android-dev:
	$(FLUTTER) build apk --debug --split-per-abi
	# adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk
	# adb shell monkey -p com.github.lamarios.clipious -c android.intent.category.LAUNCHER 1

# Build a release APK for Android (split per ABI) and deploy it
# Requires a keystore configured in android/key.properties
android-prod:
	ANDROID_KEY_FILE=/home/fmgordillo/code/clipious/android/key.properties $(FLUTTER) build apk --release --split-per-abi
	# adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
	# adb shell monkey -p com.github.lamarios.clipious -c android.intent.category.LAUNCHER 1

# Build a debug APK for the TV (armeabi-v7a) and deploy it
tv-dev:
	$(FLUTTER) build apk --debug --target-platform android-arm
	# adb install -r build/app/outputs/flutter-apk/app-debug.apk
	# adb shell monkey -p com.github.lamarios.clipious -c android.intent.category.LAUNCHER 1

# Build a release APK for the TV (armeabi-v7a) and deploy it
# Requires a keystore configured in android/key.properties
tv-prod:
	ANDROID_KEY_FILE=/home/fmgordillo/code/clipious/android/key.properties $(FLUTTER) build apk --release --target-platform android-arm
	# adb install -r build/app/outputs/flutter-apk/app-release.apk
	# adb shell monkey -p com.github.lamarios.clipious -c android.intent.category.LAUNCHER 1
