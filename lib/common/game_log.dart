import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_paths.dart';
import 'gog_error.dart';
import 'host_environment.dart';

/// Whether [gameId] has a launch log to open yet.
bool gameLogExists(int gameId) => File(gameLogPath(gameId)).existsSync();

/// Opens [gameId]'s launch log in the desktop's default handler for it,
/// with a snackbar on [context] if that fails.
Future<void> openGameLog(
  BuildContext context,
  WidgetRef ref,
  int gameId,
) async {
  final path = gameLogPath(gameId);
  final open = ref.read(openExternallyProvider);
  var opened = false;
  try {
    opened = await open(path);
  } catch (e) {
    logGogError(e);
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Couldn't open $path")));
  }
}
