import 'package:logger/logger.dart';

/// Centralized logging configuration for the app.
/// 
/// Each module has its own logger that can be enabled/disabled independently.
/// This makes debugging specific issues much easier without log spam.
class AppLogger {
  AppLogger._();

  /// Log levels for different modules.
  /// 
  /// Set to Level.off to disable, Level.debug for detailed logs,
  /// Level.info for important events only.
  static const _moduleLevels = {
    LogModule.webrtc: Level.off,      // WebRTC transport layer
    LogModule.connection: Level.off,  // Connection state management
    LogModule.chat: Level.off,         // Chat functionality
    LogModule.game: Level.info,         // Game logic (future)
    LogModule.ui: Level.info,           // UI events (future)
  };

  /// Get a logger for a specific module.
  static Logger getLogger(LogModule module) {
    final level = _moduleLevels[module] ?? Level.info;
    
    return Logger(
      filter: _ModuleFilter(level),
      printer: PrettyPrinter(
        methodCount: 0,        // No stack trace (cleaner logs)
        errorMethodCount: 3,   // Stack trace only for errors
        lineLength: 80,        // Wrap long lines
        colors: true,          // Color in browser console
        printEmojis: true,     // Visual indicators
        printTime: false,      // Time not needed (browser shows it)
      ),
    );
  }
}

/// Log filter that respects the configured level.
class _ModuleFilter extends LogFilter {
  _ModuleFilter(this.level);

  final Level level;

  @override
  bool shouldLog(LogEvent event) {
    return event.level.index >= level.index;
  }
}

/// Available logging modules.
enum LogModule {
  webrtc,
  connection,
  chat,
  game,
  ui,
}
