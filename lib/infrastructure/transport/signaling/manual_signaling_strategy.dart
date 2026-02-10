import 'dart:async';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/logging/app_logger.dart';
import 'i_signaling_strategy.dart';
import 'signaling_state.dart';

/// Manual signaling strategy using copy/paste
/// 
/// This strategy implements offline P2P signaling where users manually
/// exchange SDP offers and answers via copy/paste. No server required.
class ManualSignalingStrategy implements ISignalingStrategy {
  final _log = AppLogger.getLogger(LogModule.webrtc);
  final _stateController = StreamController<SignalingState>.broadcast();
  
  SignalingState _currentState = SignalingState.idle();
  RTCPeerConnection? _peerConnection;
  bool _isDisposed = false;

  @override
  Stream<SignalingState> get onStateChanged => _stateController.stream;

  @override
  SignalingState get currentState => _currentState;

  @override
  Future<void> exchangeSignals(RTCPeerConnection peerConnection, bool isHost) async {
    if (_isDisposed) {
      throw Exception('Strategy disposed');
    }

    _peerConnection = peerConnection;
    _updateState(SignalingState.gathering());

    try {
      if (isHost) {
        await _createOffer();
        // Host will wait for UI to call receiveAnswer()
      } else {
        // Joiner will wait for UI to call receiveOffer()
        // Nothing to do here yet
        _updateState(SignalingState.idle());
      }
    } catch (e) {
      _log.e('Signaling error: $e');
      _updateState(SignalingState.failed(e.toString()));
      rethrow;
    }
  }

  /// Host: Create and return SDP offer
  Future<void> _createOffer() async {
    _log.d('Creating offer...');

    // Create offer
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    _log.d('Offer created and set as local description');

    // Wait for ICE gathering to complete (bundles all candidates in SDP)
    await _waitForIceGatheringComplete();
    _log.d('ICE gathering complete');

    // Get the complete offer with all ICE candidates baked into SDP
    final completeOffer = await _peerConnection!.getLocalDescription();
    final offerMap = completeOffer!.toMap();
    final offerJson = json.encode(offerMap);
    _log.d('Offer JSON length: ${offerJson.length}');

    // Compress and encode
    final compressed = _compressSignalData(offerJson);
    
    // Update state with offer for UI to display
    _updateState(SignalingState.exchanging(offerSdp: compressed));
  }

  /// Joiner: Receive offer from UI and create answer
  Future<void> receiveOffer(String compressedOffer) async {
    if (_isDisposed) {
      throw Exception('Strategy disposed');
    }

    _log.d('Receiving offer (${compressedOffer.length} bytes compressed)');
    _updateState(SignalingState.gathering());

    try {
      // Decompress the offer
      final decompressed = _decompressSignalData(compressedOffer);
      final data = json.decode(decompressed) as Map<String, dynamic>;
      final sdp = data['sdp'] as String;
      final type = data['type'] as String;

      // Set remote description (offer)
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, type),
      );
      _log.d('Remote description set (offer)');

      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      _log.d('Answer created and set as local description');

      // Wait for ICE gathering to complete
      await _waitForIceGatheringComplete();
      _log.d('ICE gathering complete');

      // Get the complete answer with all ICE candidates baked into SDP
      final completeAnswer = await _peerConnection!.getLocalDescription();
      final answerMap = completeAnswer!.toMap();
      final answerJson = json.encode(answerMap);
      _log.d('Answer JSON length: ${answerJson.length}');

      // Compress and encode
      final compressed = _compressSignalData(answerJson);

      // Update state with answer for UI to display
      _updateState(SignalingState.exchanging(answerSdp: compressed));
      
      // Mark complete (P2P negotiation will finish automatically)
      _updateState(SignalingState.complete());
    } catch (e) {
      _log.e('Error receiving offer: $e');
      _updateState(SignalingState.failed(e.toString()));
      rethrow;
    }
  }

  /// Host: Receive answer from UI and complete signaling
  Future<void> receiveAnswer(String compressedAnswer) async {
    if (_isDisposed) {
      throw Exception('Strategy disposed');
    }

    _log.d('Receiving answer (${compressedAnswer.length} bytes compressed)');

    try {
      // Decompress the answer
      final decompressed = _decompressSignalData(compressedAnswer);
      final data = json.decode(decompressed) as Map<String, dynamic>;
      final sdp = data['sdp'] as String;
      final type = data['type'] as String;

      // Set remote description (answer)
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, type),
      );
      _log.d('Remote description set (answer)');

      // Mark complete
      _updateState(SignalingState.complete());
    } catch (e) {
      _log.e('Error receiving answer: $e');
      _updateState(SignalingState.failed(e.toString()));
      rethrow;
    }
  }

  /// Wait for ICE gathering to complete
  Future<void> _waitForIceGatheringComplete() async {
    final completer = Completer<void>();

    // Check current state
    final gatheringState = _peerConnection?.iceGatheringState;
    _log.d('Current ICE gathering state: $gatheringState');

    if (gatheringState == RTCIceGatheringState.RTCIceGatheringStateComplete) {
      _log.d('ICE gathering already complete');
      return;
    }

    // Set up callback for gathering state changes
    _peerConnection?.onIceGatheringState = (state) {
      _log.d('ICE gathering state changed: $state');
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    };

    // Wait for completion or timeout after 5 seconds
    try {
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _log.d('ICE gathering timeout - proceeding anyway');
        },
      );
    } catch (e) {
      _log.d('Error waiting for ICE gathering: $e');
    }
  }

  /// Compress and base64 encode signaling data
  String _compressSignalData(String jsonData) {
    _log.d('Compressing signal data (${jsonData.length} bytes)');

    // Convert string to bytes
    final bytes = utf8.encode(jsonData);

    // Gzip compress
    final compressed = GZipEncoder().encode(bytes);

    // Base64 encode
    final encoded = base64Encode(compressed!);

    _log.d('Compressed to ${encoded.length} bytes (${(encoded.length / jsonData.length * 100).toStringAsFixed(1)}%)');
    return encoded;
  }

  /// Decompress base64 encoded signaling data
  String _decompressSignalData(String encodedData) {
    _log.d('Decompressing signal data (${encodedData.length} bytes)');

    // Base64 decode
    final compressed = base64Decode(encodedData);

    // Gzip decompress
    final decompressed = GZipDecoder().decodeBytes(compressed);

    // Convert bytes to string
    final jsonData = utf8.decode(decompressed);

    _log.d('Decompressed to ${jsonData.length} bytes');
    return jsonData;
  }

  void _updateState(SignalingState newState) {
    if (_isDisposed) return;
    
    _currentState = newState;
    _stateController.add(newState);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stateController.close();
  }
}
