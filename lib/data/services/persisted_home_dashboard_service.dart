import '../../application/models/home_cell_preview.dart';
import '../../application/models/home_dashboard_snapshot.dart';
import '../../application/repositories/folder_cell_repository.dart';
import '../../application/repositories/media_asset_repository.dart';
import '../../application/repositories/scan_run_repository.dart';
import '../../application/services/home_dashboard_service.dart';
import '../../application/services/media_library_service.dart';
import '../repositories/local_folder_cell_repository.dart';
import '../repositories/local_media_asset_repository.dart';
import '../repositories/local_scan_run_repository.dart';
import 'local_scan_result_store.dart';
import 'photo_manager_media_library_service.dart';

class PersistedHomeDashboardService implements HomeDashboardService {
  PersistedHomeDashboardService({
    required MediaAssetRepository mediaAssetRepository,
    required FolderCellRepository folderCellRepository,
    required ScanRunRepository scanRunRepository,
    MediaLibraryService? mediaLibraryService,
  }) : _mediaAssetRepository = mediaAssetRepository,
       _folderCellRepository = folderCellRepository,
       _scanRunRepository = scanRunRepository,
       _mediaLibraryService = mediaLibraryService;

  final MediaAssetRepository _mediaAssetRepository;
  final FolderCellRepository _folderCellRepository;
  final ScanRunRepository _scanRunRepository;
  final MediaLibraryService? _mediaLibraryService;

  factory PersistedHomeDashboardService.standard() {
    final store = LocalScanResultStore();

    return PersistedHomeDashboardService(
      mediaAssetRepository: LocalMediaAssetRepository(store: store),
      folderCellRepository: LocalFolderCellRepository(store: store),
      scanRunRepository: LocalScanRunRepository(store: store),
      mediaLibraryService: const PhotoManagerMediaLibraryService(),
    );
  }

  static const Map<String, ({String summary, String styleKey, bool featured})>
  _previewContent = {
    'People': (
      summary: 'Portraits, selfies, and shared moments',
      styleKey: 'people',
      featured: true,
    ),
    'Family': (
      summary: 'The people you return to most',
      styleKey: 'family',
      featured: true,
    ),
    'Pets': (
      summary: 'Warm moments and familiar faces',
      styleKey: 'pets',
      featured: true,
    ),
    'Travel': (
      summary: 'Trips, weekends, and new places',
      styleKey: 'travel',
      featured: false,
    ),
    'Places': (
      summary: 'Scenery, venues, skylines, and memorable locations',
      styleKey: 'places',
      featured: false,
    ),
    'Food': (summary: 'Plates worth saving', styleKey: 'food', featured: false),
    'Videos': (
      summary: 'Clips, motion moments, and moving memories',
      styleKey: 'videos',
      featured: false,
    ),
    'Screenshots': (
      summary: 'Captured references and saved screens',
      styleKey: 'screenshots',
      featured: false,
    ),
    'Devices / Tech': (
      summary: 'Gadgets, desks, and digital gear',
      styleKey: 'tech',
      featured: false,
    ),
    'Documents / Receipts': (
      summary: 'Paperwork and references worth keeping',
      styleKey: 'documents',
      featured: false,
    ),
    'Sports': (
      summary: 'Games, training, and courtside energy',
      styleKey: 'sports',
      featured: true,
    ),
    'Animation / Cartoon / Meme': (
      summary: 'Stylized art, jokes, and saved internet moments',
      styleKey: 'animation',
      featured: true,
    ),
    'Unsorted': (
      summary: 'The next clean-up pass',
      styleKey: 'unsorted',
      featured: false,
    ),
  };

  @override
  Future<HomeDashboardSnapshot> loadDashboard() async {
    final cells = await _folderCellRepository.getAllCells();
    final assets = await _mediaAssetRepository.getAllAssets();
    final latestRun = await _scanRunRepository.getLatestRun();
    final totalAssetCount = await _resolveTotalAssetCount(
      fallbackCount: assets.length,
    );
    if (cells.isEmpty) {
      if (latestRun == null) {
        return HomeDashboardSnapshot(
          totalAssetCount: totalAssetCount,
          totalCellCount: 0,
          lastCompletedScanAt: null,
          visibleCells: const [],
          hasCompletedScan: false,
          meaningfulCellCount: 0,
        );
      }

      return HomeDashboardSnapshot(
        totalAssetCount: totalAssetCount,
        totalCellCount: 0,
        lastCompletedScanAt: latestRun.completedAt,
        visibleCells: const [],
        hasCompletedScan: latestRun.completedAt != null,
        meaningfulCellCount: 0,
      );
    }

    final visibleCells = <HomeCellPreview>[];
    var meaningfulCellCount = 0;

    for (final cell in cells) {
      final preview =
          _previewContent[cell.name] ??
          (
            summary: cell.description ?? 'A local HIVE cell',
            styleKey: 'unsorted',
            featured: false,
          );

      visibleCells.add(
        HomeCellPreview(
          id: cell.id,
          name: cell.name,
          assetCount: cell.assetCount,
          summary: preview.summary,
          styleKey: preview.styleKey,
          featured: preview.featured,
        ),
      );

      if (cell.assetCount > 0 && cell.name != 'Unsorted') {
        meaningfulCellCount += 1;
      }
    }

    return HomeDashboardSnapshot(
      totalAssetCount: totalAssetCount,
      totalCellCount: cells.length,
      lastCompletedScanAt: latestRun?.completedAt,
      visibleCells: visibleCells,
      hasCompletedScan: latestRun?.completedAt != null,
      meaningfulCellCount: meaningfulCellCount,
    );
  }

  Future<int> _resolveTotalAssetCount({required int fallbackCount}) async {
    final mediaLibraryService = _mediaLibraryService;
    if (mediaLibraryService == null) {
      return fallbackCount;
    }

    try {
      final count = await mediaLibraryService.getEstimatedAssetCount();
      return count > 0 ? count : fallbackCount;
    } catch (_) {
      return fallbackCount;
    }
  }
}
