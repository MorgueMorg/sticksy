import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di/providers.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../shared/data/services/storage_services.dart';
import '../../editor/presentation/sticker_editor_screen.dart';
import '../domain/models.dart';

class PackDetailScreen extends ConsumerWidget {
  const PackDetailScreen({super.key, required this.packId});

  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packAsync = ref.watch(packSummaryProvider(packId));
    final stickersAsync = ref.watch(stickersForPackProvider(packId));
    return GradientScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Sticker Pack'),
        actions: [
          CupertinoButton(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            onPressed: () => _showExportSheet(context, ref),
            child: const Icon(CupertinoIcons.share, color: CupertinoColors.white),
          ),
          CupertinoButton(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            onPressed: () => _showAddStickerSheet(context, ref),
            child: const Icon(CupertinoIcons.add, color: CupertinoColors.white),
          ),
        ],
      ),
      body: packAsync.when(
        data: (pack) {
          if (pack == null) {
            return const Center(
              child: Text('Pack not found', style: TextStyle(color: Color(0xFF8E8E93))),
            );
          }
          return stickersAsync.when(
            data: (stickers) => _PackDetailBody(
              pack: pack,
              stickers: stickers,
            ),
            loading: () => const Center(child: CupertinoActivityIndicator(color: CupertinoColors.white)),
            error: (error, _) =>
                Center(child: Text('Failed to load stickers: $error', style: const TextStyle(color: Color(0xFF8E8E93)))),
          );
        },
        loading: () => const Center(child: CupertinoActivityIndicator(color: CupertinoColors.white)),
        error: (error, _) => Center(child: Text('Pack error: $error', style: const TextStyle(color: Color(0xFF8E8E93)))),
      ),
    );
  }

  void _showAddStickerSheet(BuildContext context, WidgetRef ref) {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Sticker',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: CupertinoColors.white),
            ),
            SizedBox(height: 16.h),
            CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              borderRadius: BorderRadius.circular(14.r),
              color: const Color(0xFF2C2C2E),
              onPressed: () async {
                final file = await picker.pickImage(source: ImageSource.camera);
                if (file == null) return;
                if (context.mounted) Navigator.of(context).pop();
                _openEditor(context, initialImagePath: file.path);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.camera),
                  SizedBox(width: 8.w),
                  const Text('Camera'),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              borderRadius: BorderRadius.circular(14.r),
              color: const Color(0xFF2C2C2E),
              onPressed: () async {
                final file = await picker.pickImage(source: ImageSource.gallery);
                if (file == null) return;
                if (context.mounted) Navigator.of(context).pop();
                _openEditor(context, initialImagePath: file.path);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.photo),
                  SizedBox(width: 8.w),
                  const Text('Gallery'),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              onPressed: () {
                Navigator.of(context).pop();
                _openEditor(context);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.pencil),
                  SizedBox(width: 8.w),
                  const Text('Blank Canvas'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PackExportSheet(packId: packId),
    );
  }

  void _openEditor(
    BuildContext context, {
    String? initialImagePath,
  }) {
    context.push(
      '/editor',
      extra: StickerEditorArgs(
        packId: packId,
        initialImagePath: initialImagePath,
      ),
    );
  }
}

class _PackDetailBody extends StatelessWidget {
  const _PackDetailBody({
    required this.pack,
    required this.stickers,
  });

