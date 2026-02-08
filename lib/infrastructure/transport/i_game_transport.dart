/// Abstract interface for game transport layer.
/// 
/// This defines the contract for all transport implementations
/// (WebRTC, Nearby Connections, etc.) following the Hexagonal Architecture pattern.
abstract class IGameTransport {
  /// Stream of incoming messages from the opponent.
  /// Emits Map<String, dynamic> representing JSON-serializable game messages.
  Stream<Map<String, dynamic>> get onMessage;

  /// Stream that emits when connection is lost.
  Stream<void> get onDisconnect;

  /// Stream that emits connection state changes.
  Stream<ConnectionState> get onStateChanged;

  /// Get the current connection state.
  ConnectionState get connectionState;

  /// Connect to opponent using signaling data.
  /// 
  /// For WebRTC: [signalData] contains SDP offer/answer and ICE candidates.
  /// For Nearby: [signalData] contains device ID.
  Future<void> connect(String signalData);

  /// Send a message to the opponent.
  /// 
  /// [data] must be a JSON-serializable Map.
  /// Returns true if sent successfully, false otherwise.
  Future<bool> send(Map<String, dynamic> data);

  /// Close the connection and clean up resources.
  Future<void> dispose();
}

/// Connection state for transport layer.
enum ConnectionState {
  idle,
  connecting,
  connected,
  disconnected,
  failed,
}
