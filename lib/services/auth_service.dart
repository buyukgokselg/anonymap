import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/mode_config.dart';
import 'api_exception.dart';
import 'notification_service.dart';
import 'runtime_config_service.dart';

class AuthSession {
  final String accessToken;
  final DateTime expiresAt;
  final String userId;
  final String email;
  final String userName;
  final String displayName;
  final String profilePhotoUrl;
  final String mode;
  final String privacyLevel;
  final String preferredLanguage;
  final bool isVisible;
  final bool isOnboarded;

  const AuthSession({
    required this.accessToken,
    required this.expiresAt,
    required this.userId,
    required this.email,
    required this.userName,
    required this.displayName,
    required this.profilePhotoUrl,
    required this.mode,
    required this.privacyLevel,
    required this.preferredLanguage,
    required this.isVisible,
    required this.isOnboarded,
  });

  factory AuthSession.fromMap(Map<String, dynamic> map) {
    final user = Map<String, dynamic>.from(map['user'] ?? const {});
    return AuthSession(
      accessToken: (map['accessToken'] ?? '').toString(),
      expiresAt:
          DateTime.tryParse((map['expiresAt'] ?? '').toString()) ??
          DateTime.now().add(const Duration(days: 7)),
      userId: (user['id'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      userName: (user['userName'] ?? '').toString(),
      displayName: (user['displayName'] ?? '').toString(),
      profilePhotoUrl: (user['profilePhotoUrl'] ?? '').toString(),
      mode: ModeConfig.normalizeId(user['mode']?.toString()),
      privacyLevel: (user['privacyLevel'] ?? 'full').toString(),
      preferredLanguage: (user['preferredLanguage'] ?? 'tr').toString(),
      isVisible: user['isVisible'] ?? true,
      isOnboarded: user['isOnboarded'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accessToken': accessToken,
      'expiresAt': expiresAt.toIso8601String(),
      'user': {
        'id': userId,
        'email': email,
        'userName': userName,
        'displayName': displayName,
        'profilePhotoUrl': profilePhotoUrl,
        'mode': mode,
        'privacyLevel': privacyLevel,
        'preferredLanguage': preferredLanguage,
        'isVisible': isVisible,
        'isOnboarded': isOnboarded,
      },
    };
  }

  AuthSession copyWith({
    String? accessToken,
    DateTime? expiresAt,
    String? userId,
    String? email,
    String? userName,
    String? displayName,
    String? profilePhotoUrl,
    String? mode,
    String? privacyLevel,
    String? preferredLanguage,
    bool? isVisible,
    bool? isOnboarded,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      expiresAt: expiresAt ?? this.expiresAt,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      userName: userName ?? this.userName,
      displayName: displayName ?? this.displayName,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      mode: mode ?? this.mode,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      isVisible: isVisible ?? this.isVisible,
      isOnboarded: isOnboarded ?? this.isOnboarded,
    );
  }
}

class AuthResult {
  final AuthSession session;
  final bool isNewUser;

  const AuthResult({required this.session, required this.isNewUser});
}

class AuthService {
  AuthService._internal();

  static final AuthService _instance = AuthService._internal();
  static const _storageKey = 'pulsecity.auth.session';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  factory AuthService() => _instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email'],
    serverClientId:
        '51483368324-31hlp0as81o4lnbbduiu4u6r3s9i8hht.apps.googleusercontent.com',
  );
  final StreamController<AuthSession?> _authStateController =
      StreamController<AuthSession?>.broadcast();

  SharedPreferences? _prefs;
  AuthSession? _session;
  bool _initialized = false;

  AuthSession? get currentUser => _session;
  String get currentUserId => _session?.userId ?? '';
  String get currentUserEmail => _session?.email ?? '';
  String get currentUserName => _session?.displayName ?? '';
  String get currentUserUsername => _session?.userName ?? '';
  String get currentUserPhotoUrl => _session?.profilePhotoUrl ?? '';
  String get accessToken => _session?.accessToken ?? '';
  bool get isLoggedIn =>
      _session != null && _session!.accessToken.isNotEmpty && !_isExpired;
  bool get _isExpired =>
      _session == null || _session!.expiresAt.isBefore(DateTime.now());

  Stream<AuthSession?> get authStateChanges => _authStateController.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();

    var rawSession = await _secureStorage.read(key: _storageKey);
    if (rawSession == null || rawSession.isEmpty) {
      final legacySession = _prefs?.getString(_storageKey);
      if (legacySession != null && legacySession.isNotEmpty) {
        rawSession = legacySession;
        await _secureStorage.write(key: _storageKey, value: legacySession);
        await _prefs?.remove(_storageKey);
      }
    }

    if (rawSession != null && rawSession.isNotEmpty) {
      try {
        _session = AuthSession.fromMap(
          Map<String, dynamic>.from(json.decode(rawSession)),
        );
        if (_isExpired) {
          await logout(notify: false);
        }
      } catch (e) {
        debugPrint('Auth session decode error: $e');
      }
    }

    _initialized = true;
    _authStateController.add(_session);
  }

  Future<AuthResult> register({
    required String firstName,
    required String email,
    required String password,
    required String city,
    required String gender,
    required DateTime birthDate,
    required String mode,
    String? lastName,
    String matchPreference = 'auto',
  }) async {
    final body = <String, dynamic>{
      'firstName': firstName.trim(),
      'email': email.trim(),
      'password': password,
      'city': city.trim(),
      'gender': gender,
      'birthDate': birthDate.toIso8601String(),
      'matchPreference': matchPreference,
      'mode': mode,
    };
    final trimmedLastName = lastName?.trim();
    if (trimmedLastName != null && trimmedLastName.isNotEmpty) {
      body['lastName'] = trimmedLastName;
    }
    final response = await _post('/api/auth/register', body);
    return _consumeAuthResponse(response);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _post('/api/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    return _consumeAuthResponse(response);
  }

  Future<AuthResult?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final auth = await googleUser.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw 'Google kimlik doğrulaması alınamadı.';
    }

    final response = await _post('/api/auth/google', {'idToken': idToken});
    return _consumeAuthResponse(response);
  }

