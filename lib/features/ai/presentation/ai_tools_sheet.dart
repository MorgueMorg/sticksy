import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/glass_card.dart';

class AiToolsSheet extends ConsumerStatefulWidget {
  const AiToolsSheet({
    super.key,
    required this.imageBytes,
    required this.onApplyImage,
    required this.onIdeas,
    required this.onName,
  });

  final Uint8List imageBytes;
  final ValueChanged<Uint8List> onApplyImage;
  final ValueChanged<List<String>> onIdeas;
  final ValueChanged<String> onName;

  @override
  ConsumerState<AiToolsSheet> createState() => _AiToolsSheetState();
}

class _AiToolsSheetState extends ConsumerState<AiToolsSheet> {
  bool _loading = false;
  String? _error;
  final _promptController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<Result<dynamic>> Function() task) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await task();
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.isSuccess) {
      setState(() => _error = result.error?.message ?? 'AI failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiRepository = ref.watch(aiRepositoryProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'AI Studio',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _promptController,
                decoration: const InputDecoration(
                  hintText: 'Describe a theme or idea (optional)',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ToolButton(
                    icon: Icons.auto_fix_high,
                    label: 'Remove Background',
                    onTap: _loading
                        ? null
                        : () => _run(() async {
                              final result = await aiRepository
                                  .removeBackground(widget.imageBytes);
                              if (result.isSuccess) {
                                widget.onApplyImage(result.data as Uint8List);
                              }
                              return result;
                            }),
                  ),
                  _ToolButton(
                    icon: Icons.style,
                    label: 'Cartoon',
                    onTap: _loading
                        ? null
                        : () => _run(() async {
                              final result = await aiRepository
                                  .stylizeSticker(widget.imageBytes, 'cartoon');
                              if (result.isSuccess) {
                                widget.onApplyImage(result.data as Uint8List);
                              }
                              return result;
                            }),
                  ),
                  _ToolButton(
                    icon: Icons.grid_3x3,
                    label: 'Pixel',
                    onTap: _loading
                        ? null
                        : () => _run(() async {
                              final result = await aiRepository
                                  .stylizeSticker(widget.imageBytes, 'pixel');
                              if (result.isSuccess) {
                                widget.onApplyImage(result.data as Uint8List);
                              }
                              return result;
                            }),
                  ),
                  _ToolButton(
                    icon: Icons.brush,
                    label: 'Sketch',
                    onTap: _loading
                        ? null
                        : () => _run(() async {
                              final result = await aiRepository
                                  .stylizeSticker(widget.imageBytes, 'sketch');
                              if (result.isSuccess) {
                                widget.onApplyImage(result.data as Uint8List);
                              }
                              return result;
                            }),
                  ),
                  _ToolButton(
                    icon: Icons.lightbulb,
                    label: 'Idea Generator',
                    onTap: _loading
                        ? null
                        : () => _run(() async {
                              final prompt =
                                  _promptController.text.trim().isEmpty
                                      ? 'Creative sticker pack inspiration'
                                      : _promptController.text.trim();
                              final result =
                                  await aiRepository.generateIdeas(prompt);
                              if (result.isSuccess) {
                                widget.onIdeas(result.data as List<String>);
                              }
                              return result;
                            }),
                  ),
                  _ToolButton(
                    icon: Icons.short_text,
                    label: 'Name Sticker',
                    onTap: _loading
                        ? null
                        : () => _run(() async {
                              final prompt =
                                  _promptController.text.trim().isEmpty
                                      ? 'Short sticker name'
                                      : _promptController.text.trim();
                              final result =
                                  await aiRepository.generateStickerName(
                                prompt,
                              );
                              if (result.isSuccess) {
                                widget.onName(result.data as String);
                              }
                              return result;
                            }),
                  ),
                ],
              ),
              if (_loading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
