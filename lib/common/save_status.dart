import 'package:lumen/common/format.dart';
import 'package:lumen/state/downloads_state.dart' show TaskStatus;
import 'package:lumen/state/saves_state.dart';

/// One-line status for a cloud save sync, shared by the Saves tab and the
/// Downloads page card. Downloads report a job byte total up front; uploads
/// only know their file count, so they omit the byte pair.
String saveStatusText(SaveTask task) {
  final download = task.direction == SaveDirection.download;
  switch (task.status) {
    case TaskStatus.running:
      final verb = download ? "Downloading" : "Uploading";
      final files = "${task.filesProcessed}/${task.filesTotal} files";
      return download && task.total > 0
          ? "$verb saves… $files"
                " (${formatBytes(task.transferred)}/${formatBytes(task.total)})"
          : "$verb saves… $files";
    case TaskStatus.completed:
      if (task.isEmpty) {
        return "No cloud saves found";
      }
      return download ? "Saves downloaded" : "Saves uploaded";
    case TaskStatus.failed:
      final label = download ? "Save download failed" : "Save upload failed";
      return task.error == null ? label : "$label: ${task.error}";
  }
}
