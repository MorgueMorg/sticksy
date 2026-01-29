import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onPressed: () => _showExportSheet(context, ref),
            child: const Icon(CupertinoIcons.share, color: CupertinoColors.white),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add Sticker',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: CupertinoColors.white),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF2C2C2E),
              onPressed: () async {
                final file = await picker.pickImage(source: ImageSource.camera);
                if (file == null) return;
                if (context.mounted) Navigator.of(context).pop();
                _openEditor(context, initialImagePath: file.path);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.camera),
                  SizedBox(width: 8),
                  Text('Camera'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF2C2C2E),
              onPressed: () async {
                final file = await picker.pickImage(source: ImageSource.gallery);
                if (file == null) return;
                if (context.mounted) Navigator.of(context).pop();
                _openEditor(context, initialImagePath: file.path);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.photo),
                  SizedBox(width: 8),
                  Text('Gallery'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: () {
                Navigator.of(context).pop();
                _openEditor(context);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.pencil),
                  SizedBox(width: 8),
                  Text('Blank Canvas'),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pack.name,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${pack.stickerCount} stickers • ${_formatBytes(pack.totalSize)}',
                style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                'Updated ${_formatDate(pack.updatedAt)}',
                style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Stickers',
          style: TextStyle(
            color: CupertinoColors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (stickers.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: const [
                Icon(CupertinoIcons.smiley, size: 32, color: Color(0xFF8E8E93)),
                SizedBox(height: 12),
                Text(
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
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
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.file(
            File(sticker.filePath),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  void _showStickerActions(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: sticker.name);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sticker Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: CupertinoColors.white),
            ),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: nameController,
              placeholder: 'Sticker name',
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(12),
              ),
              style: const TextStyle(color: CupertinoColors.white),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(14),
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
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: () async {
                await ref.read(packRepositoryProvider).setCoverSticker(pack.id, sticker.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Set as Cover'),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: () async {
                await Share.shareXFiles([XFile(sticker.filePath)]);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Share Sticker'),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Export Pack',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: CupertinoColors.white),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 14),
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF2C2C2E),
            onPressed: () => _export(context, ref, packAsync, stickersAsync, PackExportType.zip),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.archivebox),
                SizedBox(width: 8),
                Text('ZIP Archive'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 14),
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF2C2C2E),
            onPressed: () => _export(context, ref, packAsync, stickersAsync, PackExportType.whatsapp),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.chat_bubble_2),
                SizedBox(width: 8),
                Text('WhatsApp Pack'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 14),
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF2C2C2E),
            onPressed: () => _export(context, ref, packAsync, stickersAsync, PackExportType.telegram),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.paperplane),
                SizedBox(width: 8),
                Text('Telegram Pack'),
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
