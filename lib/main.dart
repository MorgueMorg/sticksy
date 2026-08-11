import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app.dart';
import 'core/config/ai_settings.dart';
import 'core/config/app_colors.dart';
import 'core/config/onboarding_storage.dart';
import 'core/di/providers.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // A red-on-grey Flutter error screen in a release build reads as a crash.
      // Show something calm instead, and keep the details in the log.
      ErrorWidget.builder = (details) {
        if (kDebugMode) return ErrorWidget(details.exception);
        return const _FriendlyErrorScreen();
      };
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('[Sticksy] Flutter error: ${details.exceptionAsString()}');
      };
      WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
        debugPrint('[Sticksy] Uncaught: $error\n$stack');
        return true;
      };

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.bg,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );

      // Both reads are wrapped internally and fall back to defaults, so a
      // corrupt preference store can never block launch.
      final aiSettings = await AiSettingsStore().load();
      final onboardingDone = await getOnboardingCompleted();

      runApp(
        ProviderScope(
          overrides: [
            initialAiSettingsProvider.overrideWithValue(aiSettings),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (_, __) =>
                SticksyApp(onboardingCompleted: onboardingDone),
          ),
        ),
      );
    },
    (error, stack) {
      debugPrint('[Sticksy] Zone error: $error\n$stack');
    },
  );
}

class _FriendlyErrorScreen extends StatelessWidget {
  const _FriendlyErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.bg,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('😵‍💫', style: TextStyle(fontSize: 44)),
              SizedBox(height: 16),
              Text(
                'This bit hiccuped',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Go back and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
