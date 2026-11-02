# Egg Farm Manager Flutter App

## Production API

The app defaults to `https://egg-farm-backend.onrender.com/api` on Web, Android, and iOS. To target a different backend, pass a complete API base URL ending in `/api` with `--dart-define=API_BASE=...`.

## Invoice sharing

The invoice share action downloads the generated PDF and opens the native share sheet with the PDF attached and invoice details as the message text. Choose WhatsApp in the share sheet to send the attachment and summary together; no PDF URL is added to the message.

## Web Deployment

From `frontend/`, build the production Flutter Web bundle locally:

```sh
flutter pub get
flutter build web --release
```

The output is `build/web`; deploy that directory directly if cloud building is too slow. The app defaults to the production API URL. To override it at build time, use `flutter build web --release --dart-define=API_BASE=https://your-api.example.com/api`.

For Vercel, set the project **Root Directory** to `frontend`. Its `vercel.json` runs `build.sh`, uses `build/web` as the output directory, and rewrites client-side routes to `/index.html` so direct navigation and page reloads work. The script downloads the Flutter stable SDK if it is not already present. Commit `vercel.json`, `build.sh`, and any relevant documentation changes; do not commit generated `build/web` output.

## Bill receipts

The Raw Material and Medicine inward forms accept JPEG, PNG, WebP, or PDF receipts up to 5 MB. Images can be captured with the camera or selected from the gallery on mobile; Web and gallery/file selection also support PDFs. The app first uploads the file to the authenticated backend, then saves only its returned URL and bill metadata with the inward log. Configure `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` on the backend, and create the `farm-receipts` bucket with the SQL in `backend/sql/farm_receipts_bucket.sql`. Never expose the service-role key in the Flutter app.

## Mobile Release Builds

```sh
flutter build appbundle --release --dart-define=API_BASE=https://egg-farm-backend.onrender.com/api
flutter build ipa --release --dart-define=API_BASE=https://egg-farm-backend.onrender.com/api
```

Android App Bundle builds require a configured Android toolchain. iOS IPA builds require macOS, Xcode, and signing configuration.

For iOS receipt camera/gallery access, add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` to `ios/Runner/Info.plist`.
