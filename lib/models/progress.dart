// Progress snapshots emitted on the download/verify/repair/Proton/save
// streams, app-owned replacements for the bridge's `DownloadStream`,
// `VerificationStream`, `RepairStream`, `ProtonDownloadStream`,
// `SaveDownloadStream` and `SaveUploadStream` — see
// `lib/state/gog_backend.dart`. Field sets mirror the bridge types exactly,
// with counters as plain `int` instead of `BigInt` and the opaque
// `*Status` objects (whose only member was `.name()`) collapsed to a plain
// `String status`.

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

class VerificationProgress {
  final int totalBytes;
  final int totalChunks;
  final int verifiedBytes;
  final int verifiedChunks;
  final List<String> errorChunks;
  final String status;

  const VerificationProgress({
    required this.totalBytes,
    required this.totalChunks,
    required this.verifiedBytes,
    required this.verifiedChunks,
    required this.errorChunks,
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

class ProtonDownloadProgress {
  final int total;
  final int transferred;
  final String status;

  const ProtonDownloadProgress({
    required this.total,
    required this.transferred,
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
