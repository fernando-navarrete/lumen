import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/components/section_card.dart';
import 'package:lumen/screens/home/pages/settings/proton_manager.dart';
import 'package:lumen/common/gog_error.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/proton_state.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Settings", style: AppText.pageTitle),
              const SizedBox(height: AppSpacing.lg),
              const ProtonManagerSection(),
              if (kDebugMode) ...[
                const SizedBox(height: 18),
                SectionCard(
                  title: "Debug",
                  description:
                      "These actions only appear in debug builds and are "
                      "meant to help test the app under different scenarios.",
                  child: Row(
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
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearSharedPreferences(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await ref.read(gamesStateProvider.notifier).clear();
    ref.read(protonStateProvider.notifier).resetToEmpty();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("SharedPreferences cleared")));
    }
  }

  Future<void> _clearAuthToken(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(gogStateProvider).clearAuth();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Auth token cleared")));
      }
    } catch (e) {
      logGogError(e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Couldn't clear auth token: ${gogErrorText(e)}"),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }
}
