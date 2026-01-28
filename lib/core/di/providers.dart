import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai/data/openrouter_client.dart';
import '../../features/ai/data/remove_bg_client.dart';
import '../../features/ai/data/ai_repository.dart';
import '../../features/packs/data/pack_repository.dart';
import '../../features/packs/domain/models.dart';
import '../../shared/data/local/app_database.dart';
import '../../shared/data/services/storage_services.dart';
import '../config/env.dart';

final envLoadResultProvider = Provider<EnvLoadResult>(
  (ref) => throw UnimplementedError(),
);

final envConfigProvider = Provider<EnvConfig?>(
  (ref) => ref.watch(envLoadResultProvider).config,
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final storageServiceProvider = Provider<LocalStorageService>(
  (ref) => LocalStorageService(),
);

final cacheServiceProvider = Provider<CacheService>(
  (ref) => CacheService(),
);

final imageExportServiceProvider = Provider<ImageExportService>(
  (ref) => ImageExportService(),
);

final packExportServiceProvider = Provider<PackExportService>(
  (ref) => PackExportService(
    cacheService: ref.read(cacheServiceProvider),
    imageExportService: ref.read(imageExportServiceProvider),
  ),
);

final packRepositoryProvider = Provider<PackRepository>((ref) {
  return PackRepositoryImpl(
    database: ref.read(appDatabaseProvider),
    storage: ref.read(storageServiceProvider),
  );
});

final stickerRepositoryProvider = Provider<StickerRepository>((ref) {
  return StickerRepositoryImpl(
    database: ref.read(appDatabaseProvider),
    storage: ref.read(storageServiceProvider),
  );
});

final packSummariesProvider = StreamProvider<List<PackSummary>>((ref) {
  return ref.watch(packRepositoryProvider).watchPackSummaries();
});

final packSummaryProvider =
    StreamProvider.family<PackSummary?, String>((ref, id) {
  return ref
      .watch(packRepositoryProvider)
      .watchPackSummaries()
      .map((packs) => packs.firstWhereOrNull((pack) => pack.id == id));
});

final stickersForPackProvider =
    StreamProvider.family<List<StickerItem>, String>((ref, packId) {
  return ref.watch(stickerRepositoryProvider).watchStickers(packId);
});

final stickerByIdProvider =
    FutureProvider.family<StickerItem?, String>((ref, id) {
  return ref.watch(stickerRepositoryProvider).getSticker(id);
});

final openRouterClientProvider = Provider<OpenRouterClient?>((ref) {
  final config = ref.watch(envConfigProvider);
  if (config == null) return null;
  return OpenRouterClient(
    baseUrl: config.openRouterBaseUrl,
    apiKey: config.openRouterApiKey,
    model: config.openRouterModel,
  );
});

final removeBgClientProvider = Provider<RemoveBgClient?>((ref) {
  final config = ref.watch(envConfigProvider);
  final key = config?.removeBgApiKey;
  if (key == null || key.isEmpty) return null;
  return RemoveBgClient(apiKey: key);
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepositoryImpl(
    chatClient: ref.watch(openRouterClientProvider),
    removeBgClient: ref.watch(removeBgClientProvider),
  );
});
