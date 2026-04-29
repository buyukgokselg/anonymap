import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/activity_model.dart';
import '../models/activity_rating_model.dart';
import '../models/chat_model.dart';
import 'auth_service.dart';
import 'realtime_service.dart';
import 'runtime_config_service.dart';

/// Singleton broker for /api/activities REST + SignalR sync.
///
/// Holds an in-memory cache of activities the caller is touching. UI screens
/// (discover, my-activities, detail) listen via [activityChanged] / [listChanged]
/// and re-render with the canonical state from this service.
///
/// SignalR `activityChanged` events trigger a targeted refetch of the affected
/// activity so the host's pending-request count, participant counts, and
/// cancellation state stay live without polling.
class ActivityService extends ChangeNotifier {
  ActivityService._() {
    _bindRealtime();
    _bindAuth();
  }

  static final ActivityService instance = ActivityService._();

  final Map<String, ActivityModel> _cache = <String, ActivityModel>{};
  StreamSubscription<ActivityChangedEvent>? _activitySub;
  StreamSubscription<AuthSession?>? _authSub;

  /// Emits the activityId whose row was refreshed (or removed).
  final StreamController<String> _activityChangedController =
      StreamController<String>.broadcast();

  /// Emits when any list-level mutation happened (create, cancel, leave, etc.).
  /// Listeners may want to refetch their list view.
  final StreamController<void> _listChangedController =
      StreamController<void>.broadcast();

  Stream<String> get activityChanged => _activityChangedController.stream;
  Stream<void> get listChanged => _listChangedController.stream;

  ActivityModel? cachedActivity(String activityId) => _cache[activityId];

  void _bindRealtime() {
    _activitySub = RealtimeService.instance.activityChanged.listen((event) {
      unawaited(_handleRealtimeEvent(event));
    });
  }

  void _bindAuth() {
    _authSub = AuthService().authStateChanges.listen((session) {
      if (session == null || session.accessToken.isEmpty) {
        _cache.clear();
        notifyListeners();
        _listChangedController.add(null);
      }
    });
  }

  Future<void> _handleRealtimeEvent(ActivityChangedEvent event) async {
    if (event.changeType == 'created') {
      _listChangedController.add(null);
      return;
    }

    // For updates/cancellations/participants changes, refetch the canonical
    // row; if the activity is no longer visible (deleted, blocked) drop it
    // from cache.
    try {
      final fresh = await getActivity(event.activityId, useCache: false);
      if (fresh == null) {
        _cache.remove(event.activityId);
      }
    } catch (e) {
      debugPrint('ActivityService: realtime refetch failed: $e');
    }
    _activityChangedController.add(event.activityId);
    _listChangedController.add(null);
  }

  String? get _baseUrl {
    final raw = RuntimeConfigService.backendBaseUrl.trim();
    if (raw.isEmpty) return null;
    return raw.replaceFirst(RegExp(r'/$'), '');
  }

  Future<Map<String, String>?> _headers({bool jsonBody = false}) async {
    final auth = AuthService();
    if (!auth.isLoggedIn) return null;
    final headers = await auth.authorizedHeaders();
    if (jsonBody) {
      headers['Content-Type'] = 'application/json';
    }
    headers['ngrok-skip-browser-warning'] = 'true';
    return headers;
  }

