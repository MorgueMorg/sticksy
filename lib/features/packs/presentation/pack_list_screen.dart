import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/models.dart';

class PackListScreen extends ConsumerWidget {
  const PackListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsAsync = ref.watch(filteredPackSummariesProvider);
    final query = ref.watch(packSearchQueryProvider);
    final hasAnyPack =
        ref.watch(packSummariesProvider).value?.isNotEmpty ?? false;

    return GradientScaffold(
      appBar: AppBar(
        titleSpacing: 20,
        centerTitle: false,
        title: const _Wordmark(),
        actions: [
          IconPill(
            icon: CupertinoIcons.settings,
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          SizedBox(width: 20.w),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 12.h, right: 4.w),
        child: GradientButton(
          label: 'New pack',
          icon: CupertinoIcons.add,
          expand: false,
          onPressed: () => _createPack(context, ref),
        ),
      ),
      body: Column(
        children: [
          if (hasAnyPack)
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
              child: _SearchField(
                value: query,
                onChanged: (value) =>
                    ref.read(packSearchQueryProvider.notifier).state = value,
              ),
            ),
          Expanded(
            child: packsAsync.when(
              data: (packs) {
                if (packs.isEmpty && query.isNotEmpty) {
                  return EmptyState(
                    icon: CupertinoIcons.search,
                    title: 'No matches',
                    message: 'No pack called "$query".',
                    colors: const [AppColors.cyan, AppColors.violet],
                  );
                }
                if (packs.isEmpty) {
                  return EmptyState(
                    icon: CupertinoIcons.sparkles,
                    title: 'Make your first pack',
                    message:
                        'Packs hold your stickers. Create one, then generate '
                        'or import stickers into it.',
                    actionLabel: 'Create a pack',
                    onAction: () => _createPack(context, ref),
                  );
                }
                return _PackList(packs: packs);
              },
              loading: () =>
                  const Center(child: CupertinoActivityIndicator(radius: 14)),
              error: (error, _) => EmptyState(
                icon: CupertinoIcons.exclamationmark_triangle,
                title: 'Could not load your packs',
                message: '$error',
                colors: const [AppColors.orange, AppColors.danger],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createPack(BuildContext context, WidgetRef ref) async {
    final name = await promptForText(
      context,
      title: 'New sticker pack',
      hint: 'Cat reactions',
      confirmLabel: 'Create pack',
      maxLength: 40,
    );
    if (name == null) return;
    try {
      final packId = await ref.read(packRepositoryProvider).createPack(name);
      if (!context.mounted) return;
      HapticFeedback.mediumImpact();
      context.go('/pack/$packId');
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, 'Could not create the pack.', isError: true);
      }
    }
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: AppColors.brandGradient,
      ).createShader(bounds),
      child: Text(
        'Sticksy',
        style: TextStyle(
          fontSize: 28.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(fontSize: 15.sp, color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search packs',
        prefixIcon: Icon(
          CupertinoIcons.search,
          size: 18.r,
          color: AppColors.textTertiary,
        ),
        prefixIconConstraints: BoxConstraints(minWidth: 42.w),
      ),
    );
  }
}

class _PackList extends ConsumerStatefulWidget {
  const _PackList({required this.packs});

  final List<PackSummary> packs;

  @override
  ConsumerState<_PackList> createState() => _PackListState();
}

class _PackListState extends ConsumerState<_PackList> {
  late List<PackSummary> _packs = [...widget.packs];

  @override
  void didUpdateWidget(covariant _PackList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _packs = [...widget.packs];
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 110.h),
      itemCount: _packs.length,
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => Transform.scale(
        scale: 1.03,
        child: Opacity(opacity: 0.92, child: child),
      ),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = _packs.removeAt(oldIndex);
          _packs.insert(newIndex, item);
        });
        HapticFeedback.selectionClick();
        ref
            .read(packRepositoryProvider)
            .reorderPacks(_packs.map((pack) => pack.id).toList());
      },
      itemBuilder: (context, index) {
        final pack = _packs[index];
        return Padding(
          key: ValueKey(pack.id),
          padding: EdgeInsets.only(bottom: 14.h),
          child: ReorderableDelayedDragStartListener(
            index: index,
            child: _PackCard(pack: pack),
          ),
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
    final gradient = AppColors.gradientForSeed(pack.id);

    return PressFx(
      onTap: () => context.go('/pack/${pack.id}'),
      onLongPress: () => _showActions(context, ref),
      child: GlassCard(
        padding: EdgeInsets.all(14.r),
        tint: gradient.first,
        child: Row(
          children: [
            _PackCover(coverId: pack.coverStickerId, gradient: gradient),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pack.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: [
                      StatChip(
                        icon: CupertinoIcons.square_grid_2x2,
                        label: pluralise(pack.stickerCount, 'sticker'),
                        color: gradient.first,
                      ),
                      StatChip(
                        label: formatBytes(pack.totalSize),
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Updated ${formatRelativeDate(pack.updatedAt)}',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ),
            IconPill(
              icon: CupertinoIcons.ellipsis,
              tooltip: 'Pack options',
              size: 36,
              onPressed: () => _showActions(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    showAppSheet(
      context,
      builder: (sheetContext) => SheetSurface(
        title: pack.name,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoftButton(
              label: 'Rename',
              icon: CupertinoIcons.pencil,
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                final name = await promptForText(
                  context,
                  title: 'Rename pack',
                  initialValue: pack.name,
                  maxLength: 40,
                );
                if (name == null) return;
                await ref
                    .read(packRepositoryProvider)
                    .renamePack(pack.id, name);
              },
            ),
            SizedBox(height: 10.h),
            SoftButton(
              label: 'Set cover from gallery',
              icon: CupertinoIcons.photo,
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await _pickCover(context, ref);
              },
            ),
            if (pack.coverStickerId != null) ...[
              SizedBox(height: 10.h),
              SoftButton(
                label: 'Remove cover',
                icon: CupertinoIcons.clear,
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await ref
                      .read(packRepositoryProvider)
                      .setCoverSticker(pack.id, null);
                },
              ),
            ],
            SizedBox(height: 10.h),
            SoftButton(
              label: 'Duplicate pack',
              icon: CupertinoIcons.square_on_square,
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await ref.read(packRepositoryProvider).duplicatePack(pack.id);
                if (context.mounted) showAppSnack(context, 'Pack duplicated');
              },
            ),
            SizedBox(height: 10.h),
            SoftButton(
              label: 'Delete pack',
              icon: CupertinoIcons.delete,
              destructive: true,
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                final confirmed = await confirmDialog(
                  context,
                  title: 'Delete "${pack.name}"?',
                  message:
                      'This removes the pack and all ${pluralise(pack.stickerCount, 'sticker')} '
                      'inside it. This cannot be undone.',
                );
                if (!confirmed) return;
                await ref.read(packRepositoryProvider).deletePack(pack.id);
                if (context.mounted) showAppSnack(context, 'Pack deleted');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCover(BuildContext context, WidgetRef ref) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file == null) return;
    final stickerId = await createCoverStickerFromFile(ref, pack.id, file.path);
    if (stickerId == null) {
      if (context.mounted) {
        showAppSnack(context, 'Could not use that image.', isError: true);
      }
      return;
    }
    await ref.read(packRepositoryProvider).setCoverSticker(pack.id, stickerId);
  }
}

class _PackCover extends ConsumerWidget {
  const _PackCover({required this.coverId, required this.gradient});

  final String? coverId;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = coverId;
    if (id == null) return _placeholder();

    return ref.watch(stickerByIdProvider(id)).when(
          data: (sticker) {
            if (sticker == null) return _placeholder();
            return Container(
              width: 72.r,
              height: 72.r,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(20.r),
              ),
              padding: EdgeInsets.all(4.r),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: Image.file(
                  File(sticker.filePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(),
                ),
              ),
            );
          },
          loading: _placeholder,
          error: (_, __) => _placeholder(),
        );
  }

  Widget _placeholder() {
    return Container(
      width: 72.r,
      height: 72.r,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient.map((c) => c.withValues(alpha: 0.35)).toList(),
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Icon(
        CupertinoIcons.square_stack_3d_down_right,
        color: Colors.white.withValues(alpha: 0.85),
        size: 28.r,
      ),
    );
  }
}

/// Imports an arbitrary image as a sticker so it can act as a pack cover.
Future<String?> createCoverStickerFromFile(
  WidgetRef ref,
  String packId,
  String filePath,
) async {
  try {
    final bytes = await File(filePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final resized = decoded.width > 512 || decoded.height > 512
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? 512 : null,
            height: decoded.height > decoded.width ? 512 : null,
          )
        : decoded;
    final pngBytes = Uint8List.fromList(img.encodePng(resized));

    final stickerId = const Uuid().v4();
    final savedPath = await ref.read(storageServiceProvider).saveStickerBytes(
          packId: packId,
          stickerId: stickerId,
          extension: 'png',
          bytes: pngBytes,
        );
    await ref.read(stickerRepositoryProvider).createSticker(
          id: stickerId,
          packId: packId,
          name: 'Cover',
          filePath: savedPath,
          width: resized.width,
          height: resized.height,
          format: StickerFormat.png,
          fileSize: pngBytes.length,
        );
    return stickerId;
  } catch (_) {
    return null;
  }
}
