/// Thrown by [GogState] in place of the raw `PlatformException` that
/// `flutter_secure_storage`'s Linux plugin throws when there's no Secret
/// Service provider (no keyring running — common on minimal WMs) or the
/// keyring is locked. `gogErrorText` falls back to `toString()` for anything
/// that isn't a `GogError`, so surfacing this instead of the raw exception
/// makes the login screen's snackbars show actionable text instead of
/// `PlatformException(Libsecret error, ...)`.
class KeyringUnavailableError implements Exception {
  /// User-facing explanation of what's wrong and how to fix it.
  final String message;

  /// The original platform error's detail, kept for [logGogError] instead of
  /// being shown to the user.
  final String detail;

  KeyringUnavailableError(this.message, this.detail);

  @override
  String toString() => message;
}