  Future<void> logout({bool notify = true}) async {
    if (isLoggedIn) {
      try {
        final uri = _uri('/api/presence/online-status');
        await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${_session!.accessToken}',
            'ngrok-skip-browser-warning': 'true',
          },
          body: json.encode({'isOnline': false}),
        );
      } catch (error, stackTrace) {
        debugPrint('Online status update failed during logout: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    try {
      await _googleSignIn.signOut();
    } catch (error, stackTrace) {
      debugPrint('Google sign-out failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    // Unregister FCM token on logout
    try {
      await NotificationService().unregisterToken();
    } catch (e) {
      debugPrint('FCM token unregister on logout failed: $e');
    }

    _session = null;
    await _secureStorage.delete(key: _storageKey);
    await _prefs?.remove(_storageKey);
    if (notify) {
      _authStateController.add(null);
    }
  }

  Future<void> resetPassword(String email) async {
    await _post('/api/auth/password/forgot', {'email': email.trim()});
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _post('/api/auth/password/reset', {
      'email': email.trim(),
      'code': code.trim(),
      'newPassword': newPassword,
    });
  }

  Future<void> deleteCurrentAccount() async {
    if (!isLoggedIn) return;
    await _delete('/api/auth/me');
    await logout();
  }

  Future<Map<String, dynamic>?> fetchCurrentProfile() async {
    if (!isLoggedIn) return null;
    final response = await _get('/api/auth/me');
    if (response is! Map) return null;
    return Map<String, dynamic>.from(response);
  }

  Future<void> updateSessionFromProfile(Map<String, dynamic> profile) async {
    final current = _session;
    if (current == null) return;

    _session = current.copyWith(
      userName: (profile['userName'] ?? current.userName).toString(),
      displayName: (profile['displayName'] ?? current.displayName).toString(),
      profilePhotoUrl: (profile['profilePhotoUrl'] ?? current.profilePhotoUrl)
          .toString(),
      mode: (profile['mode'] ?? current.mode).toString(),
      privacyLevel: (profile['privacyLevel'] ?? current.privacyLevel)
          .toString(),
      preferredLanguage:
          (profile['preferredLanguage'] ?? current.preferredLanguage)
              .toString(),
      isVisible: profile['isVisible'] ?? current.isVisible,
      isOnboarded: (profile['interests'] as List? ?? const []).isNotEmpty,
    );
    await _persistSession();
    _authStateController.add(_session);
  }

  Future<Map<String, String>> authorizedHeaders() async {
    await initialize();
    if (!isLoggedIn) {
      return {
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };
    }

    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer ${_session!.accessToken}',
      'ngrok-skip-browser-warning': 'true',
    };
  }

  Future<dynamic> _get(String path) async {
    final uri = _uri(path);
    final response = await _guardRequest(
      () async => http
          .get(uri, headers: await authorizedHeaders())
          .timeout(const Duration(seconds: 15)),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final uri = _uri(path);
    final response = await _guardRequest(
      () => http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15)),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> _delete(String path) async {
    final uri = _uri(path);
    final response = await _guardRequest(
      () async => http
          .delete(uri, headers: await authorizedHeaders())
          .timeout(const Duration(seconds: 15)),
    );
    return _decodeResponse(response);
  }

  Uri _uri(String path) {
    final baseUrl = RuntimeConfigService.backendBaseUrl.trim();
    if (baseUrl.isEmpty) {
      throw 'Backend adresi ayarlı değil.';
    }
    return Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path');
  }

  dynamic _decodeResponse(http.Response response) {
    dynamic payload;
    if (response.body.isNotEmpty) {
      try {
        payload = json.decode(response.body);
      } catch (_) {
        payload = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload;
    }

    if (payload is Map && payload['message'] != null) {
      throw payload['message'].toString();
    }

    throw 'İstek başarısız oldu (${response.statusCode}).';
  }

  AuthResult _consumeAuthResponse(dynamic response) {
    if (response is! Map) {
      throw 'Geçersiz oturum yanıtı alındı.';
    }

    _session = AuthSession.fromMap(Map<String, dynamic>.from(response));
    unawaited(_persistSession());
    _authStateController.add(_session);

    // Register FCM token after successful login
    unawaited(
      NotificationService().initialize().catchError(
        (e) => debugPrint('Notification init after login error: $e'),
      ),
    );

    return AuthResult(
      session: _session!,
      isNewUser: response['isNewUser'] ?? false,
    );
  }

  Future<void> _persistSession() async {
    await initialize();
    final encoded = json.encode(_session?.toMap());
    await _secureStorage.write(key: _storageKey, value: encoded);
    await _prefs?.remove(_storageKey);
  }

  Future<http.Response> _guardRequest(
    Future<http.Response> Function() action,
  ) async {
    try {
      return await action();
    } on TimeoutException {
      throw const ApiException(
        'The request timed out. Please try again.',
        kind: ApiErrorKind.timeout,
      );
    } on SocketException {
      throw const ApiException(
        'No network connection is available.',
        kind: ApiErrorKind.network,
      );
    } on http.ClientException catch (error) {
      throw ApiException(error.message, kind: ApiErrorKind.network);
    }
  }
}
