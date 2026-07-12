import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/components/gradient_background.dart';
import 'package:lumen/screens/home/home_screen.dart';
import 'package:lumen/screens/login/widgets/branding_panel.dart';
import 'package:lumen/screens/login/widgets/sign_in_panel.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_decorations.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
        await gogState.restoreAuthFromStorage();
        await gogState.configureDownload(
          minConcurrency: 128,
          maxConcurrency: 256,
          timeout: 10,
        );
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
      setState(() {
        _loginError = false;
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
        _loginError = true;
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
