import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Runs before every test file in `test/`. Disables `google_fonts`' runtime
/// HTTP fetch: without this, every widget test that renders `AppText.onest`
/// (all of them, transitively via `google_fonts`) attempts a real network
/// request for the Onest font family. The package already catches a failed
/// fetch and falls back to the default font, so this is only about avoiding
/// a slow/flaky network call in CI, not a correctness fix.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
