import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_locale_service.dart';
import 'api_exception.dart';
import 'auth_service.dart';
import '../config/mode_config.dart';
import '../models/shorts_feed_scope.dart';
import 'runtime_config_service.dart';

class PulseApiService {
  static final PulseApiService instance = PulseApiService._();

  PulseApiService._();

  bool get isEnabled => RuntimeConfigService.hasBackendBaseUrl;

  String get _baseUrl =>
      RuntimeConfigService.backendBaseUrl.replaceFirst(RegExp(r'/$'), '');

  Future<dynamic> getJson(
    String path, {
    Map<String, String>? queryParameters,
    bool requiresAuth = false,
  }) =>
      _get(path, queryParameters: queryParameters, requiresAuth: requiresAuth);

  Future<dynamic> sendJson(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) => _request(
    method,
    path,
    queryParameters: queryParameters,
    body: body,
    requiresAuth: requiresAuth,
  );

  Future<dynamic> deleteJson(
    String path, {
    Map<String, String>? queryParameters,
    bool requiresAuth = false,
  }) => _request(
    'DELETE',
    path,
    queryParameters: queryParameters,
    requiresAuth: requiresAuth,
  );

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final response = await _get('/api/users/me', requiresAuth: true);
    if (response is! Map) return null;
    return _normalizeUser(Map<String, dynamic>.from(response));
  }

  Future<Map<String, dynamic>?> getLobbySnapshot() async {
    final response = await _get('/api/lobby/snapshot');
    if (response is! Map) return null;
    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>?> updateCurrentProfile(
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      'PUT',
      '/api/users/me',
      body: payload,
      requiresAuth: true,
    );
    if (response is! Map) return null;
    return _normalizeUser(Map<String, dynamic>.from(response));
  }

  Future<List<Map<String, dynamic>>> searchUsers(
    String query, {
    String? excludeUid,
  }) async {
    final response = await _get(
      '/api/users/search',
      queryParameters: {
        'q': query,
        if (excludeUid != null && excludeUid.isNotEmpty)
          'excludeUserId': excludeUid,
      },
      requiresAuth: true,
    );

    return _normalizeUserList(response);
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    final response = await _get('/api/users/$userId', requiresAuth: true);
    if (response is! Map) return null;
    return _normalizeUser(Map<String, dynamic>.from(response));
  }

  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    final response = await _get(
      '/api/users/$userId/followers',
      requiresAuth: true,
    );
    return _normalizeUserList(response);
  }

  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    final response = await _get(
      '/api/users/$userId/following',
      requiresAuth: true,
    );
    return _normalizeUserList(response);
  }

  Future<List<Map<String, dynamic>>> getFriends(String userId) async {
    final response = await _get(
      '/api/users/$userId/friends',
      requiresAuth: true,
    );
    return _normalizeUserList(response);
  }

  Future<Map<String, dynamic>?> setPinnedMoment(String? postId) async {
    final response = await _request(
      'PUT',
      '/api/users/me/pinned-moment',
      body: {'postId': postId},
      requiresAuth: true,
    );
    if (response is! Map) return null;
    return _normalizeUser(Map<String, dynamic>.from(response));
  }

  Future<List<Map<String, dynamic>>> getPlacesVisited(String userId) async {
    final response = await _get(
      '/api/users/$userId/places',
      requiresAuth: true,
    );
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> getDiscoverPeople({
    double? latitude,
    double? longitude,
    double radiusKm = 25,
    int take = 10,
    int skip = 0,
    String? mode,
    int? minAge,
    int? maxAge,
    bool? verifiedOnly,
  }) async {
    final response = await _get(
      '/api/discover/people',
      queryParameters: {
        if (latitude != null) 'latitude': '$latitude',
        if (longitude != null) 'longitude': '$longitude',
        'radiusKm': '$radiusKm',
        'take': '$take',
        'skip': '$skip',
        if (mode != null && mode.isNotEmpty) 'mode': mode,
        if (minAge != null) 'minAge': '$minAge',
        if (maxAge != null) 'maxAge': '$maxAge',
        if (verifiedOnly == true) 'verifiedOnly': 'true',
      },
      requiresAuth: true,
    );
    if (response is! Map) {
      return const {'items': <Map<String, dynamic>>[], 'totalCandidates': 0, 'cursor': ''};
    }
    final data = Map<String, dynamic>.from(response);
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => _normalizeDiscoverPerson(Map<String, dynamic>.from(item)))
              .toList()
        : <Map<String, dynamic>>[];
    return {
      'items': items,
      'totalCandidates': _toInt(data['totalCandidates']),
      'cursor': _string(data['cursor']),
    };
  }

  /// Records a left-swipe (pass) so the discover stack will not surface
  /// the same user again. Server-side is idempotent.
  Future<void> recordDiscoverPass(String targetUserId) async {
    if (targetUserId.isEmpty) return;
    await _request(
      'POST',
      '/api/discover/pass',
      requiresAuth: true,
      body: {'targetUserId': targetUserId},
    );
  }

  /// Removes a previously recorded pass (swipe rewind). Returns true when
  /// the server reports the row existed and was deleted.
  Future<bool> undoDiscoverPass(String targetUserId) async {
    if (targetUserId.isEmpty) return false;
    try {
      await _request(
        'DELETE',
        '/api/discover/pass/$targetUserId',
        requiresAuth: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSignalCrossings(String userId) async {
    final response = await _get(
      '/api/users/$userId/signal-crossings',
      requiresAuth: true,
    );
    if (response is! Map) return null;
    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>?> getPhotoVerificationStatus() async {
    final response = await _get(
      '/api/users/me/photo-verification',
      requiresAuth: true,
    );
    if (response is! Map) return null;
    return _normalizePhotoVerification(Map<String, dynamic>.from(response));
  }

  Future<Map<String, dynamic>?> submitPhotoVerification({
    required String selfieUrl,
    required String gesture,
  }) async {
    final response = await _request(
      'POST',
      '/api/users/me/photo-verification',
      body: {
        'selfieUrl': selfieUrl,
        'gesture': gesture,
      },
      requiresAuth: true,
    );
    if (response is! Map) return null;
    return _normalizePhotoVerification(Map<String, dynamic>.from(response));
  }

  Map<String, dynamic> _normalizePhotoVerification(Map<String, dynamic> data) {
    return {
      'status': _string(data['status'], fallback: 'none'),
      'isPhotoVerified': _toBool(data['isPhotoVerified']),
      'submittedAt': _stringOrNull(data['submittedAt']),
    };
  }

  Future<Map<String, dynamic>?> getRelationshipState(
    String targetUserId,
  ) async {
    final response = await _get(
      '/api/social/relationship/$targetUserId',
      requiresAuth: true,
    );
    if (response is! Map) return null;
    return Map<String, dynamic>.from(response);
  }

  Future<List<Map<String, dynamic>>> getIncomingFriendRequests() async {
    final response = await _get(
      '/api/social/friend-requests',
      requiresAuth: true,
    );
    if (response is! List) return [];
    return response.whereType<Map>().map((item) {
      final data = Map<String, dynamic>.from(item);
      return {
        'id': _string(data['id']),
        'status': _string(data['status']),
        'createdAt': _string(data['createdAt']),
        'fromUser': data['fromUser'] is Map
            ? _normalizeUser(Map<String, dynamic>.from(data['fromUser']))
            : null,
        'toUser': data['toUser'] is Map
            ? _normalizeUser(Map<String, dynamic>.from(data['toUser']))
            : null,
      };
    }).toList();
  }

  Future<Map<String, dynamic>?> sendFriendRequest(String targetUserId) async {
    final response = await _request(
      'POST',
      '/api/social/friend-requests',
      requiresAuth: true,
      body: {'targetUserId': targetUserId},
    );

    if (response is! Map) return null;
    final data = Map<String, dynamic>.from(response);
    return {
      'id': _string(data['id']),
      'status': _string(data['status']),
      'createdAt': _string(data['createdAt']),
      'fromUser': data['fromUser'] is Map
          ? _normalizeUser(Map<String, dynamic>.from(data['fromUser']))
          : null,
      'toUser': data['toUser'] is Map
          ? _normalizeUser(Map<String, dynamic>.from(data['toUser']))
          : null,
    };
  }

  Future<bool> respondToFriendRequest(
    String requestId, {
    required bool accept,
  }) async {
    final response = await _request(
      'POST',
      '/api/social/friend-requests/$requestId/${accept ? 'accept' : 'decline'}',
      requiresAuth: true,
    );
    return response != null;
  }

  Future<bool> cancelOutgoingFriendRequest(String requestId) async {
    final response = await deleteJson(
      '/api/social/friend-requests/$requestId',
      requiresAuth: true,
    );
    return response != null;
  }

  Future<bool> removeFriend(String targetUserId) async {
    final response = await deleteJson(
      '/api/social/friends/$targetUserId',
      requiresAuth: true,
    );
    return response != null;
  }

  Future<Map<String, dynamic>?> toggleFollow(String targetUserId) async {
    final response = await _request(
      'POST',
      '/api/social/follow/toggle',
      requiresAuth: true,
      body: {'targetUserId': targetUserId},
    );
    if (response is! Map) return null;
    return Map<String, dynamic>.from(response);
  }

  Future<bool> blockUser(String targetUserId) async {
    final response = await _request(
      'POST',
      '/api/social/block',
      requiresAuth: true,
      body: {'targetUserId': targetUserId},
    );
    return response != null;
  }

  Future<bool> unblockUser(String targetUserId) async {
    final response = await _request(
      'POST',
      '/api/social/unblock',
      requiresAuth: true,
      body: {'targetUserId': targetUserId},
    );
    return response != null;
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final response = await _get('/api/social/blocked', requiresAuth: true);
    if (response is! List) return [];
    return response.whereType<Map>().map((item) {
      final data = Map<String, dynamic>.from(item);
      return {
        'userId': _string(data['userId']),
        'displayName': _string(data['displayName']),
        'profilePhotoUrl': _string(data['profilePhotoUrl']),
        'blockedAt': _string(data['blockedAt']),
      };
    }).toList();
  }

  Future<bool> reportUser({
    required String targetUserId,
    required String reason,
    String details = '',
  }) async {
    final response = await _request(
      'POST',
      '/api/social/report',
      requiresAuth: true,
      body: {
        'targetUserId': targetUserId,
        'reason': reason,
        'details': details,
      },
    );
    return response != null;
  }

  Future<List<Map<String, dynamic>>> getChats({
    int skip = 0,
    int take = 25,
    bool includeArchived = false,
  }) async {
    final response = await _get(
      '/api/chats',
      queryParameters: {
        'skip': '$skip',
        'take': '$take',
        'includeArchived': '$includeArchived',
      },
      requiresAuth: true,
    );
    if (response is! List) return [];
    return response
        .whereType<Map>()
        .map((item) => _normalizeChat(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>?> getChat(String chatId) async {
    final response = await _get('/api/chats/$chatId', requiresAuth: true);
    if (response is! Map) return null;
    return _normalizeChat(Map<String, dynamic>.from(response));
  }

  Future<Map<String, dynamic>?> createOrGetDirectChat(
    String otherUserId, {
    bool isTemporary = false,
  }) async {
    final response = await _request(
      'POST',
      '/api/chats/direct',
      requiresAuth: true,
      body: {'otherUserId': otherUserId, 'isTemporary': isTemporary},
    );
    if (response is! Map) return null;
    return _normalizeChat(Map<String, dynamic>.from(response));
  }

  Future<List<Map<String, dynamic>>> getMessages(
    String chatId, {
    int skip = 0,
    int take = 50,
  }) async {
    final response = await _get(
      '/api/chats/$chatId/messages',
      queryParameters: {'skip': '$skip', 'take': '$take'},
      requiresAuth: true,
    );
    if (response is! List) return [];
    return response
        .whereType<Map>()
        .map((item) => _normalizeMessage(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>?> sendMessage(
    String chatId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      'POST',
      '/api/chats/$chatId/messages',
      requiresAuth: true,
      body: payload,
    );
    if (response is! Map) return null;
    return _normalizeMessage(Map<String, dynamic>.from(response));
  }

  Future<bool> updateMessageStatus(
    String chatId,
    String messageId,
    String status,
  ) async {
    final response = await _request(
      'POST',
      '/api/chats/$chatId/messages/$messageId/status',
      requiresAuth: true,
      body: {'status': status},
    );
    return response != null;
  }

  Future<bool> updateReaction(
    String chatId,
    String messageId,
    String? reaction,
  ) async {
    final response = await _request(
      'POST',
      '/api/chats/$chatId/messages/$messageId/reaction',
      requiresAuth: true,
      body: {'reaction': reaction},
    );
    return response != null;
  }

  Future<bool> deleteMessage(
    String chatId,
    String messageId, {
    String scope = 'everyone',
  }) async {
    final response = await deleteJson(
      '/api/chats/$chatId/messages/$messageId',
      queryParameters: {'scope': scope},
      requiresAuth: true,
    );
    return response != null;
  }

  Future<bool> setTyping(String chatId, bool isTyping) async {
    final response = await _request(
      'POST',
      '/api/chats/$chatId/typing',
      requiresAuth: true,
      body: {'isTyping': isTyping},
    );
    return response != null;
  }

  Future<bool> setChatArchived(String chatId, bool isArchived) async {
    final response = await _request(
      'POST',
      '/api/chats/$chatId/${isArchived ? 'archive' : 'unarchive'}',
      requiresAuth: true,
    );
    return response != null;
  }

  Future<bool> markChatAsRead(String chatId) async {
    final response = await _request(
      'POST',
      '/api/chats/$chatId/read',
      requiresAuth: true,
    );
    return response != null;
  }

  Future<bool> convertToFriendChat(String chatId) async {
    final response = await _request(
      'POST',
      '/api/chats/$chatId/convert-to-friend',
      requiresAuth: true,
    );
    return response != null;
  }

  /// Returns "pending" | "accepted" | "already_permanent" | "error"
  Future<String> requestChatPermanence(String chatId) async {
    try {
      final response = await _request(
        'POST',
        '/api/chats/$chatId/request-permanence',
        requiresAuth: true,
      );
      if (response is Map) {
        return (response['status'] as String?) ?? 'error';
      }
      return 'error';
    } catch (_) {
      return 'error';
    }
  }

  Future<bool> deleteChat(String chatId) async {
    final response = await deleteJson('/api/chats/$chatId', requiresAuth: true);
    return response != null;
  }

  Future<List<Map<String, dynamic>>> getFeedPosts({
    String? vibeTag,
    String? type,
    int take = 20,
  }) async {
    final response = await _get(
      '/api/posts/feed',
      queryParameters: {
        'take': '$take',
        if (vibeTag != null && vibeTag.isNotEmpty) 'vibeTag': vibeTag,
        if (type != null && type.isNotEmpty) 'type': type,
      },
      requiresAuth: AuthService().isLoggedIn,
    );
    return _normalizePostList(response);
  }

  Future<List<Map<String, dynamic>>> getShortsFeed({
    required ShortsFeedScope scope,
    double? latitude,
    double? longitude,
    double radiusKm = 4.5,
    int take = 24,
  }) async {
    final response = await _get(
      '/api/posts/shorts',
      queryParameters: {
        'scope': scope.apiValue,
        'take': '$take',
        if (latitude != null) 'latitude': '$latitude',
        if (longitude != null) 'longitude': '$longitude',
        'radiusKm': '$radiusKm',
      },
      requiresAuth: AuthService().isLoggedIn,
    );
    return _normalizePostList(response);
  }

  Future<List<Map<String, dynamic>>> getUserPosts(
    String userId, {
    String? type,
  }) async {
    final response = await _get(
      '/api/posts/user/$userId',
      queryParameters: {if (type != null && type.isNotEmpty) 'type': type},
      requiresAuth: AuthService().isLoggedIn,
    );
    return _normalizePostList(response);
  }

  Future<List<Map<String, dynamic>>> getSavedPosts() async {
    final response = await _get('/api/posts/saved', requiresAuth: true);
    return _normalizePostList(response);
  }

  Future<Map<String, dynamic>?> createPost(Map<String, dynamic> payload) async {
    final response = await _request(
      'POST',
      '/api/posts',
      requiresAuth: true,
      body: payload,
    );
    if (response is! Map) return null;
    return _normalizePost(Map<String, dynamic>.from(response));
  }

  Future<Map<String, dynamic>?> updatePost(
    String postId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      'PATCH',
      '/api/posts/$postId',
      requiresAuth: true,
      body: payload,
    );
    if (response is! Map) return null;
    return _normalizePost(Map<String, dynamic>.from(response));
  }

  Future<Map<String, dynamic>?> toggleLike(String postId) async {
    final response = await _request(
      'POST',
      '/api/posts/$postId/likes/toggle',
      requiresAuth: true,
    );
    if (response is! Map) return null;
    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>?> toggleSavePost(String postId) async {
    final response = await _request(
      'POST',
      '/api/posts/$postId/save',
      requiresAuth: true,
    );
    if (response is! Map) return null;
    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>?> addPostComment(
    String postId,
    String text,
  ) async {
    final response = await _request(
      'POST',
      '/api/posts/$postId/comments',
      requiresAuth: true,
      body: {'text': text},
    );
    if (response is! Map) return null;
    return _normalizePostComment(Map<String, dynamic>.from(response));
  }

  Future<List<Map<String, dynamic>>> getPostComments(
    String postId, {
    int skip = 0,
    int take = 50,
  }) async {
    final response = await _get(
      '/api/posts/$postId/comments',
      queryParameters: {'skip': '$skip', 'take': '$take'},
      requiresAuth: AuthService().isLoggedIn,
    );
    if (response is! List) return [];
    return response
        .whereType<Map>()
        .map((item) => _normalizePostComment(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>?> updatePostComment(
    String postId,
    String commentId,
    String text,
  ) async {
    final response = await _request(
      'PATCH',
      '/api/posts/$postId/comments/$commentId',
      requiresAuth: true,
      body: {'text': text},
    );
    if (response is! Map) return null;
    return _normalizePostComment(Map<String, dynamic>.from(response));
  }

  Future<bool> deletePost(String postId) async {
    final response = await deleteJson('/api/posts/$postId', requiresAuth: true);
    return response != null;
  }

  Future<bool> deletePostComment(String postId, String commentId) async {
    final response = await deleteJson(
      '/api/posts/$postId/comments/$commentId',
      requiresAuth: true,
    );
    return response != null;
  }

  Future<List<Map<String, dynamic>>> getNearbyPlaces({
    required double lat,
    required double lng,
    required String modeId,
    int radius = 1500,
    bool requireOpenNow = false,
    String sortBy = 'moment',
  }) async {
    final response = await _get(
      '/api/places/nearby',
      queryParameters: {
        'latitude': '$lat',
        'longitude': '$lng',
        'modeId': modeId,
        'languageCode': AppLocaleService.instance.languageCode,
        'radius': '$radius',
        'sortBy': sortBy,
        if (requireOpenNow) 'requireOpenNow': 'true',
      },
      requiresAuth: AuthService().isLoggedIn,
    );
    if (response is! List) return [];
    return response
        .whereType<Map>()
        .map((item) => _normalizePlaceSummary(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>?> getPlaceDetails(
    String placeId, {
    double? lat,
    double? lng,
    String modeId = ModeConfig.defaultId,
  }) async {
    final response = await _get(
      '/api/places/$placeId',
      queryParameters: {
        'modeId': modeId,
        'languageCode': AppLocaleService.instance.languageCode,
        if (lat != null) 'latitude': '$lat',
        if (lng != null) 'longitude': '$lng',
      },
      requiresAuth: AuthService().isLoggedIn,
    );
    if (response is! Map) return null;
    return _normalizePlaceDetail(Map<String, dynamic>.from(response));
  }

  Future<List<Map<String, dynamic>>> getForecast({
    required double lat,
    required double lng,
    required String modeId,
    int radius = 1500,
    bool requireOpenNow = false,
  }) async {
    final response = await _get(
      '/api/places/forecast',
      queryParameters: {
        'latitude': '$lat',
        'longitude': '$lng',
        'modeId': modeId,
        'languageCode': AppLocaleService.instance.languageCode,
        'radius': '$radius',
        if (requireOpenNow) 'requireOpenNow': 'true',
      },
      requiresAuth: AuthService().isLoggedIn,
    );
    if (response is! List) return [];
    return response.whereType<Map>().map((item) {
      final data = Map<String, dynamic>.from(item);
      return {
        'offset_hours': _toInt(data['offsetHours']),
        'time': _string(data['time']),
        'label': _string(data['label']),
        'score': _toInt(data['score']),
        'confidence': _toInt(data['confidence']),
        'place': data['topPlace'] is Map
            ? _normalizePlaceSummary(
                Map<String, dynamic>.from(data['topPlace']),
              )
            : const <String, dynamic>{},
      };
    }).toList();
  }

  Future<bool> toggleSavePlace(Map<String, dynamic> place) async {
    final response = await _request(
      'POST',
      '/api/places/save',
      requiresAuth: true,
      body: {
        'placeId': _string(place['place_id'] ?? place['placeId']),
        'placeName': _string(place['name'] ?? place['placeName']),
        'vicinity': _string(place['vicinity']),
        'latitude': _toDoubleOrNull(place['lat'] ?? place['latitude']),
        'longitude': _toDoubleOrNull(place['lng'] ?? place['longitude']),
      },
    );
    if (response is! Map) return false;
    return _toBool(response['saved']);
  }

  Future<Map<String, Map<String, dynamic>>> getPlaceCommunitySignals(
    List<Map<String, dynamic>> places,
  ) async {
    final response = await _request(
      'POST',
      '/api/places/community-signals',
      requiresAuth: AuthService().isLoggedIn,
      body: {
        'places': places
            .map(
              (place) => {
                'placeId': _string(place['place_id'] ?? place['placeId']),
                'name': _string(place['name']),
                'vicinity': _string(place['vicinity']),
              },
            )
            .where(
              (item) =>
                  (item['placeId'] ?? '').toString().isNotEmpty &&
                  (item['name'] ?? '').toString().isNotEmpty,
            )
            .toList(),
      },
    );

    if (response is! List) return {};

    final mapped = <String, Map<String, dynamic>>{};
    for (final item in response.whereType<Map>()) {
      final data = Map<String, dynamic>.from(item);
      final placeId = _string(data['placeId']);
      if (placeId.isEmpty) continue;
      mapped[placeId] = {
        'posts': _toInt(data['posts']),
        'shorts': _toInt(data['shorts']),
        'likes': _toInt(data['likes']),
        'comments': _toInt(data['comments']),
        'creators': _toInt(data['creators']),
      };
    }
    return mapped;
  }

  Future<bool> updatePresence({
    required double latitude,
    required double longitude,
    required String city,
    required String mode,
    required bool shareProfile,
    required bool isSignalActive,
    bool isOnline = true,
  }) async {
    final response = await _request(
      'POST',
      '/api/presence',
      requiresAuth: true,
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'city': city,
        'mode': mode,
        'shareProfile': shareProfile,
        'isSignalActive': isSignalActive,
        'isOnline': isOnline,
      },
    );
    return response != null;
  }

  Future<bool> updateOnlineStatus(bool isOnline) async {
    final response = await _request(
      'POST',
      '/api/presence/online-status',
      requiresAuth: true,
      body: {'isOnline': isOnline},
    );
    return response != null;
  }

  Future<List<Map<String, dynamic>>> getNearbyUsers({
    required double latitude,
    required double longitude,
    double radiusKm = 1.0,
    bool signalOnly = false,
  }) async {
    final response = await _get(
      '/api/presence/nearby',
      queryParameters: {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'radiusKm': '$radiusKm',
        if (signalOnly) 'signalOnly': 'true',
      },
      requiresAuth: true,
    );
    return _normalizeUserList(response);
  }

  Future<List<Map<String, dynamic>>> getHighlights(String userId) async {
    final response = await _get(
      '/api/users/$userId/highlights',
      requiresAuth: true,
    );
    return _normalizeHighlightList(response);
  }

  Future<List<Map<String, dynamic>>> getStories(String userId) async {
    final response = await _get(
      '/api/users/$userId/stories',
      requiresAuth: true,
    );
    return _normalizeHighlightList(response);
  }

  Future<bool> deleteHighlight(String userId, String highlightId) async {
    final response = await deleteJson(
      '/api/users/$userId/highlights/$highlightId',
      requiresAuth: true,
    );
    return response != null;
  }

  Future<bool> deleteStory(String userId, String storyId) async {
    final response = await deleteJson(
      '/api/users/$userId/stories/$storyId',
      requiresAuth: true,
    );
    return response != null;
  }

  Future<bool> markStoryViewed(String storyId) async {
    final response = await _request(
      'POST',
      '/api/stories/$storyId/view',
      requiresAuth: true,
    );
    return response == null ||
        response is Map ||
        response is List ||
        response is String;
  }

  List<Map<String, dynamic>> _normalizeHighlightList(dynamic response) {
    if (response is! List) return [];
    return response.whereType<Map>().map((item) {
      final data = Map<String, dynamic>.from(item);
      return {
        'id': _string(data['id']),
        'userId': _string(data['userId']),
        'title': _string(data['title']),
        'coverUrl': _string(data['coverUrl']),
        'mediaUrls': _toStringList(data['mediaUrls']),
        'type': _string(data['type'], fallback: 'image'),
        'textColorHex': _string(data['textColorHex'], fallback: '#FFFFFF'),
        'textOffsetX': _toDouble(data['textOffsetX']),
        'textOffsetY': _toDouble(data['textOffsetY']),
        'modeTag': _string(data['modeTag']),
        'locationLabel': _string(data['locationLabel']),
        'placeId': _string(data['placeId']),
        'showModeOverlay': _toBool(data['showModeOverlay']),
        'showLocationOverlay': _toBool(data['showLocationOverlay']),
        'entryKind': _string(data['entryKind'], fallback: 'highlight'),
        'expiresAt': _string(data['expiresAt']),
        'createdAt': _string(data['createdAt']),
        'seenByCurrentUser': _toBool(data['seenByCurrentUser']),
        'viewCount': _toInt(data['viewCount']),
        'viewers': (data['viewers'] as List? ?? const []).whereType<Map>().map((
          item,
        ) {
          final viewer = Map<String, dynamic>.from(item);
          return {
            'userId': _string(viewer['userId']),
            'userName': _string(viewer['userName']),
            'displayName': _string(viewer['displayName']),
            'profilePhotoUrl': _string(viewer['profilePhotoUrl']),
            'viewedAt': _string(viewer['viewedAt']),
          };
        }).toList(),
      };
    }).toList();
  }

  Future<Map<String, dynamic>?> createHighlight(
    String userId, {
    required String title,
    required String coverUrl,
    List<String> mediaUrls = const [],
    String type = 'image',
    String textColorHex = '#FFFFFF',
    double textOffsetX = 0,
    double textOffsetY = 0,
    String modeTag = '',
    String locationLabel = '',
    String placeId = '',
    bool showModeOverlay = false,
    bool showLocationOverlay = false,
    int? durationHours,
  }) async {
    final response = await _request(
      'POST',
      '/api/users/$userId/highlights',
      requiresAuth: true,
      body: {
        'title': title,
        'coverUrl': coverUrl,
        'mediaUrls': mediaUrls,
        'type': type,
        'textColorHex': textColorHex,
        'textOffsetX': textOffsetX,
        'textOffsetY': textOffsetY,
        'modeTag': modeTag,
        'locationLabel': locationLabel,
        'placeId': placeId,
        'showModeOverlay': showModeOverlay,
        'showLocationOverlay': showLocationOverlay,
        ...?(durationHours == null ? null : {'durationHours': durationHours}),
      },
    );
    if (response is! Map) return null;
    final normalized = _normalizeHighlightList([response]);
    return normalized.isEmpty ? null : normalized.first;
  }

  Future<Map<String, dynamic>?> createStory(
    String userId, {
    required String title,
    required String coverUrl,
    List<String> mediaUrls = const [],
    String type = 'image',
    String textColorHex = '#FFFFFF',
    double textOffsetX = 0,
    double textOffsetY = 0,
    String modeTag = '',
    String locationLabel = '',
    String placeId = '',
    bool showModeOverlay = false,
    bool showLocationOverlay = false,
    int durationHours = 24,
  }) async {
    final response = await _request(
      'POST',
      '/api/users/$userId/stories',
      requiresAuth: true,
      body: {
        'title': title,
        'coverUrl': coverUrl,
        'mediaUrls': mediaUrls,
        'type': type,
        'textColorHex': textColorHex,
        'textOffsetX': textOffsetX,
        'textOffsetY': textOffsetY,
        'modeTag': modeTag,
        'locationLabel': locationLabel,
        'placeId': placeId,
        'showModeOverlay': showModeOverlay,
        'showLocationOverlay': showLocationOverlay,
        'durationHours': durationHours,
      },
    );
    if (response is! Map) return null;
    final normalized = _normalizeHighlightList([response]);
    return normalized.isEmpty ? null : normalized.first;
  }

  Future<Map<String, dynamic>?> exportMyData() async {
    final response = await _request(
      'POST',
      '/api/users/me/export',
      requiresAuth: true,
    );
    if (response is! Map) return null;
    return {
      'id': _string(response['id']),
      'status': _string(response['status']),
      'fileName': _string(response['fileName']),
      'downloadUrl': _string(response['downloadUrl']),
      'fileSizeBytes': _toInt(response['fileSizeBytes']),
      'createdAt': _string(response['createdAt']),
      'expiresAt': _string(response['expiresAt']),
    };
  }

  Future<List<Map<String, dynamic>>> getPendingIncomingMatches() async {
    final response = await _get(
      '/api/matches/incoming/pending',
      requiresAuth: true,
    );
    if (response is! List) return [];
    return response
        .whereType<Map>()
        .map((item) => _normalizeMatch(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAllMatches() async {
    final response = await _get('/api/matches', requiresAuth: true);
    if (response is! List) return [];
    return response
        .whereType<Map>()
        .map((item) => _normalizeMatch(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// "Beni Beğenenler" inbox: pending matches where the caller is the
  /// recipient. Backed by `GET /api/matches/likes-me`. Returns a structured
  /// payload with the total count (for the badge), a `hasMore` flag, and a
  /// page of items pre-projected for the UI.
  Future<Map<String, dynamic>> getLikesMe({int limit = 20}) async {
    final clamped = limit.clamp(1, 50);
    final response = await _get(
      '/api/matches/likes-me',
      queryParameters: {'limit': '$clamped'},
      requiresAuth: true,
    );
    if (response is! Map) {
      return {'totalCount': 0, 'hasMore': false, 'items': const <Map<String, dynamic>>[]};
    }
    final map = Map<String, dynamic>.from(response);
    final rawItems = map['items'];
    final items = (rawItems is List ? rawItems : const [])
        .whereType<Map>()
        .map((item) => _normalizeLikesMeEntry(Map<String, dynamic>.from(item)))
        .toList();
    return {
      'totalCount': _toInt(map['totalCount']),
      'hasMore': _toBool(map['hasMore']),
      'items': items,
    };
  }

  Future<Map<String, dynamic>?> createMatch({
    required String otherUserId,
    required int compatibility,
    List<String> commonInterests = const [],
    bool anonymousInChat = false,
  }) async {
    final response = await _request(
      'POST',
      '/api/matches',
      requiresAuth: true,
      body: {
        'otherUserId': otherUserId,
        'compatibility': compatibility,
        'commonInterests': commonInterests,
        'anonymousInChat': anonymousInChat,
      },
    );
    if (response is! Map) return null;
    return _normalizeMatch(Map<String, dynamic>.from(response));
  }

  Future<bool> respondToMatch(
    String matchId, {
    required String status,
    String? chatId,
    bool anonymousInChat = false,
  }) async {
    final response = await _request(
      'POST',
      '/api/matches/$matchId/respond',
      requiresAuth: true,
      body: {
        'status': status,
        if (chatId != null && chatId.isNotEmpty) 'chatId': chatId,
        'anonymousInChat': anonymousInChat,
      },
    );
    return response != null;
  }

  Future<dynamic> _get(
    String path, {
    Map<String, String>? queryParameters,
    bool requiresAuth = false,
  }) => _request(
    'GET',
    path,
    queryParameters: queryParameters,
    requiresAuth: requiresAuth,
  );

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    final uri = _buildUri(path, queryParameters: queryParameters);
    final headers = await _headers(
      requiresAuth || AuthService().isLoggedIn,
      includeJsonContentType: body != null,
    );

    late http.Response response;
    switch (method.toUpperCase()) {
      case 'GET':
        response = await _guardRequest(
          () => http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15)),
          maxRetries: 2,
        );
        break;
      case 'POST':
        response = await _guardRequest(
          () => http
              .post(
                uri,
                headers: headers,
                body: body == null ? null : json.encode(body),
              )
              .timeout(const Duration(seconds: 20)),
        );
        break;
      case 'PUT':
        response = await _guardRequest(
          () => http
              .put(
                uri,
                headers: headers,
                body: body == null ? null : json.encode(body),
              )
              .timeout(const Duration(seconds: 20)),
        );
        break;
      case 'PATCH':
        response = await _guardRequest(
          () => http
              .patch(
                uri,
                headers: headers,
                body: body == null ? null : json.encode(body),
              )
              .timeout(const Duration(seconds: 20)),
        );
        break;
      case 'DELETE':
        response = await _guardRequest(
          () => http
              .delete(
                uri,
                headers: headers,
                body: body == null ? null : json.encode(body),
              )
              .timeout(const Duration(seconds: 20)),
        );
        break;
      default:
        throw UnsupportedError('Unsupported HTTP method: $method');
    }

    return _decodeResponse(response);
  }

  Uri _buildUri(String path, {Map<String, String>? queryParameters}) {
    if (_baseUrl.isEmpty) {
      throw const ApiException(
        'Backend base URL is not configured.',
        kind: ApiErrorKind.validation,
      );
    }

    final filtered = <String, String>{};
    for (final entry in (queryParameters ?? const <String, String>{}).entries) {
      if (entry.value.trim().isEmpty) continue;
      filtered[entry.key] = entry.value;
    }

    final base = Uri.parse('$_baseUrl$path');
    return filtered.isEmpty
        ? base
        : base.replace(queryParameters: {...base.queryParameters, ...filtered});
  }

  Future<Map<String, String>> _headers(
    bool includeAuthorization, {
    bool includeJsonContentType = false,
  }) async {
    final headers = includeAuthorization
        ? await AuthService().authorizedHeaders()
        : <String, String>{
            'Accept': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          };

    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  dynamic _decodeResponse(http.Response response) {
    dynamic payload;
    if (response.body.isNotEmpty) {
      try {
        payload = json.decode(response.body);
      } catch (e) {
        debugPrint('JSON decode failed: $e');
        payload = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload;
    }

    if (response.statusCode == 401) {
      debugPrint('API returned 401 — session expired, logging out');
      AuthService().logout(notify: true);
    }

    String? message;
    if (payload is Map) {
      if (payload['detail'] != null) {
        message = payload['detail'].toString();
      }
      if (message == null && payload['message'] != null) {
        message = payload['message'].toString();
      }
      if (message == null && payload['title'] != null) {
        message = payload['title'].toString();
      }
    }

    throw ApiException.fromStatus(response.statusCode, message: message);
  }

  Future<http.Response> _guardRequest(
    Future<http.Response> Function() action, {
    int maxRetries = 0,
  }) async {
    ApiException? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await action();
      } on TimeoutException {
        lastError = const ApiException(
          'The request timed out. Please try again.',
          kind: ApiErrorKind.timeout,
        );
      } on SocketException {
        lastError = const ApiException(
          'No network connection is available.',
          kind: ApiErrorKind.network,
        );
      } on http.ClientException catch (error) {
        lastError = ApiException(error.message, kind: ApiErrorKind.network);
      }
      if (attempt < maxRetries) {
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    throw lastError!;
  }

  List<Map<String, dynamic>> _normalizeUserList(dynamic response) {
    if (response is! List) return [];
    return response
        .whereType<Map>()
        .map((item) => _normalizeUser(Map<String, dynamic>.from(item)))
        .toList();
  }

  Map<String, dynamic> _normalizeUser(Map<String, dynamic> data) {
    final id = _string(data['id'] ?? data['uid']);
    final latitude = _toDoubleOrNull(data['latitude']);
    final longitude = _toDoubleOrNull(data['longitude']);
    final location = latitude == null || longitude == null
        ? null
        : {'latitude': latitude, 'longitude': longitude};

    return {
      'id': id,
      'uid': id,
      'email': _string(data['email']),
      'firstName': _string(data['firstName']),
      'lastName': _string(data['lastName']),
      'userName': _string(data['userName']),
      'username': _string(data['userName']),
      'displayName': _string(data['displayName']),
      'bio': _string(data['bio']),
      'city': _string(data['city']),
      'website': _string(data['website']),
      'gender': _string(data['gender']),
      'birthDate': _stringOrNull(data['birthDate']),
      'age': _toInt(data['age']),
      'purpose': _string(data['purpose']),
      'matchPreference': _string(data['matchPreference'], fallback: 'auto'),
      'mode': ModeConfig.normalizeId(_string(data['mode'])),
      'privacyLevel': _string(data['privacyLevel'], fallback: 'full'),
      'preferredLanguage': _string(data['preferredLanguage'], fallback: 'tr'),
      'locationGranularity': _string(
        data['locationGranularity'],
        fallback: 'nearby',
      ),
      'enableDifferentialPrivacy': _toBool(
        data['enableDifferentialPrivacy'],
        fallback: true,
      ),
      'kAnonymityLevel': _toInt(data['kAnonymityLevel']) == 0
          ? 3
          : _toInt(data['kAnonymityLevel']),
      'allowAnalytics': _toBool(data['allowAnalytics'], fallback: true),
      'isVisible': _toBool(data['isVisible'], fallback: true),
      'isOnline': _toBool(data['isOnline']),
      'profilePhotoUrl': _string(data['profilePhotoUrl']),
      'photoUrls': _toStringList(data['photoUrls']),
      'interests': _toStringList(data['interests']),
      ...?(latitude == null ? null : {'latitude': latitude}),
      ...?(longitude == null ? null : {'longitude': longitude}),
      ...?(location == null ? null : {'location': location}),
      'lastSeenAt': _string(data['lastSeenAt']),
      'lastSeen': _string(data['lastSeenAt']),
      'createdAt': _string(data['createdAt']),
      'followersCount': _toInt(data['followersCount']),
      'followingCount': _toInt(data['followingCount']),
      'friendsCount': _toInt(data['friendsCount']),
      'pulseScore': _toInt(data['pulseScore']),
      'placesVisited': _toInt(data['placesVisited']),
      'vibeTagsCreated': _toInt(data['vibeTagsCreated']),
      'distanceMeters': _toDoubleOrNull(data['distanceMeters']),
      'shareProfile': _toBool(data['shareProfile'], fallback: true),
      'isSignalActive': _toBool(data['isSignalActive']),
      'pinnedPostId': _stringOrNull(data['pinnedPostId']),
      'pinnedAt': _stringOrNull(data['pinnedAt']),
      'orientation': _string(data['orientation']),
      'relationshipIntent': _string(data['relationshipIntent']),
      'heightCm': _toIntOrNull(data['heightCm']),
      'drinkingStatus': _string(data['drinkingStatus']),
      'smokingStatus': _string(data['smokingStatus']),
      'isPhotoVerified': _toBool(data['isPhotoVerified']),
      'verificationStatus': _string(data['verificationStatus']),
      'verificationSubmittedAt': _stringOrNull(data['verificationSubmittedAt']),
      'datingPrompts': _toStringMap(data['datingPrompts']),
      'lookingForModes': _toStringList(data['lookingForModes']),
      'dealbreakers': _toStringList(data['dealbreakers']),
      'enabledFeatures': _toBoolMap(data['enabledFeatures']),
    };
  }

  Map<String, String> _toStringMap(dynamic value) {
    if (value is Map) {
      final result = <String, String>{};
      value.forEach((key, v) {
        if (key == null) return;
        result[key.toString()] = v?.toString() ?? '';
      });
      return result;
    }
    return const {};
  }

  Map<String, bool> _toBoolMap(dynamic value) {
    if (value is Map) {
      final result = <String, bool>{};
      value.forEach((key, v) {
        if (key == null) return;
        result[key.toString()] = _toBool(v);
      });
      return result;
    }
    return const {};
  }

  Map<String, dynamic> _normalizeDiscoverPerson(Map<String, dynamic> data) {
    return {
      'id': _string(data['id']),
      'displayName': _string(data['displayName']),
      'userName': _string(data['userName']),
      'bio': _string(data['bio']),
      'city': _string(data['city']),
      'gender': _string(data['gender']),
      'age': _toInt(data['age']),
      'mode': ModeConfig.normalizeId(_string(data['mode'])),
      'profilePhotoUrl': _string(data['profilePhotoUrl']),
      'photoUrls': _toStringList(data['photoUrls']),
      'interests': _toStringList(data['interests']),
      'orientation': _string(data['orientation']),
      'relationshipIntent': _string(data['relationshipIntent']),
      'heightCm': _toIntOrNull(data['heightCm']),
      'drinkingStatus': _string(data['drinkingStatus']),
      'smokingStatus': _string(data['smokingStatus']),
      'isPhotoVerified': _toBool(data['isPhotoVerified']),
      'datingPrompts': _toStringMap(data['datingPrompts']),
      'distanceKm': _toDoubleOrNull(data['distanceKm']) ?? 0.0,
      'chemistryScore': _toInt(data['chemistryScore']),
      'chemistryTier': _string(data['chemistryTier'], fallback: 'casual'),
      'sharedInterests': _toStringList(data['sharedInterests']),
    };
  }

  Map<String, dynamic> _normalizeChat(Map<String, dynamic> data) {
    final id = _string(data['id']);
    final participants = (data['participants'] as List? ?? const [])
        .whereType<Map>()
        .map((item) {
          final participant = Map<String, dynamic>.from(item);
          return {
            'userId': _string(participant['userId']),
            'uid': _string(participant['userId']),
            'userName': _string(participant['userName']),
            'displayName': _string(participant['displayName']),
            'profilePhotoUrl': _string(participant['profilePhotoUrl']),
            'mode': _string(participant['mode']),
            'privacyLevel': _string(participant['privacyLevel']),
            'isVisible': _toBool(participant['isVisible'], fallback: true),
            'isOnline': _toBool(participant['isOnline']),
            'unreadCount': _toInt(participant['unreadCount']),
            'isTyping': _toBool(participant['isTyping']),
            'joinedAt': _string(participant['joinedAt']),
            'lastReadAt': _string(participant['lastReadAt']),
          };
        })
        .toList();

    return {
      'id': id,
      'createdByUserId': _string(data['createdByUserId']),
      'directMessageKey': _string(data['directMessageKey']),
      'currentUserIsArchived': _toBool(data['currentUserIsArchived']),
      'participants': participants,
      'lastMessage': _string(data['lastMessage']),
      'lastSenderId': _string(data['lastSenderId']),
      'lastMessageTime': _string(data['lastMessageTime']),
      'createdAt': _string(data['createdAt']),
      'expiresAt': _string(data['expiresAt']),
      'isTemporary': _toBool(data['isTemporary']),
      'isFriendChat': _toBool(data['isFriendChat']),
    };
  }

  Map<String, dynamic> _normalizeMessage(Map<String, dynamic> data) {
    final id = _string(data['id']);
    return {
      'id': id,
      'senderId': _string(data['senderId']),
      'senderDisplayName': _string(data['senderDisplayName']),
      'senderProfilePhotoUrl': _string(data['senderProfilePhotoUrl']),
      'text': _string(data['text']),
      'type': _string(data['type'], fallback: 'text'),
      'status': _string(data['status'], fallback: 'sent'),
      'createdAt': _string(data['createdAt']),
      'updatedAt': _stringOrNull(data['updatedAt']),
      'deletedAt': _stringOrNull(data['deletedAt']),
      'deletedForEveryone': _toBool(data['deletedForEveryone']),
      'photoUrl': _stringOrNull(data['photoUrl']),
      'videoUrl': _stringOrNull(data['videoUrl']),
      'latitude': _toDoubleOrNull(data['latitude']),
      'longitude': _toDoubleOrNull(data['longitude']),
      'photoApproved': data['photoApproved'],
      'reaction': _stringOrNull(data['reaction']),
      'disappearSeconds': _toIntOrNull(data['disappearSeconds']),
      'sharedPostId': _stringOrNull(data['sharedPostId']),
      'sharedPostAuthor': _stringOrNull(data['sharedPostAuthor']),
      'sharedPostLocation': _stringOrNull(data['sharedPostLocation']),
      'sharedPostVibe': _stringOrNull(data['sharedPostVibe']),
      'sharedPostMediaUrl': _stringOrNull(data['sharedPostMediaUrl']),
    };
  }

  List<Map<String, dynamic>> _normalizePostList(dynamic response) {
    if (response is! List) return [];
    return response
        .whereType<Map>()
        .map((item) => _normalizePost(Map<String, dynamic>.from(item)))
        .toList();
  }

  Map<String, dynamic> _normalizePost(Map<String, dynamic> data) {
    final id = _string(data['id']);
    return {
      'id': id,
      'userId': _string(data['userId']),
      'userDisplayName': _string(data['userDisplayName']),
      'userProfilePhotoUrl': _string(data['userProfilePhotoUrl']),
      'text': _string(data['text']),
      'location': _string(data['location']),
      'placeId': _string(data['placeId']),
      'latitude': _toDoubleOrNull(data['latitude']),
      'longitude': _toDoubleOrNull(data['longitude']),
      'lat': _toDoubleOrNull(data['latitude']),
      'lng': _toDoubleOrNull(data['longitude']),
      'photoUrls': _toStringList(data['photoUrls']),
      'videoUrl': _stringOrNull(data['videoUrl']),
      'rating': _toDouble(data['rating']),
      'vibeTag': _string(data['vibeTag']),
      'type': _string(data['type'], fallback: 'post'),
      'likesCount': _toInt(data['likesCount']),
      'likedByCurrentUser': _toBool(data['likedByCurrentUser']),
      'savedByCurrentUser': _toBool(data['savedByCurrentUser']),
      'commentsCount': _toInt(data['commentsCount']),
      'createdAt': _string(data['createdAt']),
      'updatedAt':
          _stringOrNull(data['updatedAt']) ?? _string(data['createdAt']),
      'userMode': _string(data['userMode']),
      'distanceMeters': _toDoubleOrNull(data['distanceMeters']),
    };
  }

  Map<String, dynamic> _normalizePostComment(Map<String, dynamic> data) {
    return {
      'id': _string(data['id']),
      'postId': _string(data['postId']),
      'userId': _string(data['userId']),
      'userDisplayName': _string(data['userDisplayName']),
      'userProfilePhotoUrl': _string(data['userProfilePhotoUrl']),
      'text': _string(data['text']),
      'createdAt': _string(data['createdAt']),
    };
  }

  Map<String, dynamic> _normalizePlaceSummary(Map<String, dynamic> data) {
    return {
      'place_id': _string(data['placeId']),
      'name': _string(data['name']),
      'vicinity': _string(data['vicinity']),
      'lat': _toDouble(data['latitude']),
      'lng': _toDouble(data['longitude']),
      'rating': _toDouble(data['rating']),
      'user_ratings_total': _toInt(data['userRatingsTotal']),
      'open_now': _toBool(data['openNow']),
      'price_level': _toInt(data['priceLevel']),
      'types': _toStringList(data['types']),
      'photo_reference': _stringOrNull(data['photoReference']),
      'google_pulse_score': _toInt(data['googlePulseScore']),
      'density_score': _toInt(data['densityScore']),
      'trend_score': _toInt(data['trendScore']),
      'pulse_score': _toInt(data['pulseScore']),
      'community_score': _toInt(data['communityScore']),
      'live_signal_score': _toInt(data['liveSignalScore']),
      'ambassador_score': _toInt(data['ambassadorScore']),
      'synthetic_demand_score': _toInt(data['syntheticDemandScore']),
      'seed_confidence': _toInt(data['seedConfidence']),
      'moment_score': _toInt(data['momentScore']),
      'density_label': _string(data['densityLabel']),
      'trend_label': _string(data['trendLabel']),
      'distance_label': _string(data['distanceLabel']),
      'distance_meters': _toDouble(data['distanceMeters']),
      'pulse_driver_tags': _toStringList(data['pulseDriverTags']),
      'seed_source_breakdown': data['seedSourceBreakdown'] is Map
          ? Map<String, dynamic>.from(data['seedSourceBreakdown'] as Map)
          : const <String, dynamic>{},
      'pulse_reason': _string(data['pulseReason']),
    };
  }

  Map<String, dynamic> _normalizePlaceDetail(Map<String, dynamic> data) {
    return {
      'place_id': _string(data['placeId']),
      'name': _string(data['name']),
      'address': _string(data['address']),
      'phone': _string(data['phone']),
      'website': _string(data['website']),
      'lat': _toDouble(data['latitude']),
      'lng': _toDouble(data['longitude']),
      'rating': _toDouble(data['rating']),
      'total_ratings': _toInt(data['totalRatings']),
      'is_open': _toBool(data['isOpen']),
      'price_level': _toInt(data['priceLevel']),
      'weekday_text': _toStringList(data['weekdayText']),
      'photos': _toStringList(data['photoReferences']),
      'reviews': (data['reviews'] as List? ?? const []).whereType<Map>().map((
        item,
      ) {
        final review = Map<String, dynamic>.from(item);
        return {
          'author': _string(review['author']),
          'rating': _toInt(review['rating']),
          'text': _string(review['text']),
          'time': _string(review['relativeTime']),
        };
      }).toList(),
      'google_pulse_score': _toInt(data['googlePulseScore']),
      'density_score': _toInt(data['densityScore']),
      'trend_score': _toInt(data['trendScore']),
      'pulse_score': _toInt(data['pulseScore']),
      'community_score': _toInt(data['communityScore']),
      'live_signal_score': _toInt(data['liveSignalScore']),
      'ambassador_score': _toInt(data['ambassadorScore']),
      'synthetic_demand_score': _toInt(data['syntheticDemandScore']),
      'seed_confidence': _toInt(data['seedConfidence']),
      'pulse_driver_tags': _toStringList(data['pulseDriverTags']),
      'seed_source_breakdown': data['seedSourceBreakdown'] is Map
          ? Map<String, dynamic>.from(data['seedSourceBreakdown'] as Map)
          : const <String, dynamic>{},
      'pulse_reason': _string(data['pulseReason']),
    };
  }

  Map<String, dynamic> _normalizeMatch(Map<String, dynamic> data) {
    return {
      'id': _string(data['id']),
      'userId1': data['user1'] is Map
          ? _string(Map<String, dynamic>.from(data['user1'])['id'])
          : '',
      'userId2': data['user2'] is Map
          ? _string(Map<String, dynamic>.from(data['user2'])['id'])
          : '',
      'compatibility': _toInt(data['compatibility']),
      'commonInterests': _toStringList(data['commonInterests']),
      'status': _string(data['status'], fallback: 'pending'),
      'createdAt': _string(data['createdAt']),
      'respondedAt': _stringOrNull(data['respondedAt']),
      'chatId': _stringOrNull(data['chatId']),
      'user1': data['user1'] is Map
          ? _normalizeUser(Map<String, dynamic>.from(data['user1']))
          : null,
      'user2': data['user2'] is Map
          ? _normalizeUser(Map<String, dynamic>.from(data['user2']))
          : null,
      'initiator1AnonymousInChat': data['initiator1AnonymousInChat'] == true,
      'responder2AnonymousInChat': data['responder2AnonymousInChat'] == true,
    };
  }

  /// Mirrors `LikesMeEntryDto` from the backend. Keeps the shape predictable
  /// so the UI doesn't need to defensively poke into nested fields.
  Map<String, dynamic> _normalizeLikesMeEntry(Map<String, dynamic> data) {
    final liker = data['liker'] is Map
        ? _normalizeUser(Map<String, dynamic>.from(data['liker']))
        : <String, dynamic>{};
    return {
      'matchId': _string(data['matchId']),
      'liker': liker,
      'compatibility': _toInt(data['compatibility']),
      'commonInterests': _toStringList(data['commonInterests']),
      'likedAt': _string(data['likedAt']),
      'likerAnonymousInChat': data['likerAnonymousInChat'] == true,
    };
  }

  String _string(dynamic value, {String fallback = ''}) {
    final raw = value?.toString().trim() ?? '';
    return raw.isEmpty ? fallback : raw;
  }

  String? _stringOrNull(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  bool _toBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final raw = value?.toString().trim().toLowerCase();
    if (raw == 'true' || raw == '1') return true;
    if (raw == 'false' || raw == '0') return false;
    return fallback;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
