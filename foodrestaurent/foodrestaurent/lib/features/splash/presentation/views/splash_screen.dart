import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:food_user_application/core/providers/core_providers.dart';
import 'package:food_user_application/core/services/update_service.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_controller.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Check app update
    UpdateService.checkForUpdate();

    // Hide status bar during splash
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom],
    );

    _startSplash();
  }

  Future<void> _startSplash() async {
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    await _resolveDestination();
  }

  Future<void> _resolveDestination() async {
    await ref.read(authControllerProvider.notifier).checkSession();

    if (!mounted) return;

    switch (ref.read(authControllerProvider)) {
      case AuthAuthenticated():
        context.go('/orders');

      case AuthPendingApproval(:final message):
        context.go(
          '/application-status',
          extra: {'status': 'pending', 'message': message},
        );

      case AuthRejected(:final message):
        context.go(
          '/application-status',
          extra: {'status': 'rejected', 'message': message},
        );

      default:
        final hasSeenOnboarding = await ref
            .read(tokenStorageProvider)
            .hasSeenOnboarding;

        if (!mounted) return;

        context.go(hasSeenOnboarding ? '/login' : '/onboarding');
    }
  }

  @override
  void dispose() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: Stack(
        fit: StackFit.expand,
        children: [
          // =========================================================
          // FULL SCREEN SPLASH IMAGE
          // =========================================================
          Image.asset(
            'assets/image/splash_screen.jpeg',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),

          // =========================================================
          // FIXED BOTTOM LOADING BAR
          // =========================================================
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 5,
              child: LinearProgressIndicator(
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.45),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color.fromARGB(255, 210, 12, 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
