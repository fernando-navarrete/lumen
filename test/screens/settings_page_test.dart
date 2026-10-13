import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/screens/home/pages/settings_page.dart';
import 'package:lumen/screens/login/login_screen.dart';
import 'package:lumen/state/launch_state.dart';

import '../helpers/fake_gog_backend.dart';
import '../helpers/fake_secure_storage.dart';
import '../helpers/pump_app.dart';
import '../helpers/temp_data_home.dart';

class _RunningLaunchNotifier extends LaunchNotifier {
  @override
  LaunchState build() =>
      LaunchState({1: RunningGame(gameId: 1, status: LaunchStatus.running)});
}

void main() {
  setUp(useTempDataHome);

  Future<FakeSecureStorage> pumpSettings(
    WidgetTester tester, {
    bool gameRunning = false,
  }) async {
    final storage = FakeSecureStorage();
    await storage.write(key: 'auth', value: 'token');
    await pumpApp(
      tester,
      const SettingsPage(),
      backend: FakeGogBackend(),
      secureStorage: storage,
      overrides: [
        if (gameRunning)
          launchStateProvider.overrideWith(_RunningLaunchNotifier.new),
      ],
    );
    await tester.pump();
    return storage;
  }

  testWidgets('Sign out confirms, deletes the token and shows login', (
    tester,
  ) async {
    final storage = await pumpSettings(tester);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of GOG?'), findsOneWidget);
    await tester.tap(find.text('Sign out').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(await storage.read(key: 'auth'), isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
  });

  testWidgets('Cancel keeps the session', (tester) async {
    final storage = await pumpSettings(tester);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await storage.read(key: 'auth'), 'token');
    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('a running game refuses with a snackbar and stays', (
    tester,
  ) async {
    final storage = await pumpSettings(tester, gameRunning: true);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('a running game'), findsOneWidget);
    expect(await storage.read(key: 'auth'), 'token');
    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
