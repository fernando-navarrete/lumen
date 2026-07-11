import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/executable_finder.dart';
import 'package:lumen/components/app_dropdown.dart';
import 'package:lumen/components/executable_picker_dialog.dart';
import 'package:lumen/components/panel.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/proton_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_decorations.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// One editable KEY=VALUE row's controllers, kept alive across rebuilds.
class _EnvVarRow {
  _EnvVarRow({String key = '', String value = ''})
    : key = TextEditingController(text: key),
      value = TextEditingController(text: value);

  final TextEditingController key;
  final TextEditingController value;

  void dispose() {
    key.dispose();
    value.dispose();
  }
}

/// Per-game settings: override which Proton-GE version this game launches
/// with (falling back to the global default from the Settings screen when
/// unset), which executable to run, extra launch arguments and environment
/// variables, and show the game's Proton prefix directory.
class GameSettingsTab extends ConsumerStatefulWidget {
  const GameSettingsTab({super.key, required this.gameId});

  final int gameId;

  @override
  ConsumerState<GameSettingsTab> createState() => _GameSettingsTabState();
}

class _GameSettingsTabState extends ConsumerState<GameSettingsTab> {
  late TextEditingController _launchArgsController;
  final List<_EnvVarRow> _envRows = [];

  @override
  void initState() {
    super.initState();
    _initFromState();
  }

  @override
  void didUpdateWidget(covariant GameSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameId != widget.gameId) {
      _launchArgsController.dispose();
      for (final row in _envRows) {
        row.dispose();
      }
      _envRows.clear();
      _initFromState();
    }
  }

  void _initFromState() {
    final gamesState = ref.read(gamesStateProvider);
    _launchArgsController = TextEditingController(
      text: gamesState.getLaunchArgs(widget.gameId).join(' '),
    );
    for (final entry in gamesState.getEnvVars(widget.gameId).entries) {
      _envRows.add(_EnvVarRow(key: entry.key, value: entry.value));
    }
  }

  @override
  void dispose() {
    _launchArgsController.dispose();
    for (final row in _envRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _persistLaunchArgs() {
    final args = _launchArgsController.text
        .split(RegExp(r'\s+'))
        .where((arg) => arg.isNotEmpty)
        .toList();
    ref.read(gamesStateProvider.notifier).setLaunchArgs(widget.gameId, args);
  }

  void _persistEnvVars() {
    final vars = <String, String>{};
    for (final row in _envRows) {
      final key = row.key.text.trim();
      if (key.isEmpty) {
        continue;
      }
      vars[key] = row.value.text;
    }
    ref.read(gamesStateProvider.notifier).setEnvVars(widget.gameId, vars);
  }

  Future<void> _changeExecutable(String installPath) async {
    final candidates = findExecutables(installPath);
    if (candidates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No .exe files found in the install directory"),
          ),
        );
      }
      return;
    }
    final chosen = await showExecutablePicker(
      context,
      candidates: candidates,
      confirmLabel: "Use",
    );
    if (chosen != null) {
      ref
          .read(gamesStateProvider.notifier)
          .setExecutable(widget.gameId, chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameId = widget.gameId;
    final protonState = ref.watch(protonStateProvider);
    final gamesState = ref.watch(gamesStateProvider);
    final selectedTag = gamesState.getProtonVersion(gameId);
    final prefixPath = gamesState.getProtonPrefixPath(gameId);
    final installPath = gamesState.getInstallPath(gameId);
    final executable = gamesState.getExecutable(gameId);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Proton version", style: AppText.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          AppDropdown<String?>(
            value: selectedTag,
            entries: [
              AppDropdownEntry(
                value: null,
                label: protonState.defaultVersion != null
                    ? "Use global default (${protonState.defaultVersion})"
                    : "Use global default (none set)",
              ),
              for (final tag in protonState.installedTags)
                AppDropdownEntry(value: tag, label: tag),
            ],
            onChanged: (tag) => ref
                .read(gamesStateProvider.notifier)
                .setProtonVersion(gameId, tag),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text("Executable", style: AppText.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          Panel(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    executable ??
                        "Resolved automatically the first time you play.",
                    style: AppText.bodyMedium(color: AppColors.textSecondary),
                  ),
                ),
                if (installPath != null) ...[
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => _changeExecutable(installPath),
                    child: Text(
                      "Change",
                      style: AppText.button(color: AppColors.primary),
                    ),
                  ),
                  if (executable != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: () => ref
                          .read(gamesStateProvider.notifier)
                          .setExecutable(gameId, null),
                      child: Text(
                        "Clear",
                        style: AppText.button(color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text("Launch arguments", style: AppText.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: AppDecorations.codeBlock,
            child: TextField(
              controller: _launchArgsController,
              onChanged: (_) => _persistLaunchArgs(),
              style: AppText.code(color: Colors.white),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: "-skipintro -windowed",
                hintStyle: AppText.code(color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Environment variables",
                  style: AppText.sectionLabel,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => setState(() => _envRows.add(_EnvVarRow())),
                child: Text(
                  "+ Add",
                  style: AppText.button(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_envRows.isEmpty)
            Panel(
              child: Text(
                "None set.",
                style: AppText.bodyMedium(color: AppColors.textSecondary),
              ),
            )
          else
            Column(
              spacing: AppSpacing.sm,
              children: [for (final row in _envRows) _buildEnvRow(row)],
            ),
          const SizedBox(height: AppSpacing.lg),
          Text("Proton prefix", style: AppText.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          Panel(
            child: Text(
              prefixPath ?? "Created automatically the first time you play.",
              style: AppText.bodyMedium(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvRow(_EnvVarRow row) {
    return Row(
      spacing: AppSpacing.sm,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: AppDecorations.codeBlock,
            child: TextField(
              controller: row.key,
              onChanged: (_) => _persistEnvVars(),
              style: AppText.code(color: Colors.white),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintText: "KEY",
                hintStyle: AppText.code(color: AppColors.textMuted),
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: AppDecorations.codeBlock,
            child: TextField(
              controller: row.value,
              onChanged: (_) => _persistEnvVars(),
              style: AppText.code(color: Colors.white),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintText: "value",
                hintStyle: AppText.code(color: AppColors.textMuted),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: () {
            setState(() {
              _envRows.remove(row);
            });
            row.dispose();
            _persistEnvVars();
          },
        ),
      ],
    );
  }
}
