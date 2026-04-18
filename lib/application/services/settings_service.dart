import '../../domain/entities/app_settings.dart';

abstract interface class SettingsService {
  Future<AppSettings> loadSettings();

  Future<AppSettings> saveSettings(AppSettings settings);
}
