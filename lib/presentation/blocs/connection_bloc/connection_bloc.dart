import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import '../../../infrastructure/transport/i_game_transport.dart' as transport_pkg;
import '../../../infrastructure/transport/webrtc_transport.dart';
import 'connection_event.dart';
import 'connection_state.dart';

/// Manages WebRTC connection lifecycle and message exchange
class ConnectionBloc extends Bloc<ConnectionEvent, ConnectionState> {
  ConnectionBloc() : super(const ConnectionIdleState()) {
    on<HostGameEvent>(_onHostGame);
    on<JoinGameEvent>(_onJoinGame);
    on<HostReceiveAnswerEvent>(_onHostReceiveAnswer);
    on<HostReadyForAnswerEvent>(_onHostReadyForAnswer);
    on<ConnectionEstablishedEvent>(_onConnectionEstablished);
    on<ConnectionFailedEvent>(_onConnectionFailed);
    on<SendTestMessageEvent>(_onSendTestMessage);
    on<MessageReceivedEvent>(_onMessageReceived);
    on<DisconnectEvent>(_onDisconnect);
  }

  final _log = AppLogger.getLogger(LogModule.connection);
  
  transport_pkg.IGameTransport? _transport;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<void>? _disconnectSubscription;
  StreamSubscription<transport_pkg.ConnectionState>? _stateSubscription;

  /// Expose transport for ChatBloc
  transport_pkg.IGameTransport? get transport => _transport;

  Future<void> _onHostGame(
    HostGameEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    try {
      _log.d('HostGameEvent received, starting host flow...');
      // Create host transport
      final transport = WebRTCTransport(isHost: true);
      _transport = transport;
      _log.d('Host transport created');

      // Initialize and get offer
      final signalData = await transport.initialize();
      _log.d('Host initialized, offer generated');

      // Listen for messages
      _setupListeners();

      emit(HostingState(signalData));
      _log.d('Emitted HostingState with offer');
    } catch (e) {
      emit(ConnectionErrorState('Failed to host: $e'));
    }
  }

  Future<void> _onJoinGame(
    JoinGameEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    try {
      _log.d('JoinGameEvent received, starting join flow...');
      emit(const JoiningState());

      // Create joiner transport
      final transport = WebRTCTransport(isHost: false);
      _transport = transport;
      _log.d('Joiner transport created');

      // Initialize
      await transport.initialize();
      _log.d('Joiner transport initialized');

      // Set up message listeners only (not state listener yet - we need to show answer first)
      _setupMessageListeners();
      _log.d('Joiner message listeners set up');

      // Connect using signaling data (offer from host)
      await transport.connect(event.signalData);
      _log.d('Joiner connect() completed');

      // Get answer and emit state with it
      final answer = await transport.getAnswer();
      if (answer != null) {
        _log.d('Answer generated, emitting JoiningWaitingForHostState');
        emit(JoiningWaitingForHostState(answer));
      }

      // NOW set up state listener - connection is established but we've shown the answer first
      _setupStateListener();
      _log.d('Joiner state listener set up, will auto-navigate when ready');

      // Wait for connection to establish
      // Will emit ConnectedState when data channel opens
    } catch (e) {
      emit(ConnectionErrorState('Failed to join: $e'));
    }
  }

  Future<void> _onHostReceiveAnswer(
    HostReceiveAnswerEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    try {
      _log.d('Host received answer, connecting...');
      
      // Process the answer
      await _transport?.connect(event.answerData);
      
      // Connection should establish soon via state listener
      emit(const JoiningState()); // Show connecting state
    } catch (e) {
      emit(ConnectionErrorState('Failed to process answer: $e'));
    }
  }
  Future<void> _onHostReadyForAnswer(
    HostReadyForAnswerEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    emit(HostingWaitingForAnswerState(event.signalData));
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
    // Check if already connected (for joiners, connection may establish during connect())
    final currentState = _transport?.connectionState;
    _log.d('Setting up state listener, current state: $currentState');
    if (currentState == transport_pkg.ConnectionState.connected) {
      _log.d('Already connected! Adding ConnectionEstablishedEvent immediately');
      add(const ConnectionEstablishedEvent());
    }
    
    // Listen for future connection state changes
    _stateSubscription = _transport?.onStateChanged.listen((transportState) {
      _log.d('State changed: $transportState');
      if (transportState == transport_pkg.ConnectionState.connected) {
        _log.d('Connection established, adding event');
        add(const ConnectionEstablishedEvent());
      } else if (transportState == transport_pkg.ConnectionState.failed) {
        add(const ConnectionFailedEvent('Connection failed'));
      }
    });
  }

  void _setupListeners() {
    _setupMessageListeners();
    _setupStateListener();
  }

  Future<void> _onConnectionEstablished(
    ConnectionEstablishedEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    emit(const ConnectedState());
  }

  Future<void> _onConnectionFailed(
    ConnectionFailedEvent event,
    Emitter<ConnectionState> emit,
  ) async {
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
    // Emit initial state so lobby shows menu selection
    emit(const ConnectionIdleState());
    _log.d('Reset to initial state');
  }

  Future<void> _cleanup() async {
    _log.d('Cleaning up...');
    await _messageSubscription?.cancel();
    await _disconnectSubscription?.cancel();
    await _stateSubscription?.cancel();
    _log.d('Subscriptions cancelled');
    await _transport?.dispose();
    _transport = null;
    _log.d('Cleanup complete');
  }

  @override
  Future<void> close() async {
    await _cleanup();
    return super.close();
  }
}
