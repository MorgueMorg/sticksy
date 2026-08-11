import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai/data/ai_repository.dart';
import '../../features/packs/data/pack_repository.dart';
import '../../features/packs/domain/models.dart';
import '../../shared/data/local/app_database.dart';
import '../../shared/data/services/storage_services.dart';
import '../config/ai_settings.dart';

// ---------------------------------------------------------------------------
// AI configuration
// ---------------------------------------------------------------------------

/// Seeded in `main()` with whatever was persisted last run, so the first frame
/// already knows whether AI is available. Overridden in `ProviderScope`.
final initialAiSettingsProvider = Provider<AiSettings>(
  (ref) => const AiSettings(),
);

final aiSettingsStoreProvider = Provider<AiSettingsStore>(
  (ref) => AiSettingsStore(),
);

final aiSettingsProvider =
    StateNotifierProvider<AiSettingsController, AiSettings>((ref) {
  return AiSettingsController(
    ref.watch(initialAiSettingsProvider),
    ref.watch(aiSettingsStoreProvider),
  );
});

class AiSettingsController extends StateNotifier<AiSettings> {
  AiSettingsController(AiSettings initial, this._store) : super(initial);

  final AiSettingsStore _store;

  Future<void> update(AiSettings next) async {
    state = next;
    try {
      await _store.save(next);
    } catch (_) {
      // A failed write shouldn't lose the in-memory change.
    }
  }

  Future<void> clear() async {
    state = const AiSettings();
    try {
      await _store.clear();
    } catch (_) {
      // Ignore.
    }
  }
}

/// Rebuilt whenever settings change. Returns a no-credential stand-in rather
/// than null so screens never have to null-check the repository.
final aiRepositoryProvider = Provider<AiRepository>((ref) {
  final settings = ref.watch(aiSettingsProvider);
  if (!settings.isConfigured) return const UnconfiguredAiRepository();
  final repository = AiRepositoryImpl(settings: settings);
  ref.onDispose(repository.dispose);
  return repository;
});

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final storageServiceProvider = Provider<LocalStorageService>(
  (ref) => LocalStorageService(),
);

final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());

final imageExportServiceProvider = Provider<ImageExportService>(
  (ref) => ImageExportService(),
);

final packExportServiceProvider = Provider<PackExportService>(
  (ref) => PackExportService(
    cacheService: ref.watch(cacheServiceProvider),
    imageExportService: ref.watch(imageExportServiceProvider),
  ),
);

final packRepositoryProvider = Provider<PackRepository>((ref) {
  return PackRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    storage: ref.watch(storageServiceProvider),
  );
});

final stickerRepositoryProvider = Provider<StickerRepository>((ref) {
  return StickerRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    storage: ref.watch(storageServiceProvider),
  );
});

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

final packSummariesProvider = StreamProvider<List<PackSummary>>((ref) {
  return ref.watch(packRepositoryProvider).watchPackSummaries();
});

/// Free-text filter applied to the pack list.
final packSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredPackSummariesProvider = Provider<AsyncValue<List<PackSummary>>>((
  ref,
) {
  final packs = ref.watch(packSummariesProvider);
  final query = ref.watch(packSearchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return packs;
  return packs.whenData(
    (list) => list
        .where((pack) => pack.name.toLowerCase().contains(query))
        .toList(),
  );
});

final packSummaryProvider = StreamProvider.family<PackSummary?, String>((
  ref,
  id,
) {
  return ref
      .watch(packRepositoryProvider)
      .watchPackSummaries()
      .map((packs) => packs.firstWhereOrNull((pack) => pack.id == id));
});

final stickersForPackProvider =
    StreamProvider.family<List<StickerItem>, String>((ref, packId) {
  return ref.watch(stickerRepositoryProvider).watchStickers(packId);
});

final stickerByIdProvider = FutureProvider.family<StickerItem?, String>((
  ref,
  id,
) {
  return ref.watch(stickerRepositoryProvider).getSticker(id);
});
