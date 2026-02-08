# Logging System

## Overview

The app uses module-based logging with the `logger` package. Each module (WebRTC, Connection, Chat, etc.) has its own logger that can be independently configured.

## Configuration

Edit `lib/core/logging/app_logger.dart` to control log levels:

```dart
static const _moduleLevels = {
  LogModule.webrtc: Level.debug,      // Detailed WebRTC logs
  LogModule.connection: Level.debug,  // Connection state logs
  LogModule.chat: Level.info,         // Important chat events
  LogModule.game: Level.info,         // Game logic (future)
  LogModule.ui: Level.info,           // UI events (future)
};
```

## Log Levels

- **Level.off** - No logs (production)
- **Level.error** - Only errors
- **Level.warning** - Warnings and errors
- **Level.info** - Important information + warnings + errors
- **Level.debug** - Detailed debugging + all above
- **Level.trace** - Everything including very verbose logs

## Usage

### In Your Code

```dart
import 'package:logger/logger.dart';
import '../../core/logging/app_logger.dart';

class MyClass {
  final _log = AppLogger.getLogger(LogModule.webrtc);
  
  void myMethod() {
    _log.d('Debug message');           // Debug
    _log.i('Info message');            // Info
    _log.w('Warning message');         // Warning
    _log.e('Error message');           // Error
    _log.t('Trace message');           // Trace (very verbose)
  }
}
```

### Viewing Logs

**Browser DevTools Console:**
- Open DevTools (F12)
- Go to Console tab
- Logs are color-coded by level
- Each browser tab has its own isolated log stream
- Use browser console filters to show/hide specific modules

**Filtering Examples:**
- Show only WebRTC: Filter by emoji or "webrtc"
- Show errors only: Filter by "❗" or "ERROR"
- Show specific function: Search for function name

## Debugging WebRTC Issues

For deep debugging of connection issues:

```dart
static const _moduleLevels = {
  LogModule.webrtc: Level.trace,      // ⬅️ Maximum verbosity
  LogModule.connection: Level.debug,
  // ...
};
```

This will show:
- Every state change
- Every message sent/received
- ICE candidate details
- Data channel events
- Compression stats

## Production Configuration

For production deployments, set all levels to `Level.off` or `Level.error`:

```dart
static const _moduleLevels = {
  LogModule.webrtc: Level.off,
  LogModule.connection: Level.off,
  LogModule.chat: Level.error,        // Only show chat errors
  LogModule.game: Level.error,
  LogModule.ui: Level.off,
};
```

## Adding New Modules

1. Add to `LogModule` enum in `app_logger.dart`:
```dart
enum LogModule {
  webrtc,
  connection,
  chat,
  game,
  ui,
  myNewModule,  // ⬅️ Add here
}
```

2. Add default level:
```dart
static const _moduleLevels = {
  // ... existing modules
  LogModule.myNewModule: Level.info,
};
```

3. Use in your code:
```dart
final _log = AppLogger.getLogger(LogModule.myNewModule);
```

## Performance Notes

- Log calls with Level.off have near-zero overhead (filtered before formatting)
- Debug/trace logs are cheap in browser console (no file I/O)
- Consider using Level.off for modules you're not actively debugging
- Each browser tab maintains its own log buffer

## Tips

- **During development**: Use `Level.debug` or `Level.info`
- **When debugging specific issue**: Set that module to `Level.trace`
- **Before commit**: Set to `Level.info` or `Level.off`
- **In production**: Use `Level.off` or `Level.error` only
- **Browser console**: Use filters liberally - logs can be overwhelming with multiple modules at debug level
