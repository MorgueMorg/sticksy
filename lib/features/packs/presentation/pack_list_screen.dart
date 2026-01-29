import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:sticksy/features/settings/presentation/settings.dart';
import 'package:uuid/uuid.dart';

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
        title: const Text('Sticksy'),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (context) => SettingsScreen()));
            },
            child: const Icon(
              CupertinoIcons.settings,
              color: CupertinoColors.white,
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24, right: 20),
        child: FloatingActionButton.extended(
          onPressed: () => _showCreatePackSheet(context, ref),
          backgroundColor: const Color(0xFF2C2C2E),
          elevation: 0,
          icon: const Icon(CupertinoIcons.add, color: CupertinoColors.white),
          label: const Text(
            'New Pack',
            style: TextStyle(
              color: CupertinoColors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
      body: packsAsync.when(
        data: (packs) => packs.isEmpty
            ? _EmptyState(onCreate: () => _showCreatePackSheet(context, ref))
            : _PackList(
                packs: packs,
                onReorder: (ids) =>
                    ref.read(packRepositoryProvider).reorderPacks(ids),
              ),
        loading: () => const Center(
          child: CupertinoActivityIndicator(color: CupertinoColors.white),
        ),
        error: (error, _) => Center(
          child: Text(
            'Failed to load packs: $error',
            style: const TextStyle(color: Color(0xFF8E8E93)),
          ),
        ),
      ),
    );
  }

  void _showCreatePackSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _CreatePackSheetContent(
          onCreate: (name, coverPath) => _createPackWithCover(context, ref, name, coverPath),
        ),
      ),
    );
  }

  Future<void> _createPackWithCover(
    BuildContext context,
    WidgetRef ref,
    String name,
    String? coverPath,
  ) async {
    final packId = await ref.read(packRepositoryProvider).createPack(name);
    if (coverPath != null && context.mounted) {
      final stickerId = await createCoverStickerFromFile(ref, packId, coverPath);
      if (stickerId != null) {
        await ref.read(packRepositoryProvider).setCoverSticker(packId, stickerId);
      }
    }
    if (context.mounted) Navigator.of(context).pop();
  }
}

