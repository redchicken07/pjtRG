#!/usr/bin/env sh
set -eu

FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter-sdk}"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi

PATH="$FLUTTER_ROOT/bin:$PATH"

flutter config --enable-web
flutter pub get
flutter build web --release