  final PackSummary pack;
  final List<StickerItem> stickers;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
      children: [
        GlassCard(
          padding: EdgeInsets.all(20.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pack.name,
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '${pack.stickerCount} stickers • ${_formatBytes(pack.totalSize)}',
                style: TextStyle(color: const Color(0xFF8E8E93), fontSize: 14.sp),
              ),
              SizedBox(height: 6.h),
              Text(
                'Updated ${_formatDate(pack.updatedAt)}',
                style: TextStyle(color: const Color(0xFF8E8E93), fontSize: 12.sp),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          'Stickers',
          style: TextStyle(
            color: CupertinoColors.white,
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        if (stickers.isEmpty)
          GlassCard(
            padding: EdgeInsets.all(24.r),
            child: Column(
              children: [
                Icon(CupertinoIcons.smiley, size: 32.r, color: const Color(0xFF8E8E93)),
                SizedBox(height: 12.h),
                const Text(
                  'No stickers yet. Tap + to add one.',
                  style: TextStyle(color: Color(0xFF8E8E93)),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            itemCount: stickers.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12.h,
              crossAxisSpacing: 12.w,
            ),
            itemBuilder: (context, index) {
              final sticker = stickers[index];
              return _StickerTile(sticker: sticker, pack: pack);
            },
          ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (bytes == 0) ? 0 : (math.log(bytes) / math.log(1024)).floor();
    final size = (bytes / math.pow(1024, i)).toStringAsFixed(1);
    return '$size ${suffixes[i]}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }
}

class _StickerTile extends ConsumerWidget {
  const _StickerTile({required this.sticker, required this.pack});

  final StickerItem sticker;
  final PackSummary pack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push(
        '/editor',
        extra: StickerEditorArgs(
          packId: sticker.packId,
          stickerId: sticker.id,
        ),
      ),
      onLongPress: () => _showStickerActions(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: GlassCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.r),
                child: Image.file(
                  File(sticker.filePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            sticker.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF8E8E93),
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  void _showStickerActions(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: sticker.name);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sticker Actions',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: CupertinoColors.white),
            ),
            SizedBox(height: 16.h),
            CupertinoTextField(
              controller: nameController,
              placeholder: 'Sticker name',
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(12.r),
              ),
              style: const TextStyle(color: CupertinoColors.white),
            ),
            SizedBox(height: 12.h),
            CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              borderRadius: BorderRadius.circular(14.r),
              color: const Color(0xFF2C2C2E),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                await ref.read(stickerRepositoryProvider).renameSticker(sticker.id, name);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Save Name'),
            ),
            CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              onPressed: () async {
                await ref.read(packRepositoryProvider).setCoverSticker(pack.id, sticker.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Set as Cover'),
            ),
            CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              onPressed: () async {
                await Share.shareXFiles([XFile(sticker.filePath)]);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Share Sticker'),
            ),
            CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              onPressed: () async {
                await ref.read(stickerRepositoryProvider).deleteSticker(sticker.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Delete Sticker', style: TextStyle(color: CupertinoColors.destructiveRed)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackExportSheet extends ConsumerWidget {
  const _PackExportSheet({required this.packId});

  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packAsync = ref.watch(packSummaryProvider(packId));
    final stickersAsync = ref.watch(stickersForPackProvider(packId));
    return GlassCard(
      padding: EdgeInsets.all(24.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Export Pack',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: CupertinoColors.white),
          ),
          SizedBox(height: 16.h),
          CupertinoButton(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            borderRadius: BorderRadius.circular(14.r),
            color: const Color(0xFF2C2C2E),
            onPressed: () => _export(context, ref, packAsync, stickersAsync, PackExportType.zip),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.archivebox),
                SizedBox(width: 8.w),
                const Text('ZIP Archive'),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          CupertinoButton(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            borderRadius: BorderRadius.circular(14.r),
            color: const Color(0xFF2C2C2E),
            onPressed: () => _export(context, ref, packAsync, stickersAsync, PackExportType.whatsapp),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.chat_bubble_2),
                SizedBox(width: 8.w),
                const Text('WhatsApp Pack'),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          CupertinoButton(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            borderRadius: BorderRadius.circular(14.r),
            color: const Color(0xFF2C2C2E),
            onPressed: () => _export(context, ref, packAsync, stickersAsync, PackExportType.telegram),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.paperplane),
                SizedBox(width: 8.w),
                const Text('Telegram Pack'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<PackSummary?> packAsync,
    AsyncValue<List<StickerItem>> stickersAsync,
    PackExportType type,
  ) async {
    final pack = packAsync.value;
    final stickers = stickersAsync.value ?? [];
    if (pack == null || stickers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pack has no stickers to export.')),
      );
      return;
    }
    try {
      final exporter = ref.read(packExportServiceProvider);
      final file = await exporter.exportPack(
        pack: pack,
        stickers: stickers,
        type: type,
      );
      await Share.shareXFiles([XFile(file.path)]);
      if (context.mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    }
  }
}
