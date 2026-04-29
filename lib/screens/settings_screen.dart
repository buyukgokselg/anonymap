import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/app_localizations.dart';
import '../services/app_locale_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/colors.dart';
import '../widgets/app_snackbar.dart';
import 'legal/privacy_screen.dart';
import 'legal/terms_screen.dart';
import 'login_screen.dart';
import 'verification_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  bool _isVisible = true;
  bool _ghostMode = false;
  bool _enableDifferentialPrivacy = true;
  bool _allowAnalytics = true;
  bool _isExporting = false;
  String _locationGranularity = 'nearby';
  int _kAnonymityLevel = 3;
  String _selectedLanguage = 'tr';
  String _selectedGender = '';
  String _selectedMatchPreference = 'auto';

  bool _activityNotificationsEnabled = true;
  bool _activityAutoApprove = false;
  bool _activityShowOnProfile = true;
  int _activityRadiusKm = 10;

  bool _isPhotoVerified = false;
  String _verificationStatus = 'none';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = _authService.currentUserId;
    if (uid.isEmpty) return;

    try {
      final data = await _firestoreService.getUserProfile(uid);
      if (!mounted || data == null) return;

      setState(() {
        _isVisible = data['isVisible'] ?? true;
        _ghostMode = data['privacyLevel'] == 'ghost';
        _enableDifferentialPrivacy = data['enableDifferentialPrivacy'] ?? true;
        _allowAnalytics = data['allowAnalytics'] ?? true;
        _locationGranularity = (data['locationGranularity'] ?? 'nearby')
            .toString();
        _kAnonymityLevel = (data['kAnonymityLevel'] ?? 3) as int;
        _selectedLanguage = (data['preferredLanguage'] ?? 'tr').toString();
        _selectedGender = (data['gender'] ?? '').toString();
        _selectedMatchPreference =
            (data['matchPreference'] ?? 'auto').toString();
        _activityNotificationsEnabled =
            data['activityNotificationsEnabled'] ?? true;
        _activityAutoApprove = data['activityAutoApprove'] ?? false;
        _activityShowOnProfile = data['activityShowOnProfile'] ?? true;
        final radius = data['activityRadiusKm'];
        if (radius is num) {
          _activityRadiusKm = radius.toInt().clamp(1, 50);
        }
        _isPhotoVerified = data['isPhotoVerified'] == true;
        final raw = (data['verificationStatus'] ?? '').toString();
        _verificationStatus = raw.isEmpty
            ? (_isPhotoVerified ? 'approved' : 'none')
            : raw;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load settings: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        AppSnackbar.showError(
          context,
          context.l10n.phrase('Ayarlar yüklenemedi.'),
        );
      }
    }
  }

  Future<void> _saveSettings(Map<String, dynamic> updates) async {
    final uid = _authService.currentUserId;
    if (uid.isEmpty) return;
    await _firestoreService.updateProfile(uid, updates);
  }

  Future<void> _exportMyData() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    final l10n = context.l10n;
    AppSnackbar.showInfo(context, l10n.t('download_started'));

    try {
      final export = await _firestoreService.exportMyData();
      final url = export?['downloadUrl']?.toString() ?? '';
      if (url.isEmpty) {
        throw Exception('Export URL missing.');
      }

      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

      if (!mounted) return;
      AppSnackbar.showSuccess(context, l10n.t('download_ready'));
    } catch (error, stackTrace) {
      debugPrint('Data export failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      AppSnackbar.showError(context, l10n.t('download_failed'));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // ─── Privacy rollup ────────────────────────────────────────────────────────
  int get _privacyScore {
    var score = 38;
    if (_ghostMode) score += 26;
    if (_enableDifferentialPrivacy) score += 14;
    if (!_allowAnalytics) score += 8;
    if (_locationGranularity == 'city') score += 12;
    if (_locationGranularity == 'district') score += 8;
    if (_locationGranularity == 'nearby') score += 4;
    score += (_kAnonymityLevel - 3) * 4;
    return score.clamp(0, 100);
  }

  String get _privacyMood {
    final score = _privacyScore;
    return switch (context.l10n.languageCode) {
      'en' => score >= 80
          ? 'High protection'
          : score >= 60
          ? 'Balanced'
          : 'Open sharing',
      'de' => score >= 80
          ? 'Hoher Schutz'
          : score >= 60
          ? 'Ausgewogen'
          : 'Offene Freigabe',
      _ => score >= 80
          ? 'Yüksek koruma'
          : score >= 60
          ? 'Dengeli'
          : 'Açık paylaşım',
    };
  }

  String get _privacySummary {
    if (_ghostMode) {
      return context.tr3(
        tr:
            'Ghost mode açık. Canlı katkın gizleniyor ve görünürlüğün minimum seviyede tutuluyor.',
        en:
            'Ghost mode is on. Your live contribution is hidden and visibility stays at minimum.',
        de:
            'Ghost Mode ist aktiv. Dein Live-Beitrag bleibt verborgen und die Sichtbarkeit ist minimal.',
      );
    }

    if (_enableDifferentialPrivacy && _locationGranularity != 'exact') {
      return context.tr3(
        tr:
            'Gizlilik ve keşif şu an dengede. Şehre katkı veriyorsun ama hassasiyet kontrollü.',
        en:
            'Privacy and discovery are balanced right now. You still contribute to the city with controlled precision.',
        de:
            'Privatsphäre und Discovery sind aktuell im Gleichgewicht. Du trägst weiter zur Stadt bei, aber mit kontrollierter Genauigkeit.',
      );
    }

    return context.tr3(
      tr:
          'Daha açık bir profil paylaşıyorsun. Sosyal keşif güçlü, gizlilik seviyesi daha düşük.',
      en:
          'You are sharing a more open profile. Social discovery is stronger while privacy stays lighter.',
      de:
          'Du teilst ein offeneres Profil. Social Discovery ist stärker, während der Datenschutz geringer ausfällt.',
    );
  }

  String get _visibilityStatus {
    if (_ghostMode) {
      return context.tr3(tr: 'Ghost', en: 'Ghost', de: 'Ghost');
    }
    return _isVisible
        ? context.tr3(tr: 'Görünür', en: 'Visible', de: 'Sichtbar')
        : context.tr3(tr: 'Gizli', en: 'Hidden', de: 'Verborgen');
  }

  String get _activityRadiusLabel {
    return context.tr3(
      tr: '$_activityRadiusKm km çevre',
      en: '$_activityRadiusKm km radius',
      de: '$_activityRadiusKm km Radius',
    );
  }

  String get _granularityLabel {
    return switch (_locationGranularity) {
      'exact' => context.tr3(tr: 'Tam konum', en: 'Exact', de: 'Genau'),
      'district' => context.tr3(tr: 'İlçe', en: 'District', de: 'Bezirk'),
      'city' => context.tr3(tr: 'Şehir', en: 'City', de: 'Stadt'),
      _ => context.tr3(tr: 'Yakın çevre', en: 'Nearby', de: 'Nahbereich'),
    };
  }

  Color get _privacyAccent =>
      _ghostMode ? AppColors.modeOzelCevre : AppColors.primary;

  // ─── Build root ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: topPadding + 56),
              ),
              SliverToBoxAdapter(child: _buildPrivacyHero()),
              SliverToBoxAdapter(child: _buildQuickToggleRow()),
              SliverToBoxAdapter(child: _buildVerificationCta()),
              SliverToBoxAdapter(
                child: _buildSectionHead(
                  title: context.tr3(
                    tr: 'Canlı görünürlük',
                    en: 'Live visibility',
                    de: 'Live-Sichtbarkeit',
                  ),
                  meta: context.tr3(
                    tr: 'profilin şehirdeki ayak izi',
                    en: 'your footprint in the city',
                    de: 'dein Fußabdruck in der Stadt',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildToggleGroup([
                  _ToggleRowData(
                    icon: Icons.visibility_rounded,
                    title: l10n.t('privacy_visibility'),
                    subtitle: l10n.t('privacy_visibility_sub'),
                    value: _isVisible,
                    onChanged: (value) async {
                      setState(() => _isVisible = value);
                      await _saveSettings({'isVisible': value});
                    },
                  ),
                  _ToggleRowData(
                    icon: Icons.shield_moon_rounded,
                    title: l10n.t('ghost_mode'),
                    subtitle: l10n.t('ghost_mode_sub'),
                    value: _ghostMode,
                    accent: AppColors.modeOzelCevre,
                    onChanged: (value) async {
                      setState(() {
                        _ghostMode = value;
                        if (value) {
                          _isVisible = true;
                        }
                      });
                      await _saveSettings({
                        'privacyLevel': value ? 'ghost' : 'full',
                        'isVisible': _isVisible,
                      });
                    },
                  ),
                  _ToggleRowData(
                    icon: Icons.blur_on_rounded,
                    title: l10n.t('differential_privacy'),
                    subtitle: l10n.t('differential_privacy_sub'),
                    value: _enableDifferentialPrivacy,
                    accent: AppColors.neonCyan,
                    onChanged: (value) async {
                      setState(() => _enableDifferentialPrivacy = value);
                      await _saveSettings({
                        'enableDifferentialPrivacy': value,
                      });
                    },
                  ),
                  _ToggleRowData(
                    icon: Icons.insights_rounded,
                    title: l10n.t('analytics'),
                    subtitle: l10n.t('analytics_sub'),
                    value: _allowAnalytics,
                    accent: AppColors.modeSosyal,
                    onChanged: (value) async {
                      setState(() => _allowAnalytics = value);
                      await _saveSettings({'allowAnalytics': value});
                    },
                  ),
                ]),
              ),
              SliverToBoxAdapter(
                child: _buildSectionHead(
                  title: context.tr3(
                    tr: 'Konum hassasiyeti',
                    en: 'Location precision',
                    de: 'Standortgenauigkeit',
                  ),
                  meta: _granularityLabel,
                ),
              ),
              SliverToBoxAdapter(
                child: _buildChipRail<String>(
                  options: const ['exact', 'nearby', 'district', 'city'],
                  value: _locationGranularity,
                  labelBuilder: (v) => l10n.t(v),
                  iconBuilder: (v) => switch (v) {
                    'exact' => Icons.gps_fixed_rounded,
                    'nearby' => Icons.near_me_rounded,
                    'district' => Icons.location_city_rounded,
                    _ => Icons.public_rounded,
                  },
                  onChanged: (value) async {
                    setState(() => _locationGranularity = value);
                    await _saveSettings({'locationGranularity': value});
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: _buildSectionHead(
                  title: context.tr3(
                    tr: 'k-anonimlik',
                    en: 'k-anonymity',
                    de: 'k-Anonymität',
                  ),
                  meta: 'k = $_kAnonymityLevel',
                ),
              ),
              SliverToBoxAdapter(
                child: _buildKAnonymitySlider(),
              ),
              SliverToBoxAdapter(
                child: _buildSectionHead(
                  title: context.tr3(
                    tr: 'Kimlik ve eşleşme',
                    en: 'Identity & matching',
                    de: 'Identität & Matching',
                  ),
                  meta: context.tr3(
                    tr: 'romantik filtre · görünürlük',
                    en: 'romantic filter · visibility',
                    de: 'Romantik-Filter · Sichtbarkeit',
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildIdentityCard()),
              SliverToBoxAdapter(
                child: _buildSectionHead(
                  title: context.tr3(
                    tr: 'Etkinlik tercihleri',
                    en: 'Activity preferences',
                    de: 'Aktivitäts-Einstellungen',
                  ),
                  meta: _activityRadiusLabel,
                ),
              ),
              SliverToBoxAdapter(
                child: _buildToggleGroup([
                  _ToggleRowData(
                    icon: Icons.notifications_active_rounded,
                    title: context.tr3(
                      tr: 'Etkinlik bildirimleri',
                      en: 'Activity notifications',
                      de: 'Aktivitäts-Benachrichtigungen',
                    ),
                    subtitle: context.tr3(
                      tr: 'davet, katılım, hatırlatma uyarıları',
                      en: 'invites, joins, reminders',
                      de: 'Einladungen, Beitritte, Erinnerungen',
                    ),
                    value: _activityNotificationsEnabled,
                    accent: AppColors.primary,
                    onChanged: (value) async {
                      setState(() => _activityNotificationsEnabled = value);
                      await _saveSettings({
                        'activityNotificationsEnabled': value,
                      });
                    },
                  ),
                  _ToggleRowData(
                    icon: Icons.verified_user_rounded,
                    title: context.tr3(
                      tr: 'Kendi etkinliğimde otomatik onay',
                      en: 'Auto-approve on my activities',
                      de: 'Auto-Bestätigung meiner Aktivitäten',
                    ),
                    subtitle: context.tr3(
                      tr: 'isteyenleri elle onaylamadan ekibe alır',
                      en: 'lets requesters in without manual review',
                      de: 'lässt Anfragende ohne manuelle Prüfung beitreten',
                    ),
                    value: _activityAutoApprove,
                    accent: AppColors.modeSosyal,
                    onChanged: (value) async {
                      setState(() => _activityAutoApprove = value);
                      await _saveSettings({'activityAutoApprove': value});
                    },
                  ),
                  _ToggleRowData(
                    icon: Icons.event_available_rounded,
                    title: context.tr3(
                      tr: 'Profilde etkinliklerim görünsün',
                      en: 'Show my activities on profile',
                      de: 'Meine Aktivitäten im Profil zeigen',
                    ),
                    subtitle: context.tr3(
                      tr: 'profil ekranında host olduğun etkinlikleri yayınlar',
                      en: 'publishes hosted activities on your profile',
                      de: 'zeigt deine Host-Aktivitäten im Profil an',
                    ),
                    value: _activityShowOnProfile,
                    accent: AppColors.neonCyan,
                    onChanged: (value) async {
                      setState(() => _activityShowOnProfile = value);
                      await _saveSettings({'activityShowOnProfile': value});
                    },
                  ),
                ]),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Text(
                    context.tr3(
                      tr: 'Varsayılan keşif yarıçapı',
                      en: 'Default discovery radius',
                      de: 'Standard-Entdeckungsradius',
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: _buildChipRail<int>(
                    options: const [3, 5, 10, 20, 50],
                    value: _activityRadiusKm,
                    labelBuilder: (v) => '$v km',
                    iconBuilder: (v) => v <= 5
                        ? Icons.directions_walk_rounded
                        : v <= 10
                            ? Icons.directions_bike_rounded
                            : Icons.directions_car_rounded,
                    onChanged: (value) async {
                      setState(() => _activityRadiusKm = value);
                      await _saveSettings({'activityRadiusKm': value});
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildSectionHead(
                  title: context.tr3(
                    tr: 'Uygulama dili',
                    en: 'App language',
                    de: 'App-Sprache',
                  ),
                  meta: context.l10n.languageName(_selectedLanguage),
                ),
              ),
              SliverToBoxAdapter(child: _buildLanguageRail()),
              SliverToBoxAdapter(
                child: _buildSectionHead(
                  title: context.tr3(
                    tr: 'Veri & hukuki',
                    en: 'Data & legal',
                    de: 'Daten & Recht',
                  ),
                  meta: context.tr3(
                    tr: 'politikalar, dışa aktarım',
                    en: 'policies, export',
                    de: 'Richtlinien, Export',
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildLegalGroup()),
              SliverToBoxAdapter(
                child: _buildSectionHead(
                  title: context.tr3(
                    tr: 'Hesap',
                    en: 'Account',
                    de: 'Konto',
                  ),
                  meta: context.tr3(
                    tr: 'oturum · kalıcı işlemler',
                    en: 'session · permanent actions',
                    de: 'Sitzung · dauerhafte Aktionen',
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildAccountGroup()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 40),
                  child: Center(
                    child: Text(
                      'PulseCity · v1.0.0',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.18),
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          _buildTopOverlay(topPadding),
        ],
      ),
    );
  }

  // ─── Top overlay (back + title) ────────────────────────────────────────────
  Widget _buildTopOverlay(double topPadding) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.bgMain.withValues(alpha: 0.55),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            child: Row(
              children: [
                _buildGlassIconButton(
                  Icons.arrow_back_ios_new_rounded,
                  () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.t('settings'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        context.tr3(
                          tr: 'profilin · veri · tercihler',
                          en: 'profile · data · preferences',
                          de: 'Profil · Daten · Einstellungen',
                        ),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildPrivacyPill(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.35),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: [
            _privacyAccent.withValues(alpha: 0.22),
            _privacyAccent.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: _privacyAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 12, color: _privacyAccent),
          const SizedBox(width: 5),
          Text(
            '$_privacyScore',
            style: TextStyle(
              color: _privacyAccent,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Privacy hero ──────────────────────────────────────────────────────────
  Widget _buildPrivacyHero() {
    final accent = _privacyAccent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.22),
              AppColors.bgCard,
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    context.tr3(
                      tr: 'GİZLİLİK MERKEZİ',
                      en: 'PRIVACY CENTER',
                      de: 'PRIVATSPHÄRE',
                    ),
                    style: TextStyle(
                      color: accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '$_privacyScore',
                  style: TextStyle(
                    color: accent,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '/100',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _privacyMood,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _privacySummary,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                children: [
                  Container(
                    height: 6,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  FractionallySizedBox(
                    widthFactor: (_privacyScore / 100).clamp(0.02, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.6)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Quick toggle row ──────────────────────────────────────────────────────
  Widget _buildQuickToggleRow() {
    final items = [
      _QuickStat(
        icon: Icons.visibility_rounded,
        label: context.tr3(tr: 'Görünürlük', en: 'Visibility', de: 'Sichtbarkeit'),
        value: _visibilityStatus,
        active: _isVisible && !_ghostMode,
        accent: AppColors.primary,
      ),
      _QuickStat(
        icon: Icons.blur_on_rounded,
        label: context.tr3(tr: 'DP', en: 'DP', de: 'DP'),
        value: _enableDifferentialPrivacy
            ? context.tr3(tr: 'Açık', en: 'On', de: 'An')
            : context.tr3(tr: 'Kapalı', en: 'Off', de: 'Aus'),
        active: _enableDifferentialPrivacy,
        accent: AppColors.neonCyan,
      ),
      _QuickStat(
        icon: Icons.groups_rounded,
        label: context.tr3(tr: 'k-anon', en: 'k-anon', de: 'k-anon'),
        value: 'k=$_kAnonymityLevel',
        active: _kAnonymityLevel >= 4,
        accent: AppColors.modeSosyal,
      ),
      _QuickStat(
        icon: Icons.my_location_rounded,
        label: context.tr3(tr: 'Konum', en: 'Location', de: 'Standort'),
        value: _granularityLabel,
        active: _locationGranularity != 'exact',
        accent: AppColors.modeSakinlik,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Expanded(child: _buildQuickStatCell(items[i])),
              if (i != items.length - 1)
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatCell(_QuickStat stat) {
    final color = stat.active ? stat.accent : Colors.white.withValues(alpha: 0.3);
    return Column(
      children: [
        Icon(stat.icon, size: 16, color: color),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            stat.value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: stat.active ? 0.9 : 0.5),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          stat.label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  // ─── Verification CTA ──────────────────────────────────────────────────────
  Widget _buildVerificationCta() {
    final status = _verificationStatus;
    final approved = _isPhotoVerified || status == 'approved';
    final pending = status == 'pending';
    final rejected = status == 'rejected';

    final (gradient, icon, title, body, ctaLabel) = approved
        ? (
            const LinearGradient(
              colors: [AppColors.primary, AppColors.neonCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            Icons.verified_rounded,
            context.tr3(
              tr: 'Profilin doğrulandı',
              en: 'Profile verified',
              de: 'Profil verifiziert',
            ),
            context.tr3(
              tr: 'Mavi rozet aktif. Discover akışında öne çıkıyorsun.',
              en: 'Blue badge active. You stand out in Discover.',
              de: 'Blaues Abzeichen aktiv. Du stichst in Discover hervor.',
            ),
            context.tr3(
              tr: 'Detayları gör',
              en: 'View details',
              de: 'Details ansehen',
            ),
          )
        : pending
        ? (
            const LinearGradient(
              colors: [Color(0xFFF39C12), Color(0xFFFB923C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            Icons.hourglass_top_rounded,
            context.tr3(
              tr: 'Doğrulama incelemede',
              en: 'Verification in review',
              de: 'Verifizierung in Prüfung',
            ),
            context.tr3(
              tr: 'Selfie\'n moderasyon kuyruğunda. Sonuç bildirimle gelecek.',
              en: 'Your selfie is queued. We\'ll notify you with the result.',
              de: 'Dein Selfie wird geprüft. Wir benachrichtigen dich.',
            ),
            context.tr3(
              tr: 'Durumu yenile',
              en: 'Refresh status',
              de: 'Status aktualisieren',
            ),
          )
        : rejected
        ? (
            const LinearGradient(
              colors: [Color(0xFFE94560), Color(0xFFFF6B81)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            Icons.refresh_rounded,
            context.tr3(
              tr: 'Doğrulama reddedildi',
              en: 'Verification rejected',
              de: 'Verifizierung abgelehnt',
            ),
            context.tr3(
              tr: 'Tekrar dene — yüzün ve hareketin net görünsün.',
              en: 'Try again — make sure face and gesture are clear.',
              de: 'Bitte nochmal — Gesicht und Geste deutlich.',
            ),
            context.tr3(
              tr: 'Yeniden gönder',
              en: 'Submit again',
              de: 'Erneut senden',
            ),
          )
        : (
            const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryGlow],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            Icons.verified_user_outlined,
            context.tr3(
              tr: 'Mavi rozeti kazan',
              en: 'Earn the blue badge',
              de: 'Hol dir das blaue Abzeichen',
            ),
            context.tr3(
              tr: 'Hızlı bir selfie ile profilin doğrulansın, Discover\'da öne çık.',
              en: 'Quick selfie to verify, stand out in Discover.',
              de: 'Schnelles Selfie, sticht in Discover hervor.',
            ),
            context.tr3(
              tr: 'Doğrulamaya başla',
              en: 'Start verification',
              de: 'Verifizierung starten',
            ),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: InkWell(
        onTap: _openVerificationFlow,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.32),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ctaLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openVerificationFlow() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const VerificationScreen(),
      ),
    );
    if (mounted) {
      await _loadSettings();
    }
  }

  // ─── Section head (profile-match) ──────────────────────────────────────────
  Widget _buildSectionHead({
    required String title,
    String? meta,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (meta != null && meta.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                meta,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Toggle group ──────────────────────────────────────────────────────────
  Widget _buildToggleGroup(List<_ToggleRowData> rows) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              _buildToggleRow(rows[i]),
              if (i != rows.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 58,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(_ToggleRowData data) {
    final active = data.value;
    final accent = data.accent ?? AppColors.primary;

    return InkWell(
      onTap: () => data.onChanged(!active),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: active
                    ? LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.6)],
                      )
                    : null,
                color: active
                    ? null
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(
                data.icon,
                size: 18,
                color:
                    active ? Colors.white : Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _buildTinySwitch(active, accent, data.onChanged),
          ],
        ),
      ),
    );
  }

  Widget _buildTinySwitch(bool active, Color accent, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!active),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 42,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.7)],
                )
              : null,
          color: active ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Align(
          alignment: active ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Chip rail (for enum-like settings) ────────────────────────────────────
  Widget _buildChipRail<T>({
    required List<T> options,
    required T value,
    required String Function(T) labelBuilder,
    required IconData Function(T) iconBuilder,
    required ValueChanged<T> onChanged,
  }) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, index) {
          final option = options[index];
          final selected = option == value;
          return GestureDetector(
            onTap: () => onChanged(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryGlow],
                      )
                    : null,
                color: selected ? null : AppColors.bgCard,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.06),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.32),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconBuilder(option),
                    size: 14,
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    labelBuilder(option),
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── k-anonymity slider-style picker ───────────────────────────────────────
  Widget _buildKAnonymitySlider() {
    const options = [3, 4, 5, 6];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.groups_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.t('k_anonymity_sub'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: options.map((option) {
                final selected = option == _kAnonymityLevel;
                return Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      setState(() => _kAnonymityLevel = option);
                      await _saveSettings({'kAnonymityLevel': option});
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: selected
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryGlow,
                                ],
                              )
                            : null,
                        color:
                            selected ? null : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? Colors.transparent
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'k=$option',
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _kAnonLabel(option),
                            style: TextStyle(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : Colors.white.withValues(alpha: 0.35),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _kAnonLabel(int option) {
    return switch (option) {
      3 => context.tr3(tr: 'DENGE', en: 'BALANCED', de: 'AUSGEWOGEN'),
      4 => context.tr3(tr: 'ORTA', en: 'MEDIUM', de: 'MITTEL'),
      5 => context.tr3(tr: 'YÜKSEK', en: 'HIGH', de: 'HOCH'),
      _ => context.tr3(tr: 'MAKS', en: 'MAX', de: 'MAX'),
    };
  }

  // ─── Identity & matching ───────────────────────────────────────────────────
  Widget _buildIdentityCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.t('gender'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: const ['female', 'male', 'nonbinary']
                  .map(
                    (value) => _buildPillChoice<String>(
                      value: value,
                      selected:
                          (_selectedGender.isEmpty ? 'female' : _selectedGender) ==
                          value,
                      label: _genderLabel(value),
                      icon: switch (value) {
                        'male' => Icons.male_rounded,
                        'female' => Icons.female_rounded,
                        _ => Icons.transgender_rounded,
                      },
                      onTap: () async {
                        setState(() => _selectedGender = value);
                        await _saveSettings({'gender': value});
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.t('match_preference'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr3(
                tr:
                    'Romantik eşleşme filtresi. Arkadaşlık ve görünürlük bundan bağımsız.',
                en:
                    'Romantic matching filter. Friendship and visibility continue independently.',
                de:
                    'Romantik-Filter. Freundschaft und Sichtbarkeit laufen unabhängig.',
              ),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: const ['auto', 'women', 'men', 'everyone']
                  .map(
                    (value) => _buildPillChoice<String>(
                      value: value,
                      selected: _selectedMatchPreference == value,
                      label: _matchPreferenceLabel(value),
                      icon: switch (value) {
                        'women' => Icons.female_rounded,
                        'men' => Icons.male_rounded,
                        'everyone' => Icons.groups_rounded,
                        _ => Icons.auto_awesome_rounded,
                      },
                      onTap: () async {
                        setState(() => _selectedMatchPreference = value);
                        await _saveSettings({'matchPreference': value});
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillChoice<T>({
    required T value,
    required bool selected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryGlow],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.05),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _genderLabel(String value) {
    switch (value) {
      case 'male':
        return context.l10n.t('gender_male');
      case 'female':
        return context.l10n.t('gender_female');
      case 'nonbinary':
        return context.l10n.t('gender_nonbinary');
      default:
        return context.tr3(tr: 'Belirtilmedi', en: 'Unspecified', de: 'Nicht angegeben');
    }
  }

  String _matchPreferenceLabel(String value) {
    switch (value) {
      case 'women':
        return context.l10n.t('match_preference_women');
      case 'men':
        return context.l10n.t('match_preference_men');
      case 'everyone':
        return context.l10n.t('match_preference_everyone');
      default:
        return context.l10n.t('match_preference_auto');
    }
  }

  // ─── Language rail ─────────────────────────────────────────────────────────
  Widget _buildLanguageRail() {
    const languages = ['tr', 'en', 'de'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: languages.map((code) {
          final selected = _selectedLanguage == code;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () async {
                  if (selected) return;
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _selectedLanguage = code);
                  await AppLocaleService.instance.setLanguageCode(code);
                  await _saveSettings({'preferredLanguage': code});
                  if (!mounted) return;
                  final languageSaved = AppLocalizations(
                    AppLocaleService.instance.locale,
                  ).t('language_saved');
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(languageSaved),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primary, AppColors.primaryGlow],
                          )
                        : null,
                    color:
                        selected ? null : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.05),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color:
                                  AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        code.toUpperCase(),
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.75),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.languageName(code),
                        style: TextStyle(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Legal & data ──────────────────────────────────────────────────────────
  Widget _buildLegalGroup() {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            _buildListTile(
              icon: Icons.description_rounded,
              accent: AppColors.modeTopluluk,
              title: l10n.t('terms_of_service'),
              subtitle: context.tr3(
                tr: 'Kullanım koşullarını oku',
                en: 'Read the terms of service',
                de: 'Nutzungsbedingungen lesen',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsScreen()),
              ),
            ),
            _tileDivider(),
            _buildListTile(
              icon: Icons.privacy_tip_rounded,
              accent: AppColors.neonCyan,
              title: l10n.t('privacy_policy'),
              subtitle: context.tr3(
                tr: 'Verinin nasıl işlendiğini oku',
                en: 'How your data is handled',
                de: 'Wie deine Daten verarbeitet werden',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyScreen()),
              ),
            ),
            _tileDivider(),
            _buildListTile(
              icon: Icons.download_rounded,
              accent: AppColors.modeSakinlik,
              title: l10n.t('export_data'),
              subtitle: l10n.t('export_data_sub'),
              onTap: _exportMyData,
              trailing: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.modeSakinlik,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Account ───────────────────────────────────────────────────────────────
  Widget _buildAccountGroup() {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            _buildListTile(
              icon: Icons.logout_rounded,
              accent: AppColors.modeSosyal,
              title: l10n.t('logout'),
              subtitle: context.tr3(
                tr: 'Bu cihazdan çıkış yap',
                en: 'Sign out on this device',
                de: 'Auf diesem Gerät abmelden',
              ),
              onTap: _showLogoutDialog,
            ),
            _tileDivider(),
            _buildListTile(
              icon: Icons.delete_forever_rounded,
              accent: AppColors.error,
              title: l10n.t('delete_account'),
              subtitle: context.tr3(
                tr: 'Hesap ve tüm profil verisi kalıcı silinir',
                en: 'Account and all profile data permanently removed',
                de: 'Konto und alle Profildaten dauerhaft entfernt',
              ),
              destructive: true,
              onTap: _showDeleteDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tileDivider() => Divider(
        height: 1,
        thickness: 1,
        indent: 58,
        color: Colors.white.withValues(alpha: 0.04),
      );

  Widget _buildListTile({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    bool destructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: destructive ? AppColors.error : Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
          ],
        ),
      ),
    );
  }

  // ─── Dialogs ───────────────────────────────────────────────────────────────
  Future<void> _showLogoutDialog() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(
          l10n.t('logout'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.languageCode == 'de'
              ? 'Möchtest du dich wirklich abmelden?'
              : l10n.languageCode == 'en'
              ? 'Do you really want to log out?'
              : 'Çıkış yapmak istediğine emin misin?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l10n.t('logout')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _showDeleteDialog() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(
          l10n.t('delete_account'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.languageCode == 'de'
              ? 'Dieses Konto und deine Profildaten werden entfernt.'
              : l10n.languageCode == 'en'
              ? 'This account and your profile data will be removed.'
              : 'Bu hesap ve profil verilerin kaldırılacak.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.t('delete_account')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _authService.deleteCurrentAccount();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

// ─── Small data classes ─────────────────────────────────────────────────────

class _ToggleRowData {
  const _ToggleRowData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? accent;
}

class _QuickStat {
  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool active;
  final Color accent;
}
