import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'presentation/blocs/connection_bloc/connection_bloc.dart';
import 'presentation/screens/home_screen.dart';
import 'infrastructure/persistence/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final profileRepository = ProfileRepository();
  await profileRepository.initialize();

  runApp(PsygomokuApp(profileRepository: profileRepository));
}

class PsygomokuApp extends StatelessWidget {
  final ProfileRepository profileRepository;

  const PsygomokuApp({super.key, required this.profileRepository});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConnectionBloc(),
      child: MaterialApp(
        title: 'Psygomoku',
        debugShowCheckedModeBanner: false,
        theme: getAppTheme(),
        home: HomeScreen(profileRepository: profileRepository),
      ),
    );
  }
}
