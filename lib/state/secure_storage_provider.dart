import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The single [FlutterSecureStorage] instance [GogState] uses for the stored
/// auth token, so the app isn't repeatedly constructing (cheap, but still
/// pointless) instances across `loginWithCode`/`restoreAuthFromStorage`/the
/// token-refresh callback/`clearAuth`. Overridden with a fake in tests, since
/// the real instance needs the platform channel.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
  name: 'secureStorageProvider',
);
