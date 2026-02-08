# Master Design Document (MDD): Psygomoku

**Status:** Approved for Implementation
**Target Audience:** Human Developers & AI Coding Agents
**Version:** 2.0 (Network-First)

---

# 1. Executive Summary

**Product Name:** Psygomoku (Psychic Gomoku)
**Platforms:** Android, Web
**Core Philosophy:** Serverless, Trustless, Local-First.

**Concept:**
Psygomoku is a strategy board game based on Gomoku (5-in-a-row). It introduces a "Fog of War" mechanic derived from Mental Poker. Players do not place pieces openly; they **mark** a spot secretly. The opponent must **guess** the spot. Regardless of the guess, the mark becomes a permanent piece on the board, but the question is (and the core idea of the game), whose piece it becomes.
*   If the guess is **wrong**: The marker gets a stone on the marked place and it's the guesser's turn to mark now (turn switch).
*   If the guess is **correct**: The guesser gets a stone on the marked place and the marker is marking again. This can lead to guess chains if the marker is making poor marks.

**Implementation Strategy: Infrastructure-First**
We will not build "throwaway" logic. We will implement the WebRTC transport layer immediately. Development and debugging will primarily occur in a **Multi-Device environment** (Web vs. Android Emulator) to guarantee network reliability before game rules are applied.

---

# 2. Game Rules & Mechanics

### 2.1 The Board
*   **Grid:** 15x15 intersection points.
*   **Pieces:** Black and White stones.
*   **Win Condition:** Exactly or more than 5 stones of the same color in a continuous row, column, or diagonal.

### 2.2 The Turn Protocol (The "Psychic" Loop)
A single turn consists of a cryptographically secure handshake using **AES-256 (GCM)** and **SHA-256**.

1.  **State: MARK (Active Player)**
    *   Player A selects `(x,y)`.
    *   System generates random `Salt`.
    *   System computes `Hash = SHA256(x + y + Salt)`.
    *   System sends `Hash` to Player B.

2.  **State: GUESS (Passive Player)**
    *   Player B selects prediction `(gx, gy)`.
    *   System sends `(gx, gy)` in **plaintext** to Player A.

3.  **State: REVEAL (Active Player)**
    *   Player A receives guess.
    *   **Logic:** If `(gx, gy) == (x,y)`, Player A is blocked. Else, Player A places stone.
    *   System sends `(x, y)` and `Salt` to Player B.

4.  **State: VERIFY (Passive Player)**
    *   Player B computes `TestHash = SHA256(x + y + Salt)`.
    *   If `TestHash != OriginalHash`, Player A triggers **AUTO-FORFEIT (Cheating)**.
    *   Board updates. Turn switches.

---

# 3. Functional Requirements

### 3.1 Networking Modes
1.  **Online P2P (WebRTC):** **(Primary Mode)**
    *   Works over Internet.
    *   Requires "Signaling" via QR Code or Deep Link (`psygomoku://join?data=...`).
2.  **Local P2P (Nearby Connections):** **(Secondary Mode)**
    *   Android-to-Android only.
    *   Uses Bluetooth/Wi-Fi Direct (No Internet).

### 3.2 Time Controls
The system supports a basic timer.
*   **Implementation:** "Opponent is Judge." The active player's clock ticks on their device. Their 'Time Remaining' is sent with every message. If the opponent receives a message with `time < 0`, they claim a Timeout Win.
*   **Presets:**
    *   *Bullet:* 1 min
    *   *Blitz:* 3 min
    *   *Rapid:* 5 min
    *   *Casual:* Unlimited

### 3.3 Chat System
*   **Type:** Text-only, Ephemeral (not stored).
*   **Scope:** In-game only.
*   **UI:** An overlay/drawer that slides up over the board.
*   **UX:** Bubbles appear briefly over the avatar, then fade.

### 3.4 Identity (MVP)
*   **Storage:** Local (`shared_preferences` / `Hive`).
*   **Fields:** `Nickname` (String), `AvatarColor` (Hex), `Wins` (Int), `Losses` (Int).
*   **Exchange:** Profiles are exchanged in the initial Handshake packet.

---

# 4. Architecture: Hexagonal (Ports & Adapters)

We separate the "Game Rules" from the "Transport".

```mermaid
graph TD
    UI[Flutter UI Layer] --> BLOC[State Management (Bloc)]
    BLOC --> DOMAIN[Domain Layer (Pure Dart)]
    BLOC --> INFRA[Infrastructure Layer]
    
    subgraph DOMAIN
    Rules[GameRules Engine]
    Crypto[AES/SHA Service]
    Entities[Board, Move, Player]
    end
    
    subgraph INFRA
    Repo[GameRepository]
    Transport[IGameTransport Interface]
    WebRTC[WebRTC Adapter (Internet)]
    Nearby[Nearby Adapter (Bluetooth)]
    end
```

### 4.2 Technology Stack
*   **State:** `flutter_bloc`
*   **Data:** `freezed` (Immutable models), `json_serializable`
*   **Crypto:** `cryptography`
*   **Net 1:** `flutter_webrtc` (Online)
*   **Net 2:** `nearby_connections` (Offline)
---

