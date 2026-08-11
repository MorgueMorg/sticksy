import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/settings_logic.dart';
import 'ai_settings_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiSettings = ref.watch(aiSettingsProvider);

    return GradientScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 40.h),
        children: [
          const SectionLabel('Artificial intelligence'),
          GlassCard(
            tint: AppColors.success,
            padding: EdgeInsets.all(18.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42.r,
                      height: 42.r,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.pink, AppColors.violet],
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Icon(
                        CupertinoIcons.wand_stars,
                        color: Colors.white,
                        size: 22.r,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            aiSettings.isFreeTier
                                ? 'Free mode'
                                : aiSettings.provider.toString(),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            aiSettings.isFreeTier
                                ? 'Works with no key · tap to upgrade quality'
                                : aiSettings.resolvedImageModel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (aiSettings.isConfigured)
                      Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        color: AppColors.success,
                        size: 22.r,
                      ),
                  ],
                ),
                SizedBox(height: 16.h),
                GradientButton(
                  label: aiSettings.isFreeTier
                      ? 'Change provider'
                      : 'Manage connection',
                  icon: CupertinoIcons.link,
                  compact: true,
                  onPressed: () => showAppSheet(
                    context,
                    builder: (_) => const AiSettingsSheet(),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 26.h),

          const SectionLabel('Storage'),
          const _StorageCard(),
          SizedBox(height: 26.h),

          const SectionLabel('About'),
          _LinkTile(
            icon: CupertinoIcons.doc_text,
            label: 'Privacy Policy',
            onTap: () => openExternalUrl(context, StickSetUrl.privacyPolicy),
          ),
          _LinkTile(
            icon: CupertinoIcons.checkmark_shield,
            label: 'Terms of Use',
            onTap: () => openExternalUrl(context, StickSetUrl.termsOfUse),
          ),
          _LinkTile(
            icon: CupertinoIcons.chat_bubble_2,
            label: 'Contact support',
            onTap: () => openExternalUrl(context, StickSetUrl.support),
          ),
          SizedBox(height: 32.h),
          Center(
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: AppColors.brandGradient,
                  ).createShader(bounds),
                  child: Text(
                    'Sticksy',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Made for people who over-communicate',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageCard extends ConsumerStatefulWidget {
  const _StorageCard();

  @override
  ConsumerState<_StorageCard> createState() => _StorageCardState();
}

class _StorageCardState extends ConsumerState<_StorageCard> {
  int? _cacheBytes;
  int? _libraryBytes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final cache = await ref.read(cacheServiceProvider).getCacheSize();
    final library = await ref.read(storageServiceProvider).usedBytes();
    if (!mounted) return;
    setState(() {
      _cacheBytes = cache;
      _libraryBytes = library;
    });
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    await ref.read(cacheServiceProvider).clearCache();
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    showAppSnack(context, 'Temporary files cleared');
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.all(18.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Your stickers',
                  value: _libraryBytes == null
                      ? '—'
                      : formatBytes(_libraryBytes!),
                  color: AppColors.cyan,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Temporary files',
                  value:
                      _cacheBytes == null ? '—' : formatBytes(_cacheBytes!),
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SoftButton(
            label: _busy ? 'Clearing…' : 'Clear temporary files',
            icon: CupertinoIcons.trash,
            onPressed: _busy ? null : _clear,
          ),
          SizedBox(height: 10.h),
          Text(
            'Only exports and scratch files are removed. Your saved stickers '
            'stay untouched.',
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          label,
          style: TextStyle(fontSize: 11.sp, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: PressFx(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19.r, color: AppColors.textSecondary),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 15.r,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
