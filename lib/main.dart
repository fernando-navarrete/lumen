import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lumen/app.dart';
import 'package:lumen/state/shared_preferences_provider.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Resolved up front (rather than left to each notifier's build() to fetch
  // asynchronously) so ProtonNotifier/GamesNotifier can load their persisted
  // state synchronously during build() — see sharedPreferencesProvider.
  final prefs = await SharedPreferences.getInstance();
  await RustLib.init();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppColors.surface,
        textTheme: GoogleFonts.onestTextTheme(ThemeData.dark().textTheme),
      ),
      home: const App(),
    );
  }
}
