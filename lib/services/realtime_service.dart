import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/ihub_protocol.dart';
import 'package:signalr_netcore/signalr_client.dart';

import 'auth_service.dart';
import 'runtime_config_service.dart';

class RealtimeService {
  RealtimeService._internal();

  static final RealtimeService instance = RealtimeService._internal();

  HubConnection? _connection;
  // Keeps the auth-state listener alive for the lifetime of the singleton.
  // ignore: unused_field
  StreamSubscription<AuthSession?>? _authSub;

  final StreamController<void> _friendRequestsChangedController =
      StreamController<void>.broadcast();
  final StreamController<void> _relationshipChangedController =
      StreamController<void>.broadcast();
  final StreamController<void> _chatListChangedController =
      StreamController<void>.broadcast();
  final StreamController<void> _feedChangedController =
      StreamController<void>.broadcast();
  final StreamController<void> _presenceChangedController =
      StreamController<void>.broadcast();
  final StreamController<void> _matchesChangedController =
      StreamController<void>.broadcast();
  final StreamController<Map<String, dynamic>> _notificationCreatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<int> _notificationsUnreadCountController =
      StreamController<int>.broadcast();
  final StreamController<ActivityChangedEvent> _activityChangedController =
      StreamController<ActivityChangedEvent>.broadcast();

  final Map<String, StreamController<void>> _chatChangedControllers = {};
  final Map<String, StreamController<void>> _profileChangedControllers = {};
  final Map<String, StreamController<void>> _userPostsChangedControllers = {};

  final Set<String> _subscribedChats = <String>{};
  final Set<String> _subscribedUsers = <String>{};
  String? _presenceCity;
  bool _feedSubscribed = false;
  bool _initialized = false;
  bool _connecting = false;

  Stream<void> get friendRequestsChanged =>
      _friendRequestsChangedController.stream;
  Stream<void> get relationshipChanged => _relationshipChangedController.stream;
  Stream<void> get chatListChanged => _chatListChangedController.stream;
  Stream<void> get feedChanged => _feedChangedController.stream;
  Stream<void> get presenceChanged => _presenceChangedController.stream;
  Stream<void> get matchesChanged => _matchesChangedController.stream;

  /// Emits the freshly-created notification payload (raw JSON map).
  Stream<Map<String, dynamic>> get notificationCreated =>
      _notificationCreatedController.stream;

  /// Emits the latest unread notification count whenever it changes
  /// (mark-read, mark-all-read, delete, or new notification).
  Stream<int> get notificationsUnreadCount =>
      _notificationsUnreadCountController.stream;

  /// Emits an [ActivityChangedEvent] when the host or a participant's view
  /// of an activity should be invalidated (created/updated/cancelled/participants).
  Stream<ActivityChangedEvent> get activityChanged =>
      _activityChangedController.stream;

  Stream<void> chatChanged(String chatId) =>
      _controllerFor(_chatChangedControllers, chatId).stream;

  Stream<void> profileChanged(String userId) =>
      _controllerFor(_profileChangedControllers, userId).stream;

  Stream<void> userPostsChanged(String userId) =>
      _controllerFor(_userPostsChangedControllers, userId).stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await AuthService().initialize();
    _authSub = AuthService().authStateChanges.listen((session) async {
      if (session == null || session.accessToken.isEmpty) {
        await disconnect();
        return;
      }

      await ensureConnected();
    });

