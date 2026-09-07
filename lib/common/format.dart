/// Formats a byte count as a human-readable string, e.g. `"1.5 GB"`.
String formatBytes(int bytes) {
  const units = ["B", "KB", "MB", "GB", "TB"];
  double value = bytes.toDouble();
  int unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return "${value.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}";
}

/// Formats a byte count as a human-readable string, e.g. `"1.5 GB"`.
String formatBytesBigint(BigInt bytes) {
  const units = ["B", "KB", "MB", "GB", "TB"];
  double value = bytes.toDouble();
  int unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return "${value.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}";
}
