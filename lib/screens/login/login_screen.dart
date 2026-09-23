import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart';
import 'package:lumen/components/gradient_background.dart';
import 'package:lumen/screens/home/home_screen.dart';
import 'package:lumen/screens/login/widgets/branding_panel.dart';
import 'package:lumen/screens/login/widgets/sign_in_panel.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_decorations.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:lumen/common/gog_error.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  LoginStep _step = LoginStep.begin;
  bool _loginError = false;

  final _codeController = TextEditingController();

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gogState = ref.read(gogStateProvider);
      try {
        if (!await gogState.restoreAuthFromStorage()) return;
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
        logGogError(e);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Couldn't restore your session: ${gogErrorText(e)}"),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gogState = ref.watch(gogStateProvider);
    var size = MediaQuery.of(context).size;
    return GradientBackground(
      child: Center(
        child: Container(
          margin: EdgeInsets.all(size.width * 0.1),
          decoration: AppDecorations.card(
            borderRadius: AppRadii.panel,
            borderColor: AppColors.border09,
            borderWidth: 0.75,
            blurRadius: 45,
            spreadRadius: 20,
          ),
          child: Row(
            children: [
              const BrandingPanel(),
              SignInPanel(
                step: _step,
                loginError: _loginError,
                codeController: _codeController,
                onOpenLoginUrl: () => _openLoginUrl(context, gogState),
                onCodeChanged: (value) => _onEnteredCode(value, gogState),
                onSubmitCode: (value) => _onSubmitCode(value, gogState),
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
      if (!mounted) return;
      setState(() {
        _loginError = false;
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on GogError catch (e) {
      logGogError(e);
      if (!mounted) return;
      setState(() {
        _loginError = true;
      });
    } catch (e) {
      // Not a bad code: e.g. the keyring rejected the token write.
      logGogError(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Couldn't sign in: ${gogErrorText(e)}"),
          duration: const Duration(seconds: 8),
        ),
      );
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
    if (loginUrl.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No login URL available')));
      return;
    }
    if (!await launchUrlString(loginUrl)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open login URL: $loginUrl')),
      );
    }
    Future.delayed(Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() {
        _step = LoginStep.copyCode;
      });
    });
  }
}
