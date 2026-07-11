// Mirrors downloads_state_test.dart: exercises ProtonNotifier against a
// fake Gog, since the real one requires the native bridge library.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';
import 'package:gogdl2_flutter/state/proton_state.dart';
import 'package:gogdl2_flutter_bridge/gogdl2_flutter_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Relies on Dart's noSuchMethod-based mocking: only the methods
// ProtonNotifier calls through GogState are implemented.
class _FakeGog implements Gog {
  _FakeGog({this.downloadStream});

  final Stream<ProtonDownloadStream>? downloadStream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<ProtonRelease>> getProtonReleases({required int page}) async =>
      [_FakeProtonRelease('GE-Proton9-1')];

  @override
  Stream<ProtonDownloadStream> downloadProtonRelease({
    required ProtonRelease release,
    required String path,
  }) => downloadStream ?? const Stream.empty();
}

class _FakeProtonRelease implements ProtonRelease {
  _FakeProtonRelease(this._tag);

  final String _tag;

  @override
  String tagName() => _tag;

  @override
  BigInt downloadSize() => BigInt.from(1000);

  @override
  void dispose() {}

  @override
  bool get isDisposed => false;
}

class _FakeProtonDownloadStatus implements ProtonDownloadStatus {
  _FakeProtonDownloadStatus(this._name);

  final String _name;

  @override
  String name() => _name;

  @override
  void dispose() {}

  @override
  bool get isDisposed => false;
}

class _FakeProtonDownloadStream implements ProtonDownloadStream {
  _FakeProtonDownloadStream({
    required this.status,
    required this.transferred,
    required this.total,
  });

  @override
  ProtonDownloadStatus status;

  @override
  BigInt transferred;

  @override
  BigInt total;

  @override
  void dispose() {}

  @override
  bool get isDisposed => false;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer buildContainer(Gog gog) {
    final container = ProviderContainer(
      overrides: [gogStateProvider.overrideWithValue(GogState(gog))],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('downloadRelease installs the release and sets it as the default '
      'once the stream completes', () async {
    final events = Stream<ProtonDownloadStream>.fromIterable([
      _FakeProtonDownloadStream(
        status: _FakeProtonDownloadStatus('downloading'),
        transferred: BigInt.from(50),
        total: BigInt.from(100),
      ),
      _FakeProtonDownloadStream(
        status: _FakeProtonDownloadStatus('extracting'),
        transferred: BigInt.from(100),
        total: BigInt.from(100),
      ),
    ]);
    final container = buildContainer(_FakeGog(downloadStream: events));
    final release = _FakeProtonRelease('GE-Proton9-1');

    await container
        .read(protonStateProvider.notifier)
        .downloadRelease(release, '/tmp/proton');

    // Let the stream's onDone (which registers the install) settle.
    await Future<void>.delayed(Duration.zero);

    final state = container.read(protonStateProvider);
    expect(state.isInstalled('GE-Proton9-1'), isTrue);
    expect(state.pathFor('GE-Proton9-1'), '/tmp/proton/GE-Proton9-1');
    expect(state.defaultVersion, 'GE-Proton9-1');
  });

  test('setDefault only accepts an installed tag', () async {
    final container = buildContainer(_FakeGog());

    container.read(protonStateProvider.notifier).setDefault('not-installed');

    expect(container.read(protonStateProvider).defaultVersion, isNull);
  });

  test('fetchReleases returns releases from the bridge', () async {
    final container = buildContainer(_FakeGog());

    final releases = await container
        .read(protonStateProvider.notifier)
        .fetchReleases(1);

    expect(releases, hasLength(1));
    expect(releases!.first.tagName(), 'GE-Proton9-1');
  });
}
