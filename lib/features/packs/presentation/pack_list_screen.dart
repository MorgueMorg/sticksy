import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../domain/models.dart';

class PackListScreen extends ConsumerWidget {
  const PackListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsAsync = ref.watch(packSummariesProvider);
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Sticker Forge'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePackSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Pack'),
      ),
      body: packsAsync.when(
        data: (packs) => packs.isEmpty
            ? _EmptyState(onCreate: () => _showCreatePackSheet(context, ref))
            : _PackList(
                packs: packs,
                onReorder: (ids) => ref
                    .read(packRepositoryProvider)
                    .reorderPacks(ids),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Failed to load packs: $error'),
        ),
      ),
    );
  }

  void _showCreatePackSheet(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Create Sticker Pack'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Pack name'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                await ref.read(packRepositoryProvider).createPack(name);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _SettingsSheet(),
    );
  }
}

class _PackList extends StatefulWidget {
  const _PackList({required this.packs, required this.onReorder});

  final List<PackSummary> packs;
  final ValueChanged<List<String>> onReorder;

  @override
  State<_PackList> createState() => _PackListState();
}

class _PackListState extends State<_PackList> {
  late List<PackSummary> _packs;

  @override
  void initState() {
    super.initState();
    _packs = [...widget.packs];
  }

  @override
  void didUpdateWidget(covariant _PackList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _packs = [...widget.packs];
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _packs.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = _packs.removeAt(oldIndex);
          _packs.insert(newIndex, item);
        });
        widget.onReorder(_packs.map((pack) => pack.id).toList());
      },
      itemBuilder: (context, index) {
        final pack = _packs[index];
        return Padding(
          key: ValueKey(pack.id),
          padding: const EdgeInsets.only(bottom: 12),
          child: _PackCard(pack: pack),
        );
      },
    );
  }
}

class _PackCard extends ConsumerWidget {
  const _PackCard({required this.pack});

  final PackSummary pack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverId = pack.coverStickerId;
    return GlassCard(
      child: InkWell(
        onTap: () => context.go('/pack/${pack.id}'),
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            _PackCover(coverId: coverId),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pack.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '${pack.stickerCount} stickers • '
                    '${_formatBytes(pack.totalSize)}',
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _showPackActions(context, ref, pack),
            ),
          ],
        ),
      ),
    );
  }

  void _showPackActions(
    BuildContext context,
    WidgetRef ref,
    PackSummary pack,
  ) {
    final controller = TextEditingController(text: pack.name);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Pack Actions'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Rename pack'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                await ref.read(packRepositoryProvider).renamePack(pack.id, name);
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Name'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(packRepositoryProvider).duplicatePack(pack.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.copy),
              label: const Text('Duplicate Pack'),
            ),
            TextButton.icon(
              onPressed: () async {
                await ref.read(packRepositoryProvider).deletePack(pack.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Pack'),
            ),
          ],
        ),
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

class _PackCover extends ConsumerWidget {
  const _PackCover({required this.coverId});

  final String? coverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (coverId == null) {
      return _placeholder();
    }
    final stickerAsync = ref.watch(stickerByIdProvider(coverId!));
    return stickerAsync.when(
      data: (sticker) {
        if (sticker == null) return _placeholder();
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            File(sticker.filePath),
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        );
      },
      loading: () => _placeholder(),
      error: (_, __) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.photo, color: Colors.white54),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.collections_bookmark, size: 36),
            const SizedBox(height: 12),
            const Text('Create your first sticker pack'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onCreate,
              child: const Text('Start a Pack'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      child: FutureBuilder<int>(
        future: ref.read(cacheServiceProvider).getCacheSize(),
        builder: (context, snapshot) {
          final size = snapshot.data ?? 0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Storage & Cache'),
              const SizedBox(height: 12),
              Text('Cache size: ${_formatBytes(size)}'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await ref.read(cacheServiceProvider).clearCache();
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Clear Cache'),
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
