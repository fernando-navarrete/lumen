import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/clickable_container.dart';
import 'package:lumen/common/executable_finder.dart';
import 'package:lumen/components/app_dropdown.dart';
import 'package:lumen/components/executable_picker_dialog.dart';
import 'package:lumen/components/section_card.dart';
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

  /// "ENV=VAL … ./game.exe -args" preview assembled from the saved config.
  String _resolvedCommand(GamesState gamesState) {
    final envVars = gamesState.getEnvVars(widget.gameId);
    final executable = gamesState.getExecutable(widget.gameId);
    final args = gamesState.getLaunchArgs(widget.gameId);

    final envStr = envVars.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    final exeName = executable?.split(RegExp(r'[/\\]')).last;
    return [
      if (envStr.isNotEmpty) envStr,
      './${exeName ?? '<game>'}',
      ...args,
    ].join(' ');
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 18,
          children: [
            SectionCard(
              title: "Compatibility layer",
              description:
                  "Proton / Wine version used to run this game. Overrides the global default.",
              child: AppDropdown<String?>(
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
            ),
            SectionCard(
              title: "Executable",
              description:
                  "Resolved automatically the first time you play unless set here.",
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      executable ?? "Not set",
                      style: executable != null
                          ? AppText.code(color: Colors.white)
                          : AppText.bodyMedium(
                              color: AppColors.textSecondary,
                            ),
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
            SectionCard(
              title: "Launch arguments",
              description: "Appended to the game's command line at launch.",
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: AppDecorations.monoInput(),
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
            ),
            SectionCard(
              title: "Environment variables",
              description:
                  "Passed to the game process at launch, before the launch arguments.",
              trailing: _AddVariableButton(
                onTap: () => setState(() => _envRows.add(_EnvVarRow())),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 9,
                children: [
                  if (_envRows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        "No variables set. Add one above.",
                        style: AppText.onest(
                          size: 13,
                          weight: FontWeight.w400,
                          color: AppColors.textMuted,
                        ).copyWith(fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    for (final row in _envRows) _buildEnvRow(row),
                  const SizedBox(height: 7),
                  _ResolvedCommandPreview(command: _resolvedCommand(gamesState)),
                ],
              ),
            ),
            SectionCard(
              title: "Proton prefix",
              description: "Per-game compatibility data directory.",
              child: Text(
                prefixPath ?? "Created automatically the first time you play.",
                style: prefixPath != null
                    ? AppText.code(color: Colors.white)
                    : AppText.bodyMedium(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvRow(_EnvVarRow row) {
    return Row(
      spacing: 9,
      children: [
        Expanded(child: _envField(row.key, hint: "VARIABLE")),
        Text("=", style: AppText.code(color: AppColors.text40)),
        Expanded(child: _envField(row.value, hint: "value")),
        _RemoveButton(
          onTap: () {
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

  Widget _envField(TextEditingController controller, {required String hint}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: AppDecorations.monoInput(borderRadius: AppRadii.chip),
      child: TextField(
        controller: controller,
        onChanged: (_) => _persistEnvVars(),
        style: AppText.code(color: Colors.white),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          hintText: hint,
          hintStyle: AppText.code(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

/// Teal "+ Add variable" pill in the env-vars card header.
class _AddVariableButton extends StatelessWidget {
  const _AddVariableButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClickableContainer(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: Text(
          "+ Add variable",
          style: AppText.onest(
            size: 12.5,
            weight: FontWeight.w600,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}

/// 36×36 quiet "×" button removing an env row.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClickableContainer(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.fill05,
          border: Border.all(color: AppColors.border08),
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
      ),
    );
  }
}

/// Mono preview of the assembled launch command.
class _ResolvedCommandPreview extends StatelessWidget {
  const _ResolvedCommandPreview({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: AppDecorations.previewBox,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 7,
        children: [
          Text(
            "RESOLVED LAUNCH COMMAND",
            style: AppText.monospace(
              size: 9.5,
              weight: FontWeight.w400,
              color: AppColors.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          Text(command, style: AppText.monoPreview),
        ],
      ),
    );
  }
}
