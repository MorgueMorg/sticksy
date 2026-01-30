import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/di/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final envResult = await EnvConfigLoader.load();
  runApp(
    ProviderScope(
      overrides: [
        envLoadResultProvider.overrideWithValue(envResult),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, child) => StickerForgeApp(envResult: envResult),
      ),
    ),
  );
}
