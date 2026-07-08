import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/components/panel.dart';
import 'package:gogdl2_flutter/components/primary_button.dart';
import 'package:gogdl2_flutter/state/games_state.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_dimens.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Debug", style: AppText.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.sm,
              children: [
                Text(
                  "These actions only appear in debug builds and are meant "
                  "to help test the app under different scenarios.",
                  style: AppText.body(color: AppColors.textSecondary),
                ),
                Row(
                  spacing: AppSpacing.sm,
                  children: [
                    PrimaryButton(
                      onTap: () => _clearSharedPreferences(context, ref),
                      child: Text(
                        "Clear SharedPreferences",
                        style: AppText.button(color: Colors.white),
                      ),
                    ),
                    PrimaryButton(
                      onTap: () => _clearAuthToken(context, ref),
                      child: Text(
                        "Clear auth token",
                        style: AppText.button(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearSharedPreferences(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await ref.read(gamesStateProvider.notifier).clear();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("SharedPreferences cleared")));
    }
  }

  Future<void> _clearAuthToken(BuildContext context, WidgetRef ref) async {
    await ref.read(gogStateProvider).clearAuth();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Auth token cleared")));
    }
  }
}
