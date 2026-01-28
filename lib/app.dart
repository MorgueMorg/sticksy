import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_router.dart';
import 'core/config/app_theme.dart';
import 'core/config/env.dart';
import 'core/widgets/glass_card.dart';
import 'core/widgets/gradient_scaffold.dart';

class StickerForgeApp extends ConsumerStatefulWidget {
  const StickerForgeApp({super.key, required this.envResult});

  final EnvLoadResult envResult;

  @override
  ConsumerState<StickerForgeApp> createState() => _StickerForgeAppState();
}

class _StickerForgeAppState extends ConsumerState<StickerForgeApp> {
  bool _allowWithoutAi = false;

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

    final router = AppRouter.buildRouter();
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Sticker Forge',
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
      appBar: AppBar(
        title: const Text('Sticker Forge'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Missing environment configuration',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  envResult.errorMessage ??
                      'Create a .env file based on .env.example and add the '
                          'OpenRouter configuration.',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                if (missing.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: missing
                        .map(
                          (key) => Chip(
                            label: Text(key),
                            backgroundColor:
                                Theme.of(context).colorScheme.surface,
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.offline_bolt),
                  label: const Text('Continue without AI'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Restart the app after updating .env to enable AI tools.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
