/// Lightweight placeholder state types for the presentation layer.
///
/// Real navigation, permissions, and feature state will be added later.
enum HiveAppStage { splash, onboarding, permission, home }

final class AppState {
  const AppState({this.currentStage = HiveAppStage.splash});

  final HiveAppStage currentStage;
}