  Future<ActivityListResponse> search(ActivityListQueryParams query) async {
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) {
      return ActivityListResponse(items: const [], hasMore: false);
    }
    final uri = Uri.parse('$base/api/activities')
        .replace(queryParameters: query.toQuery());
    final res = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('search failed: HTTP ${res.statusCode}');
    }
    final body = json.decode(utf8.decode(res.bodyBytes));
    if (body is! Map) {
      return ActivityListResponse(items: const [], hasMore: false);
    }
    final response = ActivityListResponse.fromMap(
      Map<String, dynamic>.from(body),
    );
    for (final item in response.items) {
      _cache[item.id] = item;
    }
    return response;
  }

  Future<ActivityListResponse> listHosting() async {
    return _listEndpoint('/api/activities/hosting');
  }

  Future<ActivityListResponse> listJoined() async {
    return _listEndpoint('/api/activities/joined');
  }

  Future<ActivityListResponse> _listEndpoint(String path) async {
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) {
      return ActivityListResponse(items: const [], hasMore: false);
    }
    final res = await http
        .get(Uri.parse('$base$path'), headers: headers)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('list failed: HTTP ${res.statusCode}');
    }
    final body = json.decode(utf8.decode(res.bodyBytes));
    if (body is! Map) {
      return ActivityListResponse(items: const [], hasMore: false);
    }
    final response = ActivityListResponse.fromMap(
      Map<String, dynamic>.from(body),
    );
    for (final item in response.items) {
      _cache[item.id] = item;
    }
    return response;
  }

  Future<ActivityModel?> getActivity(
    String activityId, {
    bool useCache = true,
  }) async {
    if (useCache) {
      final cached = _cache[activityId];
      if (cached != null) return cached;
    }
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) return null;
    final res = await http
        .get(
          Uri.parse('$base/api/activities/$activityId'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception('getActivity failed: HTTP ${res.statusCode}');
    }
    final body = json.decode(utf8.decode(res.bodyBytes));
    if (body is! Map) return null;
    final activity = ActivityModel.fromMap(Map<String, dynamic>.from(body));
    _cache[activity.id] = activity;
    notifyListeners();
    return activity;
  }

  Future<List<ActivityParticipationModel>> listParticipants(
    String activityId,
  ) async {
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) return const [];
    final res = await http
        .get(
          Uri.parse('$base/api/activities/$activityId/participants'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return const [];
    final body = json.decode(utf8.decode(res.bodyBytes));
    if (body is! Map) return const [];
    final items = body['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map(
          (m) => ActivityParticipationModel.fromMap(
            Map<String, dynamic>.from(m),
          ),
        )
        .toList(growable: false);
  }

  Future<ActivityModel> create(Map<String, dynamic> payload) async {
    final base = _baseUrl;
    final headers = await _headers(jsonBody: true);
    if (base == null || headers == null) {
      throw StateError('Not authenticated');
    }
    final res = await http
        .post(
          Uri.parse('$base/api/activities'),
          headers: headers,
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception(_extractError(res, 'Etkinlik oluşturulamadı'));
    }
    final body = json.decode(utf8.decode(res.bodyBytes));
    if (body is! Map) {
      throw Exception('Etkinlik oluşturulamadı (geçersiz yanıt).');
    }
    final activity = ActivityModel.fromMap(Map<String, dynamic>.from(body));
    _cache[activity.id] = activity;
    _listChangedController.add(null);
    notifyListeners();
    return activity;
  }

  Future<ActivityModel?> update(
    String activityId,
    Map<String, dynamic> payload,
  ) async {
    final base = _baseUrl;
    final headers = await _headers(jsonBody: true);
    if (base == null || headers == null) return null;
    final res = await http
        .patch(
          Uri.parse('$base/api/activities/$activityId'),
          headers: headers,
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception(_extractError(res, 'Etkinlik güncellenemedi'));
    }
    final body = json.decode(utf8.decode(res.bodyBytes));
    if (body is! Map) return null;
    final activity = ActivityModel.fromMap(Map<String, dynamic>.from(body));
    _cache[activity.id] = activity;
    _listChangedController.add(null);
    notifyListeners();
    return activity;
  }

  Future<bool> cancel(String activityId, {String? reason}) async {
    final base = _baseUrl;
    final headers = await _headers(jsonBody: true);
    if (base == null || headers == null) return false;
    final res = await http
        .post(
          Uri.parse('$base/api/activities/$activityId/cancel'),
          headers: headers,
          body: json.encode({'reason': reason}),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 204) {
      final cached = _cache[activityId];
      if (cached != null) {
        _cache[activityId] = cached.copyWith(
          status: ActivityStatus.cancelled,
          cancellationReason: reason,
        );
      }
      _listChangedController.add(null);
      notifyListeners();
      return true;
    }
    if (res.statusCode == 404) return false;
    throw Exception(_extractError(res, 'Etkinlik iptal edilemedi'));
  }

  Future<ActivityParticipationModel?> join(
    String activityId, {
    String? message,
  }) async {
    final base = _baseUrl;
    final headers = await _headers(jsonBody: true);
    if (base == null || headers == null) return null;
    final res = await http
        .post(
          Uri.parse('$base/api/activities/$activityId/join'),
          headers: headers,
          body: json.encode({'message': message}),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception(_extractError(res, 'Katılma isteği başarısız'));
    }
    final body = json.decode(utf8.decode(res.bodyBytes));
    if (body is! Map) return null;
    final participation = ActivityParticipationModel.fromMap(
      Map<String, dynamic>.from(body),
    );
    // Update cached activity's viewer status and (for auto-approved opens)
    // the participant count optimistically.
    final cached = _cache[activityId];
    if (cached != null) {
      final newStatus = participation.status == ActivityParticipationStatus.approved
          ? ActivityViewerStatus.approved
          : ActivityViewerStatus.requested;
      final wasParticipant = cached.viewerStatus == ActivityViewerStatus.approved;
      _cache[activityId] = cached.copyWith(
        viewerStatus: newStatus,
        currentParticipantCount:
            !wasParticipant && newStatus == ActivityViewerStatus.approved
                ? cached.currentParticipantCount + 1
                : cached.currentParticipantCount,
      );
    }
    _activityChangedController.add(activityId);
    _listChangedController.add(null);
    notifyListeners();
    return participation;
  }

  Future<bool> leave(String activityId) async {
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) return false;
    final res = await http
        .post(
          Uri.parse('$base/api/activities/$activityId/leave'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 204) {
      final cached = _cache[activityId];
      if (cached != null) {
        final wasApproved = cached.viewerStatus == ActivityViewerStatus.approved;
        _cache[activityId] = cached.copyWith(
          viewerStatus: ActivityViewerStatus.cancelled,
          currentParticipantCount: wasApproved
              ? (cached.currentParticipantCount - 1).clamp(0, 1 << 30)
              : cached.currentParticipantCount,
        );
      }
      _activityChangedController.add(activityId);
      _listChangedController.add(null);
      notifyListeners();
      return true;
    }
    if (res.statusCode == 404) return false;
    throw Exception(_extractError(res, 'Katılım iptal edilemedi'));
  }

  /// Returns the activity's group chat thread for the caller — creates if missing.
  /// Caller must be host or an approved participant.
  Future<ChatModel?> getGroupChat(String activityId) async {
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) return null;
    final res = await http
        .get(
          Uri.parse('$base/api/activities/$activityId/chat'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception(_extractError(res, 'Grup sohbeti açılamadı'));
    }
    final body = json.decode(utf8.decode(res.bodyBytes));
    if (body is! Map) return null;
    final m = Map<String, dynamic>.from(body);
    final id = (m['id'] ?? '').toString();
    if (id.isEmpty) return null;
    return ChatModel.fromMap(id, m);
  }

  Future<ActivityParticipationModel?> respondJoin(
    String activityId,
    String participationId, {
    required bool approve,
    String? responseNote,
  }) async {
    final base = _baseUrl;
    final headers = await _headers(jsonBody: true);
    if (base == null || headers == null) return null;
    final res = await http
        .post(
          Uri.parse(
            '$base/api/activities/$activityId/participants/$participationId/respond',
          ),
          headers: headers,
          body: json.encode({
            'decision': approve ? 'approve' : 'decline',
            'responseNote': responseNote,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception(_extractError(res, 'Karar gönderilemedi'));
    }
    final body = json.decode(utf8.decode(res.bodyBytes));
    if (body is! Map) return null;
    final participation = ActivityParticipationModel.fromMap(
      Map<String, dynamic>.from(body),
    );
    if (approve) {
      final cached = _cache[activityId];
      if (cached != null) {
        _cache[activityId] = cached.copyWith(
          currentParticipantCount: cached.currentParticipantCount + 1,
        );
      }
    }
    _activityChangedController.add(activityId);
    notifyListeners();
    return participation;
  }

  // ── Ratings ─────────────────────────────────────────────────────────────

  Future<ActivityRatingListResponse> listRatings(String activityId) async {
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) {
      return ActivityRatingListResponse(items: const [], average: 0, count: 0);
    }
    final res = await http
        .get(
          Uri.parse('$base/api/activities/$activityId/ratings'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      return ActivityRatingListResponse(items: const [], average: 0, count: 0);
    }
    final body = json.decode(utf8.decode(res.bodyBytes));
    if (body is! Map) {
      return ActivityRatingListResponse(items: const [], average: 0, count: 0);
    }
    return ActivityRatingListResponse.fromMap(Map<String, dynamic>.from(body));
  }

  Future<ActivityRatingModel?> createRating(
    String activityId, {
    required String ratedUserId,
    required int score,
    String? comment,
  }) async {
    final base = _baseUrl;
    final headers = await _headers(jsonBody: true);
    if (base == null || headers == null) return null;
    final res = await http
        .post(
          Uri.parse('$base/api/activities/$activityId/ratings'),
          headers: headers,
          body: json.encode({
            'ratedUserId': ratedUserId,
            'score': score,
            'comment': comment,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception(_extractError(res, 'Puan gönderilemedi'));
    }
    final body = json.decode(utf8.decode(res.bodyBytes));
    if (body is! Map) return null;
    return ActivityRatingModel.fromMap(Map<String, dynamic>.from(body));
  }

  Future<PendingRatingListResponse> listPendingRatings() async {
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) {
      return PendingRatingListResponse(items: const []);
    }
    final res = await http
        .get(
          Uri.parse('$base/api/activities/ratings/pending'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      return PendingRatingListResponse(items: const []);
    }
    final body = json.decode(utf8.decode(res.bodyBytes));
    if (body is! Map) {
      return PendingRatingListResponse(items: const []);
    }
    return PendingRatingListResponse.fromMap(Map<String, dynamic>.from(body));
  }

  Future<ActivityRatingListResponse> listUserRatings(String userId) async {
    final base = _baseUrl;
    final headers = await _headers();
    if (base == null || headers == null) {
      return ActivityRatingListResponse(items: const [], average: 0, count: 0);
    }
    final encoded = Uri.encodeComponent(userId);
    final res = await http
        .get(
          Uri.parse('$base/api/activities/users/$encoded/ratings'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      return ActivityRatingListResponse(items: const [], average: 0, count: 0);
    }
    final body = json.decode(utf8.decode(res.bodyBytes));
    if (body is! Map) {
      return ActivityRatingListResponse(items: const [], average: 0, count: 0);
    }
    return ActivityRatingListResponse.fromMap(Map<String, dynamic>.from(body));
  }

  String _extractError(http.Response res, String fallback) {
    try {
      final body = json.decode(utf8.decode(res.bodyBytes));
      if (body is Map && body['detail'] is String) {
        return body['detail'] as String;
      }
      if (body is Map && body['title'] is String) {
        return body['title'] as String;
      }
    } catch (_) {}
    return '$fallback (${res.statusCode})';
  }

  @override
  void dispose() {
    _activitySub?.cancel();
    _authSub?.cancel();
    _activityChangedController.close();
    _listChangedController.close();
    super.dispose();
  }
}
