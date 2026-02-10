import 'package:flutter/foundation.dart';

/// Application configuration
/// 
/// Centralizes environment-specific configuration such as backend URLs.
/// Uses compile-time constants and --dart-define for build-time configuration.
class AppConfig {
  AppConfig._();

  /// Signaling server URL for WebRTC
  /// 
  /// Can be overridden at build time using:
  /// ```
  /// flutter build web --dart-define=SIGNALING_URL=wss://your-server.com
  /// flutter build appbundle --dart-define=SIGNALING_URL=wss://your-server.com
  /// ```
  /// 
  /// Default values:
  /// - Development: ws://localhost:8787 (local Wrangler dev server)
  /// - Production Web: wss://psygomoku-worker.<account>.workers.dev
  static String get signalingServerUrl {
    // Check for compile-time override
    const definedUrl = String.fromEnvironment('SIGNALING_URL');
    if (definedUrl.isNotEmpty) {
      return definedUrl;
    }

    // Default based on platform and mode
    if (kDebugMode) {
      // Development mode
      if (kIsWeb) {
        return 'ws://localhost:8787';
      } else {
        // Android/iOS emulator: use 10.0.2.2 for Android emulator localhost
        // For physical devices, use your computer's local IP
        return 'ws://10.0.2.2:8787';
      }
    } else {
      // Production mode - must be set via --dart-define
      return 'wss://psygomoku-worker.example.workers.dev';
    }
  }

  /// Whether to use server-based signaling by default
  /// 
  /// If false, shows mode selection screen. If true, defaults to auto mode.
  static const bool defaultToAutoMode = false;

  /// Maximum session code length (4 digits)
  static const int sessionCodeLength = 4;

  /// WebRTC configuration
  static const Map<String, dynamic> webrtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  /// ICE gathering timeout (milliseconds)
  static const int iceGatheringTimeout = 10000; // 10 seconds for server-mediated

  /// Session timeout (milliseconds)
  static const int sessionTimeout = 600000; // 10 minutes
}
