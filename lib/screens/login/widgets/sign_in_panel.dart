import 'package:flutter/material.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/screens/login/widgets/login_step_tile.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_decorations.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

enum LoginStep { begin, openLoginUrl, copyCode, pasteCode }

/// Right half of the login card: the three-step sign-in flow.
class SignInPanel extends StatelessWidget {
  const SignInPanel({
    super.key,
    required this.step,
    required this.loginError,
    required this.codeController,
    required this.onOpenLoginUrl,
    required this.onCodeChanged,
    required this.onSubmitCode,
  });

  final LoginStep step;
  final bool loginError;
  final TextEditingController codeController;
  final VoidCallback onOpenLoginUrl;
  final ValueChanged<String> onCodeChanged;
  final ValueChanged<String> onSubmitCode;

  // Colors.deepPurple at ~3% — the panel's subtle cool tint (one-off).
  static const _panelTint = Color(0x08673AB7);

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Container(
      width: (size.width - (size.width * 0.2) - 2) * 0.55,
      height: (size.height - (size.height * 0.1)),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(AppRadii.panel),
          bottomRight: Radius.circular(AppRadii.panel),
        ),
        color: _panelTint,
      ),
      child: Stack(
        children: [
          _DynamicGradient(step: step),
          SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "SECURE SIGN-IN",
                    style: AppText.monospace(
                      size: 10.0,
                      weight: FontWeight.w100,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "Connect your account",
                    style: AppText.onest(
                      size: 24.0,
                      weight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "Three quick steps. You'll authenticate on GOG, then paste the code it gives you back here.",
                    style: AppText.body(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  LoginStepTile(
                    isDim: false,
                    isComplete:
                        step == LoginStep.openLoginUrl ||
                        step == LoginStep.copyCode ||
                        step == LoginStep.pasteCode,
                    step: 1,
                    title: "Open the GOG login page",
                    description: Text(
                      "This opens your browser at GOG's official sign-in. Enter your email and password there.",
                      style: AppText.body(color: AppColors.textSecondary),
                    ),
                    action: PrimaryButton.icon(
                      glowing: true,
                      onTap: onOpenLoginUrl,
                      icon: Icons.open_in_browser,
                      label: "Open GOG login",
                      foreground: Colors.black,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LoginStepTile(
                    isDim: step == LoginStep.begin,
                    isComplete:
                        step == LoginStep.copyCode ||
                        step == LoginStep.pasteCode,
                    step: 2,
                    title: "Copy the code from the address bar",
                    description: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text:
                                "After signing in, GOG redirects to a blank page. Copy everything after ",
                            style: AppText.body(color: AppColors.textSecondary),
                          ),
                          TextSpan(
                            text: "code= ",
                            style: AppText.body(color: AppColors.primary),
                          ),
                          TextSpan(
                            text: "in the URL.",
                            style: AppText.body(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    action: const _RedirectUrlPreview(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LoginStepTile(
                    isDim:
                        step == LoginStep.begin ||
                        step == LoginStep.openLoginUrl,
                    isComplete: step == LoginStep.pasteCode,
                    step: 3,
                    title: "Paste the code to finish",
                    description: Text(
                      "Lumen exchanges it for your access tokens. Nothing leaves your machine but the code.",
                      style: AppText.body(color: AppColors.textSecondary),
                    ),
                    action: _CodeEntry(
                      codeController: codeController,
                      loginError: loginError,
                      onCodeChanged: onCodeChanged,
                      onSubmitCode: onSubmitCode,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Example of the GOG redirect URL, highlighting where the code lives.
class _RedirectUrlPreview extends StatelessWidget {
  const _RedirectUrlPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
      decoration: AppDecorations.codeBlock,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "REDIRECT URL LOOKS LIKE THIS:",
            style: AppText.monospace(
              size: 9.0,
              weight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: ".../on_login_success?origin=client&",
                  style: AppText.code(color: AppColors.textMuted),
                ),
                TextSpan(
                  text: "code=",
                  style: AppText.code(color: AppColors.primary),
                ),
                TextSpan(
                  text: "M0xY7...",
                  style: AppText.code(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Code input field, submit button and the invalid-code error row.
class _CodeEntry extends StatelessWidget {
  const _CodeEntry({
    required this.codeController,
    required this.loginError,
    required this.onCodeChanged,
    required this.onSubmitCode,
  });

  final TextEditingController codeController;
  final bool loginError;
  final ValueChanged<String> onCodeChanged;
  final ValueChanged<String> onSubmitCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11.0),
                decoration: AppDecorations.codeBlock,
                child: TextField(
                  controller: codeController,
                  onChanged: onCodeChanged,
                  onSubmitted: onSubmitCode,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    isDense: true,
                    border: InputBorder.none,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        "code=",
                        style: AppText.code(color: AppColors.textMuted),
                      ),
                    ),
                    hint: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: " paste authorization code",
                            style: AppText.code(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            PrimaryButton(
              glowing: true,
              onTap: () => onSubmitCode(codeController.text),
              child: Text(
                "Sign in",
                style: AppText.button(color: Colors.black),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        loginError
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: AppColors.error),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      "That code looks incomplete. Copy the full value after code= and try again.",
                      style: AppText.body(color: AppColors.error),
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ],
    );
  }
}

/// Radial shadow that slides down the panel as the user advances steps.
class _DynamicGradient extends StatelessWidget {
  const _DynamicGradient({required this.step});

  final LoginStep step;

  Alignment get _centerForStep => switch (step) {
    LoginStep.begin => const Alignment(-0.2, 1.0),
    LoginStep.openLoginUrl => const Alignment(-0.2, 1.3),
    LoginStep.copyCode => const Alignment(-0.2, 1.6),
    LoginStep.pasteCode => const Alignment(-0.2, 1.9),
  };

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [Colors.black.withAlpha(255), Colors.transparent],
              center: _centerForStep,
              radius: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
