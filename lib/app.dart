import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/config/app_router.dart';
import 'core/config/app_theme.dart';
import 'core/config/env.dart';
import 'core/config/onboarding_storage.dart' as onboarding_storage;
import 'core/widgets/glass_card.dart';
import 'core/widgets/gradient_scaffold.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';

class SticksyApp extends ConsumerStatefulWidget {
  const SticksyApp({super.key, required this.envResult});

  final EnvLoadResult envResult;

  @override
  ConsumerState<SticksyApp> createState() => _SticksyAppState();
}

class _SticksyAppState extends ConsumerState<SticksyApp> {
  bool _allowWithoutAi = false;
  bool? _onboardingCompleted;
  bool _loadingOnboarding = true;

  @override
  void initState() {
    super.initState();
    _loadOnboarding();
  }

  Future<void> _loadOnboarding() async {
    final completed = await onboarding_storage.getOnboardingCompleted();
    if (mounted) {
      setState(() {
        _onboardingCompleted = completed;
        _loadingOnboarding = false;
      });
    }
  }

  void _onOnboardingComplete() {
    setState(() => _onboardingCompleted = true);
  }

  @override
  Widget build(BuildContext context) {
    final envResult = widget.envResult;
    if (!envResult.isValid && !_allowWithoutAi) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: EnvErrorScreen(
          envResult: envResult,
          onContinue: () => setState(() => _allowWithoutAi = true),
        ),
      );
    }

    if (_loadingOnboarding) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const GradientScaffold(
          body: Center(child: CupertinoActivityIndicator()),
        ),
      );
    }

    if (_onboardingCompleted != true) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: OnboardingScreen(onComplete: _onOnboardingComplete),
      );
    }

    final router = AppRouter.buildRouter();
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Sticksy',
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}

class EnvErrorScreen extends StatelessWidget {
  const EnvErrorScreen({
    super.key,
    required this.envResult,
    required this.onContinue,
  });

  final EnvLoadResult envResult;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final missing = envResult.missingKeys;
    return GradientScaffold(
      appBar: AppBar(title: const Text('Sticksy'), centerTitle: true),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520.w),
          child: GlassCard(
            padding: EdgeInsets.all(24.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Missing environment configuration',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  envResult.errorMessage ??
                      'Create a .env file based on .env.example and add the '
                          'OpenRouter configuration.',
                  style: const TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 16.h),
                if (missing.isNotEmpty)
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: missing
                        .map(
                          (key) => Chip(
                            label: Text(key),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                          ),
                        )
                        .toList(),
                  ),
                SizedBox(height: 20.h),
                CupertinoButton(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  borderRadius: BorderRadius.circular(14.r),
                  color: const Color(0xFF2C2C2E),
                  onPressed: onContinue,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.bolt_slash, size: 20.r),
                      SizedBox(width: 8.w),
                      const Text('Continue without AI'),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Restart the app after updating .env to enable AI tools.',
                  style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
