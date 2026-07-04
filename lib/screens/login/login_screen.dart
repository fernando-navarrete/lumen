import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/components/brand_lockup.dart';
import 'package:gogdl2_flutter/components/glowing_square.dart';
import 'package:gogdl2_flutter/components/gradient_background.dart';
import 'package:gogdl2_flutter/screens/home/home_screen.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_decorations.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';
import 'package:url_launcher/url_launcher_string.dart';

BoxDecoration get _codeDecoration => BoxDecoration(
  color: AppColors.codeBackground,
  borderRadius: BorderRadius.circular(10.0),
  border: Border.all(color: AppColors.border12, width: 1.2),
);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gogState = ref.watch(gogStateProvider);
      try {
        await gogState.restoreAuthFromStorage();
        if (kDebugMode) {
          print('Auth restored from storage');
        }
        if (context.mounted) {
          Navigator.pushReplacement(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
    });
    super.initState();
  }

  LoginStep _step = LoginStep.begin;
  bool loginError = false;

  final _codeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final gogState = ref.watch(gogStateProvider);
    var size = MediaQuery.of(context).size;
    return GradientBackground(
      child: Center(
        child: Container(
          margin: EdgeInsets.all(size.width * 0.1),
          decoration: AppDecorations.card(
            borderRadius: 22.0,
            borderColor: AppColors.border09,
            borderWidth: 0.75,
            blurRadius: 45,
            spreadRadius: 20,
          ),
          child: Row(
            children: [
              Container(
                width: (size.width - (size.width * 0.2) - 2) * 0.45,
                height: (size.height - (size.height * 0.1)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22.0),
                    bottomLeft: Radius.circular(22.0),
                  ),
                  border: Border(
                    right: BorderSide(color: AppColors.border09, width: 0.75),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromARGB(25, 45, 212, 191),
                      Color.fromARGB(34, 42, 35, 80),
                    ],
                  ),
                ),
                child: Container(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandLockup(),
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGlow.withAlpha(64),
                                  blurRadius: 24,
                                  spreadRadius: 1,
                                  offset: Offset(0, 0),
                                ),
                              ],
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withAlpha(25),
                                width: 1.8,
                              ),
                              color: AppColors.primary.withAlpha(16),
                            ),
                            child: const Center(
                              child: GlowingSquare(width: 54),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width:
                            (size.width - (size.width * 0.2) - 2) * 0.45 * 0.7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Your GOG library, unwrapped.",
                              style: AppText.onest(
                                size: 21.0,
                                weight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              "An unofficial client. Lumen never sees your password - you sign in on GOG's own page and hand back a one-time code.",
                              style: AppText.body(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: (size.width - (size.width * 0.2) - 2) * 0.55,
                height: (size.height - (size.height * 0.1)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(22.0),
                    bottomRight: Radius.circular(22.0),
                  ),
                  color: Colors.deepPurple.withAlpha(8),
                ),
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Container(
                        padding: EdgeInsets.all(32.0),
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
                            SizedBox(height: 8),
                            Text(
                              "Connect your account",
                              style: AppText.onest(
                                size: 24.0,
                                weight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Three quick steps. You'll authenticate on GOG, then paste the code it gives you hack here.",
                              style: AppText.body(color: Colors.grey),
                            ),
                            SizedBox(height: 32),
                            _LoginStep(
                              isComplete:
                                  _step == LoginStep.openLoginUrl ||
                                  _step == LoginStep.copyCode ||
                                  _step == LoginStep.pasteCode,
                              step: 1,
                              title: "Open the GOG login page",
                              description: Text(
                                "This opens your browser at GOG's official sign-in. Enter your email and password there.",
                                style: AppText.body(color: Colors.grey),
                              ),
                              action: _PrimaryButton(
                                onTap: () async {
                                  await _openLoginUrl(
                                    context,
                                    ref.read(gogStateProvider),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 4.0,
                                  children: [
                                    Icon(
                                      Icons.open_in_browser,
                                      color: Colors.black,
                                    ),
                                    Text(
                                      "Open GOG login",
                                      style: AppText.onest(
                                        size: 14.0,
                                        weight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 24),
                            _LoginStep(
                              isComplete:
                                  _step == LoginStep.copyCode ||
                                  _step == LoginStep.pasteCode,
                              step: 2,
                              title: "Copy the code form the address bar",
                              description: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text:
                                          "After signing in, GOG redirects to a blank page. Copy everything after ",
                                      style: AppText.body(color: Colors.grey),
                                    ),
                                    TextSpan(
                                      text: "code= ",
                                      style: AppText.body(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    TextSpan(
                                      text: "in the URL.",
                                      style: AppText.body(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              action: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 13,
                                ),
                                decoration: _codeDecoration,
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
                                    SizedBox(height: 6),
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text:
                                                ".../on_login_success?origin=client&",
                                            style: AppText.code(
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                          TextSpan(
                                            text: "code=",
                                            style: AppText.code(
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          TextSpan(
                                            text: "M0xY7...",
                                            style: AppText.code(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 24),
                            _LoginStep(
                              isComplete: _step == LoginStep.pasteCode,
                              step: 3,
                              title: "Paste the code to finish",
                              description: Text(
                                "Lumen exchanges it for your access tokens. Nothing leaves your machine but the code.",
                                style: AppText.body(color: Colors.grey),
                              ),
                              action: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 12,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 11.0,
                                          ),
                                          decoration: _codeDecoration,
                                          child: TextField(
                                            controller: _codeController,
                                            onChanged: (value) async {
                                              await _onEnteredCode(
                                                value,
                                                gogState,
                                              );
                                            },
                                            onSubmitted: (value) async {
                                              await _onSubmitCode(
                                                value,
                                                gogState,
                                              );
                                            },
                                            decoration: InputDecoration(
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              isDense: true,
                                              border: InputBorder.none,
                                              prefixIcon: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                child: Text(
                                                  "code=",
                                                  style: AppText.code(
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ),
                                              hint: RichText(
                                                text: TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text:
                                                          " paste authorization code",
                                                      style: AppText.code(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      _PrimaryButton(
                                        onTap: () async {
                                          await _onSubmitCode(
                                            _codeController.text,
                                            gogState,
                                          );
                                        },
                                        child: Text(
                                          "Sign in",
                                          style: AppText.onest(
                                            size: 14.0,
                                            weight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.0),
                                  loginError
                                      ? Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.error,
                                              color: Colors.red,
                                            ),
                                            SizedBox(width: 8.0),
                                            Expanded(
                                              child: Text(
                                                "That code looks incomplete. Copy the full value after code= and try again.",
                                                style: AppText.body(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : SizedBox.shrink(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _DynamicGradient(step: _step),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSubmitCode(String code, GogState gogState) async {
    try {
      await gogState.loginWithCode(code.trim());
      setState(() {
        loginError = false;
      });
      if (context.mounted) {
        Navigator.pushReplacement(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        loginError = true;
      });
    }
  }

  Future<void> _onEnteredCode(String code, GogState gogState) async {
    setState(() {
      _step = LoginStep.pasteCode;
    });
  }

  Future<void> _openLoginUrl(BuildContext context, GogState gogState) async {
    setState(() {
      _step = LoginStep.openLoginUrl;
    });
    final loginUrl = gogState.getLoginUrl();
    if (!await launchUrlString(loginUrl)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open login URL: $loginUrl')),
      );
    }
    Future.delayed(Duration(seconds: 10), () {
      setState(() {
        _step = LoginStep.copyCode;
      });
    });
  }
}

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

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(11.0),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 2),
            blurRadius: 18,
            color: AppColors.primaryGlow,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 11.0),
        child: child,
      ),
    ),
  );
}

enum LoginStep { begin, openLoginUrl, copyCode, pasteCode }

class _StepIndicator extends StatelessWidget {
  final bool isComplete;
  final int step;

  const _StepIndicator({required this.isComplete, required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(90),
        border: isComplete
            ? null
            : Border.all(color: AppColors.primary, width: 1.0),
        color: isComplete ? AppColors.primary : AppColors.primary.withAlpha(64),
      ),
      child: isComplete
          ? const Icon(Icons.check, color: Colors.black, size: 14)
          : Center(
              child: Text(
                step.toString(),
                style: AppText.onest(
                  size: 12,
                  weight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }
}

class _LoginStep extends StatelessWidget {
  const _LoginStep({
    required this.title,
    required this.description,
    required this.action,
    required this.isComplete,
    required this.step,
  });
  final String title;
  final Widget description;
  final Widget action;
  final bool isComplete;
  final int step;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _StepIndicator(isComplete: isComplete, step: step),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppText.onest(
                size: 14.0,
                weight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            description,
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    ],
  );
}
