import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'container.dart';
import 'fake_gog_backend.dart';

/// Pumps [child] inside a real [MaterialApp]/[Scaffold], wired to a fresh
/// [ProviderContainer] built the same way [createContainer] builds one for
/// state tests ([gogBackendProvider]/[sharedPreferencesProvider] overridden
/// with a fake, plus any extra [overrides]). Sizes the test surface to a
/// desktop-ish window so the app's `Row`/grid layouts (built for a real
/// window, not the default 800x600 test surface) don't overflow.
///
/// Returns the container so the test can also drive the fake backend or
/// read other providers directly. Does not call `pumpAndSettle` — several
/// screens under test show an indefinitely spinning loader
/// (`CenteredLoader`) while their first fetch is pending, which would hang
/// `pumpAndSettle` forever; callers pump explicitly instead.
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  Widget child, {
  FakeGogBackend? backend,
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
  Size surfaceSize = const Size(1600, 1000),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final container = await createContainer(
    backend: backend,
    prefs: prefs,
    overrides: overrides,
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: child),
      ),
    ),
  );

  return container;
}
