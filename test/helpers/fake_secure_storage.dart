import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// In-memory [FlutterSecureStorage] stand-in for tests, since the real one
/// needs the platform channel. Only [read], [write] and [delete] are
/// implemented — everything else throws via [noSuchMethod], since
/// [GogState] never calls it.
///
/// Set [throwOnNext] to a [PlatformException] (e.g. one carrying
/// `flutter_secure_storage_linux`'s `'Libsecret error'`/`'KeyringLocked'`
/// codes) to make the very next call throw it instead of touching the
/// in-memory map; it's cleared after firing once.
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _values = {};

  PlatformException? throwOnNext;

  void _maybeThrow() {
    final e = throwOnNext;
    if (e != null) {
      throwOnNext = null;
      throw e;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _maybeThrow();
    return _values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _maybeThrow();
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _maybeThrow();
    _values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
