import 'dart:async';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/logging/app_logger.dart';
import 'i_game_transport.dart';

/// WebRTC-based transport for P2P communication over the Internet.
/// 
/// Implements the IGameTransport interface using WebRTC DataChannel.
/// Supports both host (offer creator) and join (answer creator) roles.
class WebRTCTransport implements IGameTransport {
  WebRTCTransport({this.isHost = false});

  final bool isHost;
  final _log = AppLogger.getLogger(LogModule.webrtc);

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;

  // Streams
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();

  // State
  ConnectionState _connectionState = ConnectionState.idle;
  final List<RTCIceCandidate> _iceCandidates = [];
  bool _isDisposed = false;

  @override
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  @override
  Stream<void> get onDisconnect => _disconnectController.stream;

  @override
  Stream<ConnectionState> get onStateChanged => _stateController.stream;

  @override
  ConnectionState get connectionState => _connectionState;

  /// Initialize WebRTC peer connection and create offer (if host).
  /// 
  /// Returns signaling data as JSON string containing:
  /// - SDP offer/answer
  /// - ICE candidates (as they're gathered)
  Future<String> initialize() async {
    _log.i('Initializing as ${isHost ? "HOST" : "JOINER"}');
    _updateState(ConnectionState.connecting);

    // Create peer connection with STUN servers
    final configuration = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(configuration);
    _log.d('Peer connection created');

    // Set up event handlers
    _peerConnection!.onIceCandidate = _onIceCandidate;
    _peerConnection!.onIceConnectionState = _onIceConnectionState;
    _peerConnection!.onConnectionState = _onPeerConnectionState;

    if (isHost) {
      // Host creates data channel
      final dataChannelConfig = RTCDataChannelInit();
      dataChannelConfig.ordered = true;

      _dataChannel = await _peerConnection!.createDataChannel(
        'game-channel',
        dataChannelConfig,
      );
      _setupDataChannel(_dataChannel!);

      // Create offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      _log.d('Offer created and set as local description');

      // Wait for ICE gathering to complete (this bundles all candidates in SDP)
      await _waitForIceGatheringComplete();
      _log.d('ICE gathering complete');

      // Get the complete offer with all ICE candidates baked into SDP
      final completeOffer = await _peerConnection!.getLocalDescription();
      final offerMap = completeOffer!.toMap();
      final offerJson = json.encode(offerMap);
      _log.d('Offer JSON length: ${offerJson.length}');
      
      // Compress and encode for QR code
      final compressed = _compressSignalData(offerJson);
      return compressed;
    } else {
      // Joiner sets up data channel listener
      _peerConnection!.onDataChannel = (channel) {
        _dataChannel = channel;
        _setupDataChannel(channel);
      };
    }

    return '';
  }

  @override
  Future<void> connect(String signalData) async {
    if (_isDisposed) throw Exception('Transport disposed');

    _log.d('connect() called with compressed data length: ${signalData.length}');
    
    // Decompress the signaling data
    final decompressed = _decompressSignalData(signalData);
    final data = json.decode(decompressed) as Map<String, dynamic>;
    final type = data['type'] as String;
    _log.d('Signal type: $type, isHost: $isHost');

    if (type == 'offer' && !isHost) {
      // Joiner receives offer and creates answer
      _log.d('Joiner processing offer...');
      final sdp = data['sdp'] as String;
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, type),
      );
      _log.d('Remote description set (offer)');

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      _log.d('Answer created and set as local description');

      // Wait for ICE gathering to complete (this bundles all candidates in SDP)
      await _waitForIceGatheringComplete();
      _log.d('ICE gathering complete');

      // Get the complete answer with all ICE candidates baked into SDP
      final completeAnswer = await _peerConnection!.getLocalDescription();
      final answerMap = completeAnswer!.toMap();
      _log.d('Answer generated: ${json.encode(answerMap)}');

