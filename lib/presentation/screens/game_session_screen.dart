import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/game_config.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/position.dart';
import '../../domain/entities/stone.dart';
import '../../infrastructure/persistence/profile_repository.dart';
import '../../infrastructure/transport/i_game_transport.dart' as transport_pkg;
import '../blocs/chat_bloc/chat_bloc.dart';
import '../blocs/chat_bloc/chat_event.dart';
import '../blocs/connection_bloc/connection_bloc.dart';
import '../blocs/connection_bloc/connection_event.dart' as connection_events;
import '../blocs/game_bloc/game_bloc.dart';
import '../blocs/game_bloc/game_event.dart';
import '../blocs/game_bloc/game_state.dart';
import 'game_board_screen.dart';

/// Coordinates transport messages and the game session UI
class GameSessionScreen extends StatefulWidget {
  final transport_pkg.IGameTransport transport;
  final bool isHost;
  final ProfileRepository profileRepository;

  const GameSessionScreen({
    super.key,
    required this.transport,
    required this.isHost,
    required this.profileRepository,
  });

  @override
  State<GameSessionScreen> createState() => _GameSessionScreenState();
}

class _GameSessionScreenState extends State<GameSessionScreen> {
  late final GameBloc _gameBloc;
  late final ChatBloc _chatBloc;
  StreamSubscription<Map<String, dynamic>>? _messageSub;
  StreamSubscription<void>? _disconnectSub;
  StreamSubscription<GameState>? _gameStateSub;
  Timer? _handshakeTimer;
  int _handshakeAttempts = 0;
  bool _handshakeAcked = false;
  bool _statsUpdated = false;

