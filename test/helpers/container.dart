import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/secure_storage_provider.dart';
import 'package:lumen/state/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_gog_backend.dart';
import 'fake_secure_storage.dart';

/// Builds a [ProviderContainer] wired up for tests: [gogBackendProvider]
/// overridden with [backend] (a fresh [FakeGogBackend] if omitted),
/// [secureStorageProvider] overridden with [secureStorage] (a fresh
/// [FakeSecureStorage] if omitted) and [sharedPreferencesProvider]
/// overridden with an instance seeded from [prefs], plus any extra
/// [overrides]. Registers `addTearDown(container.dispose)` on the current
/// test.
Future<ProviderContainer> createContainer({
  FakeGogBackend? backend,
  FakeSecureStorage? secureStorage,
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final resolvedPrefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      gogBackendProvider.overrideWithValue(backend ?? FakeGogBackend()),
      secureStorageProvider.overrideWithValue(
        secureStorage ?? FakeSecureStorage(),
      ),
      sharedPreferencesProvider.overrideWithValue(resolvedPrefs),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}
