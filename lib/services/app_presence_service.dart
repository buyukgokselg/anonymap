import 'dart:async';

import 'package:flutter/widgets.dart';

import 'auth_service.dart';
import 'pulse_api_service.dart';

class AppPresenceService with WidgetsBindingObserver {
  AppPresenceService._();

  static final AppPresenceService instance = AppPresenceService._();

  final AuthService _authService = AuthService();
  final PulseApiService _api = PulseApiService.instance;

  bool _initialized = false;
  bool? _lastOnlineState;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  Future<void> initialize() async {
    if (_initialized) return;

    _lifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _authService.authStateChanges.listen((_) {
      unawaited(_syncOnlineStatus(force: true));
    });
    _initialized = true;
    await _syncOnlineStatus(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    unawaited(_syncOnlineStatus());
  }

  Future<void> _syncOnlineStatus({bool force = false}) async {
    final shouldBeOnline =
        _authService.isLoggedIn && _lifecycleState == AppLifecycleState.resumed;

    if (!force && _lastOnlineState == shouldBeOnline) {
      return;
    }

    _lastOnlineState = shouldBeOnline;

    if (!_authService.isLoggedIn) {
      return;
    }

    try {
      await _api.updateOnlineStatus(shouldBeOnline);
    } catch (error, stackTrace) {
      debugPrint('App presence sync failed: $error\n$stackTrace');
    }
  }
}