Future<String?> createCoverStickerFromFile(
  WidgetRef ref,
  String packId,
  String filePath,
) async {
  try {
    final bytes = await File(filePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final pngBytes = Uint8List.fromList(img.encodePng(decoded));
    const uuid = Uuid();
    final stickerId = uuid.v4();
    final storage = ref.read(storageServiceProvider);
    final filePathSaved = await storage.saveStickerBytes(
      packId: packId,
      stickerId: stickerId,
      extension: 'png',
      bytes: pngBytes,
    );
    await ref.read(stickerRepositoryProvider).createSticker(
      id: stickerId,
      packId: packId,
      name: 'Cover',
      filePath: filePathSaved,
      width: decoded.width,
      height: decoded.height,
      format: StickerFormat.png,
      fileSize: pngBytes.length,
    );
    return stickerId;
  } catch (_) {
    return null;
  }
}

class _CreatePackSheetContent extends StatefulWidget {
  const _CreatePackSheetContent({
    required this.onCreate,
  });

  final void Function(String name, String? coverPath) onCreate;

  @override
  State<_CreatePackSheetContent> createState() => _CreatePackSheetContentState();
}

class _CreatePackSheetContentState extends State<_CreatePackSheetContent> {
  final _nameController = TextEditingController();
  String? _coverPath;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickCover(ImageSource source) async {
    final file = await _picker.pickImage(source: source);
    if (file != null && mounted) setState(() => _coverPath = file.path);
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create Sticker Pack',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
            ),
          ),
          const SizedBox(height: 16),
          CupertinoTextField(
            controller: _nameController,
            placeholder: 'Pack name',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(12),
            ),
            style: const TextStyle(color: CupertinoColors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'Cover photo (optional)',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          if (_coverPath != null) ...[
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_coverPath!),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _coverPath = null),
                    child: const Text('Remove', style: TextStyle(color: CupertinoColors.destructiveRed)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(12),
                onPressed: () => _pickCover(ImageSource.gallery),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.photo, size: 20),
                    SizedBox(width: 8),
                    Text('Gallery'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(12),
                onPressed: () => _pickCover(ImageSource.camera),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.camera, size: 20),
                    SizedBox(width: 8),
                    Text('Camera'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 14),
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF2C2C2E),
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;
              widget.onCreate(name, _coverPath);
            },
            child: const Text('Create'),
          ),
        ],
      ),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
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
      padding: const EdgeInsets.all(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/pack/${pack.id}'),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              _PackCover(coverId: coverId),
              const SizedBox(width: 16),
              Expanded(
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
                    const SizedBox(height: 6),
                    Text(
                      '${pack.stickerCount} stickers • ${_formatBytes(pack.totalSize)}',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => _showPackActions(context, ref, pack),
                child: const Icon(
                  CupertinoIcons.ellipsis,
                  color: CupertinoColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPackActions(BuildContext context, WidgetRef ref, PackSummary pack) {
    final controller = TextEditingController(text: pack.name);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Consumer(
          builder: (context, ref, _) {
            return GlassCard(
              padding: const EdgeInsets.all(24),
              child: _PackActionsSheetContent(
                pack: pack,
                nameController: controller,
              ),
            );
          },
        ),
      ),
    ).then((_) => controller.dispose());
  }
}

class _PackActionsSheetContent extends ConsumerWidget {
  const _PackActionsSheetContent({
    required this.pack,
    required this.nameController,
  });

  final PackSummary pack;
  final TextEditingController nameController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stickersAsync = ref.watch(stickersForPackProvider(pack.id));
    final picker = ImagePicker();
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pack Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
            ),
          ),
          const SizedBox(height: 16),
          CupertinoTextField(
            controller: nameController,
            placeholder: 'Pack name',
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
              await ref.read(packRepositoryProvider).renamePack(pack.id, name);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save Name'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Cover photo',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(12),
                onPressed: () async {
                  final file = await picker.pickImage(source: ImageSource.gallery);
                  if (file == null || !context.mounted) return;
                  final stickerId = await createCoverStickerFromFile(ref, pack.id, file.path);
                  if (stickerId != null && context.mounted) {
                    await ref.read(packRepositoryProvider).setCoverSticker(pack.id, stickerId);
                    if (context.mounted) Navigator.of(context).pop();
                  }
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.photo, size: 20),
                    SizedBox(width: 8),
                    Text('Gallery'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(12),
                onPressed: () async {
                  final file = await picker.pickImage(source: ImageSource.camera);
                  if (file == null || !context.mounted) return;
                  final stickerId = await createCoverStickerFromFile(ref, pack.id, file.path);
                  if (stickerId != null && context.mounted) {
                    await ref.read(packRepositoryProvider).setCoverSticker(pack.id, stickerId);
                    if (context.mounted) Navigator.of(context).pop();
                  }
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.camera, size: 20),
                    SizedBox(width: 8),
                    Text('Camera'),
                  ],
                ),
              ),
            ],
          ),
          stickersAsync.when(
            data: (stickers) {
              if (stickers.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Or choose from pack',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: stickers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final sticker = stickers[index];
                      final isCover = pack.coverStickerId == sticker.id;
                      return GestureDetector(
                        onTap: () async {
                          await ref.read(packRepositoryProvider).setCoverSticker(pack.id, sticker.id);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: isCover
                                ? Border.all(color: CupertinoColors.activeBlue, width: 2)
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(sticker.filePath),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          if (pack.coverStickerId != null) ...[
            const SizedBox(height: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 10),
              onPressed: () async {
                await ref.read(packRepositoryProvider).setCoverSticker(pack.id, null);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Remove cover', style: TextStyle(color: CupertinoColors.destructiveRed)),
            ),
          ],
          const SizedBox(height: 16),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 14),
            onPressed: () async {
              await ref.read(packRepositoryProvider).duplicatePack(pack.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Duplicate Pack'),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 14),
            onPressed: () async {
              await ref.read(packRepositoryProvider).deletePack(pack.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text(
              'Delete Pack',
              style: TextStyle(color: CupertinoColors.destructiveRed),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB'];
  final i = (bytes == 0) ? 0 : (math.log(bytes) / math.log(1024)).floor();
  final size = (bytes / math.pow(1024, i)).toStringAsFixed(1);
  return '$size ${suffixes[i]}';
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
          borderRadius: BorderRadius.circular(14),
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
        color: CupertinoColors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        CupertinoIcons.photo,
        color: Color(0xFF8E8E93),
        size: 28,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  CupertinoIcons.collections_solid,
                  size: 40,
                  color: CupertinoColors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Create your first sticker pack',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF2C2C2E),
                onPressed: onCreate,
                child: const Text('Start a Pack'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
