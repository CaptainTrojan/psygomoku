import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'presentation/blocs/connection_bloc/connection_bloc.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  runApp(const PsygomokuApp());
}

class PsygomokuApp extends StatelessWidget {
  const PsygomokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConnectionBloc(),
      child: MaterialApp(
        title: 'Psygomoku',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00E5FF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
