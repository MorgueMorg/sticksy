import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_router.dart';
import 'core/config/app_theme.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';

class SticksyApp extends ConsumerStatefulWidget {
  const SticksyApp({super.key, required this.onboardingCompleted});

  final bool onboardingCompleted;

  @override
  ConsumerState<SticksyApp> createState() => _SticksyAppState();
}

class _SticksyAppState extends ConsumerState<SticksyApp> {
  // Built exactly once. The previous version called buildRouter() inside
  // build(), handing MaterialApp.router a brand-new GoRouter on every frame —
  // which resets navigation state and leaks listeners.
  late final GoRouter _router = AppRouter.buildRouter();

  late bool _onboardingCompleted = widget.onboardingCompleted;

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_onboardingCompleted) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Sticksy',
        theme: AppTheme.darkTheme,
        home: OnboardingScreen(
          onComplete: () => setState(() => _onboardingCompleted = true),
        ),
      );
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Sticksy',
      theme: AppTheme.darkTheme,
      routerConfig: _router,
      builder: (context, child) {
        // Pin text scaling to a sane range: a 2x system font wrecks the
        // fixed-size sticker canvas and toolbars.
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale.clamp(0.85, 1.25)),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
