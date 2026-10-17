import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/gog_error.dart';
import 'package:lumen/common/host_environment.dart';
import 'package:lumen/common/login_code.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/gradient_background.dart';
import 'package:lumen/screens/home/home_screen.dart';
import 'package:lumen/screens/login/widgets/branding_panel.dart';
import 'package:lumen/screens/login/widgets/sign_in_panel.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_decorations.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/breakpoints.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _maxCardWidth = 1040.0;
  static const _maxCardHeight = 680.0;

  LoginStep _step = LoginStep.begin;
  String? _loginError;
  bool _restoring = true;
  bool _submitting = false;

  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _codeFocus.addListener(_onCodeFocusChanged);
    _lifecycle = AppLifecycleListener(onResume: _onAppResumed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _codeFocus.removeListener(_onCodeFocusChanged);
    _codeFocus.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final gogState = ref.read(gogStateProvider);
    try {
      if (await gogState.restoreAuthFromStorage()) {
        if (kDebugMode) {
          debugPrint('Auth restored from storage');
        }
        _goHome();
        return;
      }
    } catch (e) {
      logGogError(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Couldn't restore your session: ${gogErrorText(e)}"),
          duration: const Duration(seconds: 8),
        ),
      );
    }
    if (!mounted) return;
    setState(() => _restoring = false);
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  /// Back from the browser: the user has the code to copy now.
  void _onAppResumed() {
    if (!mounted || _step != LoginStep.openLoginUrl) return;
    setState(() => _step = LoginStep.copyCode);
  }

  void _onCodeFocusChanged() {
    if (!_codeFocus.hasFocus) return;
    if (_step == LoginStep.begin || _step == LoginStep.openLoginUrl) {
      setState(() => _step = LoginStep.copyCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const GradientBackground(child: CenteredLoader());
    }
    final gogState = ref.watch(gogStateProvider);
    return GradientBackground(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = min(constraints.maxWidth, _maxCardWidth);
              final height = min(constraints.maxHeight, _maxCardHeight);
              return Container(
                width: width,
                height: height,
                decoration: AppDecorations.card(
                  borderRadius: AppRadii.panel,
                  borderColor: AppColors.border09,
                  borderWidth: 0.75,
                  blurRadius: 45,
                  spreadRadius: 20,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.panel),
                  child: Row(
                    children: [
                      if (width >= Breakpoints.loginSplit)
                        const Expanded(flex: 45, child: BrandingPanel()),
                      Expanded(
                        flex: 55,
                        child: SignInPanel(
                          step: _step,
                          errorText: _loginError,
                          submitting: _submitting,
                          codeController: _codeController,
                          codeFocusNode: _codeFocus,
                          onOpenLoginUrl: () =>
                              _openLoginUrl(context, gogState),
                          onCodeChanged: _onCodeChanged,
                          onSubmitCode: (value) =>
                              _onSubmitCode(value, gogState),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _onSubmitCode(String raw, GogState gogState) async {
    if (_submitting) return;
    final code = extractLoginCode(raw);
    if (code.isEmpty) {
      setState(
        () => _loginError = 'Paste the code from the address bar first.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _loginError = null;
    });
    try {
      await gogState.loginWithCode(code);
      if (!mounted) return;
      _goHome();
    } catch (e) {
      logGogError(e);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _loginError = loginErrorText(e);
      });
    }
  }

  void _onCodeChanged(String value) {
    setState(() {
      if (value.trim().isNotEmpty) {
        _step = LoginStep.pasteCode;
      } else if (_step == LoginStep.pasteCode) {
        _step = LoginStep.copyCode;
      }
    });
  }

  Future<void> _openLoginUrl(BuildContext context, GogState gogState) async {
    setState(() {
      _step = LoginStep.openLoginUrl;
    });
    final loginUrl = gogState.getLoginUrl();
    if (loginUrl.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No login URL available')));
      return;
    }
    if (!await ref.read(openExternallyProvider)(loginUrl)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open login URL: $loginUrl')),
      );
    }
  }
}
