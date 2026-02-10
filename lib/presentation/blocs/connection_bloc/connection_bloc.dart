import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../../../core/logging/app_logger.dart';
import '../../../core/config/app_config.dart';
import '../../../infrastructure/transport/i_game_transport.dart' as transport_pkg;
import '../../../infrastructure/transport/webrtc_transport.dart';
import '../../../infrastructure/transport/signaling/manual_signaling_strategy.dart';
import '../../../infrastructure/transport/signaling/auto_signaling_strategy.dart';
import '../../../infrastructure/transport/signaling/signaling_state.dart';
import 'connection_event.dart';
import 'connection_state.dart';

/// Manages WebRTC connection lifecycle and message exchange
class ConnectionBloc extends Bloc<ConnectionEvent, ConnectionState> {
  ConnectionBloc() : super(const ConnectionIdleState()) {
    on<HostGameEvent>(_onHostGame);
    on<JoinGameEvent>(_onJoinGame);
    on<ManualHostReceiveAnswerEvent>(_onManualHostReceiveAnswer);
    on<ManualJoinerReceiveOfferEvent>(_onManualJoinerReceiveOffer);
    on<ResetConnectionEvent>(_onResetConnection);
    on<ConnectionEstablishedEvent>(_onConnectionEstablished);
    on<ConnectionFailedEvent>(_onConnectionFailed);
    on<SendTestMessageEvent>(_onSendTestMessage);
    on<MessageReceivedEvent>(_onMessageReceived);
    on<DisconnectEvent>(_onDisconnect);
    on<ManualOfferGeneratedEvent>(_onManualOfferGenerated);
    on<ManualAnswerGeneratedEvent>(_onManualAnswerGenerated);
  }

  final _log = AppLogger.getLogger(LogModule.connection);
  
  transport_pkg.IGameTransport? _transport;
  ManualSignalingStrategy? _manualStrategy;
  bool _isHost = false;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<void>? _disconnectSubscription;
  StreamSubscription<transport_pkg.ConnectionState>? _stateSubscription;
  StreamSubscription<SignalingState>? _signalingSubscription;

  /// Expose transport for ChatBloc and GameBloc
  transport_pkg.IGameTransport? get transport => _transport;
  bool get isHost => _isHost;

  Future<void> _onHostGame(
    HostGameEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    try {
      _isHost = true;
      _log.d('HostGameEvent received, mode: ${event.mode}');

      if (event.mode == SignalingMode.auto) {
        await _hostAutoMode(emit);
      } else {
        await _hostManualMode(emit);
      }
    } catch (e) {
      _log.e('Host error: $e');
      emit(ConnectionErrorState('Failed to host: $e'));
    }
  }

  Future<void> _hostAutoMode(Emitter<ConnectionState> emit) async {
    _log.d('Host: Auto mode - requesting session code...');
    
    // Request session code from backend
    final sessionCode = await _createSession();
    _log.d('Session code received: $sessionCode');
    
    // Create auto signaling strategy
    final strategy = AutoSignalingStrategy(
      backendUrl: AppConfig.signalingServerUrl,
      sessionCode: sessionCode,
    );
    
    // Create transport
    final transport = WebRTCTransport(signalingStrategy: strategy);
    _transport = transport;
    
    // Set up listeners
    _setupListeners();
    
    // Emit hosting state with session code
    emit(HostingState(mode: SignalingMode.auto, sessionCode: sessionCode));
    
    // Start connection process
    await transport.establishConnection(true);
    _log.d('Auto host connection process started');
  }

  Future<void> _hostManualMode(Emitter<ConnectionState> emit) async {
    _log.d('Host: Manual mode - generating offer...');
    
    // Create manual signaling strategy
    final strategy = ManualSignalingStrategy();
    _manualStrategy = strategy;
    
    // Create transport
    final transport = WebRTCTransport(signalingStrategy: strategy);
    _transport = transport;
    
    // Set up listeners
    _setupListeners();
    _setupManualSignalingListener();
    
    // Emit initial hosting state
    emit(const HostingState(mode: SignalingMode.manual));
    
    // Start connection process (will generate offer)
    await transport.establishConnection(true);
    _log.d('Manual host connection process started');
  }

