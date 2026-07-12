import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Synchronous access to the already-resolved [SharedPreferences] instance.
///
/// Overridden with the real instance in `main()` before `runApp`, so that
/// notifiers which persist to SharedPreferences (see [ProtonNotifier] and
/// [GamesNotifier]) can load their persisted state directly inside `build()`
/// instead of racing an async `SharedPreferences.getInstance().then(...)`
/// against the rest of app startup — a race that previously let the UI read
/// or mutate empty state before the real data had loaded, spuriously
/// reporting installed Proton versions as missing and clobbering saved
/// per-game config on the next persist.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with a resolved '
    'SharedPreferences instance in main() before runApp().',
  ),
  name: 'sharedPreferencesProvider',
);
