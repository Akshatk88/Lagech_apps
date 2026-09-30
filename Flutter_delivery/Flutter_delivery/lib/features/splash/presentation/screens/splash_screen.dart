import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:food_user_application/core/services/update_service.dart';

import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _animationDone = false;

  @override
  void initState() {
    super.initState();

    UpdateService.checkForUpdate();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom],
    );

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;

      _animationDone = true;
      _tryNavigate();
    });
  }

  void _tryNavigate() {
    if (!mounted || !_animationDone) return;

    final authState = ref.read(authControllerProvider);

    if (authState is AuthInitial || authState is AuthLoading) {
      return;
    }

    context.go('/onboarding');
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) => _tryNavigate(),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ============================================================
          // FULL SCREEN SPLASH IMAGE
          // ============================================================
          Positioned.fill(
            child: Image.asset(
              'assets/image/splash_screen.jpeg',
              fit: BoxFit.cover,
            ),
          ),

          // ============================================================
          // RED LOADING BAR
          // ============================================================
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: const LinearProgressIndicator(
                minHeight: 5,
                backgroundColor: Color(0xFFE8E8E8),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE53935)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
