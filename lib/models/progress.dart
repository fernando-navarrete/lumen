// Progress snapshots emitted on the download/repair/save streams, app-owned
// replacements for the bridge's `DownloadStream`, `RepairStream`,
// `SaveDownloadStream` and `SaveUploadStream` — see
// `lib/state/gog_backend.dart`. Field sets mirror the bridge types exactly,
// with counters as plain `int` instead of `BigInt` and the opaque `*Status`
// objects (whose only member was `.name()`) collapsed to a plain
// `String status`.
//
// Two streams are the exception: `ProtonDownloadProgress` and
// `VerifyDownloadProgress` are bridge-owned freezed unions (see
// `package:gogdl_flutter`), not app-owned classes here. `ProtonTask` in
// `lib/state/proton_state.dart` and `ActivityTask` in
// `lib/state/downloads_state.dart` adapt them directly.

class DownloadProgress {
  final int totalBytes;
  final int totalChunks;
  final int totalFiles;
  final int downloadedBytes;
  final int downloadedChunks;
  final int allocatedFiles;
  final List<String> errorFiles;
  final String status;

  const DownloadProgress({
    required this.totalBytes,
    required this.totalChunks,
    required this.totalFiles,
    required this.downloadedBytes,
    required this.downloadedChunks,
    required this.allocatedFiles,
    required this.errorFiles,
    required this.status,
  });
}

class RepairProgress {
  final int totalBytes;
  final int totalChunks;
  final int totalFiles;
  final int downloadedBytes;
  final int downloadedChunks;
  final int processedFiles;
  final List<String> errorFiles;
  final String status;

  const RepairProgress({
    required this.totalBytes,
    required this.totalChunks,
    required this.totalFiles,
    required this.downloadedBytes,
    required this.downloadedChunks,
    required this.processedFiles,
    required this.errorFiles,
    required this.status,
  });
}

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
