import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psygomoku/presentation/blocs/connection_bloc/connection_bloc.dart';
import 'package:psygomoku/presentation/screens/home_screen.dart';
import 'package:psygomoku/infrastructure/persistence/profile_repository.dart';
import 'package:psygomoku/domain/entities/player.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('displays app title and game modes', (WidgetTester tester) async {
      final profileRepository = _TestProfileRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => ConnectionBloc(),
            child: HomeScreen(profileRepository: profileRepository),
          ),
        ),
      );

      // Verify title is displayed
      expect(find.text('PSYGOMOKU'), findsOneWidget);
      expect(find.text('Psychic Gomoku'), findsOneWidget);

      // Verify Online P2P button
      expect(find.text('ONLINE P2P'), findsOneWidget);
      expect(find.text('Play over Internet'), findsOneWidget);

      // Verify Nearby P2P button
      expect(find.text('NEARBY P2P'), findsOneWidget);
      expect(find.text('Bluetooth/Wi-Fi Direct'), findsOneWidget);

      // Verify Pass & Play button is NOT present
      expect(find.text('PASS & PLAY'), findsNothing);

      // Verify profile icon
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('Online P2P button navigates to lobby', (WidgetTester tester) async {
      final profileRepository = _TestProfileRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => ConnectionBloc(),
            child: HomeScreen(profileRepository: profileRepository),
          ),
        ),
      );

      // Tap Online P2P button
      await tester.tap(find.text('ONLINE P2P'));
      await tester.pumpAndSettle();

      // Verify navigation occurred (lobby screen has "HOST GAME" text)
      expect(find.text('HOST GAME'), findsOneWidget);
    });

    testWidgets('Nearby P2P button shows coming soon message', (WidgetTester tester) async {
      final profileRepository = _TestProfileRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => ConnectionBloc(),
            child: HomeScreen(profileRepository: profileRepository),
          ),
        ),
      );

      // Tap Nearby P2P button
      await tester.tap(find.text('NEARBY P2P'));
      await tester.pump();

      // Verify snackbar message
      expect(find.text('Coming in Phase 5!'), findsOneWidget);
    });

    testWidgets('Profile icon shows placeholder message', (WidgetTester tester) async {
      final profileRepository = _TestProfileRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => ConnectionBloc(),
            child: HomeScreen(profileRepository: profileRepository),
          ),
        ),
      );

      // Tap profile icon
      await tester.tap(find.byIcon(Icons.person));
      await tester.pump();

      // Verify navigation to Profile screen
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
    });
  });
}

class _TestProfileRepository extends ProfileRepository {
  @override
  Player? getLocalPlayer() {
    return Player.create(nickname: 'TestPlayer', avatarColor: '#6B5B95');
  }

  @override
  List<Map<String, dynamic>> getMatchHistory() => [];

  @override
  Future<void> initialize() async {}
}
