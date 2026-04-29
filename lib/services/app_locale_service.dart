import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'dart:async';

class AppLocaleService extends ChangeNotifier {
  AppLocaleService._internal();

  static final AppLocaleService instance = AppLocaleService._internal();
  static const _storageKey = 'pulsecity.locale';

  SharedPreferences? _prefs;
  Locale _locale = const Locale('tr');
  bool _initialized = false;
  // Keeps the auth-state listener alive for the lifetime of the singleton.
  // ignore: unused_field
  StreamSubscription<AuthSession?>? _authSub;

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;

  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    final preferred =
        _prefs?.getString(_storageKey) ??
        AuthService().currentUser?.preferredLanguage ??
        'tr';
    _locale = Locale(_normalize(preferred));
    _authSub = AuthService().authStateChanges.listen((session) async {
      final preferredLanguage = session?.preferredLanguage;
      if (preferredLanguage == null || preferredLanguage.isEmpty) return;
      await setLanguageCode(preferredLanguage);
    });
    _initialized = true;
  }

  Future<void> setLanguageCode(String code) async {
    final normalized = _normalize(code);
    if (normalized == _locale.languageCode) return;
    _locale = Locale(normalized);
    await _prefs?.setString(_storageKey, normalized);
    notifyListeners();
  }

  String _normalize(String code) {
    final value = code.trim().toLowerCase();
    return switch (value) {
      'tr' || 'en' || 'de' => value,
      _ => 'tr',
    };
  }
}
