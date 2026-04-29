import '../services/runtime_config_service.dart';

/// Public Mapbox token (`pk.`). Override with platform-local config or
/// `flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk...`.
String get kMapboxPublicAccessToken => RuntimeConfigService.mapboxAccessToken;
