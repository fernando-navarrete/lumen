// Progress snapshots emitted on the save streams, app-owned replacements
// for the bridge's `SaveDownloadStream` and `SaveUploadStream` — see
// `lib/state/gog_backend.dart`. Field sets mirror the bridge types exactly,
// with counters as plain `int` instead of `BigInt` and the opaque
// `*Status` objects (whose only member was `.name()`) collapsed to a plain
// `String status`.
//
// Four streams are the exception: `ProtonDownloadProgress`,
// `VerifyDownloadProgress`, `DownloadGameProgress` and `RepairGameProgress`
// are bridge-owned freezed unions (see `package:gogdl_flutter`), not
// app-owned classes here. `ProtonTask` in `lib/state/proton_state.dart` and
// `ActivityTask` in `lib/state/downloads_state.dart` adapt them directly.

/// Covers both the save-download and save-upload streams — the bridge gave
/// each its own opaque type, but both were `{transferred, total, status}`.
class SaveTransferProgress {
  final int total;
  final int transferred;
  final String status;

  const SaveTransferProgress({
    required this.total,
    required this.transferred,
    required this.status,
  });
}
