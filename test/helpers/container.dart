import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/shared_preferences_provider.dart';

import 'fake_gog_backend.dart';

/// Builds a [ProviderContainer] wired up for tests: [gogBackendProvider]
/// overridden with [backend] (a fresh [FakeGogBackend] if omitted) and
/// [sharedPreferencesProvider] overridden with an instance seeded from
/// [prefs]. Registers `addTearDown(container.dispose)` on the current test.
Future<ProviderContainer> createContainer({
  FakeGogBackend? backend,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final resolvedPrefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      gogBackendProvider.overrideWithValue(backend ?? FakeGogBackend()),
      sharedPreferencesProvider.overrideWithValue(resolvedPrefs),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