    if (AuthService().isLoggedIn) {
      await ensureConnected();
    }
  }

  Future<void> ensureConnected() async {
    if (!RuntimeConfigService.hasBackendBaseUrl || !AuthService().isLoggedIn) {
      return;
    }

    final existing = _connection;
    if (existing != null &&
        existing.state != HubConnectionState.Disconnected &&
        existing.state != HubConnectionState.Disconnecting) {
      return;
    }

    if (_connecting) return;
    _connecting = true;

    try {
      final hubUrl =
          '${RuntimeConfigService.backendBaseUrl.replaceFirst(RegExp(r'/$'), '')}/hubs/realtime';
      final headers = MessageHeaders();
      headers.setHeaderValue('ngrok-skip-browser-warning', 'true');
      final connection = HubConnectionBuilder()
          .withUrl(
            hubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async => AuthService().accessToken,
              headers: headers,
              requestTimeout: 8000,
            ),
          )
          .withAutomaticReconnect(
            retryDelays: const [0, 2000, 5000, 10000, 15000, 30000, 60000],
          )
          .build();

      connection.onclose(({error}) {
        debugPrint('SignalR connection closed: $error');
      });

      connection.onreconnecting(({error}) {
        debugPrint('SignalR reconnecting: $error');
      });

      connection.onreconnected(({connectionId}) {
        debugPrint('SignalR reconnected: $connectionId');
        unawaited(_restoreSubscriptions());
      });

      connection.on('friendRequestsChanged', (_) {
        _friendRequestsChangedController.add(null);
      });
      connection.on('relationshipChanged', (_) {
        _relationshipChangedController.add(null);
      });
      connection.on('chatListChanged', (_) {
        _chatListChangedController.add(null);
      });
      connection.on('feedChanged', (_) {
        _feedChangedController.add(null);
      });
      connection.on('presenceChanged', (_) {
        _presenceChangedController.add(null);
      });
      connection.on('matchesChanged', (_) {
        _matchesChangedController.add(null);
      });
      connection.on('profileChanged', (arguments) {
        final userId = _stringField(arguments, 'userId');
        if (userId.isEmpty) return;
        _controllerFor(_profileChangedControllers, userId).add(null);
      });
      connection.on('userPostsChanged', (arguments) {
        final userId = _stringField(arguments, 'userId');
        if (userId.isEmpty) return;
        _controllerFor(_userPostsChangedControllers, userId).add(null);
      });
      connection.on('chatChanged', (arguments) {
        final chatId = _stringField(arguments, 'chatId');
        if (chatId.isEmpty) return;
        _controllerFor(_chatChangedControllers, chatId).add(null);
      });
      connection.on('typingChanged', (arguments) {
        final chatId = _stringField(arguments, 'chatId');
        if (chatId.isEmpty) return;
        _controllerFor(_chatChangedControllers, chatId).add(null);
        _chatListChangedController.add(null);
      });
      connection.on('messageCreated', (arguments) {
        final chatId = _stringField(arguments, 'chatId');
        if (chatId.isEmpty) return;
        _controllerFor(_chatChangedControllers, chatId).add(null);
        _chatListChangedController.add(null);
      });
      connection.on('notificationCreated', (arguments) {
        if (arguments == null || arguments.isEmpty) return;
        final payload = arguments.first;
        if (payload is! Map) return;
        final notification = payload['notification'];
        if (notification is Map) {
          _notificationCreatedController.add(
            Map<String, dynamic>.from(notification),
          );
        }
        final unreadCount = _toInt(payload['unreadCount']);
        if (unreadCount != null) {
          _notificationsUnreadCountController.add(unreadCount);
        }
      });
      connection.on('notificationsChanged', (arguments) {
        if (arguments == null || arguments.isEmpty) return;
        final payload = arguments.first;
        if (payload is! Map) return;
        final unreadCount = _toInt(payload['unreadCount']);
        if (unreadCount != null) {
          _notificationsUnreadCountController.add(unreadCount);
        }
      });
      connection.on('activityChanged', (arguments) {
        if (arguments == null || arguments.isEmpty) return;
        final payload = arguments.first;
        if (payload is! Map) return;
        final activityId = _stringField([payload], 'activityId');
        if (activityId.isEmpty) return;
        final changeType = (payload['changeType'] ?? '').toString();
        _activityChangedController.add(
          ActivityChangedEvent(activityId: activityId, changeType: changeType),
        );
      });

      await connection.start();
      _connection = connection;
      await _restoreSubscriptions();
    } catch (e) {
      debugPrint('SignalR connection failed: $e');
    } finally {
      _connecting = false;
    }
  }

  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      try {
        await connection.stop();
      } catch (e) {
        debugPrint('SignalR disconnect error: $e');
      }
    }
  }

  Future<void> subscribeFeed() async {
    _feedSubscribed = true;
    await ensureConnected();
    await _safeInvoke('SubscribeFeed');
  }

  Future<void> subscribeUser(String userId) async {
    if (userId.isEmpty) return;
    _subscribedUsers.add(userId);
    await ensureConnected();
    await _safeInvoke('SubscribeUser', args: <Object>[userId]);
  }

  Future<void> subscribePresence(String city) async {
    final trimmed = city.trim();
    if (trimmed.isEmpty) return;
    final previous = _presenceCity;
    _presenceCity = trimmed;
    await ensureConnected();

    if (previous != null &&
        previous.isNotEmpty &&
        previous.toLowerCase() != trimmed.toLowerCase()) {
      await _safeInvoke('UnsubscribePresence', args: <Object>[previous]);
    }

    await _safeInvoke('SubscribePresence', args: <Object>[trimmed]);
  }

  Future<void> subscribeChat(String chatId) async {
    if (chatId.isEmpty) return;
    _subscribedChats.add(chatId);
    await ensureConnected();
    await _safeInvoke('SubscribeChat', args: <Object>[chatId]);
  }

  Future<bool> updatePresence({
    required double latitude,
    required double longitude,
    required String mode,
    required bool shareProfile,
    required bool isSignalActive,
    required String city,
  }) async {
    try {
      await ensureConnected();
      await _safeInvoke(
        'UpdatePresence',
        args: <Object>[
          latitude,
          longitude,
          mode,
          shareProfile,
          isSignalActive,
          city,
        ],
      );
      return true;
    } catch (e) {
      debugPrint('SignalR presence update failed: $e');
      return false;
    }
  }

  Future<void> _restoreSubscriptions() async {
    if (_connection == null) return;

    if (_feedSubscribed) {
      await _safeInvoke('SubscribeFeed');
    }
    if (_presenceCity != null && _presenceCity!.isNotEmpty) {
      await _safeInvoke('SubscribePresence', args: <Object>[_presenceCity!]);
    }
    for (final chatId in _subscribedChats) {
      await _safeInvoke('SubscribeChat', args: <Object>[chatId]);
    }
    for (final userId in _subscribedUsers) {
      await _safeInvoke('SubscribeUser', args: <Object>[userId]);
    }
  }

  Future<void> _safeInvoke(String method, {List<Object>? args}) async {
    final connection = _connection;
    if (connection == null) return;

    try {
      if (connection.state == HubConnectionState.Disconnected) {
        await connection.start();
      }
      await connection.invoke(method, args: args);
    } catch (e) {
      debugPrint('SignalR invoke failed ($method): $e');
    }
  }

  StreamController<void> _controllerFor(
    Map<String, StreamController<void>> map,
    String key,
  ) {
    return map.putIfAbsent(key, () => StreamController<void>.broadcast());
  }

  String _stringField(List<Object?>? arguments, String key) {
    if (arguments == null || arguments.isEmpty) {
      return '';
    }

    final payload = arguments.first;
    if (payload is Map) {
      return payload[key]?.toString() ?? '';
    }

    return '';
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }
}

class ActivityChangedEvent {
  ActivityChangedEvent({required this.activityId, required this.changeType});

  final String activityId;

  /// "created" | "updated" | "cancelled" | "participants"
  final String changeType;
}
