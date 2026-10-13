import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/app.dart';
import 'package:lumen/common/gog_error.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/components/section_card.dart';
import 'package:lumen/screens/home/pages/settings/proton_manager.dart';
import 'package:lumen/state/account.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/proton_state.dart';
import 'package:lumen/theme/app_colors.dart';
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
              const SizedBox(height: 18),
              SectionCard(
                title: "GOG account",
                description:
                    "Signing out keeps your installed games and settings on "
                    "this computer.",
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PrimaryButton(
                    onTap: () => _signOut(context, ref),
                    child: Text(
                      "Sign out",
                      style: AppText.button(color: Colors.white),
                    ),
                  ),
                ),
              ),
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

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _SignOutDialog(),
    );
    if (confirmed != true) return;
    try {
      await ref.read(accountProvider).signOut();
    } catch (e) {
      logGogError(e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Couldn't sign out: ${gogErrorText(e)}"),
            duration: const Duration(seconds: 8),
          ),
        );
      }
      return;
    }
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const App()),
        (_) => false,
      );
    }
  }

  Future<void> _clearSharedPreferences(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await ref.read(gamesStateProvider.notifier).clear();
    ref.read(protonStateProvider.notifier).resetToEmpty();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("SharedPreferences cleared")),
      );
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

class _SignOutDialog extends StatelessWidget {
  const _SignOutDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sign out of GOG?', style: AppText.sectionLabel),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Installed games, their settings, Wine prefixes and Proton '
                'versions stay on this computer. Signing back in finds them '
                'as they were.',
                style: AppText.meta(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancel',
                      style: AppText.button(color: AppColors.textSecondary),
                    ),
                  ),
                  PrimaryButton(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Text(
                      'Sign out',
                      style: AppText.button(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
