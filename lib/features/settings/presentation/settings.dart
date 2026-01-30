import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sticksy/core/di/providers.dart';
import 'package:sticksy/core/widgets/glass_card.dart';
import 'package:sticksy/core/widgets/stick_btn.dart';
import 'package:sticksy/features/settings/domain/settings_logic.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Image.asset('assets/icons/set.png', width: 150, height: 150),
              StickBtn(
                onTap: () {
                  stickWbLnch(context, StickSetUrl.setone);
                },
                child: SizedBox(
                  width: double.infinity,
                  child: GlassCard(child: Text("Privacy Policy")),
                ),
              ),
              SizedBox(height: 10),
              StickBtn(
                onTap: () {
                  stickWbLnch(context, StickSetUrl.settwo);
                },
                child: SizedBox(
                  width: double.infinity,
                  child: GlassCard(child: Text("Terms of Use")),
                ),
              ),
              SizedBox(height: 10),
              StickBtn(
                onTap: () {
                  stickWbLnch(context, StickSetUrl.setthree);
                },
                child: SizedBox(
                  width: double.infinity,
                  child: GlassCard(child: Text("Support")),
                ),
              ),
              SizedBox(height: 10),
              StickBtn(
                onTap: () => _showCacheSheet(context, ref),
                child: SizedBox(
                  width: double.infinity,
                  child: GlassCard(child: Text("Clear Cache")),
                ),
              ),
              Spacer(),
              Text(
                "Made with ❤️",
                style: TextStyle(color: CupertinoColors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showCacheSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _SettingsSheet(onCleared: () => _showCacheClearedDialog(context)),
  );
}

void _showCacheClearedDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF2ED47A).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: Color(0xFF2ED47A),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Cache cleared',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Temporary files have been removed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 14),
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF2C2C2E),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet({required this.onCleared});

  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: FutureBuilder<int>(
        future: ref.read(cacheServiceProvider).getCacheSize(),
        builder: (context, snapshot) {
          final size = snapshot.data ?? 0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Storage & Cache',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Cache size: ${_formatBytes(size)}',
                style: const TextStyle(color: Color(0xFF8E8E93)),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 14),
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF2C2C2E),
                onPressed: () async {
                  await ref.read(cacheServiceProvider).clearCache();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  onCleared();
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.trash),
                    SizedBox(width: 8),
                    Text('Clear Cache'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (bytes == 0) ? 0 : (math.log(bytes) / math.log(1024)).floor();
    final size = (bytes / math.pow(1024, i)).toStringAsFixed(1);
    return '$size ${suffixes[i]}';
  }
}
