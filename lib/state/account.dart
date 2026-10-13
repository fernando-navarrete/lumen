import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/home_state.dart';
import 'package:lumen/state/launch_state.dart';
import 'package:lumen/state/proton_state.dart';
import 'package:lumen/state/saves_state.dart';

/// Thrown by [Account.signOut] when it refuses to start; [toString] is the
/// user-facing message.
class SignOutError implements Exception {
  final String message;

  const SignOutError(this.message);

  @override
  String toString() => message;
}

/// The signed-in GOG account. Stateless: everything it changes lives in the
/// providers it invalidates.
class Account {
  final Ref _ref;

  Account(this._ref);

  /// What would be lost by signing out right now, as user-facing phrases.
  /// Paused tasks don't count: they resume after signing back in.
  List<String> _running() {
    final downloads = _ref
        .read(downloadsStateProvider)
        .tasks
        .values
        .where((t) => t.status == TaskStatus.running);
    return [
      if (downloads.any((t) => t.kind == TaskKind.download)) 'a download',
      if (downloads.any((t) => t.kind == TaskKind.verification))
        'a verification',
      if (downloads.any((t) => t.kind == TaskKind.repair)) 'a repair',
      if (_ref
          .read(protonStateProvider)
          .tasks
          .values
          .any((t) => t.status == TaskStatus.running))
        'a Proton download',
      if (_ref
          .read(savesStateProvider)
          .tasks
          .values
          .any((t) => t.status == TaskStatus.running))
        'a cloud save sync',
      if (_ref
          .read(launchStateProvider)
          .games
          .keys
          .any(_ref.read(launchStateProvider).isActive))
        'a running game',
    ];
  }

  /// Signs out: deletes the stored token and resets everything that held the
  /// old session, keeping all local data (installed games, configs, prefixes,
  /// Proton versions).
  ///
  /// Refuses while a job, save sync or game is running, naming what is. A
  /// keyring failure from [GogState.clearAuth] propagates and leaves the
  /// session untouched. The caller routes back to the login screen.
  Future<void> signOut() async {
    final running = _running();
    if (running.isNotEmpty) {
      throw SignOutError(
        'Finish or stop ${running.join(', ')} before signing out',
      );
    }

    await _ref.read(gogStateProvider).clearAuth();

    // Disposes the old backend and builds a fresh, unauthenticated one on
    // next use; `gogStateProvider` and every library metadata provider
    // depend on it, so they reset too.
    _ref.invalidate(gogBackendProvider);
    // These capture `GogState` once in `build()` with `ref.read`, so they
    // would keep calling the disposed backend. Nothing of theirs is running
    // (checked above); paused downloads reload like after a restart.
    _ref.invalidate(downloadsStateProvider);
    _ref.invalidate(savesStateProvider);
    _ref.invalidate(protonStateProvider);

    _ref.invalidate(navBarItemProvider);
    _ref.invalidate(librarySelectionProvider);
    _ref.invalidate(librarySearchProvider);
  }
}

final accountProvider = Provider<Account>(Account.new, name: 'accountProvider');
