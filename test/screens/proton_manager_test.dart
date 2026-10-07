import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/models/proton_release.dart';
import 'package:lumen/screens/home/pages/settings/proton_manager.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/launch_state.dart';
import 'package:lumen/state/proton_state.dart';

import '../helpers/fake_gog_backend.dart';
import '../helpers/fake_proton.dart';
import '../helpers/pump_app.dart';
import '../helpers/temp_data_home.dart';

/// Regression `v1.1.2`: the Proton releases dialog distinguishes a failed
/// fetch (shows an error + Retry) from a merely-empty page (shows "No
/// releases available", no Retry), instead of showing "No releases loaded"
/// with an endless "Load more" for both.
void main() {
  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('Manage / install versions…'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a failed fetch shows an error and a Retry button', (
    tester,
  ) async {
    final backend = FakeGogBackend()
      ..throwOn['getProtonReleases'] = Exception('boom');

    await pumpApp(tester, const ProtonManagerSection(), backend: backend);
    await openDialog(tester);

    expect(find.text("Couldn't load releases"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets(
    'tapping Retry after clearing the failure re-fetches the same page',
    (tester) async {
      final backend = FakeGogBackend()
        ..throwOn['getProtonReleases'] = Exception('boom');

      await pumpApp(tester, const ProtonManagerSection(), backend: backend);
      await openDialog(tester);

      backend.throwOn.clear();
      backend.protonReleases = [
        const ProtonRelease(tagName: 'GE-Proton9-1', downloadSize: 1000),
      ];

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.text('GE-Proton9-1'), findsOneWidget);
      final calls = backend.callsTo('getProtonReleases');
      expect(calls, hasLength(2));
      expect(calls[0].args['page'], 1);
      expect(calls[1].args['page'], 1);
    },
  );

  testWidgets(
    'an empty page shows "No releases available" with no Load more button',
    (tester) async {
      final backend = FakeGogBackend()..protonReleases = [];

      await pumpApp(tester, const ProtonManagerSection(), backend: backend);
      await openDialog(tester);

      expect(find.text('No releases available'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets('a non-empty page shows Load more, not an error', (tester) async {
    final backend = FakeGogBackend()
      ..protonReleases = [
        const ProtonRelease(tagName: 'GE-Proton9-1', downloadSize: 1000),
      ];

    await pumpApp(tester, const ProtonManagerSection(), backend: backend);
    await openDialog(tester);

    expect(find.text('GE-Proton9-1'), findsOneWidget);
    expect(find.text('Load more'), findsOneWidget);
  });

  group('installed versions (v1.3.0)', () {
    Map<String, Object> seed(Map<String, String> paths, String defaultTag) => {
      'protonInstalled': jsonEncode(paths),
      'protonDefault': defaultTag,
    };

    testWidgets('the remove dialog starts checked for a release under the '
        'Proton dir, without the custom-folder warning', (tester) async {
      useTempDataHome();
      final path = fakeProtonInstall('${protonInstallDir()}/GE-A');
      await pumpApp(
        tester,
        const ProtonManagerSection(),
        prefs: seed({'GE-A': path}, 'GE-A'),
      );

      expect(find.text('Installed versions'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Remove GE-A?'), findsOneWidget);
      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.value, true);
      expect(find.textContaining("outside Lumen's Proton"), findsNothing);
    });

    testWidgets('confirming with the box unchecked removes the row and keeps '
        'the files', (tester) async {
      final home = useTempDataHome();
      final path = fakeProtonInstall('${home.path}/elsewhere/GE-A');
      final container = await pumpApp(
        tester,
        const ProtonManagerSection(),
        prefs: seed({'GE-A': path}, 'GE-A'),
      );

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();

      expect(container.read(protonStateProvider).isInstalled('GE-A'), false);
      expect(find.text('Installed versions'), findsNothing);
      expect(Directory(path).existsSync(), true);
    });

    testWidgets('a custom directory is unchecked by default and warns', (
      tester,
    ) async {
      final home = useTempDataHome();
      final path = fakeProtonInstall('${home.path}/elsewhere/GE-A');
      await pumpApp(
        tester,
        const ProtonManagerSection(),
        prefs: seed({'GE-A': path}, 'GE-A'),
      );

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.value, false);
      expect(find.textContaining(path), findsWidgets);
      expect(find.textContaining("outside Lumen's Proton"), findsOneWidget);
    });

    testWidgets('Remove is disabled while a game using the version runs', (
      tester,
    ) async {
      useTempDataHome();
      final path = fakeProtonInstall('${protonInstallDir()}/GE-A');
      final container = await pumpApp(
        tester,
        const ProtonManagerSection(),
        prefs: seed({'GE-A': path}, 'GE-A'),
        overrides: [
          launchStateProvider.overrideWith(_RunningLaunchNotifier.new),
        ],
      );
      // Game 1 has no override, so it runs the default (GE-A).
      container.read(gamesStateProvider.notifier).setSelectedBuild(1, 'b');
      await tester.pump();

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Remove'),
      );
      expect(button.onPressed, isNull);
    });
  });
}

class _RunningLaunchNotifier extends LaunchNotifier {
  @override
  LaunchState build() =>
      LaunchState({1: RunningGame(gameId: 1, status: LaunchStatus.running)});
}
