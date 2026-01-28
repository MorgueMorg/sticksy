import 'dart:io';
import 'dart:math' as math;

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
        title: const Text('Sticker Pack'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () => _showExportSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddStickerSheet(context, ref),
          ),
        ],
      ),
      body: packAsync.when(
        data: (pack) {
          if (pack == null) {
            return const Center(child: Text('Pack not found'));
          }
          return stickersAsync.when(
            data: (stickers) => _PackDetailBody(
              pack: pack,
              stickers: stickers,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Failed to load stickers: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Pack error: $error')),
      ),
    );
  }

  void _showAddStickerSheet(BuildContext context, WidgetRef ref) {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add Sticker'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                final file =
                    await picker.pickImage(source: ImageSource.camera);
                if (file == null) return;
                if (context.mounted) Navigator.of(context).pop();
                _openEditor(context, initialImagePath: file.path);
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final file =
                    await picker.pickImage(source: ImageSource.gallery);
                if (file == null) return;
                if (context.mounted) Navigator.of(context).pop();
                _openEditor(context, initialImagePath: file.path);
              },
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _openEditor(context);
              },
              icon: const Icon(Icons.draw),
              label: const Text('Blank Canvas'),
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
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pack.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '${pack.stickerCount} stickers • '
                '${_formatBytes(pack.totalSize)}',
              ),
              const SizedBox(height: 6),
              Text(
                'Updated ${_formatDate(pack.updatedAt)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Stickers',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (stickers.isEmpty)
          GlassCard(
            child: Column(
              children: const [
                Icon(Icons.auto_awesome, size: 28),
                SizedBox(height: 8),
                Text('No stickers yet. Tap + to add one.'),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Sticker Actions'),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Sticker name'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                await ref
                    .read(stickerRepositoryProvider)
                    .renameSticker(sticker.id, name);
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.save),
              label: const Text('Save Name'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await ref
                    .read(packRepositoryProvider)
                    .setCoverSticker(pack.id, sticker.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.photo),
              label: const Text('Set as Cover'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await Share.shareXFiles([XFile(sticker.filePath)]);
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.share),
              label: const Text('Share Sticker'),
            ),
            TextButton.icon(
              onPressed: () async {
                await ref
                    .read(stickerRepositoryProvider)
                    .deleteSticker(sticker.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Sticker'),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Export Pack'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _export(
              context,
              ref,
              packAsync,
              stickersAsync,
              PackExportType.zip,
            ),
            icon: const Icon(Icons.archive),
            label: const Text('ZIP Archive'),
          ),
          OutlinedButton.icon(
            onPressed: () => _export(
              context,
              ref,
              packAsync,
              stickersAsync,
              PackExportType.whatsapp,
            ),
            icon: const Icon(Icons.chat),
            label: const Text('WhatsApp Pack'),
          ),
          OutlinedButton.icon(
            onPressed: () => _export(
              context,
              ref,
              packAsync,
              stickersAsync,
              PackExportType.telegram,
            ),
            icon: const Icon(Icons.send),
            label: const Text('Telegram Pack'),
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
