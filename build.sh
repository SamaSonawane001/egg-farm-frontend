#!/usr/bin/env bash
set -euo pipefail

if [ -d flutter/.git ]; then
  git -C flutter pull --ff-only
elif [ ! -e flutter ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable
else
  echo "The flutter path exists but is not a Git checkout." >&2
  exit 1
fi

export PATH="$PWD/flutter/bin:$PATH"
export API_BASE="${API_BASE:-https://egg-farm-backend.onrender.com/api}"

flutter config --enable-web
flutter pub get
flutter build web --release --dart-define="API_BASE=$API_BASE"
