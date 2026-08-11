import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/config/ai_settings.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../ai/data/ai_repository.dart';
import '../domain/settings_logic.dart';

/// Where the API key lives now.
///
/// The old build read credentials from a bundled `.env` asset that shipped
/// empty — which is why AI never worked and why a parse failure could block
/// launch. Keys are per-device, editable without a rebuild, and testable
/// in place.
class AiSettingsSheet extends ConsumerStatefulWidget {
  const AiSettingsSheet({super.key});

  @override
  ConsumerState<AiSettingsSheet> createState() => _AiSettingsSheetState();
}

class _AiSettingsSheetState extends ConsumerState<AiSettingsSheet> {
  late AiProvider _provider;
  late TextEditingController _keyController;
  late TextEditingController _removeBgController;
  late TextEditingController _baseUrlController;
  late String _imageModel;

  bool _showKey = false;
  bool _showAdvanced = false;
  bool _testing = false;
  String? _testMessage;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiSettingsProvider);
    _provider = settings.provider;
    _keyController = TextEditingController(text: settings.apiKey);
    _removeBgController = TextEditingController(text: settings.removeBgApiKey);
    _baseUrlController = TextEditingController(text: settings.baseUrl);
    _imageModel = settings.resolvedImageModel;
  }

  @override
  void dispose() {
    _keyController.dispose();
    _removeBgController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  AiSettings _draft() => AiSettings(
        provider: _provider,
        apiKey: _keyController.text.trim(),
        baseUrl: _baseUrlController.text.trim(),
        chatModel: '',
        imageModel: _imageModel,
        removeBgApiKey: _removeBgController.text.trim(),
      );

  Future<void> _save() async {
    final messenger = appMessenger(context);
    await ref.read(aiSettingsProvider.notifier).update(_draft());
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    showAppSnack(context, 'AI connection saved', messengerOverride: messenger);
  }

  Future<void> _test() async {
    final draft = _draft();
    if (draft.provider.requiresKey && !draft.isConfigured) {
      setState(() {
        _testOk = false;
        _testMessage = 'Paste your API key first.';
      });
      return;
    }

    setState(() {
      _testing = true;
      _testMessage = null;
    });

    final repository = AiRepositoryImpl(settings: draft);
    final result = await repository.verifyCredentials();
    repository.dispose();

    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = result.isSuccess;
      _testMessage = result.isSuccess
          ? (draft.provider.requiresKey
              ? 'Connected. Your key works.'
              : 'Free generator is up. You are ready to go.')
          : result.errorMessage;
    });
  }

  Future<void> _disconnect() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Disconnect AI?',
      message: 'Your key will be removed from this device.',
      confirmLabel: 'Disconnect',
    );
    if (!confirmed) return;
    final messenger = appMessenger(context);
    await ref.read(aiSettingsProvider.notifier).clear();
    if (!mounted) return;
    Navigator.of(context).pop();
    showAppSnack(context, 'AI disconnected', messengerOverride: messenger);
  }

  @override
  Widget build(BuildContext context) {
    final presets = ImageModelPreset.forProvider(_provider);
    final hasStoredKey =
        ref.watch(aiSettingsProvider).apiKey.trim().isNotEmpty;

    return SheetSurface(
      title: 'AI connection',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Provider'),
          ...AiProvider.values.map(
            (provider) => _ProviderTile(
              provider: provider,
              selected: provider == _provider,
              onTap: () => setState(() {
                _provider = provider;
                _imageModel = provider.defaultImageModel;
                _baseUrlController.text = '';
                _testMessage = null;
              }),
            ),
          ),
          SizedBox(height: 18.h),

          if (_provider.requiresKey) ...[
            const SectionLabel('API key'),
            TextField(
              controller: _keyController,
              obscureText: !_showKey,
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary),
              onChanged: (_) => setState(() => _testMessage = null),
              decoration: InputDecoration(
                hintText: _provider.keyHint,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showKey ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                    size: 18.r,
                    color: AppColors.textTertiary,
                  ),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(
                  CupertinoIcons.lock_shield,
                  size: 13.r,
                  color: AppColors.textTertiary,
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'Stored on this device only. Sticksy never sends it '
                    'anywhere except your chosen provider.',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textTertiary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            TextButton(
              onPressed: () => openExternalUrl(
                context,
                _provider == AiProvider.openRouter
                    ? 'https://openrouter.ai/keys'
                    : 'https://platform.openai.com/api-keys',
              ),
              child: Text('Get a ${_provider.label} key →'),
            ),
          ] else
            const _FreeTierNote(),
          SizedBox(height: 18.h),

          const SectionLabel('Image model'),
          ...presets.map(
            (preset) => _ModelTile(
              preset: preset,
              selected: preset.id == _imageModel,
              onTap: () => setState(() {
                _imageModel = preset.id;
                _testMessage = null;
              }),
            ),
          ),
          SizedBox(height: 14.h),

          if (_testMessage != null) ...[
            _TestResult(message: _testMessage!, ok: _testOk),
            SizedBox(height: 14.h),
          ],

          SoftButton(
            label: _testing ? 'Testing…' : 'Test connection',
            icon: CupertinoIcons.bolt,
            onPressed: _testing ? null : _test,
          ),
          SizedBox(height: 10.h),
          GradientButton(
            label: 'Save',
            icon: CupertinoIcons.checkmark_alt,
            onPressed: _save,
          ),

          SizedBox(height: 20.h),
          PressFx(
            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Advanced',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                  ),
                ),
                Icon(
                  _showAdvanced
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 14.r,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
          if (_showAdvanced) ...[
            SizedBox(height: 14.h),
            Text(
              'Custom base URL',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 6.h),
            TextField(
              controller: _baseUrlController,
              autocorrect: false,
              keyboardType: TextInputType.url,
              style: TextStyle(fontSize: 13.sp),
              decoration: InputDecoration(
                hintText: _provider.defaultBaseUrl,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'remove.bg key (optional)',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 6.h),
            TextField(
              controller: _removeBgController,
              autocorrect: false,
              obscureText: true,
              style: TextStyle(fontSize: 13.sp),
              decoration: const InputDecoration(
                hintText: 'Improves cutouts on photos',
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Without this, Sticksy still cuts out flat backgrounds on '
              'device — no key or network needed.',
              style: TextStyle(
                fontSize: 11.sp,
                color: AppColors.textTertiary,
                height: 1.35,
              ),
            ),
          ],

          if (hasStoredKey) ...[
            SizedBox(height: 22.h),
            SoftButton(
              label: 'Disconnect',
              icon: CupertinoIcons.xmark_circle,
              destructive: true,
              onPressed: _disconnect,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  final AiProvider provider;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final free = !provider.requiresKey;
    final accent = free ? AppColors.success : AppColors.violet;

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: PressFx(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.14)
                : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected ? accent : AppColors.stroke,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? CupertinoIcons.largecircle_fill_circle
                    : CupertinoIcons.circle,
                size: 18.r,
                color: selected ? accent : AppColors.textTertiary,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          provider.label,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        StatChip(
                          label: free ? 'no key' : 'needs key',
                          color: free ? AppColors.success : AppColors.orange,
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      provider.tagline,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textTertiary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeTierNote extends StatelessWidget {
  const _FreeTierNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.gift,
                size: 16.r,
                color: AppColors.success,
              ),
              SizedBox(width: 8.w),
              Text(
                'Ready to use',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Generation runs through pollinations.ai, a free public service. '
            'No account, no card, nothing to paste.\n\n'
            'The trade-offs: it is shared, so it can be slow or briefly '
            'unavailable, the art is simpler than paid models, and your prompt '
            'text is sent to that service. Switch to OpenRouter any time for '
            'sharper results and transparent PNGs.',
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ImageModelPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: PressFx(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.violet.withValues(alpha: 0.14)
                : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected ? AppColors.violet : AppColors.stroke,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? CupertinoIcons.largecircle_fill_circle
                    : CupertinoIcons.circle,
                size: 18.r,
                color: selected ? AppColors.violet : AppColors.textTertiary,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            preset.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (preset.transparentBackground) ...[
                          SizedBox(width: 8.w),
                          StatChip(
                            label: 'alpha',
                            color: AppColors.success,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      preset.blurb,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textTertiary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestResult extends StatelessWidget {
  const _TestResult({required this.message, required this.ok});

  final String message;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.danger;
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok
                ? CupertinoIcons.checkmark_seal_fill
                : CupertinoIcons.exclamationmark_triangle_fill,
            size: 16.r,
            color: color,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
