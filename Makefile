# Determine this makefile's path.
# Be sure to place this BEFORE `include` directives, if any.
THIS_FILE := $(lastword $(MAKEFILE_LIST))

FLAVOR = ""
ENV_FILE = ""
ANDROID_APP_TYPE = ""

build-runner:
	dart run build_runner build --delete-conflicting-outputs
build-runner-watch:
	dart run build_runner watch --delete-conflicting-outputs

splashscreen:
	dart run flutter_native_splash:create --path flutter_native_splash.yaml

# Build a debug APK for Android (split per ABI) and deploy it
android-dev:
	flutter build apk --debug --split-per-abi
	# adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk
	# adb shell monkey -p com.github.lamarios.clipious -c android.intent.category.LAUNCHER 1

# Build a release APK for Android (split per ABI) and deploy it
# Requires a keystore configured in android/key.properties
android-prod:
	ANDROID_KEY_FILE=/home/fmgordillo/code/clipious/android/key.properties flutter build apk --release --split-per-abi
	# adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
	# adb shell monkey -p com.github.lamarios.clipious -c android.intent.category.LAUNCHER 1

# Build a debug APK for the TV (armeabi-v7a) and deploy it
tv-dev:
	flutter build apk --debug --target-platform android-arm
	# adb install -r build/app/outputs/flutter-apk/app-debug.apk
	# adb shell monkey -p com.github.lamarios.clipious -c android.intent.category.LAUNCHER 1

# Build a release APK for the TV (armeabi-v7a) and deploy it
# Requires a keystore configured in android/key.properties
tv-prod:
	ANDROID_KEY_FILE=/home/fmgordillo/code/clipious/android/key.properties flutter build apk --release --target-platform android-arm
	# adb install -r build/app/outputs/flutter-apk/app-release.apk
	# adb shell monkey -p com.github.lamarios.clipious -c android.intent.category.LAUNCHER 1
