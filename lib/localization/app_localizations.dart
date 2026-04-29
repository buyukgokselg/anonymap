import 'dart:convert';

import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  String get languageCode => locale.languageCode;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('tr'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const supportedLocales = [Locale('tr'), Locale('en'), Locale('de')];
  static final Map<String, Map<String, String>> _canonicalTranslations =
      _buildCanonicalTable(_translations);
  static final Map<String, Map<String, String>> _canonicalPhrases =
      _buildCanonicalTable(_phrases);
  static final Map<String, String> _canonicalAliases = _buildCanonicalAliases();
  static final RegExp _brokenSequencePattern = RegExp(
    '[\\u00C2-\\u00C5][\\u0080-\\u00FF]|\\u00E2[\\u0080-\\u00FF]{2}',
  );
  static final RegExp _brokenQuestionPattern = RegExp(
    r'\?{2,}|[A-Za-zÇĞİÖŞÜÄÖÜçğıöşüäöüß]\?[A-Za-zÇĞİÖŞÜÄÖÜçğıöşüäöüß]|(^|[\s"({\[])\?[A-Za-zÇĞİÖŞÜÄÖÜçğıöşüäöüß]',
  );

  static const Map<String, Map<String, String>> _translations = {
    'tr': {
      'settings': 'Ayarlar',
      'privacy': 'Gizlilik',
      'language': 'Dil',
      'cancel': 'İptal',
      'close': 'Kapat',
      'email': 'E-posta adresin',
      'password': 'Şifren',
      'password_hint': 'Şifre oluştur',
      'confirm_password': 'Şifreyi doğrula',
      'login': 'Giriş Yap',
      'login_title_line1': 'Şehrin nabzını',
      'login_title_line2': 'Şimdi keşfet',
      'login_subtitle': 'Yakındaki insanları, canlı mekanları ve anlık şehir akışını tek yerde gör.',
      'login_live_context': 'Şehir şu anda canlı. Anonim sinyaller nabzın etrafında akıyor.',
      'login_signal_badge': 'CANLI ŞEHİR SİNYALİ',
      'login_card_title': 'Yeniden hoş geldin',
      'login_card_subtitle': 'Kaldığın yerden şehir akışına bağlan ve anı kaçırma.',
      'login_active_users': 'aktif kullanıcı',
      'login_live_places': 'canlı mekan',
      'login_rising_zones': 'yükselen bölge',
      'forgot_password': 'Şifremi unuttum',
      'register_cta_prefix': 'Hesabın yok mu?',
      'register_cta': 'Kayıt ol',
      'register_title_line1': "PulseCity'ye",
      'register_title_line2': 'katıl',
      'register_subtitle': 'Şehrin canlı akışını keşfetmek, paylaşmak ve yeni insanlarla bağlanmak için hesabını oluştur.',
      'register_profile_details': 'Profil bilgileri',
      'register_account_details': 'Hesap bilgileri',
      'first_name': 'Ad',
      'last_name': 'Soyad',
      'birth_date': 'Doğum tarihi',
      'gender': 'Cinsiyet',
      'gender_male': 'Erkek',
      'gender_female': 'Kadın',
      'gender_nonbinary': 'Non-binary',
      'match_preference': 'Eşleşme tercihi',
      'match_preference_auto': 'Otomatik',
      'match_preference_women': 'Kadınlar',
      'match_preference_men': 'Erkekler',
      'match_preference_everyone': 'Herkes',
      'register_age_requirement': 'Kayıt olmak için en az 18 yaşında olmalısın.',
      'continue_with_google': 'Google ile devam et',
      'or_email': 'veya e-posta ile',
      'terms_prefix': 'Devam ederek',
      'terms_of_service': 'Kullanım Koşulları',
      'privacy_policy': 'Gizlilik Politikası',
      'create_account': 'Hesap oluştur',
      'fill_all_fields': 'Lütfen tüm alanları doldur.',
      'invalid_email': 'Geçerli bir e-posta adresi gir.',
      'password_too_short': 'Şifren en az 6 karakter olmalı.',
      'passwords_mismatch': 'Şifreler eşleşmiyor.',
      'accept_terms_required': 'Devam etmek için koşulları ve gizlilik politikasını kabul et.',
      'accept_terms_google': 'Google ile devam etmeden önce koşulları ve gizlilik politikasını kabul et.',
      'password_strength_weak': 'Zayıf',
      'password_strength_medium': 'Orta',
      'password_strength_strong': 'Güçlü',
      'password_strength_very_strong': 'Çok güçlü',
      'reset_password_sent': 'Şifre sıfırlama bağlantısı gönderildi.',
      'reset_password_requires_email': 'Önce e-posta adresini girmen gerekiyor.',
      'reset_password_title': 'Şifreyi yenile',
      'reset_password_subtitle': 'E-postana gelen kodu gir, sonra yeni şifreni belirle.',
      'reset_password_code_hint': 'Sıfırlama kodu',
      'reset_password_new_password': 'Yeni şifre',
      'reset_password_submit': 'Şifreyi güncelle',
      'reset_password_success': 'Şifren güncellendi. Yeni şifrenle giriş yapabilirsin.',
      'reset_password_resend': 'Kodu yeniden gönder',
      'reset_password_resending': 'Kod gönderiliyor...',
      'story_viewers_title': 'Görenler',
      'story_viewers_count_suffix': 'görüntüleme',
      'story_viewers_empty': 'Henüz görüntüleyen yok.',
      'shorts_scope_personal': 'Sana uygun',
      'shorts_scope_global': 'Genel shorts',
      'shorts_personal_title': 'Sana uygun shorts',
      'shorts_personal_subtitle': 'Genel moduna, yak\u0131nl\u0131\u011f\u0131na ve yeni payla\u015f\u0131lan videolara g\u00f6re se\u00e7ildi.',
      'shorts_personal_empty': 'Bu modda yak\u0131n\u0131nda hen\u00fcz short yok.',
      'shorts_personal_hint': 'Profil moduna g\u00f6re yak\u0131n k\u0131sa videolar burada ak\u0131yor.',
      'shorts_global_title': 'Genel shorts',
      'shorts_global_subtitle': 'PulseCity i\u00e7indeki t\u00fcm k\u0131sa videolar\u0131 tek ak\u0131\u015fta izle.',
      'shorts_global_empty': 'Hen\u00fcz genel short ak\u0131\u015f\u0131 yok.',
      'messages': 'Mesajlar',
      'temporary': 'Geçici',
      'requests': 'İstekler',
      'discover': 'Keşfet',
      'posts': 'Paylaşım',
      'live': 'Canlı',
      'user': 'Kullanıcı',
      'now': 'Şimdi',
      'comments': 'Yorumlar',
      'download_started': 'Veri dışa aktarma hazırlanıyor.',
      'download_ready': 'Veri dışa aktarma dosyan hazır.',
      'download_failed': 'Veri dışa aktarma başlatılamadı.',
      'privacy_visibility': 'Profil görünürlüğü',
      'privacy_visibility_sub': 'Signal, profil ve canlı katkılarda görünür olup olmayacağını seç.',
      'ghost_mode': 'Ghost mode',
      'ghost_mode_sub': 'Canlı katkını gizle ve görünürlüğünü en aza indir.',
      'differential_privacy': 'Differential privacy',
      'differential_privacy_sub': 'Toplu sinyaller içinde bireysel hareketini belirsizleştir.',
      'analytics': 'Anonim analitik',
      'analytics_sub': 'Ürünü geliştirmek için anonim kullanım verilerini paylaş.',
      'location_granularity': 'Konum hassasiyeti',
      'location_granularity_sub': 'Yakındaki insanlar seni hangi doğrulukta görsün seç.',
      'k_anonymity': 'k-Anonimlik seviyesi',
      'k_anonymity_sub': 'Yakınında yeterli kişi yoksa hassas görünürlüğü otomatik azalt.',
      'legal': 'Yasal',
      'export_data': 'Verilerimi dışa aktar',
      'export_data_sub': 'Profilini, paylaşımlarını ve temel hesap kayıtlarını indir.',
      'account': 'Hesap',
      'logout': 'Çıkış yap',
      'delete_account': 'Hesabı sil',
      'exact': 'Tam konum',
      'nearby': 'Yakın çevre',
      'district': 'İlçe',
      'city': 'Şehir',
      'select_language': 'Uygulama dili',
      'language_saved': 'Dil tercihi kaydedildi.',
      'privacy_saved': 'Gizlilik tercihi güncellendi.',
      'profile_mode_title': 'Profil modu',
      'profile_interests_title': 'İlgi alanları',
      'profile_highlights_title': 'Öne çıkanlar',
      'section_edit': 'Düzenle',
      'section_manage': 'Yönet',
      'profile_add_interests': 'İlgi alanlarını ekle',
      'exit_app_title': 'Uygulamadan çık',
      'exit_app_message': 'Uygulamayı kapatmak istediğine emin misin?',
      'exit_app_confirm': 'Çık',
      'shopping_title': 'Alışveriş',
      'shopping_subtitle': 'Yakındaki mağazalar ve AVM\'ler',
      'shopping_cat_all': 'Tümü',
      'shopping_cat_mall': 'AVM & Outlet',
      'shopping_cat_clothing': 'Giyim',
      'shopping_cat_tech': 'Teknoloji',
      'shopping_cat_home': 'Ev & Mobilya',
      'shopping_cat_market': 'Market',
      'shopping_cat_cosmetics': 'Kozmetik',
      'shopping_cat_sports': 'Spor',
      'shopping_cat_books': 'Kitap',
      'shopping_cat_garden': 'Bahçe & DIY',
      'shopping_cat_accessories': 'Aksesuar',
      'shopping_featured': 'Öne Çıkan AVM\'ler',
      'shopping_all_stores': 'Tüm Mağazalar',
      'shopping_open': 'Açık',
      'shopping_closed': 'Kapalı',
      'shopping_open_now': 'Şu an Açık',
      'shopping_closed_now': 'Şu an Kapalı',
      'shopping_error': 'Yerler yüklenemedi. Tekrar dene.',
      'shopping_retry': 'Tekrar Dene',
      'shopping_empty': 'Bu kategoride yakında\nmağaza bulunamadı.',
      'shopping_directions': 'Yol Tarifi Al',
      'shopping_detail_title': 'Mağaza Detayı',
      'activity_validation_title_required': 'Başlık ekle.',
      'activity_validation_title_too_short': 'Başlık biraz daha açıklayıcı olsun.',
      'activity_validation_location_required': 'Buluşma yeri seç.',
      'activity_validation_city_required': 'Şehir gerekli.',
      'activity_validation_coordinates_required':
          'Koordinat al — konum izni gerekiyor.',
      'activity_validation_start_in_future': 'Başlangıç ileri bir zaman olmalı.',
      'activity_validation_end_after_start':
          'Bitiş zamanı, başlangıçtan sonra olmalı.',
      'activity_validation_age_range_invalid': 'Yaş aralığını gözden geçir.',
    },
    'en': {
      'settings': 'Settings',
      'privacy': 'Privacy',
      'language': 'Language',
      'cancel': 'Cancel',
      'close': 'Close',
      'email': 'Email address',
      'password': 'Password',
      'password_hint': 'Create a password',
      'confirm_password': 'Confirm password',
      'login': 'Log in',
      'login_title_line1': 'Feel the pulse',
      'login_title_line2': 'of your city',
      'login_subtitle': 'See nearby people, live places, and the real-time city flow in one place.',
      'login_live_context': 'The city is live right now. Anonymous signals move around the pulse.',
      'login_signal_badge': 'LIVE CITY SIGNAL',
      'login_card_title': 'Welcome back',
      'login_card_subtitle': 'Pick up the city pulse right where you left it.',
      'login_active_users': 'active users',
      'login_live_places': 'live places',
      'login_rising_zones': 'rising zones',
      'forgot_password': 'Forgot password?',
      'register_cta_prefix': "Don't have an account?",
      'register_cta': 'Sign up',
      'register_title_line1': 'Join',
      'register_title_line2': 'PulseCity',
      'register_subtitle': 'Create your account to discover the live city pulse, share moments, and meet new people nearby.',
      'register_profile_details': 'Profile details',
      'register_account_details': 'Account details',
      'first_name': 'First name',
      'last_name': 'Last name',
      'birth_date': 'Birth date',
      'gender': 'Gender',
      'gender_male': 'Male',
      'gender_female': 'Female',
      'gender_nonbinary': 'Non-binary',
      'match_preference': 'Match preference',
      'match_preference_auto': 'Automatic',
      'match_preference_women': 'Women',
      'match_preference_men': 'Men',
      'match_preference_everyone': 'Everyone',
      'register_age_requirement': 'You must be at least 18 years old to register.',
      'continue_with_google': 'Continue with Google',
      'or_email': 'or use email',
      'terms_prefix': 'By continuing, you agree to the',
      'terms_of_service': 'Terms of Service',
      'privacy_policy': 'Privacy Policy',
      'create_account': 'Create account',
      'fill_all_fields': 'Please fill in all fields.',
      'invalid_email': 'Enter a valid email address.',
      'password_too_short': 'Your password must be at least 6 characters.',
      'passwords_mismatch': 'Passwords do not match.',
      'accept_terms_required': 'You need to accept the terms and privacy policy to continue.',
      'accept_terms_google': 'Accept the terms and privacy policy before continuing with Google.',
      'password_strength_weak': 'Weak',
      'password_strength_medium': 'Fair',
      'password_strength_strong': 'Strong',
      'password_strength_very_strong': 'Very strong',
      'reset_password_sent': 'Password reset link sent.',
      'reset_password_requires_email': 'Enter your email address first.',
      'reset_password_title': 'Reset your password',
      'reset_password_subtitle': 'Enter the code from your email, then choose a new password.',
      'reset_password_code_hint': 'Reset code',
      'reset_password_new_password': 'New password',
      'reset_password_submit': 'Update password',
      'reset_password_success': 'Your password has been updated. You can now sign in.',
      'reset_password_resend': 'Send the code again',
      'reset_password_resending': 'Sending code...',
      'story_viewers_title': 'Viewers',
      'story_viewers_count_suffix': 'views',
      'story_viewers_empty': 'No viewers yet.',
      'shorts_scope_personal': 'For you',
      'shorts_scope_global': 'Global shorts',
      'shorts_personal_title': 'Shorts for you',
      'shorts_personal_subtitle': 'Picked for your profile mode, nearby activity, and fresh uploads.',
      'shorts_personal_empty': 'No nearby shorts match this mode yet.',
      'shorts_personal_hint': 'Nearby short videos flow here based on your profile mode.',
      'shorts_global_title': 'Global shorts',
      'shorts_global_subtitle': 'Watch short videos from across PulseCity in one continuous stream.',
      'shorts_global_empty': 'No global shorts yet.',
      'messages': 'Messages',
      'temporary': 'Temporary',
      'requests': 'Requests',
      'discover': 'Discover',
      'posts': 'Posts',
      'live': 'Live',
      'user': 'User',
      'now': 'Now',
      'comments': 'Comments',
      'download_started': 'Preparing your data export.',
      'download_ready': 'Your data export is ready.',
      'download_failed': 'Could not start the data export.',
      'privacy_visibility': 'Profile visibility',
      'privacy_visibility_sub': 'Choose whether you appear in Signal, your profile, and live posts.',
      'ghost_mode': 'Ghost mode',
      'ghost_mode_sub': 'Hide your live contribution and keep your visibility minimal.',
      'differential_privacy': 'Differential privacy',
      'differential_privacy_sub': 'Add uncertainty to aggregated signals to protect individual behavior.',
      'analytics': 'Anonymous analytics',
      'analytics_sub': 'Share anonymous usage data so PulseCity can improve.',
      'location_granularity': 'Location precision',
      'location_granularity_sub': 'Choose how precisely nearby people can see your area.',
      'k_anonymity': 'k-anonymity level',
      'k_anonymity_sub': 'Reduce visibility automatically when too few people are nearby.',
      'legal': 'Legal',
      'export_data': 'Export my data',
      'export_data_sub': 'Download your profile, posts, and essential account records.',
      'account': 'Account',
      'logout': 'Log out',
      'delete_account': 'Delete account',
      'exact': 'Exact',
      'nearby': 'Nearby',
      'district': 'District',
      'city': 'City',
      'select_language': 'App language',
      'language_saved': 'Language preference saved.',
      'privacy_saved': 'Privacy preference updated.',
      'profile_mode_title': 'Profile mode',
      'profile_interests_title': 'Interests',
      'profile_highlights_title': 'Highlights',
      'section_edit': 'Edit',
      'section_manage': 'Manage',
      'profile_add_interests': 'Add your interests',
      'exit_app_title': 'Exit app',
      'exit_app_message': 'Are you sure you want to close the app?',
      'exit_app_confirm': 'Exit',
      'shopping_title': 'Shopping',
      'shopping_subtitle': 'Nearby stores and shopping centers',
      'shopping_cat_all': 'All',
      'shopping_cat_mall': 'Mall & Outlet',
      'shopping_cat_clothing': 'Clothing',
      'shopping_cat_tech': 'Electronics',
      'shopping_cat_home': 'Home & Furniture',
      'shopping_cat_market': 'Supermarket',
      'shopping_cat_cosmetics': 'Beauty',
      'shopping_cat_sports': 'Sports',
      'shopping_cat_books': 'Books',
      'shopping_cat_garden': 'Garden & DIY',
      'shopping_cat_accessories': 'Accessories',
      'shopping_featured': 'Featured Malls',
      'shopping_all_stores': 'All Stores',
      'shopping_open': 'Open',
      'shopping_closed': 'Closed',
      'shopping_open_now': 'Open Now',
      'shopping_closed_now': 'Closed Now',
      'shopping_error': 'Could not load places. Try again.',
      'shopping_retry': 'Try Again',
      'shopping_empty': 'No stores found nearby\nfor this category.',
      'shopping_directions': 'Get Directions',
      'shopping_detail_title': 'Store Details',
      'activity_validation_title_required': 'Add a title.',
      'activity_validation_title_too_short':
          'Make the title a bit more descriptive.',
      'activity_validation_location_required': 'Pick a meeting place.',
      'activity_validation_city_required': 'City is required.',
      'activity_validation_coordinates_required':
          'Get coordinates — location permission required.',
      'activity_validation_start_in_future':
          'Start time must be in the future.',
      'activity_validation_end_after_start':
          'End time must be after the start.',
      'activity_validation_age_range_invalid': 'Check the age range.',
    },
    'de': {
      'settings': 'Einstellungen',
      'privacy': 'Datenschutz',
      'language': 'Sprache',
      'cancel': 'Abbrechen',
      'close': 'Schließen',
      'email': 'E-Mail-Adresse',
      'password': 'Passwort',
      'password_hint': 'Passwort erstellen',
      'confirm_password': 'Passwort bestätigen',
      'login': 'Anmelden',
      'login_title_line1': 'Spüre den Puls',
      'login_title_line2': 'deiner Stadt',
      'login_subtitle': 'Sieh Menschen in deiner Nähe, lebendige Orte und den aktuellen Stadtfluss an einem Ort.',
      'login_live_context': 'Die Stadt lebt gerade. Anonyme Signale bewegen sich um den Puls.',
      'login_signal_badge': 'LIVE STADT-SIGNAL',
      'login_card_title': 'Willkommen zurück',
      'login_card_subtitle': 'Finde sofort zurück in den Live-Puls deiner Stadt.',
      'login_active_users': 'aktive Nutzer',
      'login_live_places': 'aktive Orte',
      'login_rising_zones': 'aufsteigende Zonen',
      'forgot_password': 'Passwort vergessen?',
      'register_cta_prefix': 'Noch kein Konto?',
      'register_cta': 'Registrieren',
      'register_title_line1': 'Werde Teil von',
      'register_title_line2': 'PulseCity',
      'register_subtitle': 'Erstelle dein Konto, um den Live-Pulse der Stadt zu entdecken, Momente zu teilen und neue Menschen in deiner Nähe zu treffen.',
      'register_profile_details': 'Profildaten',
      'register_account_details': 'Kontodaten',
      'first_name': 'Vorname',
      'last_name': 'Nachname',
      'birth_date': 'Geburtsdatum',
      'gender': 'Geschlecht',
      'gender_male': 'Männlich',
      'gender_female': 'Weiblich',
      'gender_nonbinary': 'Nicht-binär',
      'match_preference': 'Match-Präferenz',
      'match_preference_auto': 'Automatisch',
      'match_preference_women': 'Frauen',
      'match_preference_men': 'Männer',
      'match_preference_everyone': 'Alle',
      'register_age_requirement': 'Du musst mindestens 18 Jahre alt sein, um dich zu registrieren.',
      'continue_with_google': 'Mit Google fortfahren',
      'or_email': 'oder mit E-Mail',
      'terms_prefix': 'Mit dem Fortfahren akzeptierst du die',
      'terms_of_service': 'Nutzungsbedingungen',
      'privacy_policy': 'Datenschutzerklärung',
      'create_account': 'Konto erstellen',
      'fill_all_fields': 'Bitte fülle alle Felder aus.',
      'invalid_email': 'Gib eine gültige E-Mail-Adresse ein.',
      'password_too_short': 'Dein Passwort muss mindestens 6 Zeichen lang sein.',
      'passwords_mismatch': 'Die Passwörter stimmen nicht überein.',
      'accept_terms_required': 'Du musst die Nutzungsbedingungen und die Datenschutzerklärung akzeptieren, um fortzufahren.',
      'accept_terms_google': 'Akzeptiere die Nutzungsbedingungen und die Datenschutzerklärung, bevor du mit Google fortfährst.',
      'password_strength_weak': 'Schwach',
      'password_strength_medium': 'Mittel',
      'password_strength_strong': 'Stark',
      'password_strength_very_strong': 'Sehr stark',
      'reset_password_sent': 'Link zum Zurücksetzen des Passworts gesendet.',
      'reset_password_requires_email': 'Gib zuerst deine E-Mail-Adresse ein.',
      'reset_password_title': 'Passwort erneuern',
      'reset_password_subtitle': 'Gib den Code aus deiner E-Mail ein und wähle danach ein neues Passwort.',
      'reset_password_code_hint': 'Zurücksetzungscode',
      'reset_password_new_password': 'Neues Passwort',
      'reset_password_submit': 'Passwort aktualisieren',
      'reset_password_success': 'Dein Passwort wurde aktualisiert. Du kannst dich jetzt anmelden.',
      'reset_password_resend': 'Code erneut senden',
      'reset_password_resending': 'Code wird gesendet...',
      'story_viewers_title': 'Zuschauer',
      'story_viewers_count_suffix': 'Aufrufe',
      'story_viewers_empty': 'Noch keine Aufrufe.',
      'shorts_scope_personal': 'F\u00fcr dich',
      'shorts_scope_global': 'Globale Shorts',
      'shorts_personal_title': 'Shorts f\u00fcr dich',
      'shorts_personal_subtitle': 'Ausgew\u00e4hlt nach deinem Profilmodus, deiner N\u00e4he und frischen Uploads.',
      'shorts_personal_empty': 'In diesem Modus gibt es in deiner N\u00e4he noch keine Shorts.',
      'shorts_personal_hint': 'Hier laufen kurze Videos aus deiner N\u00e4he passend zu deinem Profilmodus.',
      'shorts_global_title': 'Globale Shorts',
      'shorts_global_subtitle': 'Sieh dir kurze Videos aus ganz PulseCity in einem durchgehenden Stream an.',
      'shorts_global_empty': 'Noch keine globalen Shorts.',
      'messages': 'Nachrichten',
      'temporary': 'Temporär',
      'requests': 'Anfragen',
      'discover': 'Entdecken',
      'posts': 'Beiträge',
      'live': 'Live',
      'user': 'Nutzer',
      'now': 'Jetzt',
      'comments': 'Kommentare',
      'download_started': 'Dein Datenexport wird vorbereitet.',
      'download_ready': 'Dein Datenexport ist bereit.',
      'download_failed': 'Der Datenexport konnte nicht gestartet werden.',
      'privacy_visibility': 'Profilsichtbarkeit',
      'privacy_visibility_sub': 'Lege fest, ob du in Signal, im Profil und bei Live-Beiträgen sichtbar bist.',
      'ghost_mode': 'Ghost Mode',
      'ghost_mode_sub': 'Verberge deinen Live-Beitrag und halte deine Sichtbarkeit minimal.',
      'differential_privacy': 'Differential Privacy',
      'differential_privacy_sub': 'Verfälsche aggregierte Signale leicht, um individuelles Verhalten zu schützen.',
      'analytics': 'Anonyme Analysen',
      'analytics_sub': 'Teile anonyme Nutzungsdaten, damit PulseCity besser wird.',
      'location_granularity': 'Standortgenauigkeit',
      'location_granularity_sub': 'Bestimme, wie genau andere deinen Bereich in der Nähe sehen können.',
      'k_anonymity': 'k-Anonymitätsstufe',
      'k_anonymity_sub': 'Reduziere die Sichtbarkeit automatisch, wenn zu wenige Personen in der Nähe sind.',
      'legal': 'Rechtliches',
      'export_data': 'Meine Daten exportieren',
      'export_data_sub': 'Lade dein Profil, deine Beiträge und wichtige Kontodaten herunter.',
      'account': 'Konto',
      'logout': 'Abmelden',
      'delete_account': 'Konto löschen',
      'exact': 'Genau',
      'nearby': 'Nahbereich',
      'district': 'Bezirk',
      'city': 'Stadt',
      'select_language': 'App-Sprache',
      'language_saved': 'Sprache gespeichert.',
      'privacy_saved': 'Datenschutzeinstellung aktualisiert.',
      'profile_mode_title': 'Profilmodus',
      'profile_interests_title': 'Interessen',
      'profile_highlights_title': 'Highlights',
      'section_edit': 'Bearbeiten',
      'section_manage': 'Verwalten',
      'profile_add_interests': 'Interessen hinzufügen',
      'exit_app_title': 'App schließen',
      'exit_app_message': 'Möchtest du die App wirklich schließen?',
      'exit_app_confirm': 'Schließen',
      'shopping_title': 'Einkaufen',
      'shopping_subtitle': 'Geschäfte und Einkaufszentren in der Nähe',
      'shopping_cat_all': 'Alle',
      'shopping_cat_mall': 'Einkaufszentrum',
      'shopping_cat_clothing': 'Kleidung',
      'shopping_cat_tech': 'Elektronik',
      'shopping_cat_home': 'Wohnen & Möbel',
      'shopping_cat_market': 'Supermarkt',
      'shopping_cat_cosmetics': 'Kosmetik',
      'shopping_cat_sports': 'Sport',
      'shopping_cat_books': 'Bücher',
      'shopping_cat_garden': 'Garten & DIY',
      'shopping_cat_accessories': 'Accessoires',
      'shopping_featured': 'Empfohlene Einkaufszentren',
      'shopping_all_stores': 'Alle Geschäfte',
      'shopping_open': 'Offen',
      'shopping_closed': 'Geschlossen',
      'shopping_open_now': 'Jetzt geöffnet',
      'shopping_closed_now': 'Jetzt geschlossen',
      'shopping_error': 'Orte konnten nicht geladen werden. Erneut versuchen.',
      'shopping_retry': 'Erneut versuchen',
      'shopping_empty': 'Keine Geschäfte in dieser\nKategorie in der Nähe gefunden.',
      'shopping_directions': 'Route berechnen',
      'shopping_detail_title': 'Geschäftsdetails',
      'activity_validation_title_required': 'Titel hinzufügen.',
      'activity_validation_title_too_short':
          'Mach den Titel etwas aussagekräftiger.',
      'activity_validation_location_required': 'Treffpunkt wählen.',
      'activity_validation_city_required': 'Stadt ist erforderlich.',
      'activity_validation_coordinates_required':
          'Koordinaten erforderlich — Standortzugriff nötig.',
      'activity_validation_start_in_future':
          'Startzeit muss in der Zukunft liegen.',
      'activity_validation_end_after_start':
          'Endzeit muss nach dem Start liegen.',
      'activity_validation_age_range_invalid': 'Altersspanne prüfen.',
    },
  };
  static const Map<String, Map<String, String>> _phrases = {
    'tr': {
      'Açık': 'Açık',
      'Kapalı': 'Kapalı',
      'Genel Mod': 'Genel Mod',
      'Şehir sana önce bu modla açılsın.': 'Şehir sana önce bu modla açılsın.',
      'Bu profil şehir akışını bu modla kullanıyor.':
          'Bu profil şehir akışını bu modla kullanıyor.',
      'Mod güncellendi.': 'Mod güncellendi.',
      'Mod güncellenemedi.': 'Mod güncellenemedi.',
      'Mod güncelleniyor...': 'Mod güncelleniyor...',
      'Anonim Kullanıcı': 'Anonim Kullanıcı',
      'kullanıcı': 'kullanıcı',
      'Video paylaştı': 'Video paylaştı',
      'Fotoğraf paylaştı': 'Fotoğraf paylaştı',
      'Video gönderildi.': 'Video gönderildi.',
      'Fotoğraf gönderildi.': 'Fotoğraf gönderildi.',
      'yazıyor...': 'yazıyor...',
      'Sohbet yüklenemedi.': 'Sohbet yüklenemedi.',
      'Mesaj gönderilemedi.': 'Mesaj gönderilemedi.',
      'Konum izni gerekli.': 'Konum izni gerekli.',
      'Canlı konum paylaştı': 'Canlı konum paylaştı',
      'Konum paylaşılamadı.': 'Konum paylaşılamadı.',
      '{name} profilini paylaştı.': '{name} profilini paylaştı.',
      'Kullanıcı: @{username}': 'Kullanıcı: @{username}',
      'Sohbet ettiğin kişi: {city}': 'Sohbet ettiğin kişi: {city}',
      'Profil kartı paylaşıldı.': 'Profil kartı paylaşıldı.',
      'Profil paylaşımı başarısız.': 'Profil paylaşımı başarısız.',
      'Gönderi kartı paylaşıldı.': 'Gönderi kartı paylaşıldı.',
      'Gönderi paylaşımı başarısız.': 'Gönderi paylaşımı başarısız.',
      'Gönderi Paylaş': 'Gönderi Paylaş',
      'Paylaşacak bir gönderi yok.': 'Paylaşacak bir gönderi yok.',
      'Medya gönderisi': 'Medya gönderisi',
      'Arkadaşlık isteği gönderildi.': 'Arkadaşlık isteği gönderildi.',
      'Arkadaşlık isteği gönderilemedi.': 'Arkadaşlık isteği gönderilemedi.',
      'Resim Paylaş': 'Resim Paylaş',
      'Video Paylaş': 'Video Paylaş',
      'Konum Paylaş': 'Konum Paylaş',
      'Profil Paylaş': 'Profil Paylaş',
      'Video mesajı': 'Video mesajı',
      'Canlı konum': 'Canlı konum',
      '{author} gönderi paylaştı': '{author} gönderi paylaştı',
      'Bir kullanıcı': 'Bir kullanıcı',
      'Sohbet açılamadı.': 'Sohbet açılamadı.',
      'Aranıyor...': 'Aranıyor...',
      'Arıyor': 'Arıyor',
      'Aç': 'Aç',
      'Uyumlu kişiler aranıyor...': 'Uyumlu kişiler aranıyor...',
      'Yakında aktif birileri göründüğünde burada listelenecek.':
          'Yakında aktif birileri göründüğünde burada listelenecek.',
      'kişi menzilde': 'kişi menzilde',
      'kişi yakınında': 'kişi yakınında',
      'Merkez butona bas ve başla.': 'Merkez butona bas ve başla.',
      'Bu kullanıcı anonim modda. Profil detayları gizli.':
          'Bu kullanıcı anonim modda. Profil detayları gizli.',
      'için arkadaşlık isteği gönderildi.':
          'için arkadaşlık isteği gönderildi.',
      'Anonim moddasın. Adın ve profilin gizli.':
          'Anonim moddasın. Adın ve profilin gizli.',
      'Story / Short Paylaş': 'Story / Short Paylaş',
      'Kısa açıklama': 'Kısa açıklama',
      'Short yayında.': 'Short yayında.',
      'Short Yayınla': 'Short Yayınla',
      'Takipten Çık': 'Takipten Çık',
      'Şehir anlarını kısa videolarla paylaş.':
          'Şehir anlarını kısa videolarla paylaş.',
      'Bu kullanıcı': 'Bu kullanıcı',
      'Gönderi oluşturulamadı.': 'Gönderi oluşturulamadı.',
      'Mekan kaydedildi.': 'Mekan kaydedildi.',
      'Sil': 'Sil',
      'Etkinliklerin': 'Etkinliklerin',
      'İşlem tamamlanamadı': 'İşlem tamamlanamadı',
    },
    'en': {
      'Açık': 'Open',
      'Kapalı': 'Closed',
      'Yorumlar': 'Comments',
      'İlk yorumu sen yaz.': 'Be the first to comment.',
      'Yorum yaz...': 'Write a comment...',
      'Gönder': 'Send',
      'Mekan ara': 'Search places',
      'Önümüzdeki Saatler': 'Upcoming Hours',
      'Puan': 'Rating',
      'Yorum': 'Reviews',
      'Evet': 'Yes',
      'Hayır': 'No',
      'Henüz short yok': 'No shorts yet',
      'Henüz paylaşım yok': 'No posts yet',
      'Kullanıcı': 'User',
      'Yükseliş Adayı': 'Rising Candidate',
      'Gönderi': 'Post',
      'Tahmin': 'Forecast',
      'Topluluk': 'Community',
      'Google': 'Google',
      'Konum': 'Location',
      'Kaydet': 'Save',
      'Paylaş': 'Share',
      'Yakında canlı mekan bulunamadı': 'No nearby live venues found',
      'Şu an açık hotspot bulunamadı': 'No open hotspots right now',
      'Tahmin üretmek için yeterli veri yok':
          'Not enough data to build a forecast',
      'Tahmin Motoru': 'Forecast Engine',
      'Mode Uygunluğu': 'Mode Fit',
      'Zaman Tahminleri': 'Time Forecasts',
      'Güven': 'Confidence',
      'Canlı veri': 'Live data',
      'Bölge Pulse Skoru': 'Area Pulse Score',
      'Neden Yükseliyor': 'Why It Is Rising',
      'Yoğunluk': 'Density',
      'İvme': 'Momentum',
      'Çalışma Saatleri': 'Opening Hours',
      'En Yakın': 'Nearest',
      'En Popüler': 'Most Popular',
      'Sinyal': 'Signal',
      'Aktif': 'Active',
      'Aranıyor...': 'Scanning...',
      'Arıyor': 'Scanning',
      'Aç': 'Start',
      'kişi menzilde': 'people in range',
      'kişi yakınında': 'people nearby',
      'Merkez butona bas ve başla.': 'Tap the center button to start.',
      'Yakında aktif birileri göründüğünde burada listelenecek.':
          'Active people nearby will appear here.',
      'için arkadaşlık isteği gönderildi.': 'friend request sent.',
      'Mesaj Gönder': 'Send Message',
      'Arkadaş Ekle': 'Add Friend',
      'Profil Gizli': 'Profile Hidden',
      'Profili Aç': 'Open Profile',
      'Sonraki': 'Next',
      'Sinyal Gizliliği': 'Signal Privacy',
      'Profilini Göster': 'Show Your Profile',
      'Kişi Bul': 'Find People',
      'Başlık': 'Title',
      'Devam': 'Continue',
      'Yeni': 'New',
      'Takipçi': 'Followers',
      'Takip': 'Following',
      'Arkadaş': 'Friends',
      'Takipçiler': 'Followers',
      'Takip Edilenler': 'Following',
      'Arkadaşlar': 'Friends',
      'Ortak Arkadaşlar': 'Mutual Friends',
      'Profili Düzenle': 'Edit Profile',
      'Profili Paylaş': 'Share Profile',
      'Takip Et': 'Follow',
      'Takipten Çık': 'Unfollow',
      'Mesaj': 'Message',
      'Postlar': 'Posts',
      'Kayıtlar': 'Saved',
      'Profil': 'Profile',
      'Şikayet Et': 'Report',
      'Engelle': 'Block',
      'Vazgeç': 'Cancel',
      'ortak arkadaş': 'mutual friends',
      'engellenecek:': 'will be blocked:',
      'Kullanıcı engellenemedi.': 'The user could not be blocked.',
      'Ad Soyad': 'Full Name',
      'Hakkında': 'About',
      'Şehir': 'City',
      'Website': 'Website',
      'profilini PulseCity’de keşfet.':
          'discover this profile on PulseCity.',
      'profili': 'profile',
      'Profil kodu panoya kopyalandı.': 'Profile code copied to clipboard.',
      'Mesaj ekranı açılamadı.': 'Message screen could not be opened.',
      'Profil yüklenirken hata oluştu.':
          'An error occurred while loading the profile.',
      'Takip işlemi sırasında hata oluştu.':
          'An error occurred during the follow action.',
      'Arkadaşlık isteği gönderildi!': 'Friend request sent!',
      'Arkadaşlık isteği gönderilemedi.':
          'Friend request could not be sent.',
      'Story / Short Paylaş': 'Share Story / Short',
      'Yeni Gönderi': 'New Post',
      'Kısa açıklama': 'Short caption',
      'Ne oluyor?': 'What is happening?',
      'Vibe': 'Vibe',
      'Short Yayınla': 'Publish Short',
      'Gönderiyi Paylaş': 'Publish Post',
      'Mesaj yaz...': 'Write a message...',
      'Kullanıcı ara': 'Search users',
      'Kabul Et': 'Accept',
      'Reddet': 'Decline',
      'Şikayet kaydı oluşturuldu.': 'Report record created.',
      'Şikayet gönderilemedi.': 'Report could not be sent.',
      'Profil başarıyla güncellendi.': 'Profile updated successfully.',
      'Profil güncellenemedi.': 'Profile could not be updated.',
      'Enerji': 'Energy',
      'Tazelik': 'Freshness',
      'Genel': 'General',
      '{count} öneri': '{count} suggestions',
      'SU AN YAKININDA AKTIF': 'ACTIVE NEAR YOU NOW',
      'Kaydetmek için giriş gerekli.': 'Log in to save places.',
      'Mekan kaydedildi.': 'Place saved.',
      'Kayıt kaldırıldı.': 'Removed from saved places.',
      'Yol tarifi açılamadı.': 'Could not open directions.',
      'Website açılamadı.': 'Could not open the website.',
      'Arama başlatılamadı.': 'Could not start the call.',
      '{name} profilini paylaştı.': '{name} shared their profile.',
      'Kullanici: @{username}': 'User: @{username}',
      'Sohbet ettiğin kişi: {city}': 'Chat partner: {city}',
      'Profil kartı paylaşıldı.': 'Profile card shared.',
      'Profil paylaşımı başarısız.': 'Profile share failed.',
      'Gönderi kartı paylaşıldı.': 'Post card shared.',
      'Gönderi paylaşımı başarısız.': 'Post share failed.',
      'Gönderi Paylaş': 'Share Post',
      'Resim Paylaş': 'Share Image',
      'Video Paylaş': 'Share Video',
      'Konum Paylaş': 'Share Location',
      'Profil Paylaş': 'Share Profile',
      'Paylaşacak bir gönderi yok.': 'No post available to share.',
      'Medya gönderisi': 'Media message',
      'Arkadaşlık isteği gönderildi.': 'Friend request sent.',
      'Video paylaştı': 'Shared a video',
      'Fotoğraf paylaştı': 'Shared a photo',
      'Video gönderildi.': 'Video sent.',
      'Fotoğraf gönderildi.': 'Photo sent.',
      'Medya gönderilemedi.': 'Media could not be sent.',
      'Video mesajı': 'Video message',
      'Canlı konum': 'Live location',
      '{author} gönderi paylaştı': '{author} shared a post',
      'Bir kullanıcı': 'A user',
      'yaziyor...': 'typing...',
      'Sohbet açılamadı.': 'Chat could not be opened.',
      'Geçici sohbet: {hours} s {minutes} dk kaldı':
          'Temporary chat: {hours}h {minutes}m left',
      'Mesajlaşma başlatmak için ilk mesajı gönder.':
          'Send the first message to start chatting.',
      'Bekleyen istek yok.': 'No pending requests.',
      '{count} yeni arkadaşlık isteği': '{count} new friend requests',
      'Henüz sohbet yok.': 'No chats yet.',
      'Sohbet başlatıldı': 'Chat started',
      'Mesajları görmek için giriş gerekli.': 'Log in to see your messages.',
      'Bekleyen arkadaşlık isteği yok.':
          'There are no pending friend requests.',
      'kullanici': 'user',
      'Yeni yerler ve gizli köşeler keşfet':
          'Discover new places and hidden corners',
      'Huzurlu ve sakin ortamlar bul': 'Find calm and peaceful places',
      'Yeni insanlarla tanış, sosyal ortamlar':
          'Meet new people in social places',
      'Sessiz çalışma ortamları & hızlı Wi-Fi':
          'Quiet workspaces and fast Wi-Fi',
      'Enerji dolu gece hayatı & etkinlikler':
          'High-energy nightlife and events',
      'Parklar, doğa & dış mekan aktiviteleri':
          'Parks, nature, and outdoor activities',
      'Benzer ilgi alanlarına sahip insanlar': 'People with similar interests',
      'Çocuk dostu & güvenli ortamlar': 'Child-friendly and safe places',
      'AVM\'ler, mağazalar ve outlet\'ler': 'Malls, stores and outlets',
      'Alışveriş': 'Shopping',
      'Aile & Çocuk': 'Family & Kids',
      'Türkçe': 'Turkish',
      'English': 'English',
      'Deutsch': 'German',
      'Sil': 'Delete',
      'Etkinliklerin': 'Your activities',
      'İşlem tamamlanamadı': 'Could not complete action',
    },
    'de': {
      'Açık': 'Offen',
      'Kapalı': 'Geschlossen',
      'Yorumlar': 'Kommentare',
      'İlk yorumu sen yaz.': 'Schreibe den ersten Kommentar.',
      'Yorum yaz...': 'Kommentar schreiben...',
      'Gönder': 'Senden',
      'Mekan ara': 'Ort suchen',
      'Önümüzdeki Saatler': 'Kommende Stunden',
      'Puan': 'Bewertung',
      'Yorum': 'Rezensionen',
      'Evet': 'Ja',
      'Hayır': 'Nein',
      'Henüz short yok': 'Noch keine Shorts',
      'Henüz paylaşım yok': 'Noch keine Beiträge',
      'Kullanıcı': 'Nutzer',
      'Yükseliş Adayı': 'Aufstiegs-Kandidat',
      'Gönderi': 'Beitrag',
      'Tahmin': 'Prognose',
      'Topluluk': 'Community',
      'Google': 'Google',
      'Konum': 'Ort',
      'Kaydet': 'Speichern',
      'Paylaş': 'Teilen',
      'Yakında canlı mekan bulunamadı':
          'Keine lebendigen Orte in der Nähe gefunden',
      'Şu an açık hotspot bulunamadı':
          'Zurzeit keine offenen Hotspots gefunden',
      'Tahmin üretmek için yeterli veri yok':
          'Nicht genügend Daten für eine Prognose',
      'Tahmin Motoru': 'Prognosemotor',
      'Mode Uygunluğu': 'Modus-Fit',
      'Zaman Tahminleri': 'Zeitprognosen',
      'Güven': 'Vertrauen',
      'Canlı veri': 'Live-Daten',
      'Bölge Pulse Skoru': 'Pulse-Score des Bereichs',
      'Neden Yükseliyor': 'Warum steigt es',
      'Yoğunluk': 'Dichte',
      'İvme': 'Dynamik',
      'Çalışma Saatleri': 'Öffnungszeiten',
      'En Yakın': 'Am nächsten',
      'En Popüler': 'Am beliebtesten',
      'Sinyal': 'Signal',
      'Aktif': 'Aktiv',
      'Aranıyor...': 'Wird gesucht...',
      'Arıyor': 'Sucht',
      'Aç': 'Starten',
      'kişi menzilde': 'Personen in Reichweite',
      'kişi yakınında': 'Personen in deiner Nähe',
      'Merkez butona bas ve başla.':
          'Tippe auf die zentrale Taste und starte.',
      'Yakında aktif birileri göründüğünde burada listelenecek.':
          'Wenn in der Nähe aktive Personen auftauchen, erscheinen sie hier.',
      'için arkadaşlık isteği gönderildi.':
          'Freundschaftsanfrage gesendet.',
      'Mesaj Gönder': 'Nachricht senden',
      'Arkadaş Ekle': 'Freund hinzufügen',
      'Profil Gizli': 'Profil verborgen',
      'Profili Aç': 'Profil öffnen',
      'Sonraki': 'Weiter',
      'Sinyal Gizliliği': 'Signal-Datenschutz',
      'Profilini Göster': 'Profil anzeigen',
      'Kişi Bul': 'Personen finden',
      'Başlık': 'Titel',
      'Devam': 'Weiter',
      'Yeni': 'Neu',
      'Takipçi': 'Follower',
      'Takip': 'Folgt',
      'Arkadaş': 'Freunde',
      'Takipçiler': 'Follower',
      'Takip Edilenler': 'Gefolgt',
      'Arkadaşlar': 'Freunde',
      'Ortak Arkadaşlar': 'Gemeinsame Freunde',
      'Profili Düzenle': 'Profil bearbeiten',
      'Profili Paylaş': 'Profil teilen',
      'Takip Et': 'Folgen',
      'Takipten Çık': 'Entfolgen',
      'Mesaj': 'Nachricht',
      'Postlar': 'Beiträge',
      'Kayıtlar': 'Gespeichert',
      'Profil': 'Profil',
      'Şikayet Et': 'Melden',
      'Engelle': 'Blockieren',
      'Vazgeç': 'Abbrechen',
      'ortak arkadaş': 'gemeinsame Freunde',
      'engellenecek:': 'wird blockiert:',
      'Kullanıcı engellenemedi.': 'Der Nutzer konnte nicht blockiert werden.',
      'Ad Soyad': 'Vollständiger Name',
      'Hakkında': 'Über dich',
      'Şehir': 'Stadt',
      'Website': 'Website',
      'profilini PulseCity’de keşfet.':
          'dieses Profil auf PulseCity entdecken.',
      'profili': 'Profil',
      'Profil kodu panoya kopyalandı.':
          'Profilcode wurde in die Zwischenablage kopiert.',
      'Mesaj ekranı açılamadı.':
          'Nachrichtenansicht konnte nicht geöffnet werden.',
      'Profil yüklenirken hata oluştu.':
          'Beim Laden des Profils ist ein Fehler aufgetreten.',
      'Takip işlemi sırasında hata oluştu.':
          'Beim Folgen ist ein Fehler aufgetreten.',
      'Arkadaşlık isteği gönderildi!':
          'Freundschaftsanfrage wurde gesendet!',
      'Arkadaşlık isteği gönderilemedi.':
          'Freundschaftsanfrage konnte nicht gesendet werden.',
      'Story / Short Paylaş': 'Story / Short teilen',
      'Yeni Gönderi': 'Neuer Beitrag',
      'Kısa açıklama': 'Kurze Beschreibung',
      'Ne oluyor?': 'Was passiert?',
      'Vibe': 'Vibe',
      'Short Yayınla': 'Short veröffentlichen',
      'Gönderiyi Paylaş': 'Beitrag veröffentlichen',
      'Mesaj yaz...': 'Nachricht schreiben...',
      'Kullanıcı ara': 'Nutzer suchen',
      'Kabul Et': 'Akzeptieren',
      'Reddet': 'Ablehnen',
      'Şikayet kaydı oluşturuldu.': 'Meldung wurde erstellt.',
      'Şikayet gönderilemedi.': 'Meldung konnte nicht gesendet werden.',
      'Profil başarıyla güncellendi.':
          'Profil wurde erfolgreich aktualisiert.',
      'Profil güncellenemedi.': 'Profil konnte nicht aktualisiert werden.',
      'Enerji': 'Energie',
      'Tazelik': 'Frische',
      'Genel': 'Allgemein',
      '{count} öneri': '{count} Empfehlungen',
      'SU AN YAKININDA AKTIF': 'JETZT AKTIV IN DEINER NÄHE',
      'Kaydetmek için giriş gerekli.': 'Zum Speichern bitte anmelden.',
      'Mekan kaydedildi.': 'Ort gespeichert.',
      'Kayıt kaldırıldı.': 'Aus gespeicherten Orten entfernt.',
      'Yol tarifi açılamadı.': 'Route konnte nicht geöffnet werden.',
      'Website açılamadı.': 'Website konnte nicht geöffnet werden.',
      'Arama başlatılamadı.': 'Anruf konnte nicht gestartet werden.',
      '{name} profilini paylaştı.': '{name} hat das Profil geteilt.',
      'Kullanici: @{username}': 'Nutzer: @{username}',
      'Sohbet ettiğin kişi: {city}': 'Chat-Partner: {city}',
      'Profil kartı paylaşıldı.': 'Profilkarte wurde geteilt.',
      'Profil paylaşımı başarısız.': 'Profil konnte nicht geteilt werden.',
      'Gönderi kartı paylaşıldı.': 'Beitragskarte wurde geteilt.',
      'Gönderi paylaşımı başarısız.': 'Beitrag konnte nicht geteilt werden.',
      'Gönderi Paylaş': 'Beitrag teilen',
      'Resim Paylaş': 'Bild teilen',
      'Video Paylaş': 'Video teilen',
      'Konum Paylaş': 'Standort teilen',
      'Profil Paylaş': 'Profil teilen',
      'Paylaşacak bir gönderi yok.': 'Kein Beitrag zum Teilen vorhanden.',
      'Medya gönderisi': 'Mediennachricht',
      'Arkadaşlık isteği gönderildi.': 'Freundschaftsanfrage wurde gesendet.',
      'Video paylaştı': 'Hat ein Video geteilt',
      'Fotoğraf paylaştı': 'Hat ein Foto geteilt',
      'Video gönderildi.': 'Video gesendet.',
      'Fotoğraf gönderildi.': 'Foto gesendet.',
      'Medya gönderilemedi.': 'Medien konnten nicht gesendet werden.',
      'Video mesajı': 'Videonachricht',
      'Canlı konum': 'Live-Standort',
      '{author} gönderi paylaştı': '{author} hat einen Beitrag geteilt',
      'Bir kullanıcı': 'Ein Nutzer',
      'yaziyor...': 'schreibt...',
      'Sohbet açılamadı.': 'Chat konnte nicht geöffnet werden.',
      'Geçici sohbet: {hours} s {minutes} dk kaldı':
          'Temporärer Chat: noch {hours} Std. {minutes} Min.',
      'Mesajlaşma başlatmak için ilk mesajı gönder.':
          'Sende die erste Nachricht, um den Chat zu starten.',
      'Bekleyen istek yok.': 'Keine offenen Anfragen.',
      '{count} yeni arkadaşlık isteği': '{count} neue Freundschaftsanfragen',
      'Henüz sohbet yok.': 'Noch keine Chats.',
      'Sohbet başlatıldı': 'Chat gestartet',
      'Mesajları görmek için giriş gerekli.':
          'Zum Anzeigen der Nachrichten bitte anmelden.',
      'Bekleyen arkadaşlık isteği yok.':
          'Es gibt keine offenen Freundschaftsanfragen.',
      'kullanici': 'nutzer',
      'Yeni yerler ve gizli köşeler keşfet':
          'Entdecke neue Orte und versteckte Ecken',
      'Huzurlu ve sakin ortamlar bul': 'Finde ruhige und entspannte Orte',
      'Yeni insanlarla tanış, sosyal ortamlar':
          'Lerne neue Menschen an sozialen Orten kennen',
      'Sessiz çalışma ortamları & hızlı Wi-Fi':
          'Ruhige Arbeitsorte und schnelles WLAN',
      'Enerji dolu gece hayatı & etkinlikler':
          'Energiegeladenes Nachtleben und Events',
      'Parklar, doğa & dış mekan aktiviteleri':
          'Parks, Natur und Aktivitäten im Freien',
      'Benzer ilgi alanlarına sahip insanlar':
          'Menschen mit ähnlichen Interessen',
      'Çocuk dostu & güvenli ortamlar': 'Kinderfreundliche und sichere Orte',
      'AVM\'ler, mağazalar ve outlet\'ler':
          'Einkaufszentren, Geschäfte und Outlets',
      'Alışveriş': 'Einkaufen',
      'Aile & Çocuk': 'Familie & Kinder',
      'Türkçe': 'Türkisch',
      'English': 'Englisch',
      'Deutsch': 'Deutsch',
      'Sil': 'Löschen',
      'Etkinliklerin': 'Deine Aktivitäten',
      'İşlem tamamlanamadı': 'Aktion konnte nicht ausgeführt werden',
    },
  };

  static const Map<String, String> _aliases = {
    'Açık': 'Açık',
    'Kapalı': 'Kapalı',
    'Canlı veri': 'Canlı veri',
    'Bölge Pulse Skoru': 'Bölge Pulse Skoru',
    'Yükseliyor': 'Yükseliyor',
    'Yukseliyor': 'Yükseliyor',
    'Yoğun': 'Yoğun',
    'Düşük': 'Düşük',
    'Keşif': 'Keşif',
    'Üretkenlik': 'Üretkenlik',
    'Eğlence': 'Eğlence',
    'Açık Alan': 'Açık Alan',
    'Şimdi': 'Şimdi',
    'Kullanıcı': 'Kullanıcı',
    'Paylaşım': 'Paylaşım',
    'Keşfet': 'Keşfet',
    'Aranıyor...': 'Aranıyor...',
    'Aç': 'Aç',
    'Arıyor': 'Arıyor',
    'Kaydetmek icin giris gerekli.': 'Kaydetmek için giriş gerekli.',
    'Kayit kaldirildi.': 'Kayıt kaldırıldı.',
    'Yol tarifi acilamadi.': 'Yol tarifi açılamadı.',
    'Website acilamadi.': 'Website açılamadı.',
    'Arama baslatilamadi.': 'Arama başlatılamadı.',
    'Profil karti paylasildi.': 'Profil kartı paylaşıldı.',
    'Profil paylasimi basarisiz.': 'Profil paylaşımı başarısız.',
    'Gonderi karti paylasildi.': 'Gönderi kartı paylaşıldı.',
    'Gonderi paylasimi basarisiz.': 'Gönderi paylaşımı başarısız.',
    'Paylasacak bir gonderi yok.': 'Paylaşacak bir gönderi yok.',
    'Medya gonderisi': 'Medya gönderisi',
    'Arkadaslik istegi gonderildi.': 'Arkadaşlık isteği gönderildi.',
    'Arkadaslik istegi gonderilemedi.': 'Arkadaşlık isteği gönderilemedi.',
    'Video paylasti': 'Video paylaştı',
    'Fotograf paylasti': 'Fotoğraf paylaştı',
    'Video gonderildi.': 'Video gönderildi.',
    'Fotograf gonderildi.': 'Fotoğraf gönderildi.',
    'Medya gonderilemedi.': 'Medya gönderilemedi.',
    'Resim Paylas': 'Resim Paylaş',
    'Video Paylas': 'Video Paylaş',
    'Konum Paylas': 'Konum Paylaş',
    'Gonderi Paylas': 'Gönderi Paylaş',
    'Profil Paylas': 'Profil Paylaş',
    'Video mesaji': 'Video mesajı',
    'Canli konum': 'Canlı konum',
    'Bir kullanici': 'Bir kullanıcı',
    'Sohbet acilamadi.': 'Sohbet açılamadı.',
    'Gecici sohbet: {hours} s {minutes} dk kaldi':
        'Geçici sohbet: {hours} s {minutes} dk kaldı',
    'Mesajlasma baslatmak icin ilk mesaji gonder.':
        'Mesajlaşma başlatmak için ilk mesajı gönder.',
    'Bekleyen arkadaslik istegi yok.': 'Bekleyen arkadaşlık isteği yok.',
    'Mesajlari gormek icin giris gerekli.':
        'Mesajları görmek için giriş gerekli.',
    'Henüz sohbet yok.': 'Henüz sohbet yok.',
    'Sohbet başlatıldı': 'Sohbet başlatıldı',
    'SU AN YAKININDA AKTIF': 'ŞU AN YAKININDA AKTİF',
    '{count} öneri': '{count} öneri',
    '{name} profilini paylasti.': '{name} profilini paylaştı.',
    'Sohbet ettigin kisi: {city}': 'Sohbet ettiğin kişi: {city}',
    'yaziyor...': 'yazıyor...',
    'kullanici': 'kullanıcı',
    'İlçe': 'İlçe',
    'Şehir': 'Şehir',
    'Yakın çevre': 'Yakın çevre',
    'Görünür': 'Görünür',
    'Yüksek koruma': 'Yüksek koruma',
    'Açık paylaşım': 'Açık paylaşım',
    'Ghost mode açık. Canlı katkın gizleniyor ve görünürlüğün minimum seviyede tutuluyor.':
        'Ghost mode açık. Canlı katkın gizleniyor ve görünürlüğün minimum seviyede tutuluyor.',
    'Gizlilik ve keşif şu an dengede. Şehre katkı veriyorsun ama hassasiyet kontrollü.':
        'Gizlilik ve keşif şu an dengede. Şehre katkı veriyorsun ama hassasiyet kontrollü.',
    'Daha açık bir profil paylaşıyorsun. Sosyal keşif güçlü, gizlilik seviyesi daha düşük.':
        'Daha açık bir profil paylaşıyorsun. Sosyal keşif güçlü, gizlilik seviyesi daha düşük.',
    'Profil görünür': 'Profil görünür',
    'Profili Ac': 'Profili Aç',
  };

  String t(String key) {
    final canonicalKey = _canonicalize(key);
    final normalizedKey = _normalize(key);

    return _canonicalize(
      _canonicalTranslations[languageCode]?[canonicalKey] ??
          _canonicalTranslations[languageCode]?[normalizedKey] ??
          _canonicalTranslations['tr']?[canonicalKey] ??
          _canonicalTranslations['tr']?[normalizedKey] ??
          canonicalKey,
    );
  }

  String phrase(String text) {
    final canonical = _canonicalize(text);
    final normalized = _normalize(canonical);
    return _canonicalize(
      _canonicalPhrases[languageCode]?[canonical] ??
          _canonicalPhrases[languageCode]?[normalized] ??
          _canonicalPhrases['tr']?[canonical] ??
          _canonicalPhrases['tr']?[normalized] ??
          canonical,
    );
  }

  String repairText(String text) => _canonicalize(text);

  String formatPhrase(String text, [Map<String, Object?> params = const {}]) {
    var result = phrase(text);
    params.forEach((key, value) {
      result = result.replaceAll('{$key}', '${value ?? ''}');
    });
    return result;
  }

  String modeLabel(String modeId) {
    return switch (modeId) {
      'flirt' => phrase('Flört'),
      'friends' => phrase('Arkadaşlık'),
      'fun' => phrase('Eğlence'),
      'chill' => phrase('Keşif'),
      'kesif' => phrase('Keşif'),
      'sakinlik' => phrase('Keşif'),
      'sosyal' => phrase('Arkadaşlık'),
      'uretkenlik' => phrase('Keşif'),
      'eglence' => phrase('Eğlence'),
      'acik_alan' => phrase('Keşif'),
      'topluluk' => phrase('Arkadaşlık'),
      'aile' => phrase('Keşif'),
      'alisveris' => phrase('Keşif'),
      _ => phrase(modeId),
    };
  }

  String densityLabel(dynamic raw) {
    return switch (_normalize(raw)) {
      'cok yogun' => phrase('Çok Yoğun'),
      'yogun' => phrase('Yoğun'),
      'orta' => phrase('Orta'),
      'dusuk' => phrase('Düşük'),
      'cok dusuk' => phrase('Çok Düşük'),
      _ => phrase(raw?.toString() ?? ''),
    };
  }

  String trendLabel(dynamic raw) {
    return switch (_normalize(raw)) {
      'patliyor' => phrase('Patlıyor'),
      'yukseliyor' => phrase('Yükseliyor'),
      'sabit' => phrase('Sabit'),
      'sakin' => phrase('Sakin'),
      _ => phrase(raw?.toString() ?? ''),
    };
  }

  String forecastLabel(int offsetHours) {
    if (offsetHours == 0) return t('now');
    return switch (languageCode) {
      'en' => '+${offsetHours}h',
      'de' => '+$offsetHours Std.',
      _ => '+${offsetHours}s',
    };
  }

  String relativeShort(Duration diff) {
    if (diff.inMinutes < 1) return t('now').toLowerCase();
    if (diff.inHours < 1) {
      return switch (languageCode) {
        'en' => '${diff.inMinutes}m',
        'de' => '${diff.inMinutes} Min.',
        _ => '${diff.inMinutes} dk',
      };
    }
    if (diff.inDays < 1) {
      return switch (languageCode) {
        'en' => '${diff.inHours}h',
        'de' => '${diff.inHours} Std.',
        _ => '${diff.inHours} sa',
      };
    }
    if (diff.inDays < 7) {
      return switch (languageCode) {
        'en' => '${diff.inDays}d',
        'de' => '${diff.inDays} T.',
        _ => '${diff.inDays} gün',
      };
    }
    final weeks = (diff.inDays / 7).floor();
    return switch (languageCode) {
      'en' => '${weeks}w',
      'de' => '$weeks Wo.',
      _ => '$weeks hf',
    };
  }

  String languageName(String code) {
    return switch (code) {
      'tr' => phrase('Türkçe'),
      'en' => phrase('English'),
      'de' => phrase('Deutsch'),
      _ => code,
    };
  }

  String monthName(int month) {
    const tr = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    const en = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const de = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];

    if (month < 1 || month > 12) return '';
    return _canonicalize(switch (languageCode) {
      'en' => en[month - 1],
      'de' => de[month - 1],
      _ => tr[month - 1],
    });
  }

  String _canonicalize(String text) {
    final repaired = _repairTextStatic(text.trim());
    if (repaired.isEmpty) return repaired;
    return _canonicalAliases[repaired] ??
        _canonicalAliases[_normalizeStatic(repaired)] ??
        repaired;
  }

  static Map<String, Map<String, String>> _buildCanonicalTable(
    Map<String, Map<String, String>> source,
  ) {
    final result = <String, Map<String, String>>{};
    source.forEach((language, values) {
      final table = <String, String>{};
      values.forEach((key, value) {
        final canonicalKey = _repairTextStatic(key);
        final canonicalValue = _repairTextStatic(value);
        if (canonicalKey.isEmpty) return;
        table[canonicalKey] = canonicalValue;
        table[_normalizeStatic(canonicalKey)] = canonicalValue;
      });
      result[language] = table;
    });
    return result;
  }

  static Map<String, String> _buildCanonicalAliases() {
    final result = <String, String>{};
    _aliases.forEach((key, value) {
      final canonicalValue = _repairTextStatic(value);
      for (final candidate in {key, value}) {
        final canonicalCandidate = _repairTextStatic(candidate);
        if (canonicalCandidate.isEmpty) continue;
        result[canonicalCandidate] = canonicalValue;
        result[_normalizeStatic(canonicalCandidate)] = canonicalValue;
      }
    });
    return result;
  }

  static String _repairTextStatic(String value) {
    var current = value.trim();
    if (current.isEmpty) return current;
    for (var i = 0; i < 3; i++) {
      if (!_looksBrokenStatic(current)) break;
      try {
        final decoded = _decodeMisencodedUtf8(current);
        if (decoded == current) break;
        current = decoded.trim();
      } catch (_) {
        break;
      }
    }
    return current;
  }

  static bool _looksBrokenStatic(String value) {
    return _brokenSequencePattern.hasMatch(value) ||
        _brokenQuestionPattern.hasMatch(value) ||
        value.contains('�');
  }

  static String _decodeMisencodedUtf8(String value) {
    final bytes = <int>[];
    for (final rune in value.runes) {
      final cp1252 = _cp1252ByteMap[rune];
      if (cp1252 != null) {
        bytes.add(cp1252);
        continue;
      }
      if (rune <= 0xFF) {
        bytes.add(rune);
        continue;
      }
      return value;
    }
    return utf8.decode(bytes);
  }

  static const Map<int, int> _cp1252ByteMap = {
    0x20AC: 0x80,
    0x201A: 0x82,
    0x0192: 0x83,
    0x201E: 0x84,
    0x2026: 0x85,
    0x2020: 0x86,
    0x2021: 0x87,
    0x02C6: 0x88,
    0x2030: 0x89,
    0x0160: 0x8A,
    0x2039: 0x8B,
    0x0152: 0x8C,
    0x017D: 0x8E,
    0x2018: 0x91,
    0x2019: 0x92,
    0x201C: 0x93,
    0x201D: 0x94,
    0x2022: 0x95,
    0x2013: 0x96,
    0x2014: 0x97,
    0x02DC: 0x98,
    0x2122: 0x99,
    0x0161: 0x9A,
    0x203A: 0x9B,
    0x0153: 0x9C,
    0x017E: 0x9E,
    0x0178: 0x9F,
  };

  String _normalize(dynamic value) {
    return _normalizeStatic(value);
  }

  static String _normalizeStatic(dynamic value) {
    final normalized = _repairTextStatic(value.toString()).trim().toLowerCase();
    return normalized
        .replaceAll('\u015f', 's')
        .replaceAll('\u0131', 'i')
        .replaceAll('\u011f', 'g')
        .replaceAll('\u00fc', 'u')
        .replaceAll('\u00f6', 'o')
        .replaceAll('\u00e7', 'c')
        .replaceAll('\u0130', 'i')
        .replaceAll('\u015e', 's')
        .replaceAll('\u011e', 'g')
        .replaceAll('\u00dc', 'u')
        .replaceAll('\u00d6', 'o')
        .replaceAll('\u00c7', 'c')
        .replaceAll('\u00e4', 'a')
        .replaceAll('\u00df', 'ss')
        .replaceAll('\u2019', "'")
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
  }

  @visibleForTesting
  static Map<String, Map<String, String>> get debugTranslations => _translations;

  @visibleForTesting
  static Map<String, Map<String, String>> get debugPhrases => _phrases;

  @visibleForTesting
  static bool debugLooksBroken(String value) => _looksBrokenStatic(value);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Inline 3-dilli quick-copy helper. ARB tablolarına anahtar eklemeye
  /// gerek olmayan, ekrana özel kısa stringler için kullan (tooltip,
  /// placeholder, küçük UI label'ları). Daha geniş paylaşılan stringler
  /// hâlâ `l10n.t(...)` veya `l10n.phrase(...)` üzerinden gitmeli.
  ///
  /// Örnek:
  /// ```
  /// Text(context.tr3(tr: 'Yakındakiler', en: 'Nearby', de: 'In der Nähe'))
  /// ```
  String tr3({required String tr, required String en, required String de}) {
    return switch (l10n.languageCode) {
      'en' => en,
      'de' => de,
      _ => tr,
    };
  }
}
