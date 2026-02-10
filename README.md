# Psygomoku (Psycho-Gomoku)

**Serverless P2P Gomoku with Cryptographic 'Fog of War'**

A strategy board game based on Gomoku (5-in-a-row) with a unique "Mental Poker" twist. Players place pieces secretly using cryptographic commitments—guess your opponent's move correctly to steal their turn!

## 🎮 Game Rules

### The Board
- **Grid:** 15×15 intersection points
- **Pieces:** Cyan (Player 1) and Magenta (Player 2) glowing stones
- **Win Condition:** 5 or more stones of the same color in a continuous row, column, or diagonal

### The Psycho Turn Protocol

Each turn is a cryptographic handshake that creates "fog of war". Let's say that it's Alice's turn to place a stone. In normal gomoku, she would do just that and it would be Bob's turn to play next. But here, each turn has four phases:

1. **MARK Phase**
   - Alice secretly selects coordinates `(x, y)`
   - System generates random `Salt`
   - System computes `Hash = SHA256(x + y + Salt)`
   - System sends only `Hash` to Bob
   
2. **GUESS Phase**
   - Bob tries to predict the marked spot `(gx, gy)`
   - System sends guess in plaintext to Alice
   
3. **REVEAL Phase**
   - Alice reveals `(x, y, Salt)` to Bob
   
4. **VERIFY Phase**
   - Bob computes `TestHash = SHA256(x + y + Salt)`
   - If `TestHash ≠ Hash` → Bob **auto-disconnects** from Alice (cheating detected)
   - If guess was **correct** `(gx, gy) == (x, y)`:
     - **Bob** gets a stone at that position instead of Alice (intercepted!)
     - Alice **marks again** (turn doesn't switch)
   - If guess was **wrong**:
     - Alice gets a stone at marked position (like in normal gomoku)
     - Turn switches to Bob (like in normal gomoku)

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
