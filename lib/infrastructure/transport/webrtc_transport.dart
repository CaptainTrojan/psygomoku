import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/logging/app_logger.dart';
import '../../core/config/app_config.dart';
import 'i_game_transport.dart';
import 'signaling/i_signaling_strategy.dart';
import 'signaling/signaling_state.dart';

/// WebRTC-based transport for P2P communication over the Internet.
/// 
/// Implements the IGameTransport interface using WebRTC DataChannel.
/// Uses a pluggable signaling strategy for offer/answer exchange.
class WebRTCTransport implements IGameTransport {
  WebRTCTransport({
    required this.signalingStrategy,
  });

  final ISignalingStrategy signalingStrategy;
  final _log = AppLogger.getLogger(LogModule.webrtc);

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  StreamSubscription<SignalingState>? _signalingSubscription;

  // Streams
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();

  // State
  ConnectionState _connectionState = ConnectionState.idle;
  bool _isDisposed = false;

  @override
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  @override
  Stream<void> get onDisconnect => _disconnectController.stream;

  @override
  Stream<ConnectionState> get onStateChanged => _stateController.stream;

  @override
  ConnectionState get connectionState => _connectionState;

  /// Legacy connection method for IGameTransport interface.
  /// Deprecated: Use establishConnection() instead.
  @Deprecated('Use establishConnection() instead')
  @override
  Future<void> connect(String signalData) async {
    throw UnsupportedError(
      'WebRTCTransport no longer supports connect() method. '
      'Use establishConnection() with a signaling strategy instead.',
    );
  }

  /// Establish P2P connection using the configured signaling strategy
  /// 
  /// [isHost] Whether this peer is the host (creates offer) or joiner (creates answer)
  Future<void> establishConnection(bool isHost) async {
    if (_isDisposed) throw Exception('Transport disposed');

    _log.d('Establishing connection as ${isHost ? "host" : "joiner"}');
    _updateState(ConnectionState.connecting);

    try {
      // Create peer connection
      _peerConnection = await createPeerConnection(AppConfig.webrtcConfig);
      _log.d('Peer connection created');

      // Set up callbacks
      _peerConnection!.onIceConnectionState = _onIceConnectionState;
      _peerConnection!.onConnectionState = _onPeerConnectionState;

      // Host creates data channel; joiner listens for it
      if (isHost) {
        final dataChannelConfig = RTCDataChannelInit();
        dataChannelConfig.ordered = true;

        _dataChannel = await _peerConnection!.createDataChannel(
          'game-channel',
          dataChannelConfig,
        );
        _setupDataChannel(_dataChannel!);
        _log.d('Data channel created (host)');
      } else {
        _peerConnection!.onDataChannel = (channel) {
          _log.d('Data channel received (joiner)');
          _dataChannel = channel;
          _setupDataChannel(channel);
        };
      }

      // Listen to signaling state changes
      _signalingSubscription = signalingStrategy.onStateChanged.listen((state) {
        _log.d('Signaling state: ${state.phase}');
        
        if (state.phase == SignalingPhase.failed) {
          _log.e('Signaling failed: ${state.errorMessage}');
          _updateState(ConnectionState.failed);
        }
      });

      // Execute signaling exchange
      await signalingStrategy.exchangeSignals(_peerConnection!, isHost);
      _log.d('Signaling exchange initiated');
      
    } catch (e) {
      _log.e('Error establishing connection: $e');
      _updateState(ConnectionState.failed);
      rethrow;
    }
  }

  @override
  Future<bool> send(Map<String, dynamic> data) async {
    if (_isDisposed) {
      _log.w('Attempted to send after disposal');
      return false;
    }

    if (_dataChannel == null || 
        _dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      _log.w('Data channel not open, cannot send');
      return false;
    }

    try {
      final message = json.encode(data);
      await _dataChannel!.send(RTCDataChannelMessage(message));
      _log.d('Message sent: ${data['type']}');
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

    await _signalingSubscription?.cancel();
    signalingStrategy.dispose();
    
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
        _log.e('Message parse error: $e');
      }
    };
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
}
