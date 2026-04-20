import '../../application/services/settings_service.dart';
import '../../domain/entities/app_settings.dart';

class InMemorySettingsService implements SettingsService {
  InMemorySettingsService({AppSettings? initialSettings})
    : _settings = initialSettings ?? const AppSettings();

  AppSettings _settings;

  @override
  Future<AppSettings> loadSettings() async {
    return _settings;
  }

  @override
  Future<AppSettings> saveSettings(AppSettings settings) async {
    _settings = settings;
    return _settings;
  }
}
