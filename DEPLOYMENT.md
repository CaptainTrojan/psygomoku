# Psygomoku - Infrastructure Overhaul Complete

This document provides setup and deployment instructions after the infrastructure refactoring.

## What Changed

### Architecture
- **OLD:** QR code-based manual signaling only
- **NEW:** Dual-mode signaling:
  - **Manual Mode:** Offline copy/paste (no server required)
  - **Auto Mode:** Server-mediated with 4-digit session codes

### Backend
- **Cloudflare Workers + Durable Objects** for WebSocket signaling
- Serves Flutter web build via Workers Sites (KV)
- Rate limiting (10 sessions/hour/IP)
- 10-minute session TTL with auto-cleanup

### Flutter
- Pluggable signaling strategies
- Cleaner architecture (WebRTC transport separated from signaling)
- New UI for mode selection and connection flows

### CI/CD
- GitHub Actions for automated deployment
- Web: Cloudflare Workers
- Android: Google Play Store (Internal Track)

---

## Local Development Setup

### Prerequisites
- Flutter SDK `>= 3.7.2`
- Node.js `>= 20.x`
- (Optional) Android Studio for Android development
- (Optional) Wrangler CLI for Cloudflare development

### 1. Flutter Setup

```bash
# Install dependencies
flutter pub get

# Generate Freezed code
flutter pub run build_runner build --delete-conflicting-outputs

# Run on Chrome (uses localhost:8787 for backend by default)
flutter run -d chrome
```

### 2. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Run local development server
npm run dev
# Server runs at http://localhost:8787
```

### 3. Test Locally

1. Start backend: `cd backend && npm run dev`
2. Start Flutter web: `flutter run -d chrome`
3. In the app:
   - Click "HOST GAME" → Choose "AUTO"
   - Note the 4-digit code
   - Open incognito window
   - Click "JOIN GAME" → Enter the code
   - Connection should establish automatically

---

## Production Deployment

### Cloudflare Setup

1. **Create Cloudflare Account** (if needed)

2. **Update `backend/wrangler.toml`:**
   ```toml
   # After first deploy, add KV namespace ID:
   [[kv_namespaces]]
   binding = "ASSETS"
   id = "your_namespace_id_here"  # From: wrangler kv:namespace create ASSETS
   ```

3. **Manual Deploy:**
   ```bash
   # Build Flutter web
   flutter build web --release --dart-define=SIGNALING_URL=wss://your-worker.workers.dev

   # Deploy Worker
   cd backend
   npx wrangler login
   npx wrangler deploy
   ```

4. **Note Your Worker URL:**
   - Example: `https://psygomoku-worker.<account>.workers.dev`
   - Update this in your build commands

### Android Setup

1. **Generate Release Keystore:**
   ```bash
   keytool -genkey -v -keystore android/app/upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. **Create `android/key.properties`:**
   ```properties
   storePassword=<your_password>
   keyPassword=<your_password>
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```

3. **Manual Build:**
   ```bash
   flutter build appbundle --release
   # Output: build/app/outputs/bundle/release/app-release.aab
   ```

4. **Google Play Console:**
   - Create app entry
   - Upload AAB manually for first release
   - Create Service Account for CI/CD
   - Download JSON key

### GitHub Actions Setup

Required secrets (Settings → Secrets → Actions):

| Secret | Description | How to Get |
|--------|-------------|------------|
| `CF_API_TOKEN` | Cloudflare API token | cloudflare.com → My Profile → API Tokens → Create (Workers template) |
| `CF_ACCOUNT_ID` | Cloudflare account ID | Workers dashboard → Account ID |
| `SIGNALING_URL` | Production Worker URL | `wss://your-worker.workers.dev` |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded keystore | `base64 -i android/app/upload-keystore.jks` (Linux/Mac) or `certutil -encode upload-keystore.jks keystore.txt` (Windows) |
| `KEYSTORE_PASSWORD` | Keystore password | From step 1 above |
| `KEY_PASSWORD` | Key password | From step 1 above |
| `KEY_ALIAS` | Key alias | `upload` |
| `PLAY_STORE_JSON` | Service account JSON | Google Cloud Console → Service Accounts → Keys |

