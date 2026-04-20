import '../../application/repositories/settings_repository.dart';
import '../../application/services/settings_service.dart';
import '../../domain/entities/app_settings.dart';
import '../repositories/local_settings_repository.dart';
import 'local_scan_result_store.dart';

class LocalSettingsService implements SettingsService {
  LocalSettingsService({required SettingsRepository repository})
    : _repository = repository;

  final SettingsRepository _repository;

  factory LocalSettingsService.standard() {
    final store = LocalScanResultStore();
    return LocalSettingsService(
      repository: LocalSettingsRepository(store: store),
    );
  }

  @override
  Future<AppSettings> loadSettings() {
    return _repository.load();
  }

  @override
  Future<AppSettings> saveSettings(AppSettings settings) async {
    await _repository.save(settings);
    return settings;
  }
}