  Future<void> _onJoinGame(
    JoinGameEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    try {
      _isHost = false;
      _log.d('JoinGameEvent received, mode: ${event.mode}');

      if (event.mode == SignalingMode.auto) {
        if (event.sessionCode == null) {
          emit(const ConnectionErrorState('Session code required for auto mode'));
          return;
        }
        await _joinAutoMode(event.sessionCode!, emit);
      } else {
        if (event.offerString == null) {
          emit(const ConnectionErrorState('Offer string required for manual mode'));
          return;
        }
        await _joinManualMode(event.offerString!, emit);
      }
    } catch (e) {
      _log.e('Join error: $e');
      emit(ConnectionErrorState('Failed to join: $e'));
    }
  }

  Future<void> _joinAutoMode(
    String sessionCode,
    Emitter<ConnectionState> emit,
  ) async {
    _log.d('Joiner: Auto mode - connecting to session $sessionCode...');
    emit(const JoiningState());
    
    // Create auto signaling strategy
    final strategy = AutoSignalingStrategy(
      backendUrl: AppConfig.signalingServerUrl,
      sessionCode: sessionCode,
    );
    
    // Create transport
    final transport = WebRTCTransport(signalingStrategy: strategy);
    _transport = transport;
    
    // Set up listeners
    _setupListeners();
    
    // Start connection process
    await transport.establishConnection(false);
    _log.d('Auto joiner connection process started');
  }

  Future<void> _joinManualMode(
    String offerString,
    Emitter<ConnectionState> emit,
  ) async {
    _log.d('Joiner: Manual mode - processing offer...');
    emit(const JoiningState());
    
    // Create manual signaling strategy
    final strategy = ManualSignalingStrategy();
    _manualStrategy = strategy;
    
    // Create transport
    final transport = WebRTCTransport(signalingStrategy: strategy);
    _transport = transport;
    
    // Set up listeners
    _setupListeners();
    _setupManualSignalingListener();
    
    // Start connection process
    await transport.establishConnection(false);
    
    // Provide offer to strategy
    await strategy.receiveOffer(offerString);
    _log.d('Manual joiner offer processed');
  }

  Future<void> _onManualHostReceiveAnswer(
    ManualHostReceiveAnswerEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    try {
      _log.d('Manual host receiving answer...');
      
      if (_manualStrategy == null) {
        throw Exception('Manual strategy not initialized');
      }
      
      await _manualStrategy!.receiveAnswer(event.answerString);
      _log.d('Manual host answer processed, connection should complete');
    } catch (e) {
      _log.e('Error receiving answer: $e');
      emit(ConnectionErrorState('Failed to process answer: $e'));
    }
  }

  Future<void> _onManualJoinerReceiveOffer(
    ManualJoinerReceiveOfferEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    try {
      _log.d('Manual joiner receiving offer...');
      
      if (_manualStrategy == null) {
        throw Exception('Manual strategy not initialized');
      }
      
      await _manualStrategy!.receiveOffer(event.offerString);
      _log.d('Manual joiner offer processed');
    } catch (e) {
      _log.e('Error receiving offer: $e');
      emit(ConnectionErrorState('Failed to process offer: $e'));
    }
  }

  Future<void> _onResetConnection(
    ResetConnectionEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    _log.d('Resetting connection...');
    await _cleanup();
    emit(const ConnectionIdleState());
  }

  void _setupManualSignalingListener() {
    _signalingSubscription = _manualStrategy?.onStateChanged.listen((state) {
      _log.d('Manual signaling state: ${state.phase}');
      
      if (state.phase == SignalingPhase.exchanging) {
        if (state.offerSdp != null) {
          // Host generated offer
          _log.d('Manual offer generated, adding event');
          add(ManualOfferGeneratedEvent(state.offerSdp!));
        } else if (state.answerSdp != null) {
          // Joiner generated answer
          _log.d('Manual answer generated, adding event');
          add(ManualAnswerGeneratedEvent(state.answerSdp!));
        }
      }
    });
  }

