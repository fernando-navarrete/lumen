// Regression test for a crash where DownloadsNotifier threw "Cannot modify
// unmodifiable map" the first time a task was added: build() returns
// DownloadsState.empty(), whose `tasks` map is `const {}`, and the old code
// wrote into `state.tasks` in place before that map was ever replaced.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:gogdl2_flutter_bridge/gogdl2_flutter_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Relies on Dart's noSuchMethod-based mocking: only the stream-returning
// methods DownloadsNotifier calls through GogState are implemented.
class _FakeGog implements Gog {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<VerificationStream> verifyDownload({
    required String path,
    required String buildName,
    required List<String> selectedProducts,
    required int gameId,
  }) => const Stream.empty();

  @override
  Stream<DownloadStream> downloadGame({
    required String path,
    required String buildName,
    required List<String> selectedProducts,
    required int gameId,
  }) => const Stream.empty();

  @override
  Stream<RepairStream> repairDownload({
    required String path,
    required String buildName,
    required List<String> selectedProducts,
    required int gameId,
  }) => const Stream.empty();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [gogStateProvider.overrideWithValue(GogState(_FakeGog()))],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'startVerification does not throw when adding the very first task',
    () async {
      final container = buildContainer();

      await container
          .read(downloadsStateProvider.notifier)
          .startVerification(1, path: '/tmp/game', buildName: 'v1.0', productIds: ['base']);

      expect(
        container.read(downloadsStateProvider).tasks.containsKey(1),
        isTrue,
      );

      // Let the fake stream's onDone (which calls markInstalled) settle
      // before teardown disposes the container.
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'startDownload does not throw when adding the very first task',
    () async {
      final container = buildContainer();

      await container
          .read(downloadsStateProvider.notifier)
          .startDownload(2, path: '/tmp/game2', buildName: 'v1.0', productIds: ['base']);

      expect(
        container.read(downloadsStateProvider).tasks.containsKey(2),
        isTrue,
      );

      // Let the fake stream's onDone (which calls markInstalled) settle
      // before teardown disposes the container.
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('removeTask does not throw on an empty task registry', () async {
    final container = buildContainer();

    expect(
      () => container.read(downloadsStateProvider.notifier).removeTask(3),
      returnsNormally,
    );
  });
}
