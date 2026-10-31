# Egg Farm Manager Flutter App

## Production API

The app defaults to `https://egg-farm-backend.onrender.com/api` on Web, Android, and iOS. To target a different backend, pass a complete API base URL ending in `/api` with `--dart-define=API_BASE=...`.

## Web Deployment

From `frontend/`, build the production Flutter Web bundle locally:

```sh
flutter pub get
flutter build web --release
```

The output is `build/web`; deploy that directory directly if cloud building is too slow. The app defaults to the production API URL. To override it at build time, use `flutter build web --release --dart-define=API_BASE=https://your-api.example.com/api`.

For Vercel, set the project **Root Directory** to `frontend`. Its `vercel.json` runs `build.sh`, uses `build/web` as the output directory, and rewrites client-side routes to `/index.html` so direct navigation and page reloads work. The script downloads the Flutter stable SDK if it is not already present. Commit `vercel.json`, `build.sh`, and any relevant documentation changes; do not commit generated `build/web` output.

## Mobile Release Builds

```sh
flutter build appbundle --release --dart-define=API_BASE=https://egg-farm-backend.onrender.com/api
flutter build ipa --release --dart-define=API_BASE=https://egg-farm-backend.onrender.com/api
```

Android App Bundle builds require a configured Android toolchain. iOS IPA builds require macOS, Xcode, and signing configuration.
