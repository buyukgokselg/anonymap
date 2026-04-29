import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/notification_model.dart';
import 'auth_service.dart';
import 'realtime_service.dart';
import 'runtime_config_service.dart';

/// In-app notification inbox: REST list/mark-read + realtime SignalR sync.
///
/// This is separate from [NotificationService] (FCM/push) because the inbox
/// is a server-persisted list, while FCM is OS-level delivery. SignalR keeps
/// the unread badge live without polling.
class NotificationsInboxService extends ChangeNotifier {
  NotificationsInboxService._() {
    _bindRealtime();
    _bindAuth();
  }

  static final NotificationsInboxService instance = NotificationsInboxService._();

  final List<AppNotification> _items = <AppNotification>[];
  int _unreadCount = 0;
  bool _hasMore = false;
  bool _loading = false;
  Object? _lastError;
  StreamSubscription<Map<String, dynamic>>? _createdSub;
  StreamSubscription<int>? _unreadSub;
  StreamSubscription<AuthSession?>? _authSub;

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _unreadCount;
  bool get hasMore => _hasMore;
  bool get loading => _loading;
  Object? get lastError => _lastError;

  void _bindRealtime() {
    _createdSub = RealtimeService.instance.notificationCreated.listen((payload) {
      try {
        final notification = AppNotification.fromMap(payload);
        _items.removeWhere((entry) => entry.id == notification.id);
        _items.insert(0, notification);
        notifyListeners();
      } catch (e) {
        debugPrint('NotificationsInbox: failed to parse pushed notification: $e');
      }
    });
    _unreadSub = RealtimeService.instance.notificationsUnreadCount.listen((count) {
      if (count == _unreadCount) return;
      _unreadCount = count;
      notifyListeners();
    });
  }

  void _bindAuth() {
    _authSub = AuthService().authStateChanges.listen((session) {
      if (session == null || session.accessToken.isEmpty) {
        clear();
      } else {
        unawaited(fetchUnreadCount());
      }
    });
  }

  String? get _baseUrl {
    final raw = RuntimeConfigService.backendBaseUrl.trim();
    if (raw.isEmpty) return null;
    return raw.replaceFirst(RegExp(r'/$'), '');
  }

  Future<Map<String, String>?> _headers() async {
    final auth = AuthService();
    if (!auth.isLoggedIn) return null;
    final headers = await auth.authorizedHeaders();
    headers['Content-Type'] = 'application/json';
    headers['ngrok-skip-browser-warning'] = 'true';
    return headers;
  }

  Future<void> refresh({bool unreadOnly = false}) async {
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) return;
    _loading = true;
    _lastError = null;
    notifyListeners();

    try {
      final uri = Uri.parse('$base/api/notifications').replace(
        queryParameters: <String, String>{
          'limit': '40',
          if (unreadOnly) 'unreadOnly': 'true',
        },
      );
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        _lastError = 'HTTP ${res.statusCode}';
      } else {
        final body = json.decode(res.body);
        if (body is Map) {
          _items
            ..clear()
            ..addAll(_parseItems(body['items']));
          _unreadCount = (body['unreadCount'] as num?)?.toInt() ?? 0;
          _hasMore = body['hasMore'] == true;
        }
      }
    } catch (e) {
      _lastError = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _items.isEmpty || _loading) return;
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) return;
    _loading = true;
    notifyListeners();
    try {
      final cursor = _items.last.createdAt.toUtc().toIso8601String();
      final uri = Uri.parse('$base/api/notifications').replace(
        queryParameters: <String, String>{'limit': '30', 'before': cursor},
      );
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map) {
          _items.addAll(_parseItems(body['items']));
          _unreadCount = (body['unreadCount'] as num?)?.toInt() ?? _unreadCount;
          _hasMore = body['hasMore'] == true;
        }
      }
    } catch (e) {
      _lastError = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String notificationId) async {
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) return;

    final index = _items.indexWhere((entry) => entry.id == notificationId);
    if (index >= 0 && !_items[index].isRead) {
      _items[index] = _items[index].copyWith(isRead: true, readAt: DateTime.now());
      _unreadCount = (_unreadCount - 1).clamp(0, 1 << 30);
      notifyListeners();
    }

    try {
      await http
          .post(
            Uri.parse('$base/api/notifications/$notificationId/read'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('markRead failed: $e');
    }
  }

  Future<void> markAllRead() async {
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) return;

    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) {
        _items[i] = _items[i].copyWith(isRead: true, readAt: DateTime.now());
      }
    }
    _unreadCount = 0;
    notifyListeners();

    try {
      await http
          .post(
            Uri.parse('$base/api/notifications/read-all'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('markAllRead failed: $e');
    }
  }

  Future<void> delete(String notificationId) async {
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) return;

    final removed = _items.firstWhere(
      (entry) => entry.id == notificationId,
      orElse: () => _items.isNotEmpty ? _items.first : _empty(),
    );
    final wasUnread = removed.id == notificationId && !removed.isRead;
    _items.removeWhere((entry) => entry.id == notificationId);
    if (wasUnread) {
      _unreadCount = (_unreadCount - 1).clamp(0, 1 << 30);
    }
    notifyListeners();

    try {
      await http
          .delete(
            Uri.parse('$base/api/notifications/$notificationId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('delete notification failed: $e');
    }
  }

  Future<int> fetchUnreadCount() async {
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) return 0;
    try {
      final res = await http
          .get(
            Uri.parse('$base/api/notifications/unread-count'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map) {
          final count = (body['unreadCount'] as num?)?.toInt() ?? 0;
          if (count != _unreadCount) {
            _unreadCount = count;
            notifyListeners();
          }
          return count;
        }
      }
    } catch (e) {
      debugPrint('fetchUnreadCount failed: $e');
    }
    return _unreadCount;
  }

  void clear() {
    _items.clear();
    _unreadCount = 0;
    _hasMore = false;
    _lastError = null;
    notifyListeners();
  }

  List<AppNotification> _parseItems(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((entry) => AppNotification.fromMap(Map<String, dynamic>.from(entry)))
        .toList(growable: false);
  }

  static AppNotification _empty() => AppNotification(
        id: '',
        type: AppNotificationType.system,
        title: '',
        body: '',
        isRead: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  @override
  void dispose() {
    _createdSub?.cancel();
    _unreadSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
