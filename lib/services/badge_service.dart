import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/badge_model.dart';
import 'auth_service.dart';
import 'runtime_config_service.dart';

/// Singleton broker for /api/badges endpoints.
///
/// Cataloğu tek sefer çekip bellek içinde tutar (statik veri); kullanıcı rozet
/// ilerlemesini API çağrısıyla tazeler. Profile/Badges sayfaları bu servise
/// bağlanır ve [notifyListeners] sayesinde yeni rozet kazanıldığında yeniden
/// renderlanırlar.
class BadgeService extends ChangeNotifier {
  BadgeService._();

  static final BadgeService instance = BadgeService._();

  BadgeCatalogResponse? _catalog;
  Future<BadgeCatalogResponse?>? _catalogInflight;
  final Map<String, UserBadgesResponse> _byUserId =
      <String, UserBadgesResponse>{};

  /// Bellek-içi katalog (UI'ın hızlı erişimi için).
  BadgeCatalogResponse? get catalog => _catalog;

  /// Bellek-içi kullanıcı rozet durumu (varsa).
  UserBadgesResponse? cachedForUser(String userId) => _byUserId[userId];

  String? get _baseUrl {
    final raw = RuntimeConfigService.backendBaseUrl.trim();
    if (raw.isEmpty) return null;
    return raw.replaceFirst(RegExp(r'/$'), '');
  }

  Future<Map<String, String>?> _headers({bool requireAuth = true}) async {
    final auth = AuthService();
    if (requireAuth && !auth.isLoggedIn) return null;
    final headers = auth.isLoggedIn
        ? await auth.authorizedHeaders()
        : <String, String>{};
    headers['ngrok-skip-browser-warning'] = 'true';
    return headers;
  }

  /// Statik rozet kataloğunu çeker. AllowAnonymous endpoint, login öncesi de
  /// çağrılabilir; aynı oturumda tekrar çağrıldığında bellek'tekini döner.
  Future<BadgeCatalogResponse?> getCatalog({bool forceRefresh = false}) async {
    if (!forceRefresh && _catalog != null) return _catalog;
    _catalogInflight ??= _fetchCatalog();
    final result = await _catalogInflight;
    _catalogInflight = null;
    return result;
  }

  Future<BadgeCatalogResponse?> _fetchCatalog() async {
    final base = _baseUrl;
    final headers = await _headers(requireAuth: false);
    if (base == null || headers == null) return _catalog;
    try {
      final res = await http
          .get(Uri.parse('$base/api/badges/catalog'), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return _catalog;
      final body = json.decode(utf8.decode(res.bodyBytes));
      if (body is! Map) return _catalog;
      _catalog = BadgeCatalogResponse.fromMap(Map<String, dynamic>.from(body));
      notifyListeners();
      return _catalog;
    } catch (_) {
      return _catalog;
    }
  }

  /// Caller'ın kendi rozet durumu — login zorunlu.
  Future<UserBadgesResponse?> getMine() async {
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) return null;
    try {
      final res = await http
          .get(Uri.parse('$base/api/badges/me'), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body = json.decode(utf8.decode(res.bodyBytes));
      if (body is! Map) return null;
      final response =
          UserBadgesResponse.fromMap(Map<String, dynamic>.from(body));
      final myId = AuthService().currentUserId;
      if (myId.isNotEmpty) {
        _byUserId[myId] = response;
      }
      notifyListeners();
      return response;
    } catch (_) {
      return null;
    }
  }

  /// Bir başka kullanıcının rozetlerini çeker (profil sayfası).
  Future<UserBadgesResponse?> getForUser(String userId) async {
    if (userId.isEmpty) return null;
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) return null;
    try {
      final encoded = Uri.encodeComponent(userId);
      final res = await http
          .get(
            Uri.parse('$base/api/badges/users/$encoded'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body = json.decode(utf8.decode(res.bodyBytes));
      if (body is! Map) return null;
      final response =
          UserBadgesResponse.fromMap(Map<String, dynamic>.from(body));
      _byUserId[userId] = response;
      notifyListeners();
      return response;
    } catch (_) {
      return null;
    }
  }

  /// Logout/clear — auth değişimi sonrası çağrılır.
  void clear() {
    _byUserId.clear();
    notifyListeners();
  }
}
