import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psygomoku/presentation/blocs/connection_bloc/connection_bloc.dart';
import 'package:psygomoku/presentation/screens/home_screen.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('displays app title and game modes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => ConnectionBloc(),
            child: const HomeScreen(),
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
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => ConnectionBloc(),
            child: const HomeScreen(),
          ),
        ),
      );

      // Tap Online P2P button
      await tester.tap(find.text('ONLINE P2P'));
      await tester.pumpAndSettle();

      // Verify navigation occurred (lobby screen has "Host Game" title)
      expect(find.text('Host Game'), findsOneWidget);
    });

    testWidgets('Nearby P2P button shows coming soon message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => ConnectionBloc(),
            child: const HomeScreen(),
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
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => ConnectionBloc(),
            child: const HomeScreen(),
          ),
        ),
      );

      // Tap profile icon
      await tester.tap(find.byIcon(Icons.person));
      await tester.pump();

      // Verify snackbar message
      expect(find.text('Profile screen coming in Phase 5!'), findsOneWidget);
    });
  });
}
