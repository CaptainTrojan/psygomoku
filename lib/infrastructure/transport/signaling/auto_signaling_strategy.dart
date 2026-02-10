import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/logging/app_logger.dart';
import 'i_signaling_strategy.dart';
import 'signaling_state.dart';

/// Auto signaling strategy using WebSocket server
/// 
/// This strategy implements server-mediated P2P signaling where users
/// connect via a 4-digit session code. The server relays SDP and ICE
/// candidates between peers.
class AutoSignalingStrategy implements ISignalingStrategy {
  AutoSignalingStrategy({
    required this.backendUrl,
    required this.sessionCode,
  });

  final String backendUrl;
  final String sessionCode;
  final _log = AppLogger.getLogger(LogModule.signaling);
  final _stateController = StreamController<SignalingState>.broadcast();

  SignalingState _currentState = SignalingState.idle();
  RTCPeerConnection? _peerConnection;
  WebSocketChannel? _channel;
  bool _isDisposed = false;
  String? _assignedRole;
  Completer<void>? _peerJoinedCompleter;
  final List<RTCIceCandidate> _pendingIceCandidates = [];

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
      // Connect to WebSocket
      await _connectWebSocket();

      // Set up ICE candidate trickling
      _setupIceCandidateTrickling();

      if (isHost) {
        await _hostFlow();
      } else {
        await _joinerFlow();
      }
    } catch (e) {
      _log.e('Signaling error: $e');
      _updateState(SignalingState.failed(e.toString()));
      rethrow;
    }
  }

  /// Connect to the signaling server via WebSocket
  Future<void> _connectWebSocket() async {
    final wsUrl = backendUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    final url = '$wsUrl/ws/$sessionCode';
    
    _log.d('Connecting to WebSocket: $url');
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      // Listen for messages
      _channel!.stream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          _log.e('WebSocket error: $error');
          if (!_isDisposed) {
            _updateState(SignalingState.failed(error.toString()));
          }
        },
        onDone: () {
          _log.d('WebSocket closed');
        },
      );

      _log.d('WebSocket connected');
    } catch (e) {
      _log.e('Failed to connect WebSocket: $e');
      throw Exception('Failed to connect to signaling server: $e');
    }
  }

  /// Handle incoming WebSocket messages
  void _handleWebSocketMessage(dynamic message) {
    if (_isDisposed) return;

    try {
      final data = json.decode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      _log.d('Received message: $type');

      switch (type) {
        case 'ROLE_ASSIGNED':
          _assignedRole = data['role'] as String?;
          _log.d('Role assigned: $_assignedRole');
          break;

        case 'PEER_JOINED':
          _log.d('Peer joined the room');
          _peerJoinedCompleter?.complete();
          break;

        case 'OFFER':
          _handleRemoteOffer(data);
          break;

        case 'ANSWER':
          _handleRemoteAnswer(data);
          break;

        case 'ICE_CANDIDATE':
          _handleRemoteIceCandidate(data);
          break;

        case 'PEER_DISCONNECTED':
          _log.w('Peer disconnected');
          if (!_isDisposed) {
            _updateState(SignalingState.failed('Peer disconnected'));
          }
          break;

        case 'ERROR':
          final errorMsg = data['message'] as String? ?? 'Unknown error';
          _log.e('Server error: $errorMsg');
          if (!_isDisposed) {
            _updateState(SignalingState.failed(errorMsg));
          }
          break;

        default:
          _log.w('Unknown message type: $type');
      }
    } catch (e) {
      _log.e('Error handling WebSocket message: $e');
    }
  }

  /// Host flow: create offer and send to server
  Future<void> _hostFlow() async {
    _log.d('Starting host flow...');

    // Wait for joiner to connect
    _peerJoinedCompleter = Completer<void>();
    _log.d('Waiting for peer to join...');
    
    // Wait up to 60 seconds for peer to join
    try {
      await _peerJoinedCompleter!.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Timeout waiting for peer to join');
        },
      );
      _log.d('Peer joined, creating offer...');
    } catch (e) {
      _log.e('Error waiting for peer: $e');
      throw e;
    }

    // Create offer
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    _log.d('Offer created and set as local description');

    // Wait for ICE gathering to complete
    await _waitForIceGatheringComplete();
    _log.d('ICE gathering complete');

    // Get the complete offer with all ICE candidates
    final completeOffer = await _peerConnection!.getLocalDescription();
    
    // Send offer to server
    _sendMessage({
      'type': 'OFFER',
      'sdp': completeOffer!.sdp,
    });

    _log.d('Offer sent to server');
    _updateState(SignalingState.exchanging(sessionCode: sessionCode));
  }

  /// Joiner flow: wait for offer, create answer
  Future<void> _joinerFlow() async {
    _log.d('Starting joiner flow...');
    _updateState(SignalingState.exchanging(sessionCode: sessionCode));
    
    // Will receive offer via WebSocket message handler
    // Answer will be created in _handleRemoteOffer()
  }

  /// Handle remote offer (joiner receives this)
  Future<void> _handleRemoteOffer(Map<String, dynamic> data) async {
    _log.d('Handling remote offer...');

    final sdp = data['sdp'] as String?;
    if (sdp == null) {
      _log.e('Offer missing SDP');
      return;
    }

    // Set remote description
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, 'offer'),
    );
    _log.d('Remote description set (offer)');

    // Process any pending ICE candidates
    await _processPendingIceCandidates();

    // Create answer
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    _log.d('Answer created and set as local description');

    // Wait for ICE gathering to complete
    await _waitForIceGatheringComplete();
    _log.d('ICE gathering complete');

    // Get the complete answer
    final completeAnswer = await _peerConnection!.getLocalDescription();

    // Send answer to server
    _sendMessage({
      'type': 'ANSWER',
      'sdp': completeAnswer!.sdp,
    });

    _log.d('Answer sent to server');
    _updateState(SignalingState.complete());
  }

  /// Handle remote answer (host receives this)
  Future<void> _handleRemoteAnswer(Map<String, dynamic> data) async {
    _log.d('Handling remote answer...');

    final sdp = data['sdp'] as String?;
    if (sdp == null) {
      _log.e('Answer missing SDP');
      return;
    }

    // Set remote description
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, 'answer'),
    );
    _log.d('Remote description set (answer)');

    // Process any pending ICE candidates
    await _processPendingIceCandidates();

    _updateState(SignalingState.complete());
  }

  /// Handle remote ICE candidate
  Future<void> _handleRemoteIceCandidate(Map<String, dynamic> data) async {
    _log.d('Handling remote ICE candidate...');

    final candidateData = data['candidate'] as Map<String, dynamic>?;
    if (candidateData == null) {
      _log.e('ICE candidate missing data');
      return;
    }

    final candidate = candidateData['candidate'] as String?;
    final sdpMid = candidateData['sdpMid'] as String?;
    final sdpMLineIndex = candidateData['sdpMLineIndex'] as int?;

    if (candidate != null) {
      final iceCandidate = RTCIceCandidate(
        candidate,
        sdpMid,
        sdpMLineIndex,
      );

      // Check if remote description is set
      final remoteDesc = await _peerConnection!.getRemoteDescription();
      if (remoteDesc == null) {
        // Queue candidate for later
        _log.d('Queuing ICE candidate (no remote description yet)');
        _pendingIceCandidates.add(iceCandidate);
      } else {
        // Add immediately
        try {
          await _peerConnection!.addCandidate(iceCandidate);
          _log.d('Remote ICE candidate added');
        } catch (e) {
          _log.e('Error adding ICE candidate: $e');
        }
      }
    }
  }

  /// Process any ICE candidates that arrived before remote description was set
  Future<void> _processPendingIceCandidates() async {
    if (_pendingIceCandidates.isEmpty) return;

    _log.d('Processing ${_pendingIceCandidates.length} pending ICE candidates');
    for (final candidate in _pendingIceCandidates) {
      try {
        await _peerConnection!.addCandidate(candidate);
        _log.d('Pending ICE candidate added');
      } catch (e) {
        _log.e('Error adding pending ICE candidate: $e');
      }
    }
    _pendingIceCandidates.clear();
  }

  /// Set up trickle ICE (send candidates as they're discovered)
  void _setupIceCandidateTrickling() {
    _peerConnection!.onIceCandidate = (candidate) {
      if (_isDisposed) return;
      
      _log.d('Local ICE candidate: ${candidate.candidate}');
      
      // Send to server for relay to peer
      _sendMessage({
        'type': 'ICE_CANDIDATE',
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };
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

    // Wait for completion or timeout after 10 seconds (longer for server-mediated)
    try {
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _log.d('ICE gathering timeout - proceeding anyway');
        },
      );
    } catch (e) {
      _log.d('Error waiting for ICE gathering: $e');
    }
  }

  /// Send message to WebSocket server
  void _sendMessage(Map<String, dynamic> message) {
    if (_isDisposed || _channel == null) return;

    try {
      final jsonMessage = json.encode(message);
      _channel!.sink.add(jsonMessage);
      _log.d('Message sent: ${message['type']}');
    } catch (e) {
      _log.e('Error sending message: $e');
    }
  }

  void _updateState(SignalingState newState) {
    if (_isDisposed) return;

    _currentState = newState;
    _stateController.add(newState);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _channel?.sink.close();
    _stateController.close();
  }
}
