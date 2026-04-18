import '../../application/models/home_cell_preview.dart';
import '../../application/models/home_dashboard_snapshot.dart';
import '../../application/repositories/folder_cell_repository.dart';
import '../../application/repositories/media_asset_repository.dart';
import '../../application/repositories/scan_run_repository.dart';
import '../../application/services/home_dashboard_service.dart';
import '../repositories/in_memory_folder_cell_repository.dart';
import '../repositories/in_memory_media_asset_repository.dart';
import '../repositories/in_memory_scan_run_repository.dart';

class InMemoryHomeDashboardService implements HomeDashboardService {
  InMemoryHomeDashboardService({
    required MediaAssetRepository mediaAssetRepository,
    required FolderCellRepository folderCellRepository,
    required ScanRunRepository scanRunRepository,
  }) : _mediaAssetRepository = mediaAssetRepository,
       _folderCellRepository = folderCellRepository,
       _scanRunRepository = scanRunRepository;

  final MediaAssetRepository _mediaAssetRepository;
  final FolderCellRepository _folderCellRepository;
  final ScanRunRepository _scanRunRepository;

  factory InMemoryHomeDashboardService.seeded() {
    return InMemoryHomeDashboardService(
      mediaAssetRepository: InMemoryMediaAssetRepository.seeded(),
      folderCellRepository: InMemoryFolderCellRepository.seeded(),
      scanRunRepository: InMemoryScanRunRepository.seeded(),
    );
  }

  static const Map<String, ({String summary, String styleKey, bool featured})>
  _previewContent = {
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
    'Food': (summary: 'Plates worth saving', styleKey: 'food', featured: false),
    'Basketball': (
      summary: 'Game nights and court-side shots',
      styleKey: 'basketball',
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
    final assets = await _mediaAssetRepository.getAllAssets();
    final cells = await _folderCellRepository.getAllCells();
    final latestRun = await _scanRunRepository.getLatestRun();

    final visibleCells = <HomeCellPreview>[];

    for (final cell in cells) {
      final preview = _previewContent[cell.name];

      if (preview == null) {
        continue;
      }

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
    }

    return HomeDashboardSnapshot(
      totalAssetCount: assets.length,
      totalCellCount: cells.length,
      lastCompletedScanAt: latestRun?.completedAt,
      visibleCells: visibleCells,
    );
  }
}