  void _setupListeners() {
    _setupMessageListeners();
    _setupStateListener();
  }

  void _setupMessageListeners() {
    _messageSubscription = _transport?.onMessage.listen((data) {
      add(MessageReceivedEvent(data));
    });

    _disconnectSubscription = _transport?.onDisconnect.listen((_) {
      add(const DisconnectEvent());
    });
  }

  void _setupStateListener() {
    // Check if already connected
    final currentState = _transport?.connectionState;
    _log.d('Setting up state listener, current state: $currentState');
    if (currentState == transport_pkg.ConnectionState.connected) {
      _log.d('Already connected! Adding ConnectionEstablishedEvent immediately');
      add(const ConnectionEstablishedEvent());
    }
    
    // Listen for future connection state changes
    _stateSubscription = _transport?.onStateChanged.listen((transportState) {
      _log.d('Transport state changed: $transportState');
      if (transportState == transport_pkg.ConnectionState.connected) {
        _log.d('Connection established, adding event');
        add(const ConnectionEstablishedEvent());
      } else if (transportState == transport_pkg.ConnectionState.failed) {
        add(const ConnectionFailedEvent('Connection failed'));
      }
    });
  }

  Future<String> _createSession() async {
    try {
      // Convert WebSocket URL to HTTP URL for REST endpoint
      final wsUrl = AppConfig.signalingServerUrl;
      final httpUrl = wsUrl
          .replaceFirst('ws://', 'http://')
          .replaceFirst('wss://', 'https://');
      
      final url = Uri.parse('$httpUrl/api/session');
      final response = await http.post(url);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to create session: ${response.statusCode}');
      }
      
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['sessionCode'] as String;
    } catch (e) {
      _log.e('Error creating session: $e');
      throw Exception('Failed to create session: $e');
    }
  }

  Future<void> _onConnectionEstablished(
    ConnectionEstablishedEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    _log.d('Connection established!');
    emit(const ConnectedState());
  }

  Future<void> _onConnectionFailed(
    ConnectionFailedEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    _log.e('Connection failed: ${event.error}');
    emit(ConnectionErrorState(event.error));
  }

  Future<void> _onSendTestMessage(
    SendTestMessageEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    if (_transport != null) {
      final success = await _transport!.send({
        'type': 'test',
        'text': event.message,
      });

      if (!success) {
        emit(const ConnectionErrorState('Failed to send message'));
      }
    }
  }

  Future<void> _onMessageReceived(
    MessageReceivedEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    final currentState = state;
    if (currentState is ConnectedState) {
      emit(currentState.copyWithMessage(event.data));

      // Auto-respond to ping with pong
      if (event.data['type'] == 'ping') {
        await _transport?.send({
          'type': 'pong',
          'text': 'Pong',
        });
      }
    }
  }

  Future<void> _onDisconnect(
    DisconnectEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    _log.d('Disconnecting...');
    await _cleanup();
    emit(const ConnectionIdleState());
    _log.d('Reset to initial state');
  }

  Future<void> _onManualOfferGenerated(
    ManualOfferGeneratedEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    _log.d('Manual offer generated event handler');
    emit(ManualWaitingForAnswerState(event.offerString));
  }

  Future<void> _onManualAnswerGenerated(
    ManualAnswerGeneratedEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    _log.d('Manual answer generated event handler');
    emit(ManualAnswerReadyState(event.answerString));
  }

  Future<void> _cleanup() async {
    _log.d('Cleaning up...');
    await _messageSubscription?.cancel();
    await _disconnectSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _signalingSubscription?.cancel();
    _log.d('Subscriptions cancelled');
    await _transport?.dispose();
    _transport = null;
    _manualStrategy = null;
    _log.d('Cleanup complete');
  }

  @override
  Future<void> close() async {
    await _cleanup();
    return super.close();
  }
}
