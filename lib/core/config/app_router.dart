import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../../features/editor/presentation/sticker_editor_screen.dart';
import '../../features/packs/presentation/pack_detail_screen.dart';
import '../../features/packs/presentation/pack_list_screen.dart';
import '../../features/settings/presentation/settings.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/ui_kit.dart';

class AppRouter {
  const AppRouter._();

  static GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: 'packs',
          builder: (context, state) => const PackListScreen(),
          routes: [
            GoRoute(
              path: 'pack/:id',
              name: 'pack-detail',
              builder: (context, state) =>
                  PackDetailScreen(packId: state.pathParameters['id'] ?? ''),
            ),
            GoRoute(
              path: 'editor',
              name: 'editor',
              builder: (context, state) {
                final extra = state.extra;
                return StickerEditorScreen(
                  args: extra is StickerEditorArgs ? extra : null,
                );
              },
            ),
            GoRoute(
              path: 'settings',
              name: 'settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => GradientScaffold(
        body: EmptyState(
          icon: CupertinoIcons.compass,
          title: 'Nothing here',
          message: 'That screen does not exist.',
          actionLabel: 'Back to packs',
          actionIcon: CupertinoIcons.house_fill,
          onAction: () => context.go('/'),
        ),
      ),
    );
  }
}