      // Answer will be returned via a callback mechanism
      // For now, store it for retrieval
    } else if (type == 'answer' && isHost) {
      // Host receives answer
      _log.d('Host processing answer...');
      final sdp = data['sdp'] as String;
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, type),
      );
      _log.d('Remote description set (answer)');

      // No more pending ICE candidates needed - they're in the SDP
      _log.d('Adding ${_iceCandidates.length} pending ICE candidates');
      for (final candidate in _iceCandidates) {
        await _peerConnection!.addCandidate(candidate);
      }
      _iceCandidates.clear();
    } else if (type == 'ice-candidate') {
      // Add ICE candidate
      _log.d('Processing ICE candidate');
      final candidate = data['candidate'] as String;
      final sdpMid = data['sdpMid'] as String?;
      final sdpMLineIndex = data['sdpMLineIndex'] as int?;

      final iceCandidate = RTCIceCandidate(
        candidate,
        sdpMid,
        sdpMLineIndex,
      );

      final remoteDesc = await _peerConnection!.getRemoteDescription();
      if (remoteDesc != null) {
        await _peerConnection!.addCandidate(iceCandidate);
        _log.d('ICE candidate added');
      } else {
        _iceCandidates.add(iceCandidate);
        _log.d('ICE candidate queued (no remote description yet)');
      }
    }
  }

  /// Get the local SDP answer (for joiner).
  Future<String?> getAnswer() async {
    final localDesc = await _peerConnection?.getLocalDescription();
    if (localDesc != null && localDesc.type == 'answer') {
      final answerJson = json.encode(localDesc.toMap());
      _log.d('Answer JSON length: ${answerJson.length}');
      
      // Compress and encode for QR code
      final compressed = _compressSignalData(answerJson);
      return compressed;
    }
    return null;
  }

  @override
  Future<bool> send(Map<String, dynamic> data) async {
    if (_isDisposed) return false;
    if (_dataChannel == null) return false;
    if (_dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      return false;
    }

    try {
      final message = json.encode(data);
      await _dataChannel!.send(RTCDataChannelMessage(message));
      return true;
    } catch (e) {
      _log.e('Send error: $e');
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _log.d('Disposing transport...');
    _isDisposed = true;

    await _dataChannel?.close();
    await _peerConnection?.close();

    await _messageController.close();
    await _disconnectController.close();
    await _stateController.close();
    
    _log.d('Transport disposed');
  }

  // Private helpers

  void _setupDataChannel(RTCDataChannel channel) {
    _log.d('Setting up data channel: ${channel.label}');
    
    channel.onDataChannelState = (state) {
      if (_isDisposed) return; // Ignore callbacks after disposal
      
      _log.d('Data channel state: $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _log.d('Data channel opened!');
        _updateState(ConnectionState.connected);
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _log.d('Data channel closed');
        _updateState(ConnectionState.disconnected);
        if (!_isDisposed) {
          _disconnectController.add(null);
        }
      }
    };
    
    channel.onMessage = (message) {
      if (_isDisposed) return; // Ignore callbacks after disposal
      
      try {
        _log.d('Message received: ${message.text}');
        final data = json.decode(message.text) as Map<String, dynamic>;
        _messageController.add(data);
      } catch (e) {
        _log.d('Message parse error: $e');
      }
    };
  }

  void _onIceCandidate(RTCIceCandidate candidate) {
    // ICE candidate discovered
    // With vanilla ICE, all candidates are bundled in SDP after gathering completes
    _log.d('ICE Candidate: ${candidate.candidate}');
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

  void _onIceConnectionState(RTCIceConnectionState state) {
    if (_isDisposed) return; // Ignore callbacks after disposal
    
    _log.d('ICE Connection State: $state');
    
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        _updateState(ConnectionState.failed);
        break;
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        _updateState(ConnectionState.disconnected);
        if (!_isDisposed) {
          _disconnectController.add(null);
        }
        break;
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        // Don't set connected here - wait for data channel to open
        _log.d('ICE connected, waiting for data channel...');
        break;
      default:
        break;
    }
  }

  void _onPeerConnectionState(RTCPeerConnectionState state) {
    if (_isDisposed) return; // Ignore callbacks after disposal
    
    _log.d('Peer Connection State: $state');
    
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _updateState(ConnectionState.failed);
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        _updateState(ConnectionState.disconnected);
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        // Don't set connected here - wait for data channel to open
        _log.d('Peer connection established, waiting for data channel...');
        break;
      default:
        break;
    }
  }

  void _updateState(ConnectionState newState) {
    if (_isDisposed) {
      _log.d('Ignoring state update after disposal: $newState');
      return;
    }
    
    _log.d('_updateState called: current=$_connectionState, new=$newState');
    if (_connectionState != newState) {
      _connectionState = newState;
      _log.d('State changed, adding to stream: $newState');
      _stateController.add(newState);
    } else {
      _log.d('State unchanged, not emitting');
    }
  }

  /// Compress and base64 encode signaling data.
  /// 
  /// Makes QR codes smaller and easier to scan.
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

  /// Decompress base64 encoded signaling data.
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
}