  @override
  void initState() {
    super.initState();
    _gameBloc = GameBloc(transport: widget.transport);
    _chatBloc = ChatBloc(widget.transport);

    _messageSub = widget.transport.onMessage.listen(_handleTransportMessage);
    
    // Handle transport disconnect (opponent closes browser/tab or leaves after game ends)
    _disconnectSub = widget.transport.onDisconnect.listen((_) {
      if (!mounted) return;
      
      // Opponent disconnected - show notification and handle event
      _gameBloc.add(const OpponentDisconnectedEvent());
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opponent disconnected'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      
      // Navigate back to lobby after brief delay to show snackbar
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        context.read<ConnectionBloc>().add(const connection_events.DisconnectEvent());
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    });

    _gameStateSub = _gameBloc.stream.listen((state) {
      if (state is GameOverState && !_statsUpdated) {
        _statsUpdated = true;
        widget.profileRepository.updateStats(state.result);
      }
    });

    if (widget.isHost) {
      _startAsHost();
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _disconnectSub?.cancel();
    _gameStateSub?.cancel();
    _handshakeTimer?.cancel();
    _gameBloc.close();
    _chatBloc.close();
    super.dispose();
  }

  void _startAsHost() {
    final localPlayer = _buildLocalPlayer(isHost: true);
    final remotePlayer = _buildRemotePlaceholder(isHost: false);
    final config = GameConfig.defaultConfig();

    _gameBloc.add(StartGameEvent(
      localPlayer: localPlayer,
      remotePlayer: remotePlayer,
      config: config,
    ));

    widget.transport.send({
      'type': 'game_start',
      'config': config.toJson(),
      'hostPlayer': localPlayer.toJson(),
    });

    _handshakeTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_handshakeAcked || _handshakeAttempts >= 5) {
        timer.cancel();
        return;
      }
      _handshakeAttempts++;
      widget.transport.send({
        'type': 'game_start',
        'config': config.toJson(),
        'hostPlayer': localPlayer.toJson(),
      });
    });
  }

  void _handleTransportMessage(Map<String, dynamic> data) {
    final type = data['type'];
    if (type == null) return;

    switch (type) {
      case 'game_start':
        if (!widget.isHost) {
          final configJson = data['config'] as Map<String, dynamic>;
          final config = GameConfig.fromJson(configJson);
          final hostJson = data['hostPlayer'] as Map<String, dynamic>;
          final hostPlayer = Player.fromJson(hostJson).copyWith(
            isHost: true,
            stoneColor: StoneColor.cyan,
          );

          final localPlayer = _buildLocalPlayer(isHost: false);
          final remotePlayer = hostPlayer;

          _gameBloc.add(StartGameEvent(
            localPlayer: localPlayer,
            remotePlayer: remotePlayer,
            config: config,
          ));

          widget.transport.send({
            'type': 'game_start_ack',
          });

          widget.transport.send({
            'type': 'profile',
            'player': localPlayer.toJson(),
          });
        }
        break;
      case 'game_start_ack':
        _handshakeAcked = true;
        _handshakeTimer?.cancel();
        break;
      case 'profile':
        if (widget.isHost) {
          final playerJson = data['player'] as Map<String, dynamic>;
          final remotePlayer = Player.fromJson(playerJson).copyWith(
            isHost: false,
            stoneColor: StoneColor.magenta,
          );
          _gameBloc.add(UpdateRemotePlayerEvent(remotePlayer));
        } else {
          final playerJson = data['player'] as Map<String, dynamic>;
          final remotePlayer = Player.fromJson(playerJson).copyWith(
            isHost: true,
            stoneColor: StoneColor.cyan,
          );
          _gameBloc.add(UpdateRemotePlayerEvent(remotePlayer));
        }
        break;
      case 'chat':
        final message = data['text'] as String?;
        final timestampStr = data['timestamp'] as String?;
        if (message != null) {
          final timestamp = timestampStr != null
              ? DateTime.tryParse(timestampStr) ?? DateTime.now()
              : DateTime.now();
          _chatBloc.add(ReceiveChatMessageEvent(message, timestamp));
        }
        break;
      case 'mark':
        _gameBloc.add(OpponentMarkedEvent(
          hash: data['hash'] as String,
          timestamp: _parseTimestamp(data['timestamp']),
        ));
        break;
      case 'guess':
        _gameBloc.add(OpponentGuessedEvent(
          guessedPosition: Position.fromJson(data['position'] as Map<String, dynamic>),
          timestamp: _parseTimestamp(data['timestamp']),
        ));
        break;
      case 'reveal':
        _gameBloc.add(OpponentRevealedEvent(
          revealedPosition: Position.fromJson(data['position'] as Map<String, dynamic>),
          salt: data['salt'] as String,
          timestamp: _parseTimestamp(data['timestamp']),
        ));
        break;
      case 'forfeit':
        _gameBloc.add(OpponentForfeitedEvent(
          timestamp: _parseTimestamp(data['timestamp']),
        ));
        break;
      case 'disconnect':
        // Disconnect message received - transport will close soon and onDisconnect will handle it
        // No need to process here to avoid duplicate handling
        break;
      case 'rematch_request':
        _gameBloc.add(const OpponentRequestedRematchEvent());
        break;
      default:
        break;
    }
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Player _buildLocalPlayer({required bool isHost}) {
    final stored = widget.profileRepository.getLocalPlayer();
    final base = stored ?? Player.create(nickname: 'Player', avatarColor: '#6B5B95');

    return base.copyWith(
      isHost: isHost,
      stoneColor: isHost ? StoneColor.cyan : StoneColor.magenta,
    );
  }

  Player _buildRemotePlaceholder({required bool isHost}) {
    return Player(
      id: 'remote',
      nickname: 'Opponent',
      avatarColor: '#444444',
      wins: 0,
      losses: 0,
      draws: 0,
      isHost: isHost,
      stoneColor: isHost ? StoneColor.cyan : StoneColor.magenta,
    );
  }

  void _handleDisconnect(BuildContext context) {
    // Send disconnect message to opponent (best effort)
    widget.transport.send({
      'type': 'disconnect',
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // WE are disconnecting, so WE forfeit (DisconnectEvent)
    _gameBloc.add(const DisconnectEvent('User left game'));
    
    // Clean up connection
    context.read<ConnectionBloc>().add(const connection_events.DisconnectEvent());
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleDisconnect(context);
        }
      },
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _gameBloc),
          BlocProvider.value(value: _chatBloc),
          BlocProvider.value(value: context.read<ConnectionBloc>()),
        ],
        child: const GameBoardScreen(),
      ),
    );
  }
}
