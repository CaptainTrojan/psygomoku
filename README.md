# Psygomoku (Psychic Gomoku)

**Serverless P2P Gomoku with Cryptographic Fog of War**

A strategy board game based on Gomoku (5-in-a-row) with a unique "Mental Poker" twist. Players place pieces secretly using cryptographic commitments—guess your opponent's move correctly to steal their turn!

## 🎮 Game Rules

### The Board
- **Grid:** 15×15 intersection points
- **Pieces:** Cyan (Player 1) and Magenta (Player 2) glowing stones
- **Win Condition:** 5 or more stones of the same color in a continuous row, column, or diagonal

### The Psychic Turn Protocol

Each turn is a cryptographic handshake that creates "fog of war":

1. **MARK Phase** (Active Player)
   - Player A secretly selects coordinates `(x, y)`
   - System generates random `Salt`
   - System computes `Hash = SHA256(x + y + Salt)`
   - System sends only `Hash` to Player B
   
2. **GUESS Phase** (Passive Player)
   - Player B tries to predict the marked spot `(gx, gy)`
   - System sends guess in plaintext to Player A
   
3. **REVEAL Phase** (Active Player)
   - Player A reveals `(x, y, Salt)` to Player B
   
4. **VERIFY Phase** (Passive Player)
   - Player B computes `TestHash = SHA256(x + y + Salt)`
   - If `TestHash ≠ Hash` → Player A **auto-forfeits** (cheating detected)
   - If guess was **correct** `(gx, gy) == (x, y)`:
     - Player B gets a stone at that position (intercepted!)
     - Player A marks again (turn doesn't switch)
   - If guess was **wrong**:
     - Player A gets a stone at marked position
     - Turn switches to Player B

### Move Confirmation
- **Two-Step Selection:** First tap selects, second tap confirms
- Tapping a different spot cancels the previous selection
- Only the active player (marker or guesser) can select positions

### Timers & Anti-Cheat
- Each player has a countdown timer
- Timer runs for the **active player** (marker or guesser)
- Opponent validates timer consistency (±2 seconds tolerance)
- Timer cheat detection triggers auto-forfeit

### Visual Feedback
- **Correct Guess:** Stone appears in guesser's color with marker's border (stolen piece effect)
- **Wrong Guess:** Stone in marker's color + small X at guess location in guesser's color

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

**Status:** 🚧 Implementing Core Game Logic (Phase 2-3)
