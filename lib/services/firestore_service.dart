import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/mode_config.dart';
import '../models/chat_model.dart';
import '../models/highlight_model.dart';
import '../models/message_model.dart';
import '../models/place_visit_model.dart';
import '../models/post_model.dart';
import '../models/shorts_feed_scope.dart';
import '../models/signal_crossing_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'pulse_api_service.dart';
import 'realtime_service.dart';

class BackendQuerySnapshot {
  final List<Map<String, dynamic>> docs;

  const BackendQuerySnapshot(this.docs);
}

class FirestoreService {
  final PulseApiService _api = PulseApiService.instance;
  final AuthService _auth = AuthService();
  final RealtimeService _realtime = RealtimeService.instance;
  final Map<String, Stream<dynamic>> _sharedStreams = {};

  bool _lastKnownSignalActive = false;

  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String gender,
    required int age,
    required String purpose,
    required List<String> interests,
  }) async {
    if (uid.isEmpty || uid != _auth.currentUserId) return;

    final existing = await getUserProfile(uid) ?? const <String, dynamic>{};
    final payload = _buildProfilePayload(existing, {
      'displayName': _profileString(
        existing,
        'displayName',
        fallback: _auth.currentUserName.isNotEmpty
            ? _auth.currentUserName
            : _auth.currentUserUsername,
      ),
      'gender': gender,
      'age': age,
      'purpose': purpose,
      'interests': interests,
      'profilePhotoUrl': _profileString(
        existing,
        'profilePhotoUrl',
        fallback: _auth.currentUserPhotoUrl,
      ),
    });

    final updated = await _api.updateCurrentProfile(payload);
    if (updated != null) {
      await _auth.updateSessionFromProfile(updated);
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    if (uid.isEmpty) return null;
    if (_auth.isLoggedIn && uid == _auth.currentUserId) {
      return await _api.getCurrentProfile() ?? await _api.getUserById(uid);
    }
    return _api.getUserById(uid);
  }

  Future<UserModel?> getUser(String uid) async {
    final data = await getUserProfile(uid);
    return data == null ? null : UserModel.fromMap(data);
  }

  Stream<UserModel?> userStream(String uid) {
    unawaited(_realtime.ensureConnected());
    if (uid.isNotEmpty) {
      unawaited(_realtime.subscribeUser(uid));
    }
    return _sharedLiveQuery(
      'user:$uid',
      () => getUser(uid),
      interval: null,
      triggers: [if (uid.isNotEmpty) _realtime.profileChanged(uid)],
    );
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    if (uid.isEmpty || uid != _auth.currentUserId) return;

    final existing = await getUserProfile(uid) ?? const <String, dynamic>{};
    final payload = _buildProfilePayload(existing, data);
    final updated = await _api.updateCurrentProfile(payload);
    if (updated != null) {
      await _auth.updateSessionFromProfile(updated);
      await _syncPresenceFromProfile(updated);
    }
  }

  Future<void> updateMode(String uid, String mode) async {
    await updateProfile(uid, {'mode': mode});
  }

  Future<void> updateVisibility(String uid, bool isVisible) async {
    await updateProfile(uid, {'isVisible': isVisible});
  }

  Future<void> updateLocation(String uid, double lat, double lng) async {
    if (uid.isEmpty || uid != _auth.currentUserId) return;

    final existing = await getUserProfile(uid) ?? const <String, dynamic>{};
    final payload = _buildProfilePayload(existing, {
      'latitude': lat,
      'longitude': lng,
    });
    final updated = await _api.updateCurrentProfile(payload);
    final merged = updated ?? {...existing, 'latitude': lat, 'longitude': lng};
    if (updated != null) {
      await _auth.updateSessionFromProfile(updated);
    }
    await _syncPresenceFromProfile(merged);
  }

  Future<void> setOnlineStatus(String uid, bool isOnline) async {
    if (uid.isEmpty || uid != _auth.currentUserId) return;
    _lastKnownSignalActive = isOnline;
    await _api.updateOnlineStatus(isOnline);
  }

  Future<void> deleteUserProfile(String uid) async {
    if (uid.isEmpty || uid != _auth.currentUserId) return;
    await _api.updateOnlineStatus(false);
  }

  Future<List<UserModel>> getNearbyUsersList(
    String uid,
    double lat,
    double lng, {
    double radiusKm = 1.0,
    bool signalOnly = false,
  }) async {
    if (uid.isEmpty || uid != _auth.currentUserId) return const [];
    final response = await _api.getNearbyUsers(
      latitude: lat,
      longitude: lng,
      radiusKm: radiusKm,
      signalOnly: signalOnly,
    );
    return response.map(UserModel.fromMap).toList();
  }

  Future<void> followUser(String myUid, String targetUid) async {
    if (myUid.isEmpty || myUid != _auth.currentUserId || targetUid.isEmpty) {
      return;
    }

    final relation = await _api.getRelationshipState(targetUid);
    if (relation?['isFollowing'] == true) return;
    await _api.toggleFollow(targetUid);
  }

  Future<void> unfollowUser(String myUid, String targetUid) async {
    if (myUid.isEmpty || myUid != _auth.currentUserId || targetUid.isEmpty) {
      return;
    }

    final relation = await _api.getRelationshipState(targetUid);
    if (relation?['isFollowing'] != true) return;
    await _api.toggleFollow(targetUid);
  }

  Future<bool> isFollowing(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty) return false;
    final relation = await _api.getRelationshipState(targetUid);
    return relation?['isFollowing'] == true;
  }

  Stream<List<UserModel>> getFollowers(String uid) {
    unawaited(_realtime.ensureConnected());
    if (uid.isNotEmpty) {
      unawaited(_realtime.subscribeUser(uid));
    }
    return _sharedLiveQuery(
      'followers:$uid',
      () async =>
          (await _api.getFollowers(uid)).map(UserModel.fromMap).toList(),
      interval: null,
      triggers: [_realtime.relationshipChanged],
    );
  }

  Stream<List<UserModel>> getFollowing(String uid) {
    unawaited(_realtime.ensureConnected());
    if (uid.isNotEmpty) {
      unawaited(_realtime.subscribeUser(uid));
    }
    return _sharedLiveQuery(
      'following:$uid',
      () async =>
          (await _api.getFollowing(uid)).map(UserModel.fromMap).toList(),
      interval: null,
      triggers: [_realtime.relationshipChanged],
    );
  }

  Future<void> sendFriendRequest(String myUid, String targetUid) async {
    if (myUid.isEmpty || myUid != _auth.currentUserId || targetUid.isEmpty) {
      return;
    }
    await _api.sendFriendRequest(targetUid);
  }

  Future<void> acceptFriendRequest(
    String requestId,
    String myUid,
    String fromUid,
  ) async {
    if (myUid.isEmpty || myUid != _auth.currentUserId || requestId.isEmpty) {
      return;
    }
    await _api.respondToFriendRequest(requestId, accept: true);
  }

  Future<void> declineFriendRequest(String requestId) async {
    if (requestId.isEmpty) return;
    await _api.respondToFriendRequest(requestId, accept: false);
  }

  Stream<BackendQuerySnapshot> getPendingFriendRequests(String uid) {
    unawaited(_realtime.ensureConnected());
    return _sharedLiveQuery(
      'friend-requests:$uid',
      () async => BackendQuerySnapshot(await _api.getIncomingFriendRequests()),
      interval: null,
      triggers: [_realtime.friendRequestsChanged],
    );
  }

  Stream<List<Map<String, dynamic>>> getPendingFriendRequestsDetailed(
    String uid,
  ) {
    unawaited(_realtime.ensureConnected());
    return _sharedLiveQuery(
      'friend-requests-detailed:$uid',
      () async =>
          _mapDetailedFriendRequests(await _api.getIncomingFriendRequests()),
      interval: null,
      triggers: [_realtime.friendRequestsChanged],
    );
  }

  Future<bool> isFriend(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty) return false;
    final relation = await _api.getRelationshipState(targetUid);
    return relation?['isFriend'] == true;
  }

  Future<Map<String, dynamic>?> getRelationshipState(
    String myUid,
    String targetUid,
  ) async {
    if (myUid.isEmpty || targetUid.isEmpty || myUid != _auth.currentUserId) {
      return null;
    }
    return _api.getRelationshipState(targetUid);
  }

  Future<bool> cancelOutgoingFriendRequest(
    String myUid,
    String requestId,
  ) async {
    if (myUid.isEmpty || myUid != _auth.currentUserId || requestId.isEmpty) {
      return false;
    }
    return _api.cancelOutgoingFriendRequest(requestId);
  }

  Future<bool> removeFriend(String myUid, String targetUid) async {
    if (myUid.isEmpty || myUid != _auth.currentUserId || targetUid.isEmpty) {
      return false;
    }
    return _api.removeFriend(targetUid);
  }

  Future<List<UserModel>> getFriendsList(String uid) async {
    final response = await _api.getFriends(uid);
    return response.map(UserModel.fromMap).toList();
  }

  Future<List<UserModel>> searchUsers(
    String query, {
    String? excludeUid,
  }) async {
    final response = await _api.searchUsers(query, excludeUid: excludeUid);
    return response.map(UserModel.fromMap).toList();
  }

  Future<UserModel?> setPinnedMoment(String? postId) async {
    final response = await _api.setPinnedMoment(postId);
    if (response == null) return null;
    await _auth.updateSessionFromProfile(response);
    return UserModel.fromMap(response);
  }

  Future<List<PlaceVisitModel>> getPlacesVisited(String uid) async {
    if (uid.isEmpty) return const [];
    final response = await _api.getPlacesVisited(uid);
    return response.map(PlaceVisitModel.fromMap).toList();
  }

  Future<SignalCrossingSummaryModel> getSignalCrossings(String uid) async {
    if (uid.isEmpty) return const SignalCrossingSummaryModel.empty();
    final response = await _api.getSignalCrossings(uid);
    if (response == null) return const SignalCrossingSummaryModel.empty();
    return SignalCrossingSummaryModel.fromMap(response);
  }

  Future<ChatModel> createOrGetDirectChat(
    String myUid,
    String otherUid, {
    bool isTemporary = false,
  }) async {
    if (myUid.isEmpty || myUid != _auth.currentUserId || otherUid.isEmpty) {
      throw Exception('Gecersiz sohbet istegi.');
    }

    final response = await _api.createOrGetDirectChat(
      otherUid,
      isTemporary: isTemporary,
    );
    if (response == null) {
      throw Exception('Sohbet olusturulamadi.');
    }

    return ChatModel.fromMap(response['id']?.toString() ?? '', response);
  }

  Future<void> convertToFriendChat(String chatId) async {
    if (chatId.isEmpty) return;
    await _api.convertToFriendChat(chatId);
  }

  /// Returns "pending" | "accepted" | "already_permanent" | "error"
  Future<String> requestChatPermanence(String chatId) async {
    if (chatId.isEmpty) return 'error';
    return _api.requestChatPermanence(chatId);
  }

  Future<void> setChatArchived(String chatId, bool isArchived) async {
    if (chatId.isEmpty) return;
    await _api.setChatArchived(chatId, isArchived);
  }

  Stream<List<ChatModel>> getChats(String uid) {
    unawaited(_realtime.ensureConnected());
    return _sharedLiveQuery(
      'chats:$uid',
      () async => (await _api.getChats())
          .map((item) => ChatModel.fromMap(item['id']?.toString() ?? '', item))
          .toList(),
      interval: null,
      triggers: [_realtime.chatListChanged, _realtime.relationshipChanged],
    );
  }

  Stream<ChatModel?> getChatStream(String chatId) {
    unawaited(_realtime.subscribeChat(chatId));
    return _sharedLiveQuery(
      'chat:$chatId',
      () async {
        final data = await _api.getChat(chatId);
        if (data == null) return null;
        return ChatModel.fromMap(data['id']?.toString() ?? '', data);
      },
      interval: null,
      triggers: [if (chatId.isNotEmpty) _realtime.chatChanged(chatId)],
    );
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    unawaited(_realtime.subscribeChat(chatId));
    return _sharedLiveQuery(
      'messages:$chatId',
      () async => (await _api.getMessages(chatId))
          .map(
            (item) => MessageModel.fromMap(item['id']?.toString() ?? '', item),
          )
          .toList(),
      interval: null,
      triggers: [if (chatId.isNotEmpty) _realtime.chatChanged(chatId)],
    );
  }

  Future<void> sendMessage(String chatId, MessageModel message) async {
    if (chatId.isEmpty) return;

    await _api.sendMessage(chatId, {
      'text': message.text,
      'type': message.type.name,
      if (message.photoUrl != null) 'photoUrl': message.photoUrl,
      if (message.videoUrl != null) 'videoUrl': message.videoUrl,
      if (message.latitude != null) 'latitude': message.latitude,
      if (message.longitude != null) 'longitude': message.longitude,
      if (message.photoApproved != null) 'photoApproved': message.photoApproved,
      if (message.reaction != null) 'reaction': message.reaction,
      if (message.disappearSeconds != null)
        'disappearSeconds': message.disappearSeconds,
      if ((message.sharedPostId ?? '').isNotEmpty)
        'sharedPostId': message.sharedPostId,
      if ((message.sharedPostAuthor ?? '').isNotEmpty)
        'sharedPostAuthor': message.sharedPostAuthor,
      if ((message.sharedPostLocation ?? '').isNotEmpty)
        'sharedPostLocation': message.sharedPostLocation,
      if ((message.sharedPostVibe ?? '').isNotEmpty)
        'sharedPostVibe': message.sharedPostVibe,
      if ((message.sharedPostMediaUrl ?? '').isNotEmpty)
        'sharedPostMediaUrl': message.sharedPostMediaUrl,
    });
  }

  Future<void> updateMessageStatus(
    String chatId,
    String messageId,
    String status,
  ) async {
    if (chatId.isEmpty || messageId.isEmpty) return;
    await _api.updateMessageStatus(chatId, messageId, status);
  }

  Future<void> addReaction(
    String chatId,
    String messageId,
    String? reaction,
  ) async {
    if (chatId.isEmpty || messageId.isEmpty) return;
    await _api.updateReaction(chatId, messageId, reaction);
  }

  Future<void> deleteMessage(
    String chatId,
    String messageId, {
    bool forEveryone = true,
  }) async {
    if (chatId.isEmpty || messageId.isEmpty) return;
    await _api.deleteMessage(
      chatId,
      messageId,
      scope: forEveryone ? 'everyone' : 'me',
    );
  }

  Future<void> deleteChatForMe(String chatId) async {
    if (chatId.isEmpty) return;
    await _api.deleteChat(chatId);
  }

  Future<void> setTyping(String chatId, String myUid, bool isTyping) async {
    if (chatId.isEmpty || myUid.isEmpty || myUid != _auth.currentUserId) return;
    await _api.setTyping(chatId, isTyping);
  }

  Future<void> markChatAsRead(String chatId, String myUid) async {
    if (chatId.isEmpty || myUid.isEmpty || myUid != _auth.currentUserId) return;
    await _api.markChatAsRead(chatId);
  }

  Stream<List<PostModel>> getFeedPosts({
    String? vibeTag,
    String? type,
    int take = 24,
  }) {
    unawaited(_realtime.subscribeFeed());
    return _sharedLiveQuery(
      'feed:${vibeTag ?? ''}:${type ?? ''}:$take',
      () async =>
          (await _api.getFeedPosts(vibeTag: vibeTag, type: type, take: take))
              .map(
                (item) => PostModel.fromMap(item['id']?.toString() ?? '', item),
              )
              .toList(),
      interval: null,
      triggers: [_realtime.feedChanged],
    );
  }

  Stream<List<PostModel>> getShortsFeed({
    required ShortsFeedScope scope,
    double? latitude,
    double? longitude,
    double radiusKm = 4.5,
    int take = 24,
  }) {
    unawaited(_realtime.subscribeFeed());
    final myUid = _auth.currentUserId;
    if (scope.isPersonal && myUid.isNotEmpty) {
      unawaited(_realtime.subscribeUser(myUid));
    }
    return _sharedLiveQuery(
      'shorts-feed:${scope.apiValue}:${latitude?.toStringAsFixed(3) ?? ''}:${longitude?.toStringAsFixed(3) ?? ''}:$radiusKm:$take',
      () async =>
          (await _api.getShortsFeed(
                scope: scope,
                latitude: latitude,
                longitude: longitude,
                radiusKm: radiusKm,
                take: take,
              ))
              .map(
                (item) => PostModel.fromMap(item['id']?.toString() ?? '', item),
              )
              .toList(),
      interval: const Duration(seconds: 30),
      triggers: [
        _realtime.feedChanged,
        if (scope.isPersonal && myUid.isNotEmpty)
          _realtime.profileChanged(myUid),
      ],
    );
  }

  Future<List<PostModel>> fetchUserPostsOnce(
    String uid, {
    String? type,
  }) async {
    if (uid.isEmpty) return const [];
    final rows = await _api.getUserPosts(uid, type: type);
    return rows
        .map((item) => PostModel.fromMap(item['id']?.toString() ?? '', item))
        .toList();
  }

  Stream<List<PostModel>> getUserPosts(String uid, {String? type}) {
    unawaited(_realtime.ensureConnected());
    if (uid.isNotEmpty) {
      unawaited(_realtime.subscribeUser(uid));
    }
    return _sharedLiveQuery(
      'user-posts:$uid:${type ?? ''}',
      () async => (await _api.getUserPosts(uid, type: type))
          .map((item) => PostModel.fromMap(item['id']?.toString() ?? '', item))
          .toList(),
      interval: null,
      triggers: [
        _realtime.feedChanged,
        if (uid.isNotEmpty) _realtime.userPostsChanged(uid),
        if (uid.isNotEmpty) _realtime.profileChanged(uid),
      ],
    );
  }

  Stream<List<PostModel>> getSavedPosts(String uid) {
    if (uid.isEmpty || uid != _auth.currentUserId) {
      return Stream<List<PostModel>>.value(const <PostModel>[]);
    }

    unawaited(_realtime.ensureConnected());
    return _sharedLiveQuery(
      'saved-posts:$uid',
      () async => (await _api.getSavedPosts())
          .map((item) => PostModel.fromMap(item['id']?.toString() ?? '', item))
          .toList(),
      interval: null,
      triggers: [_realtime.feedChanged],
    );
  }

  Future<PostModel?> createPost(PostModel post) async {
    final response = await _api.createPost({
      'text': post.text,
      'location': post.location,
      'placeId': post.placeId,
      'latitude': post.lat,
      'longitude': post.lng,
      'photoUrls': post.photoUrls,
      'videoUrl': post.videoUrl,
      'rating': post.rating,
      'vibeTag': post.vibeTag,
      'type': post.type,
    });

    if (response == null) return null;
    return PostModel.fromMap(response['id']?.toString() ?? '', response);
  }

  Future<PostModel?> updatePost(PostModel post, String myUid) async {
    if (post.id.isEmpty || myUid.isEmpty || myUid != _auth.currentUserId) {
      return null;
    }

    final response = await _api.updatePost(post.id, {
      'text': post.text,
      'location': post.location,
      'placeId': post.placeId,
      'latitude': post.lat,
      'longitude': post.lng,
      'photoUrls': post.photoUrls,
      'videoUrl': post.videoUrl,
      'rating': post.rating,
      'vibeTag': post.vibeTag,
    });

    if (response == null) return null;
    return PostModel.fromMap(response['id']?.toString() ?? '', response);
  }

  Future<void> toggleLike(String postId, String myUid) async {
    if (postId.isEmpty || myUid.isEmpty || myUid != _auth.currentUserId) return;
    await _api.toggleLike(postId);
  }

  Future<void> toggleSavePost(String postId, String myUid) async {
    if (postId.isEmpty || myUid.isEmpty || myUid != _auth.currentUserId) return;
    await _api.toggleSavePost(postId);
  }

  Stream<List<Map<String, dynamic>>> getPostComments(String postId) {
    unawaited(_realtime.ensureConnected());
    return _sharedLiveQuery(
      'post-comments:$postId',
      () => _api.getPostComments(postId),
      interval: null,
      triggers: [_realtime.feedChanged],
    );
  }

  Future<void> addPostComment(String postId, String myUid, String text) async {
    if (postId.isEmpty || myUid.isEmpty || myUid != _auth.currentUserId) return;
    await _api.addPostComment(postId, text);
  }

  Future<Map<String, dynamic>?> updatePostComment(
    String postId,
    String commentId,
    String myUid,
    String text,
  ) async {
    if (postId.isEmpty ||
        commentId.isEmpty ||
        myUid.isEmpty ||
        myUid != _auth.currentUserId) {
      return null;
    }

    return _api.updatePostComment(postId, commentId, text);
  }

  Future<bool> deletePost(String postId, String myUid) async {
    if (postId.isEmpty || myUid.isEmpty || myUid != _auth.currentUserId) {
      return false;
    }
    return _api.deletePost(postId);
  }

  Future<bool> deletePostComment(
    String postId,
    String commentId,
    String myUid,
  ) async {
    if (postId.isEmpty ||
        commentId.isEmpty ||
        myUid.isEmpty ||
        myUid != _auth.currentUserId) {
      return false;
    }

    return _api.deletePostComment(postId, commentId);
  }

  Future<bool> toggleSavePlace(String myUid, Map<String, dynamic> place) async {
    if (myUid.isEmpty || myUid != _auth.currentUserId) return false;
    return _api.toggleSavePlace(place);
  }

  Future<Map<String, Map<String, dynamic>>> getCommunitySignalsForPlaces(
    List<Map<String, dynamic>> places,
  ) {
    return _api.getPlaceCommunitySignals(places);
  }

  Future<void> addHighlight(HighlightModel highlight) async {
    if (highlight.userId.isEmpty || highlight.userId != _auth.currentUserId) {
      return;
    }

    await _api.createHighlight(
      highlight.userId,
      title: highlight.title,
      coverUrl: highlight.coverUrl,
      mediaUrls: highlight.mediaUrls,
      type: highlight.type,
      textColorHex: highlight.textColorHex,
      textOffsetX: highlight.textOffsetX,
      textOffsetY: highlight.textOffsetY,
      modeTag: highlight.modeTag,
      locationLabel: highlight.locationLabel,
      placeId: highlight.placeId,
      showModeOverlay: highlight.showModeOverlay,
      showLocationOverlay: highlight.showLocationOverlay,
    );
  }

  Future<void> addStory(HighlightModel story, {int durationHours = 24}) async {
    if (story.userId.isEmpty || story.userId != _auth.currentUserId) {
      return;
    }

    await _api.createStory(
      story.userId,
      title: story.title,
      coverUrl: story.coverUrl,
      mediaUrls: story.mediaUrls,
      type: story.type,
      textColorHex: story.textColorHex,
      textOffsetX: story.textOffsetX,
      textOffsetY: story.textOffsetY,
      modeTag: story.modeTag,
      locationLabel: story.locationLabel,
      placeId: story.placeId,
      showModeOverlay: story.showModeOverlay,
      showLocationOverlay: story.showLocationOverlay,
      durationHours: durationHours,
    );
  }

  Future<void> deleteHighlight(String userId, String highlightId) async {
    if (userId.isEmpty ||
        highlightId.isEmpty ||
        userId != _auth.currentUserId) {
      return;
    }
    await _api.deleteHighlight(userId, highlightId);
  }

  Future<void> deleteStory(String userId, String storyId) async {
    if (userId.isEmpty || storyId.isEmpty || userId != _auth.currentUserId) {
      return;
    }
    await _api.deleteStory(userId, storyId);
  }

  Future<void> markStoryViewed(String storyId) async {
    if (storyId.isEmpty || !_auth.isLoggedIn) return;
    await _api.markStoryViewed(storyId);
  }

  Stream<List<HighlightModel>> getHighlights(String uid) {
    unawaited(_realtime.ensureConnected());
    if (uid.isNotEmpty) {
      unawaited(_realtime.subscribeUser(uid));
    }
    return _sharedLiveQuery(
      'highlights:$uid',
      () async => (await _api.getHighlights(uid))
          .map(
            (item) =>
                HighlightModel.fromMap(item['id']?.toString() ?? '', item),
          )
          .toList(),
      interval: null,
      triggers: [if (uid.isNotEmpty) _realtime.profileChanged(uid)],
    );
  }

  Stream<List<HighlightModel>> getStories(String uid) {
    unawaited(_realtime.ensureConnected());
    if (uid.isNotEmpty) {
      unawaited(_realtime.subscribeUser(uid));
    }
    return _sharedLiveQuery(
      'stories:$uid',
      () async => (await _api.getStories(uid))
          .map(
            (item) =>
                HighlightModel.fromMap(item['id']?.toString() ?? '', item),
          )
          .toList(),
      interval: null,
      triggers: [if (uid.isNotEmpty) _realtime.profileChanged(uid)],
    );
  }

  Future<void> createUserReport({
    required String reporterUid,
    required String targetUid,
    required String reason,
    String details = '',
  }) async {
    if (reporterUid.isEmpty ||
        reporterUid != _auth.currentUserId ||
        targetUid.isEmpty) {
      return;
    }

    await _api.reportUser(
      targetUserId: targetUid,
      reason: reason,
      details: details,
    );
  }

  Future<void> blockUser(String myUid, String targetUid) async {
    if (myUid.isEmpty || myUid != _auth.currentUserId || targetUid.isEmpty) {
      return;
    }
    await _api.blockUser(targetUid);
  }

  Future<bool> unblockUser(String myUid, String targetUid) async {
    if (myUid.isEmpty || myUid != _auth.currentUserId || targetUid.isEmpty) {
      return false;
    }
    return _api.unblockUser(targetUid);
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers(String myUid) async {
    if (myUid.isEmpty || myUid != _auth.currentUserId) {
      return const [];
    }
    return _api.getBlockedUsers();
  }

  Future<Map<String, dynamic>?> exportMyData() async {
    if (_auth.currentUserId.isEmpty) return null;
    return _api.exportMyData();
  }

  Future<List<Map<String, dynamic>>> getPendingIncomingMatches() async {
    return _api.getPendingIncomingMatches();
  }

  Stream<List<Map<String, dynamic>>> getPendingIncomingMatchesStream() {
    unawaited(_realtime.ensureConnected());
    return _sharedLiveQuery(
      'matches:incoming',
      _api.getPendingIncomingMatches,
      interval: null,
      triggers: [_realtime.matchesChanged],
    );
  }

  Future<Map<String, dynamic>?> createMatch({
    required String otherUserId,
    required int compatibility,
    List<String> commonInterests = const [],
    bool anonymousInChat = false,
  }) async {
    return _api.createMatch(
      otherUserId: otherUserId,
      compatibility: compatibility,
      commonInterests: commonInterests,
      anonymousInChat: anonymousInChat,
    );
  }

  Future<bool> respondToMatch(
    String matchId, {
    required String status,
    String? chatId,
    bool anonymousInChat = false,
  }) async {
    return _api.respondToMatch(matchId, status: status, chatId: chatId, anonymousInChat: anonymousInChat);
  }

  Stream<T> _liveQuery<T>(
    Future<T> Function() loader, {
    Duration? interval = const Duration(seconds: 6),
    List<Stream<void>> triggers = const [],
  }) {
    late StreamController<T> controller;
    Timer? timer;
    final subscriptions = <StreamSubscription<void>>[];
    T? lastValue;
    var hasValue = false;
    var loading = false;

    Future<void> emit() async {
      if (loading) return;
      loading = true;
      try {
        final next = await loader();
        lastValue = next;
        hasValue = true;
        if (!controller.isClosed) {
          controller.add(next);
        }
      } catch (e, st) {
        debugPrint('Live query error: $e\n$st');
        if (!controller.isClosed) {
          if (hasValue) {
            controller.add(lastValue as T);
          } else {
            controller.addError(e, st);
          }
        }
      } finally {
        loading = false;
      }
    }

    controller = StreamController<T>.broadcast(
      onListen: () {
        unawaited(emit());
        if (interval != null) {
          timer = Timer.periodic(interval, (_) => unawaited(emit()));
        }
        for (final trigger in triggers) {
          subscriptions.add(trigger.listen((_) => unawaited(emit())));
        }
      },
      onCancel: () async {
        timer?.cancel();
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }

  Stream<T> _sharedLiveQuery<T>(
    String key,
    Future<T> Function() loader, {
    Duration? interval = const Duration(seconds: 6),
    List<Stream<void>> triggers = const [],
  }) {
    final cached = _sharedStreams[key];
    if (cached != null) {
      return cached as Stream<T>;
    }

    late final Stream<T> sharedStream;
    sharedStream = _liveQuery(loader, interval: interval, triggers: triggers)
        .asBroadcastStream(
          onCancel: (subscription) {
            _sharedStreams.remove(key);
            subscription.cancel();
          },
        );

    _sharedStreams[key] = sharedStream;
    return sharedStream;
  }

  List<Map<String, dynamic>> _mapDetailedFriendRequests(
    List<Map<String, dynamic>> requests,
  ) {
    return requests.map((request) {
      final fromUser = request['fromUser'] is Map
          ? Map<String, dynamic>.from(request['fromUser'])
          : const <String, dynamic>{};
      final user = UserModel.fromMap(fromUser);

      return {
        'id': request['id']?.toString() ?? '',
        'fromUid': user.uid,
        'toUid': request['toUser'] is Map
            ? Map<String, dynamic>.from(request['toUser'])['id']?.toString() ??
                  ''
            : '',
        'createdAt': request['createdAt']?.toString() ?? '',
        'user': user,
      };
    }).toList();
  }

  Map<String, dynamic> _buildProfilePayload(
    Map<String, dynamic> existing,
    Map<String, dynamic> updates,
  ) {
    final merged = {...existing, ...updates};
    final photoUrls = _asStringList(merged['photoUrls']);
    final interests = _asStringList(merged['interests']);
    final latitude = _readDouble(merged, ['latitude', 'lat']);
    final longitude = _readDouble(merged, ['longitude', 'lng']);

    return {
      'userName': _profileString(
        merged,
        'userName',
        fallback: _auth.currentUserUsername,
      ),
      'displayName': _profileString(
        merged,
        'displayName',
        fallback: _auth.currentUserName.isNotEmpty
            ? _auth.currentUserName
            : _auth.currentUserUsername,
      ),
      'firstName': _profileString(merged, 'firstName'),
      'lastName': _profileString(merged, 'lastName'),
      'bio': _profileString(merged, 'bio'),
      'city': _profileString(merged, 'city'),
      'website': _profileString(merged, 'website'),
      'gender': _profileString(merged, 'gender'),
      'birthDate': merged['birthDate'],
      'age': _readInt(merged, ['age']),
      'purpose': _profileString(merged, 'purpose'),
      'matchPreference': _profileString(
        merged,
        'matchPreference',
        fallback: 'auto',
      ),
      'mode': ModeConfig.normalizeId(_profileString(merged, 'mode')),
      'privacyLevel': _profileString(merged, 'privacyLevel', fallback: 'full'),
      'preferredLanguage': _profileString(
        merged,
        'preferredLanguage',
        fallback: 'tr',
      ),
      'locationGranularity': _profileString(
        merged,
        'locationGranularity',
        fallback: 'nearby',
      ),
      'enableDifferentialPrivacy': _readBool(merged, [
        'enableDifferentialPrivacy',
      ], fallback: true),
      'kAnonymityLevel': _readInt(merged, ['kAnonymityLevel'], fallback: 3),
      'allowAnalytics': _readBool(merged, ['allowAnalytics'], fallback: true),
      'isVisible': _readBool(merged, ['isVisible'], fallback: true),
      'profilePhotoUrl': _profileString(
        merged,
        'profilePhotoUrl',
        fallback: _auth.currentUserPhotoUrl,
      ),
      'photoUrls': photoUrls,
      'interests': interests,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Future<void> _syncPresenceFromProfile(Map<String, dynamic> profile) async {
    final latitude = _readDouble(profile, ['latitude', 'lat']);
    final longitude = _readDouble(profile, ['longitude', 'lng']);
    if (latitude == null || longitude == null) return;

    final city = _profileString(profile, 'city');
    if (city.isNotEmpty) {
      unawaited(_realtime.subscribePresence(city));
    }

    final updatedViaRealtime = await _realtime.updatePresence(
      latitude: latitude,
      longitude: longitude,
      city: city,
      mode: ModeConfig.normalizeId(_profileString(profile, 'mode')),
      shareProfile:
          _profileString(profile, 'privacyLevel', fallback: 'full') != 'ghost',
      isSignalActive: _lastKnownSignalActive,
    );

    if (updatedViaRealtime) return;

    await _api.updatePresence(
      latitude: latitude,
      longitude: longitude,
      city: city,
      mode: ModeConfig.normalizeId(_profileString(profile, 'mode')),
      shareProfile:
          _profileString(profile, 'privacyLevel', fallback: 'full') != 'ghost',
      isSignalActive: _lastKnownSignalActive,
      isOnline: _readBool(profile, ['isOnline'], fallback: true),
    );
  }

  String _profileString(
    Map<String, dynamic> source,
    String key, {
    String fallback = '',
  }) {
    final raw = source[key]?.toString().trim() ?? '';
    return raw.isEmpty ? fallback : raw;
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  double? _readDouble(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }

    final location = source['location'];
    if (location is Map) {
      final locationMap = Map<String, dynamic>.from(location);
      if (keys.contains('latitude') || keys.contains('lat')) {
        final value = locationMap['latitude'] ?? locationMap['lat'];
        if (value is num) return value.toDouble();
        final parsed = double.tryParse(value?.toString() ?? '');
        if (parsed != null) return parsed;
      }
      if (keys.contains('longitude') || keys.contains('lng')) {
        final value = locationMap['longitude'] ?? locationMap['lng'];
        if (value is num) return value.toDouble();
        final parsed = double.tryParse(value?.toString() ?? '');
        if (parsed != null) return parsed;
      }
    }

    return null;
  }

  int _readInt(
    Map<String, dynamic> source,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = source[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  bool _readBool(
    Map<String, dynamic> source,
    List<String> keys, {
    bool fallback = false,
  }) {
    for (final key in keys) {
      final value = source[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      final raw = value?.toString().trim().toLowerCase();
      if (raw == 'true' || raw == '1') return true;
      if (raw == 'false' || raw == '0') return false;
    }
    return fallback;
  }
}
