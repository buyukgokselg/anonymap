import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RuntimeConfigService {
  static const MethodChannel _channel = MethodChannel(
    'pulsecity/runtime_config',
  );

  static String _googlePlacesApiKey = const String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: '',
  );
  static String _mapboxAccessToken = const String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );
  static String _backendBaseUrl = const String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );
  static bool _isInitialized = false;

  static String get googlePlacesApiKey => _googlePlacesApiKey;
  static String get mapboxAccessToken => _mapboxAccessToken;
  static String get backendBaseUrl => _backendBaseUrl;
  static bool get hasGooglePlacesApiKey => _googlePlacesApiKey.isNotEmpty;
  static bool get hasMapboxAccessToken => _mapboxAccessToken.isNotEmpty;
  static bool get hasBackendBaseUrl => _backendBaseUrl.isNotEmpty;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final config = await _channel.invokeMapMethod<String, dynamic>(
        'getRuntimeConfig',
      );
      final nativeGooglePlacesApiKey =
          _sanitizeConfigValue(config?['googlePlacesApiKey'] as String?);
      final nativeMapboxAccessToken =
          _sanitizeConfigValue(config?['mapboxAccessToken'] as String?);
      final nativeBackendBaseUrl =
          _sanitizeConfigValue(config?['backendBaseUrl'] as String?);

      if (nativeGooglePlacesApiKey.isNotEmpty) {
        _googlePlacesApiKey = nativeGooglePlacesApiKey;
      }
      if (nativeMapboxAccessToken.isNotEmpty) {
        _mapboxAccessToken = nativeMapboxAccessToken;
      }
      if (nativeBackendBaseUrl.isNotEmpty) {
        _backendBaseUrl = nativeBackendBaseUrl;
      }
    } on MissingPluginException {
      // Native bridge is optional for tests and unsupported platforms.
    } catch (e) {
      debugPrint('Runtime config load error: $e');
    } finally {
      _isInitialized = true;
    }
  }

  static String _sanitizeConfigValue(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || trimmed.startsWith(r'$(')) {
      return '';
    }
    return trimmed;
  }
}
