# Determine this makefile's path.
# Be sure to place this BEFORE `include` directives, if any.
THIS_FILE := $(lastword $(MAKEFILE_LIST))

FLAVOR = ""
ENV_FILE = ""
ANDROID_APP_TYPE = ""

build-runner:
	flutter clean
	flutter pub get
	dart run build_runner build
build-runner-watch:
	dart run build_runner watch

splashscreen:
	dart run flutter_native_splash:create --path flutter_native_splash.yaml