# 5. Testing & Debugging Strategy

This is a two-device system. We debug it as such.

### 5.1 Tier 1: Multi-Device Debugging (The Standard)
We do **not** rely on single-device simulation for integration.
*   **Tool:** VS Code Compound Launch.
*   **Setup:** `launch.json` configured to launch **Chrome (Client A)** and **Android Emulator (Client B)** simultaneously.
*   **Workflow:**
    1.  Hit F5 -> Both windows open.
    2.  Set breakpoints in `WebRTCTransport`.
    3.  Verify handshake and data flow across the simulated internet.

### 5.2 Tier 2: Automated Integration (Headless WebRTC)
To ensure the pipeline never breaks.
*   **Tool:** Docker + Dart CLI.
*   **Scenario:**
    1.  Script starts `Container A` (Host) and `Container B` (Joiner).
    2.  Script pipes `stdout` (SDP Offer) from A to `stdin` of B.
    3.  Script pipes `stdout` (SDP Answer) from B to `stdin` of A.
    4.  **Assertion:** `flutter_webrtc` establishes a DataChannel and exchanges 10 dummy packets successfully.

---

# 5. UI/Design Guide ("Cyber-Zen")

**Theme:** Dark Mode by default. High contrast.
**Palette:**
*   **Background:** Deep Charcoal (`#121212`)
*   **Grid Lines:** Faint Grey (`#333333`)
*   **Player A (Self):** Neon Cyan (`#00E5FF`)
*   **Player B (Opponent):** Neon Pink (`#FF4081`)
*   **Timer (Normal):** White (`#FFFFFF`)
*   **Timer (Low):** Amber (`#FFC107`) -> Red (`#FF5252`)

**Key Screens:**
1.  **Home:** Large Logo, 3 Big Buttons (Online, Nearby, Pass & Play), small "Profile" icon top-right.
2.  **Lobby (Host):** Shows large QR Code in center. "Share Link" button below. "Waiting for opponent..." spinner.
3.  **Lobby (Join):** Split screen: Top half Camera (Scanner), Bottom half "Paste Link".
4.  **Game Board:**
    *   Top Bar: Opponent Name, Avatar, Timer.
    *   Center: 15x15 Zoomable Grid.
    *   Bottom Bar: Your Name, Avatar, Timer.
    *   Floating Action Button: "Chat".

# 6. Implementation Roadmap

### Phase 1: The "P2P Echo" (Tracer Bullet)
**Goal:** Prove Device A (Android) and Device B (Web) can talk.
*   **Task 1.1:** Setup Flutter project & `launch.json` for multi-device debugging.
*   **Task 1.2:** Implement `WebRTCTransport`.
*   **Task 1.3:** Build the "Signaling UI" (Generate QR / Scan QR / Paste Link).
*   **Task 1.4:** **Verification:** Send `{"text": "Ping"}` from Android, receive `{"text": "Pong"}` on Web.

### Phase 2: The Protocol (Data Layer)
**Goal:** Ensure complex data survives the network.
*   **Task 2.1:** Define Domain Models (`Move`, `GameConfig`, `TimeState`) using `freezed`.
*   **Task 2.2:** Implement `BroadcastTransport` for faster local iteration.
*   **Task 2.3:** **Verification:** Serialize a full Board object, send it, deserialize it, and assert equality.

### Phase 3: The Engine (Game Logic)
**Goal:** Connect the pipe to the brain.
*   **Task 3.1:** Implement `Board` logic (5-in-a-row check).
*   **Task 3.2:** Implement `CryptoService` (AES/SHA).
*   **Task 3.3:** Implement `GameBloc` (The State Machine: Mark -> Guess -> Reveal).
*   **Task 3.4:** **Verification:** Play a full game in "Cross-Tab" mode.

### Phase 4: UI & Polish
**Goal:** Make it playable for humans.
*   **Task 4.1:** Build the "Cyber-Zen" 15x15 Grid.
*   **Task 4.2:** Add Timers and Chat Overlay.
*   **Task 4.3:** Add Haptic Feedback and Sounds.

### Phase 5: The Offline Adapter
**Goal:** Android-to-Android capability.
*   **Task 5.1:** Implement `NearbyTransport` (Copying the interface from Phase 1).
*   **Task 5.2:** Handle Android Permissions.
*   **Task 5.3:** **Verification:** Play a game between two emulators (if supported) or physical devices without Wi-Fi.

---

# 7. Instructions for Coding Agents

*   **Context:** You are building a Serverless P2P Game.
*   **Constraint 1 (Network):** Always assume the `Transport` is asynchronous. Never block the UI waiting for a message.
*   **Constraint 2 (Typing):** Use strict Dart typing.
*   **Constraint 3 (Testing):** When asked to write a test, prioritize **Integration Tests** that mock the `IGameTransport` interface to simulate packet loss or delay.
*   **Constraint 4 (State):** All game state must be reconstructible from the history of JSON messages.