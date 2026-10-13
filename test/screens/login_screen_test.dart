import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/screens/home/home_screen.dart';
import 'package:lumen/screens/login/login_screen.dart';
import 'package:lumen/screens/login/widgets/branding_panel.dart';
import 'package:lumen/screens/login/widgets/sign_in_panel.dart';

import '../helpers/fake_gog_backend.dart';
import '../helpers/fake_secure_storage.dart';
import '../helpers/pump_app.dart';
import '../helpers/temp_data_home.dart';

void main() {
  setUp(useTempDataHome);

  Future<FakeGogBackend> pumpLogin(
    WidgetTester tester, {
    FakeGogBackend? backend,
    FakeSecureStorage? storage,
    Size surfaceSize = const Size(1600, 1000),
  }) async {
    final fake = backend ?? FakeGogBackend();
    await pumpApp(
      tester,
      const LoginScreen(),
      backend: fake,
      secureStorage: storage ?? FakeSecureStorage(),
      surfaceSize: surfaceSize,
    );
    await tester.pump();
    await tester.pump();
    return fake;
  }

  int checks() => find.byIcon(Icons.check).evaluate().length;

  testWidgets('fits at the minimum window size', (tester) async {
    await pumpLogin(tester, surfaceSize: const Size(960, 600));
    expect(find.byType(SignInPanel), findsOneWidget);
    expect(find.byType(BrandingPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits at 1920x1080', (tester) async {
    await pumpLogin(tester, surfaceSize: const Size(1920, 1080));
    expect(find.byType(SignInPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow card drops the branding panel', (tester) async {
    await pumpLogin(tester, surfaceSize: const Size(700, 600));
    expect(find.byType(SignInPanel), findsOneWidget);
    expect(find.byType(BrandingPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stored token goes home without building the card', (
    tester,
  ) async {
    final storage = FakeSecureStorage();
    await storage.write(key: 'auth', value: 'token');
    await pumpApp(
      tester,
      const LoginScreen(),
      backend: FakeGogBackend(),
      secureStorage: storage,
    );
    expect(find.byType(CenteredLoader), findsOneWidget);
    expect(find.byType(SignInPanel), findsNothing);
    await tester.pump();
    await tester.pump();
    expect(find.byType(SignInPanel), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('no stored token shows the card', (tester) async {
    await pumpLogin(tester);
    expect(find.byType(SignInPanel), findsOneWidget);
    expect(find.byType(CenteredLoader), findsNothing);
  });

  testWidgets('a restore failure shows the card and a snackbar', (
    tester,
  ) async {
    final storage = FakeSecureStorage();
    await storage.write(key: 'auth', value: 'token');
    final backend = FakeGogBackend()..throwOn['restoreAuth'] = StateError('x');
    await pumpLogin(tester, backend: backend, storage: storage);
    expect(find.byType(SignInPanel), findsOneWidget);
    expect(find.textContaining("Couldn't restore your session"), findsOne);
  });

  testWidgets('a failed sign-in shows the error inline', (tester) async {
    final backend = FakeGogBackend()
      ..throwOn['loginWithCode'] = StateError('x');
    await pumpLogin(tester, backend: backend);
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining("Couldn't sign in"), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(SignInPanel), findsOneWidget);
  });

  testWidgets('a keyring failure on the token write shows inline', (
    tester,
  ) async {
    final storage = FakeSecureStorage();
    final backend = FakeGogBackend();
    await pumpLogin(tester, backend: backend, storage: storage);
    storage.throwOnNext = PlatformException(code: 'KeyringLocked');
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('keyring is locked'), findsOneWidget);
  });

  testWidgets('a pasted redirect URL submits only the code', (tester) async {
    final backend = await pumpLogin(tester);
    await tester.enterText(
      find.byType(TextField),
      'https://embed.gog.com/on_login_success?origin=client&code=XYZ',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump();
    expect(backend.callsTo('loginWithCode').single.args['code'], 'XYZ');
  });

  testWidgets('an empty submit asks for the code and makes no call', (
    tester,
  ) async {
    final backend = await pumpLogin(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(
      find.text('Paste the code from the address bar first.'),
      findsOneWidget,
    );
    expect(backend.callsTo('loginWithCode'), isEmpty);
  });

  testWidgets('steps advance on open, resume and typing, with no timer', (
    tester,
  ) async {
    await pumpLogin(tester);
    expect(checks(), 0);

    await tester.tap(find.text('Open GOG login'));
    await tester.pump();
    expect(checks(), 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(checks(), 2);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(checks(), 3);
  });
}
