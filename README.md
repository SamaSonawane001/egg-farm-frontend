# Egg Farm Manager Flutter App

## Production API

The app defaults to `https://egg-farm-backend.onrender.com/api` on Web, Android, and iOS. To target a different backend, pass a complete API base URL ending in `/api` with `--dart-define=API_BASE=...`.

## Web Deployment

Build the production Flutter Web bundle from this directory:

```sh
flutter build web --release --dart-define=API_BASE=https://egg-farm-backend.onrender.com/api
```

Deploy `build/web` as the static output directory on Vercel. `vercel.json` rewrites client-side routes to `/` so direct navigation and page reloads work. The PWA manifest and Flutter-generated service worker are included in the web build.

## Mobile Release Builds

```sh
flutter build appbundle --release --dart-define=API_BASE=https://egg-farm-backend.onrender.com/api
flutter build ipa --release --dart-define=API_BASE=https://egg-farm-backend.onrender.com/api
```

Android App Bundle builds require a configured Android toolchain. iOS IPA builds require macOS, Xcode, and signing configuration.
