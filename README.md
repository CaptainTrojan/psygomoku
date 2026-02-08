# Psygomoku (Psychic Gomoku)

**Serverless P2P Gomoku with Cryptographic Fog of War**

A strategy board game based on Gomoku (5-in-a-row) with a unique "Mental Poker" twist. Players place pieces secretly using cryptographic commitments—guess your opponent's move correctly to block them!

## 🏗️ Architecture

**Hexagonal Architecture (Ports & Adapters)**
- `lib/domain/` - Pure Dart business logic
- `lib/infrastructure/` - External dependencies (WebRTC, Hive, Crypto)
- `lib/presentation/` - Flutter UI & Blocs

## 🚀 Quick Start

### Prerequisites
- Flutter SDK ^3.7.2
- Android Studio / VS Code
- Chrome (for Web platform)
- Android Emulator / Physical Device

### Installation

```bash
# Clone the repository
cd psygomoku

# Install dependencies
flutter pub get

# Run code generation
flutter pub run build_runner build --delete-conflicting-outputs

# Run on your platform
flutter run -d chrome        # Web
flutter run -d emulator-5554 # Android Emulator
```

### Multi-Device Debugging (VS Code)

Press **F5** and select **"Multi-Device (Web + Android)"** to launch both platforms simultaneously for P2P testing.

## 📦 Tech Stack

- **State Management:** flutter_bloc
- **Networking:** flutter_webrtc (Internet), nearby_connections (Offline)
- **Cryptography:** cryptography (AES-256, SHA-256)
- **Storage:** Hive
- **Code Generation:** freezed, json_serializable

## 🧪 Testing

```bash
# Unit tests
flutter test test/unit/

# Integration tests
flutter test test/integration/

# All tests
flutter test
```

## 📱 Platforms

- ✅ **Web** (Chrome, Edge, Firefox)
- ✅ **Android** (API 21+)

## 📖 Documentation

See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for full architecture and roadmap.

## 🎨 Theme

**Cyber-Zen Dark Mode**
- Background: `#121212`
- Player A: Cyan `#00E5FF`
- Player B: Pink `#FF4081`
- Grid: `#333333`

## 📄 License

Private project - Not for distribution

---

**Status:** 🚧 Phase 0 - In Development
