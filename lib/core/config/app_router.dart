import 'package:go_router/go_router.dart';

import '../../features/editor/presentation/sticker_editor_screen.dart';
import '../../features/packs/presentation/pack_detail_screen.dart';
import '../../features/packs/presentation/pack_list_screen.dart';

class AppRouter {
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
              builder: (context, state) => PackDetailScreen(
                packId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: 'editor',
              name: 'editor',
              builder: (context, state) => StickerEditorScreen(
                args: state.extra as StickerEditorArgs?,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
