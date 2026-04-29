import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'config/mapbox_access.dart';
import 'localization/app_localizations.dart';
import 'navigation/app_route_observer.dart';
import 'screens/splash_screen.dart';
import 'services/app_locale_service.dart';
import 'services/app_presence_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/notifications_inbox_service.dart';
import 'services/place_focus_service.dart';
import 'services/realtime_service.dart';
import 'services/runtime_config_service.dart';
import 'theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter framework error: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled platform error: $error');
    debugPrint(stack.toString());
    return true;
  };

  ErrorWidget.builder = (details) => _AppRenderFallback(details: details);

  await RuntimeConfigService.initialize();
  await AuthService().initialize();
  // Initialize push notifications if user is logged in
  if (AuthService().isLoggedIn) {
    NotificationService().initialize().catchError(
      (e) => debugPrint('Notification init error: $e'),
    );
    unawaited(NotificationsInboxService.instance.fetchUnreadCount());
  }
  await AppLocaleService.instance.initialize();
  await RealtimeService.instance.initialize();
  await AppPresenceService.instance.initialize();

  if (kMapboxPublicAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(kMapboxPublicAccessToken);
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const PulseCityApp());
}

class PulseCityApp extends StatelessWidget {
  const PulseCityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocaleService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'PulseCity',
          debugShowCheckedModeBanner: false,
          navigatorKey: rootNavigatorKey,
          locale: AppLocaleService.instance.locale,
          navigatorObservers: [appRouteObserver],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.bgMain,
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class _AppRenderFallback extends StatelessWidget {
  const _AppRenderFallback({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final languageCode = AppLocaleService.instance.languageCode;
    final title = switch (languageCode) {
      'en' => 'This section could not be displayed.',
      'de' => 'Dieser Bereich konnte nicht angezeigt werden.',
      _ => 'Bu alan şu anda gösterilemiyor.',
    };
    final subtitle = switch (languageCode) {
      'en' => 'Try reopening the screen.',
      'de' => 'Versuche, den Bildschirm erneut zu öffnen.',
      _ => 'Ekranı yeniden açmayı deneyebilirsin.',
    };
    final debugHint = switch (languageCode) {
      'en' => 'Debug details are shown below.',
      'de' => 'Debug-Details werden unten angezeigt.',
      _ => 'Debug detayları aşağıda gösteriliyor.',
    };

    return Material(
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      height: 1.4,
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 14),
                    Text(
                      debugHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgMain,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        details.exceptionAsString(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