**Trigger Deployment:**
```bash
git push origin main
# Automatically deploys to Cloudflare and Play Store Internal Track
```

---

## Configuration

### Environment URLs

Edit [lib/core/config/app_config.dart](lib/core/config/app_config.dart) to change default signaling URLs:

```dart
static String get signalingServerUrl {
  const definedUrl = String.fromEnvironment('SIGNALING_URL');
  if (definedUrl.isNotEmpty) return definedUrl;

  // Update these defaults:
  if (kDebugMode) {
    return kIsWeb ? 'ws://localhost:8787' : 'ws://10.0.2.2:8787';
  } else {
    return 'wss://psygomoku-worker.example.workers.dev'; // Change this!
  }
}
```

### Build-Time Configuration

Use `--dart-define` to override:

```bash
flutter build web --dart-define=SIGNALING_URL=wss://your-server.com
flutter build appbundle --dart-define=SIGNALING_URL=wss://your-server.com
```

---

## Testing

### Manual Testing Checklist

- [ ] **Manual Mode (Offline):**
  - [ ] Host generates offer
  - [ ] Joiner pastes offer, generates answer
  - [ ] Host pastes answer
  - [ ] Connection establishes

- [ ] **Auto Mode (Server-based):**
  - [ ] Host gets 4-digit code
  - [ ] Joiner enters code
  - [ ] Connection establishes automatically

- [ ] **Cross-platform:**
  - [ ] Web (Chrome) ↔ Web (Firefox)
  - [ ] Web ↔ Android
  - [ ] Android ↔ Android

- [ ] **Error Handling:**
  - [ ] Invalid session code
  - [ ] Backend offline (Manual mode still works)
  - [ ] Connection timeout

### Unit Tests

```bash
flutter test
```

---

## Architecture Diagrams

### Signaling Flow (Auto Mode)

```
Host                  Backend (DO)           Joiner
 |                         |                    |
 |-- Create Session ------>|                    |
 |<---- Code: 1234 --------|                    |
 |                         |                    |
 |-- WebSocket Connect --->|                    |
 |-- Send Offer ---------->|                    |
 |                         |<-- WS Connect -----|
 |                         |<-- (receives offer)|
 |                         |--- Send Offer ---->|
 |                         |<-- Send Answer ----|
 |<----- Answer -----------|                    |
 |                         |                    |
 |<======= P2P Data Channel =================>|
```

### Manual Flow

```
Host                          Joiner
 |                               |
 |-- Generate Offer              |
 |    (Copy to clipboard)        |
 |                               |
 |   (User shares offer via      |
 |    external channel)          |
 |                               |
 |                          Paste Offer --|
 |                          Generate Answer
 |                        (Copy to clipboard)
 |                               |
 |<-- (User shares answer        |
 |     via external channel)     |
 |                               |
 Paste Answer ---|               |
 |                               |
 |<======= P2P Data Channel ====|
```

---

## Troubleshooting

### Backend Issues

**"Room full" error:**
- Durable Object limits 2 connections (host + joiner)
- Wait for previous session to expire (10 minutes) or use different code

**Rate limit exceeded:**
- 10 sessions/hour/IP
- Wait or use different network

**WebSocket fails:**
- Check CORS settings in Worker
- Verify Worker URL is correct
- Check browser console for errors

### Flutter Issues

**Compilation errors after upgrade:**
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

**Android build fails:**
- Verify `key.properties` exists in `android/`
- Check keystore password
- Ensure JDK 17 installed

**Connection timeout:**
- Check if backend is running (`wrangler dev` or deployed)
- Verify SIGNALING_URL matches backend URL
- Check firewall/network restrictions

---

## Resources

- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
- [Flutter WebRTC Plugin](https://pub.dev/packages/flutter_webrtc)
- [GitHub Actions for Flutter](https://docs.flutter.dev/deployment/cd)
- [Google Play Console](https://play.google.com/console)

---

## License

MIT (or your existing license)
