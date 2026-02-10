import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_state.dart';

/// Abstract interface for WebRTC signaling strategies
/// 
/// Implementations handle the exchange of SDP offers/answers between peers.
/// Different strategies support different signaling methods (manual copy/paste,
/// server-mediated exchange, etc.).
abstract class ISignalingStrategy {
  /// Stream of signaling state changes
  Stream<SignalingState> get onStateChanged;

  /// Current signaling state
  SignalingState get currentState;

  /// Exchange signaling data with peer
  /// 
  /// [peerConnection] The WebRTC peer connection to configure
  /// [isHost] Whether this peer is the host (creates offer) or joiner (creates answer)
  /// 
  /// This method handles the full signaling exchange:
  /// - For host: creates offer, waits for ICE, exchanges with peer
  /// - For joiner: waits for offer, creates answer, waits for ICE
  Future<void> exchangeSignals(RTCPeerConnection peerConnection, bool isHost);

  /// Dispose resources
  void dispose();
}
