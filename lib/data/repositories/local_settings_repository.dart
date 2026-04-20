import '../../application/repositories/settings_repository.dart';
import '../../domain/entities/app_settings.dart';
import '../services/local_scan_result_store.dart';
import 'local_scan_storage_codec.dart';

class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository({required LocalScanResultStore store})
    : _store = store;

  final LocalScanResultStore _store;

  @override
  Future<AppSettings> load() async {
    final snapshot = await _store.read();
    return appSettingsFromJson(snapshot.settings);
  }

  @override
  Future<void> save(AppSettings settings) async {
    final snapshot = await _store.read();
    await _store.write(
      copyStoredScanSnapshot(snapshot, settings: appSettingsToJson(settings)),
    );
  }
}
