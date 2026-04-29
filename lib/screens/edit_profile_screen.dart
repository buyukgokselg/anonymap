import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/mode_config.dart';
import '../localization/app_localizations.dart';
import '../models/user_model.dart';
import '../theme/colors.dart';

class EditProfileDraft {
  final String userName;
  final String displayName;
  final String firstName;
  final String lastName;
  final String bio;
  final String city;
  final String website;
  final String gender;
  final DateTime? birthDate;
  final String purpose;
  final String matchPreference;
  final String mode;
  final String privacyLevel;
  final String preferredLanguage;
  final String locationGranularity;
  final bool enableDifferentialPrivacy;
  final int kAnonymityLevel;
  final bool allowAnalytics;
  final bool isVisible;
  final List<String> interests;
  final String orientation;
  final String relationshipIntent;
  final int? heightCm;
  final String drinkingStatus;
  final String smokingStatus;
  final List<String> lookingForModes;
  final List<String> dealbreakers;
  final Map<String, String> datingPrompts;

  const EditProfileDraft({
    required this.userName,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.bio,
    required this.city,
    required this.website,
    required this.gender,
    required this.birthDate,
    required this.purpose,
    required this.matchPreference,
    required this.mode,
    required this.privacyLevel,
    required this.preferredLanguage,
    required this.locationGranularity,
    required this.enableDifferentialPrivacy,
    required this.kAnonymityLevel,
    required this.allowAnalytics,
    required this.isVisible,
    required this.interests,
    this.orientation = '',
    this.relationshipIntent = '',
    this.heightCm,
    this.drinkingStatus = '',
    this.smokingStatus = '',
    this.lookingForModes = const [],
    this.dealbreakers = const [],
    this.datingPrompts = const {},
  });
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const List<String> _interestOptions = [
    'Kafeler',
    'Restoranlar',
    'Street Food',
    'Barlar & Gece',
    'Müzik & Konser',
    'Sanat & Müze',
    'Tiyatro & Sinema',
    'Kitap & Okuma',
    'Fitness & Spor',
    'Koşu & Yürüyüş',
    'Parklar & Doğa',
    'Bisiklet',
    'Yoga & Meditasyon',
    'Teknoloji',
    'Board Game',
    'Workshop & Etkinlik',
  ];

  final _userNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _websiteController = TextEditingController();

  late String _gender;
  late DateTime? _birthDate;
  late String _purpose;
  late String _matchPreference;
  late String _mode;
  late String _privacyLevel;
  late String _preferredLanguage;
  late String _locationGranularity;
  late bool _enableDifferentialPrivacy;
  late int _kAnonymityLevel;
  late bool _allowAnalytics;
  late bool _isVisible;
  late Set<String> _interests;
  late String _orientation;
  late String _relationshipIntent;
  int? _heightCm;
  late String _drinkingStatus;
  late String _smokingStatus;
  late Set<String> _lookingForModes;
  late Set<String> _dealbreakers;
  final Map<String, TextEditingController> _promptControllers = {};

  AppLocalizations get _l10n => context.l10n;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _userNameController.text = user.username;
    _displayNameController.text = user.displayName;
    _firstNameController.text = user.firstName;
    _lastNameController.text = user.lastName;
    _bioController.text = user.bio;
    _cityController.text = user.city;
    _websiteController.text = user.website;
    _gender = user.gender.isNotEmpty ? user.gender : 'male';
    _birthDate = user.birthDate;
    _purpose = user.purpose.isNotEmpty ? user.purpose : user.mode;
    _matchPreference = user.matchPreference.isNotEmpty
        ? user.matchPreference
        : 'auto';
    _mode = user.mode;
    _privacyLevel = user.privacyLevel;
    _preferredLanguage = user.preferredLanguage;
    _locationGranularity = user.locationGranularity;
    _enableDifferentialPrivacy = user.enableDifferentialPrivacy;
    _kAnonymityLevel = user.kAnonymityLevel;
    _allowAnalytics = user.allowAnalytics;
    _isVisible = user.isVisible;
    _interests = user.interests.toSet();
    _orientation = user.orientation;
    _relationshipIntent = user.relationshipIntent;
    _heightCm = user.heightCm;
    _drinkingStatus = user.drinkingStatus;
    _smokingStatus = user.smokingStatus;
    _lookingForModes = user.lookingForModes.toSet();
    _dealbreakers = user.dealbreakers.toSet();
    for (final id in _promptIds) {
      _promptControllers[id] =
          TextEditingController(text: user.datingPrompts[id] ?? '');
    }
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _displayNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _websiteController.dispose();
    for (final c in _promptControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _copy({required String tr, required String en, required String de}) {
    return switch (_l10n.languageCode) {
      'en' => en,
      'de' => de,
      _ => tr,
    };
  }

  String get _normalizedUserName {
    final raw = _userNameController.text.trim().toLowerCase();
    return raw.startsWith('@') ? raw.substring(1) : raw;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 24, now.month, now.day),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
    }
  }

  String? _validateDraft() {
    if (_normalizedUserName.length < 3) {
      return _copy(
        tr: 'Kullanıcı adı en az 3 karakter olmalı.',
        en: 'Username must be at least 3 characters.',
        de: 'Der Benutzername muss mindestens 3 Zeichen lang sein.',
      );
    }
    if (!RegExp(r'^[a-z0-9._]+$').hasMatch(_normalizedUserName)) {
      return _copy(
        tr: 'Kullanıcı adı sadece küçük harf, rakam, nokta ve alt çizgi içerebilir.',
        en: 'Username can only contain lowercase letters, numbers, dots, and underscores.',
        de: 'Der Benutzername darf nur Kleinbuchstaben, Zahlen, Punkte und Unterstriche enthalten.',
      );
    }
    if (_displayNameController.text.trim().isEmpty ||
        _firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty) {
      return _copy(
        tr: 'Görünen ad, ad, soyad ve şehir zorunlu.',
        en: 'Display name, first name, last name, and city are required.',
        de: 'Anzeigename, Vorname, Nachname und Stadt sind erforderlich.',
      );
    }
    if (_birthDate == null) {
      return _copy(
        tr: 'Doğum tarihi seçmelisin.',
        en: 'You need to select a birth date.',
        de: 'Du musst ein Geburtsdatum auswählen.',
      );
    }
    if (_interests.isEmpty) {
      return _copy(
        tr: 'En az bir ilgi alanı seç.',
        en: 'Select at least one interest.',
        de: 'Wähle mindestens ein Interesse aus.',
      );
    }
    return null;
  }

  void _submit() {
    final error = _validateDraft();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      EditProfileDraft(
        userName: _normalizedUserName,
        displayName: _displayNameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        bio: _bioController.text.trim(),
        city: _cityController.text.trim(),
        website: _websiteController.text.trim(),
        gender: _gender,
        birthDate: _birthDate,
        purpose: _purpose,
        matchPreference: _matchPreference,
        mode: _mode,
        privacyLevel: _privacyLevel,
        preferredLanguage: _preferredLanguage,
        locationGranularity: _locationGranularity,
        enableDifferentialPrivacy: _enableDifferentialPrivacy,
        kAnonymityLevel: _kAnonymityLevel,
        allowAnalytics: _allowAnalytics,
        isVisible: _isVisible,
        interests: _interests.toList(),
        orientation: _orientation,
        relationshipIntent: _relationshipIntent,
        heightCm: _heightCm,
        drinkingStatus: _drinkingStatus,
        smokingStatus: _smokingStatus,
        lookingForModes: _lookingForModes.toList(),
        dealbreakers: _dealbreakers.toList(),
        datingPrompts: _collectPromptAnswers(),
      ),
    );
  }

  Map<String, String> _collectPromptAnswers() {
    final result = <String, String>{};
    for (final entry in _promptControllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) {
        result[entry.key] = value;
      }
    }
    return result;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _copy(
            tr: 'Profili Düzenle',
            en: 'Edit Profile',
            de: 'Profil bearbeiten',
          ),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submit,
            child: Text(
              _copy(tr: 'Kaydet', en: 'Save', de: 'Speichern'),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _hero(),
                  const SizedBox(height: 16),
                  _section(
                    title: _copy(tr: 'Kimlik', en: 'Identity', de: 'Identität'),
                    subtitle: _copy(
                      tr: 'Kullanıcı adı, görünen ad ve temel profil alanlarını güncelle.',
                      en: 'Update your username, display name, and primary profile fields.',
                      de: 'Aktualisiere Benutzernamen, Anzeigenamen und zentrale Profilfelder.',
                    ),
                    child: Column(
                      children: [
                        _field(
                          _userNameController,
                          _copy(
                            tr: 'Kullanıcı adı',
                            en: 'Username',
                            de: 'Benutzername',
                          ),
                          'ataberk',
                          prefixText: '@',
                          maxLength: 32,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9._@]'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _field(
                          _displayNameController,
                          _copy(
                            tr: 'Görünen ad',
                            en: 'Display name',
                            de: 'Anzeigename',
                          ),
                          _copy(
                            tr: 'Profilde görünen isim',
                            en: 'Name shown on profile',
                            de: 'Im Profil sichtbarer Name',
                          ),
                          maxLength: 64,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                _firstNameController,
                                _copy(
                                  tr: 'Ad',
                                  en: 'First name',
                                  de: 'Vorname',
                                ),
                                _copy(
                                  tr: 'Adın',
                                  en: 'Your first name',
                                  de: 'Dein Vorname',
                                ),
                                maxLength: 64,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                _lastNameController,
                                _copy(
                                  tr: 'Soyad',
                                  en: 'Last name',
                                  de: 'Nachname',
                                ),
                                _copy(
                                  tr: 'Soyadın',
                                  en: 'Your last name',
                                  de: 'Dein Nachname',
                                ),
                                maxLength: 64,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _field(
                          _cityController,
                          _copy(tr: 'Şehir', en: 'City', de: 'Stadt'),
                          _copy(
                            tr: 'Yaşadığın şehir',
                            en: 'Your city',
                            de: 'Deine Stadt',
                          ),
                          maxLength: 120,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          _websiteController,
                          'Website',
                          'https://',
                          maxLength: 256,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          _bioController,
                          'Bio',
                          _copy(
                            tr: 'Kendinden kısaca bahset',
                            en: 'Tell people about yourself',
                            de: 'Erzähle kurz etwas über dich',
                          ),
                          maxLength: 160,
                          minLines: 4,
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    title: _copy(
                      tr: 'Kişisel Ayarlar',
                      en: 'Personal Settings',
                      de: 'Persönliche Einstellungen',
                    ),
                    subtitle: _copy(
                      tr: 'Kayıt sırasında alınan kişisel bilgileri burada güncelleyebilirsin.',
                      en: 'Update the personal information collected during signup here.',
                      de: 'Hier kannst du die bei der Registrierung erfassten Angaben aktualisieren.',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _birthDateTile(),
                        const SizedBox(height: 12),
                        _label(
                          _copy(tr: 'Cinsiyet', en: 'Gender', de: 'Geschlecht'),
                        ),
                        const SizedBox(height: 8),
                        _chipGroup<String>(
                          const ['male', 'female', 'nonbinary'],
                          _gender,
                          (v) => switch (v) {
                            'male' => _l10n.t('gender_male'),
                            'female' => _l10n.t('gender_female'),
                            _ => _l10n.t('gender_nonbinary'),
                          },
                          (v) => setState(() => _gender = v),
                        ),
                        const SizedBox(height: 12),
                        _label(
                          _copy(
                            tr: 'Eşleşme tercihi',
                            en: 'Match preference',
                            de: 'Matching-Präferenz',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _chipGroup<String>(
                          const ['auto', 'women', 'men', 'everyone'],
                          _matchPreference,
                          (v) => switch (v) {
                            'women' => _l10n.t('match_preference_women'),
                            'men' => _l10n.t('match_preference_men'),
                            'everyone' => _l10n.t('match_preference_everyone'),
                            _ => _l10n.t('match_preference_auto'),
                          },
                          (v) => setState(() => _matchPreference = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    title: _copy(
                      tr: 'Mod ve Gizlilik',
                      en: 'Mode & Privacy',
                      de: 'Modus & Privatsphäre',
                    ),
                    subtitle: _copy(
                      tr: 'Onboarding seçimleri, dil ve görünürlük ayarları burada yönetilir.',
                      en: 'Manage onboarding choices, language, and visibility here.',
                      de: 'Verwalte hier Onboarding-Auswahl, Sprache und Sichtbarkeit.',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(
                          _copy(
                            tr: 'Ana mod',
                            en: 'Primary mode',
                            de: 'Hauptmodus',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _modeGroup(_mode, (v) => setState(() => _mode = v)),
                        const SizedBox(height: 12),
                        _label(
                          _copy(
                            tr: 'Profil amacı',
                            en: 'Profile intent',
                            de: 'Profilabsicht',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _modeGroup(
                          _purpose,
                          (v) => setState(() => _purpose = v),
                        ),
                        const SizedBox(height: 12),
                        _label(
                          _copy(
                            tr: 'Gizlilik düzeyi',
                            en: 'Privacy level',
                            de: 'Privatsphäre-Stufe',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _chipGroup<String>(
                          const ['full', 'partial', 'ghost'],
                          _privacyLevel,
                          (v) => switch (v) {
                            'partial' => _copy(
                              tr: 'Kısmi Katılım',
                              en: 'Partial',
                              de: 'Teilweise',
                            ),
                            'ghost' => 'Ghost',
                            _ => _copy(
                              tr: 'Tam Katılım',
                              en: 'Full',
                              de: 'Voll',
                            ),
                          },
                          (v) => setState(() => _privacyLevel = v),
                        ),
                        const SizedBox(height: 12),
                        _label(_copy(tr: 'Dil', en: 'Language', de: 'Sprache')),
                        const SizedBox(height: 8),
                        _chipGroup<String>(
                          const ['tr', 'en', 'de'],
                          _preferredLanguage,
                          (v) => switch (v) {
                            'en' => 'English',
                            'de' => 'Deutsch',
                            _ => 'Türkçe',
                          },
                          (v) => setState(() => _preferredLanguage = v),
                        ),
                        const SizedBox(height: 12),
                        _label(
                          _copy(
                            tr: 'Konum hassasiyeti',
                            en: 'Location granularity',
                            de: 'Standortgenauigkeit',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _chipGroup<String>(
                          const ['nearby', 'district', 'city', 'exact'],
                          _locationGranularity,
                          (v) => switch (v) {
                            'district' => _copy(
                              tr: 'İlçe',
                              en: 'District',
                              de: 'Bezirk',
                            ),
                            'city' => _copy(
                              tr: 'Şehir',
                              en: 'City',
                              de: 'Stadt',
                            ),
                            'exact' => _copy(
                              tr: 'Tam Konum',
                              en: 'Exact',
                              de: 'Genau',
                            ),
                            _ => _copy(
                              tr: 'Yakın Çevre',
                              en: 'Nearby',
                              de: 'Nahbereich',
                            ),
                          },
                          (v) => setState(() => _locationGranularity = v),
                        ),
                        const SizedBox(height: 12),
                        _label(
                          _copy(
                            tr: 'K anonimlik seviyesi',
                            en: 'K-anonymity level',
                            de: 'K-Anonymitätsstufe',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _chipGroup<int>(
                          const [2, 3, 5, 7, 10],
                          _kAnonymityLevel,
                          (v) => 'k=$v',
                          (v) => setState(() => _kAnonymityLevel = v),
                        ),
                        const SizedBox(height: 12),
                        _switchTile(
                          _copy(
                            tr: 'Profil görünür olsun',
                            en: 'Profile visible',
                            de: 'Profil sichtbar',
                          ),
                          _copy(
                            tr: 'Diğer kullanıcılar profilini görebilsin.',
                            en: 'Allow other users to discover your profile.',
                            de: 'Andere Nutzer dürfen dein Profil entdecken.',
                          ),
                          _isVisible,
                          (v) => setState(() => _isVisible = v),
                        ),
                        _switchTile(
                          _copy(
                            tr: 'Diferansiyel gizlilik',
                            en: 'Differential privacy',
                            de: 'Differential Privacy',
                          ),
                          _copy(
                            tr: 'Anonim sinyal hesaplarında ek gizlilik katmanı uygula.',
                            en: 'Apply an additional privacy layer to anonymous signal calculations.',
                            de: 'Aktiviere eine zusätzliche Datenschutzschicht für anonyme Signalberechnungen.',
                          ),
                          _enableDifferentialPrivacy,
                          (v) => setState(() => _enableDifferentialPrivacy = v),
                        ),
                        _switchTile(
                          _copy(
                            tr: 'Ürün analizine izin ver',
                            en: 'Allow analytics',
                            de: 'Analysen erlauben',
                          ),
                          _copy(
                            tr: 'Anonim kullanım verisiyle ürünü geliştirmemize yardımcı ol.',
                            en: 'Help improve the product with anonymous usage data.',
                            de: 'Hilf uns mit anonymen Nutzungsdaten, das Produkt zu verbessern.',
                          ),
                          _allowAnalytics,
                          (v) => setState(() => _allowAnalytics = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDatingSection(),
                  const SizedBox(height: 16),
                  _buildPromptsSection(),
                  const SizedBox(height: 16),
                  _section(
                    title: _copy(
                      tr: 'İlgi Alanları',
                      en: 'Interests',
                      de: 'Interessen',
                    ),
                    subtitle: _copy(
                      tr: 'Keşif ve öneri mantığı bu alanları referans alır.',
                      en: 'Discovery and recommendation logic uses these interests.',
                      de: 'Discovery- und Empfehlungslogik nutzt diese Interessen.',
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _interestOptions.map((interest) {
                        final selected = _interests.contains(interest);
                        return _interestChip(interest, selected, () {
                          setState(() {
                            if (selected) {
                              _interests.remove(interest);
                            } else {
                              _interests.add(interest);
                            }
                          });
                        });
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    _copy(
                      tr: 'Değişiklikleri kaydet',
                      en: 'Save changes',
                      de: 'Änderungen speichern',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.18),
          AppColors.bgCard,
          AppColors.modeSosyal.withValues(alpha: 0.16),
        ],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Row(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.modeSosyal],
            ),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 38,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${_normalizedUserName.isEmpty ? widget.user.username : _normalizedUserName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _displayNameController.text.trim().isEmpty
                    ? widget.user.username
                    : _displayNameController.text.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(
                    _l10n.modeLabel(_mode),
                    ModeConfig.all
                        .firstWhere(
                          (m) => m.id == _mode,
                          orElse: () => ModeConfig.all.first,
                        )
                        .color,
                  ),
                  _pill(
                    _cityController.text.trim().isEmpty
                        ? _copy(
                            tr: 'Şehir yok',
                            en: 'No city',
                            de: 'Keine Stadt',
                          )
                        : _cityController.text.trim(),
                    AppColors.modeKesif,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _section({
    required String title,
    required String subtitle,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    String? prefixText,
    int? maxLength,
    int minLines = 1,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(label),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefixText,
          counterText: '',
          filled: true,
          fillColor: AppColors.bgMain,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.28)),
          prefixStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w700,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    ],
  );

  Widget _birthDateTile() {
    final hasDate = _birthDate != null;
    final label = hasDate
        ? '${_birthDate!.day.toString().padLeft(2, '0')}.${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.year}'
        : _copy(
            tr: 'Doğum tarihi seç',
            en: 'Select birth date',
            de: 'Geburtsdatum wählen',
          );
    return Material(
      color: hasDate
          ? AppColors.success.withValues(alpha: 0.08)
          : AppColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _pickBirthDate,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasDate
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cake_rounded,
                size: 18,
                color: hasDate ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _copy(
                        tr: 'Doğum Tarihi',
                        en: 'Birth Date',
                        de: 'Geburtsdatum',
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: hasDate
                            ? AppColors.success.withValues(alpha: 0.8)
                            : AppColors.primary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: hasDate
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    if (hasDate) ...[
                      const SizedBox(height: 2),
                      Text(
                        _copy(
                          tr: 'Yaş: ${_calculateAge(_birthDate!)}',
                          en: 'Age: ${_calculateAge(_birthDate!)}',
                          de: 'Alter: ${_calculateAge(_birthDate!)}',
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                hasDate ? Icons.edit_calendar_rounded : Icons.calendar_month_rounded,
                size: 18,
                color: hasDate
                    ? AppColors.success.withValues(alpha: 0.6)
                    : AppColors.primary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateAge(DateTime birth) {
    final now = DateTime.now();
    int age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }


  Widget _switchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.bgMain,
      borderRadius: BorderRadius.circular(16),
    ),
    child: SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppColors.primary,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
          height: 1.3,
        ),
      ),
    ),
  );

  Widget _chipGroup<T>(
    List<T> values,
    T selectedValue,
    String Function(T value) labelBuilder,
    ValueChanged<T> onChanged,
  ) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: values.map((value) {
      final selected = value == selectedValue;
      return GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.16)
                : AppColors.bgMain,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Text(
            labelBuilder(value),
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      );
    }).toList(),
  );

  Widget _modeGroup(String selectedValue, ValueChanged<String> onChanged) =>
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: ModeConfig.all.map((mode) {
          final selected = selectedValue == mode.id;
          return GestureDetector(
            onTap: () => onChanged(mode.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? mode.color.withValues(alpha: 0.16)
                    : AppColors.bgMain,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? mode.color.withValues(alpha: 0.32)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    mode.icon,
                    size: 16,
                    color: selected
                        ? mode.color
                        : Colors.white.withValues(alpha: 0.54),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _l10n.modeLabel(mode.id),
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );

  Widget _interestChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.16)
                : AppColors.bgMain,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      );

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.72),
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
  );

  // ── Dating Profile section ──
  static const List<String> _promptIds = [
    'about_me',
    'perfect_weekend',
    'deal_maker',
    'dream_trip',
    'always_laughing_at',
    'looking_for',
    'green_flags',
    'go_to_song',
  ];

  String _promptLabel(String id) {
    return switch (id) {
      'about_me' => _copy(
          tr: 'Hakkımda',
          en: 'About me',
          de: 'Über mich',
        ),
      'perfect_weekend' => _copy(
          tr: 'Mükemmel hafta sonum',
          en: 'My perfect weekend',
          de: 'Mein perfektes Wochenende',
        ),
      'deal_maker' => _copy(
          tr: 'Benim için olmazsa olmaz',
          en: 'My must-have',
          de: 'Mein Must-have',
        ),
      'dream_trip' => _copy(
          tr: 'Hayalimdeki seyahat',
          en: 'Dream trip',
          de: 'Meine Traumreise',
        ),
      'always_laughing_at' => _copy(
          tr: 'Beni hep güldüren şey',
          en: 'Always laughing at',
          de: 'Worüber ich immer lache',
        ),
      'looking_for' => _copy(
          tr: 'Aradığım şey',
          en: 'What I am looking for',
          de: 'Was ich suche',
        ),
      'green_flags' => _copy(
          tr: 'Yeşil bayraklarım',
          en: 'My green flags',
          de: 'Meine Green Flags',
        ),
      'go_to_song' => _copy(
          tr: 'Vazgeçilmez şarkım',
          en: 'My go-to song',
          de: 'Mein Lieblingslied',
        ),
      _ => id,
    };
  }

  String _promptHint(String id) {
    return switch (id) {
      'about_me' => _copy(
          tr: 'Birkaç cümleyle sen',
          en: 'A few lines about you',
          de: 'Ein paar Zeilen über dich',
        ),
      'perfect_weekend' => _copy(
          tr: 'Brunch, kısa bir yol, film maratonu…',
          en: 'Brunch, a short trip, movie marathon…',
          de: 'Brunch, Kurztrip, Filmemarathon…',
        ),
      'deal_maker' => _copy(
          tr: 'Benim için çok değerli olan şey',
          en: 'Something that matters to me',
          de: 'Was mir wichtig ist',
        ),
      'dream_trip' => _copy(
          tr: 'Gidilecek yer ve neden',
          en: 'Where and why',
          de: 'Wohin und warum',
        ),
      'always_laughing_at' => _copy(
          tr: 'Mem, diziden sahne, bir iç şaka…',
          en: 'A meme, a scene, an inside joke…',
          de: 'Ein Meme, eine Szene, ein Insider…',
        ),
      'looking_for' => _copy(
          tr: 'Kısaca bekle veya umut et',
          en: 'Briefly what you hope for',
          de: 'Kurz, was du dir wünschst',
        ),
      'green_flags' => _copy(
          tr: 'Seni heyecanlandıran özellikler',
          en: 'Traits that excite you',
          de: 'Eigenschaften, die dich begeistern',
        ),
      'go_to_song' => _copy(
          tr: 'Şarkıcı – parça',
          en: 'Artist – track',
          de: 'Künstler – Titel',
        ),
      _ => '',
    };
  }

  static const List<String> _orientationIds = [
    'straight', 'gay', 'lesbian', 'bi', 'pan', 'queer', 'asexual', 'none',
  ];
  static const List<String> _intentIds = [
    'casual', 'relationship', 'friendship', 'open', 'unsure',
  ];
  static const List<String> _frequencyIds = [
    'never', 'rarely', 'socially', 'regularly',
  ];
  static const List<String> _modeIds = ['flirt', 'friends', 'fun', 'chill'];
  static const List<String> _dealbreakerIds = [
    'smoker', 'drinks_heavily', 'no_photo', 'unverified', 'no_bio',
  ];

  String _datingLabel(String key) {
    return switch (key) {
      'straight' => _copy(tr: 'Heteroseksüel', en: 'Straight', de: 'Hetero'),
      'gay' => _copy(tr: 'Gey', en: 'Gay', de: 'Schwul'),
      'lesbian' => _copy(tr: 'Lezbiyen', en: 'Lesbian', de: 'Lesbisch'),
      'bi' => _copy(tr: 'Biseksüel', en: 'Bisexual', de: 'Bisexuell'),
      'pan' => _copy(tr: 'Panseksüel', en: 'Pansexual', de: 'Pansexuell'),
      'queer' => 'Queer',
      'asexual' => _copy(tr: 'Aseksüel', en: 'Asexual', de: 'Asexuell'),
      'none' => _copy(tr: 'Belirtmedim', en: 'Unspecified', de: 'Keine Angabe'),
      'casual' => _copy(tr: 'Rahat', en: 'Casual', de: 'Locker'),
      'relationship' => _copy(tr: 'İlişki', en: 'Relationship', de: 'Beziehung'),
      'friendship' => _copy(tr: 'Arkadaşlık', en: 'Friendship', de: 'Freundschaft'),
      'open' => _copy(tr: 'Açık', en: 'Open', de: 'Offen'),
      'unsure' => _copy(tr: 'Henüz emin değilim', en: 'Still figuring out', de: 'Unsicher'),
      'never' => _copy(tr: 'Hiç', en: 'Never', de: 'Nie'),
      'rarely' => _copy(tr: 'Nadiren', en: 'Rarely', de: 'Selten'),
      'socially' => _copy(tr: 'Sosyal', en: 'Socially', de: 'Gesellig'),
      'regularly' => _copy(tr: 'Düzenli', en: 'Regularly', de: 'Regelmäßig'),
      'flirt' => _copy(tr: 'Flört', en: 'Flirt', de: 'Flirt'),
      'friends' => _copy(tr: 'Arkadaş', en: 'Friends', de: 'Freunde'),
      'fun' => _copy(tr: 'Eğlence', en: 'Fun', de: 'Spaß'),
      'chill' => _copy(tr: 'Keşif', en: 'Chill', de: 'Chill'),
      'smoker' => _copy(tr: 'Sigara içen', en: 'Smoker', de: 'Raucher'),
      'drinks_heavily' => _copy(tr: 'Çok içen', en: 'Heavy drinker', de: 'Viel Alkohol'),
      'no_photo' => _copy(tr: 'Fotoğrafsız', en: 'No photo', de: 'Ohne Foto'),
      'unverified' => _copy(tr: 'Doğrulanmamış', en: 'Unverified', de: 'Unverifiziert'),
      'no_bio' => _copy(tr: 'Bio yok', en: 'No bio', de: 'Keine Bio'),
      _ => key,
    };
  }

  Widget _buildDatingSection() {
    return _section(
      title: _copy(
        tr: 'Dating Profili',
        en: 'Dating Profile',
        de: 'Dating-Profil',
      ),
      subtitle: _copy(
        tr: 'Eşleşme algoritması bu alanları senin için anlamlı kişileri bulmakta kullanır.',
        en: 'The matching algorithm uses these to surface meaningful people for you.',
        de: 'Das Matching nutzt diese Angaben, um passende Menschen zu finden.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(_copy(tr: 'Yönelim', en: 'Orientation', de: 'Orientierung')),
          const SizedBox(height: 8),
          _chipGroup<String>(
            _orientationIds,
            _orientation.isEmpty ? 'none' : _orientation,
            _datingLabel,
            (v) => setState(() => _orientation = v == 'none' ? '' : v),
          ),
          const SizedBox(height: 14),
          _label(_copy(tr: 'Niyet', en: 'Intent', de: 'Absicht')),
          const SizedBox(height: 8),
          _chipGroup<String>(
            _intentIds,
            _relationshipIntent.isEmpty ? 'open' : _relationshipIntent,
            _datingLabel,
            (v) => setState(() => _relationshipIntent = v),
          ),
          const SizedBox(height: 14),
          _label(_copy(tr: 'Boy (cm)', en: 'Height (cm)', de: 'Größe (cm)')),
          const SizedBox(height: 8),
          _heightField(),
          const SizedBox(height: 14),
          _label(_copy(tr: 'Alkol', en: 'Drinking', de: 'Alkohol')),
          const SizedBox(height: 8),
          _chipGroup<String>(
            _frequencyIds,
            _drinkingStatus.isEmpty ? 'rarely' : _drinkingStatus,
            _datingLabel,
            (v) => setState(() => _drinkingStatus = v),
          ),
          const SizedBox(height: 14),
          _label(_copy(tr: 'Sigara', en: 'Smoking', de: 'Rauchen')),
          const SizedBox(height: 8),
          _chipGroup<String>(
            _frequencyIds,
            _smokingStatus.isEmpty ? 'never' : _smokingStatus,
            _datingLabel,
            (v) => setState(() => _smokingStatus = v),
          ),
          const SizedBox(height: 14),
          _label(_copy(
            tr: 'Hangi modlar görsün?',
            en: 'Which modes show up?',
            de: 'Welche Modi anzeigen?',
          )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _modeIds.map((id) {
              final selected = _lookingForModes.contains(id);
              return _interestChip(_datingLabel(id), selected, () {
                setState(() {
                  if (selected) {
                    _lookingForModes.remove(id);
                  } else {
                    _lookingForModes.add(id);
                  }
                });
              });
            }).toList(),
          ),
          const SizedBox(height: 14),
          _label(_copy(
            tr: 'Dealbreaker (öneri dışı bırak)',
            en: 'Dealbreakers (filter out)',
            de: 'Dealbreaker (ausfiltern)',
          )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _dealbreakerIds.map((id) {
              final selected = _dealbreakers.contains(id);
              return _interestChip(_datingLabel(id), selected, () {
                setState(() {
                  if (selected) {
                    _dealbreakers.remove(id);
                  } else {
                    _dealbreakers.add(id);
                  }
                });
              });
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptsSection() {
    return _section(
      title: _copy(
        tr: 'Profil Soruları',
        en: 'Profile Prompts',
        de: 'Profil-Prompts',
      ),
      subtitle: _copy(
        tr: 'Birkaç kısa cevap profilini daha canlı gösterir. Boş bıraktıkların görünmez.',
        en: 'A few short answers make your profile feel alive. Empty ones stay hidden.',
        de: 'Ein paar kurze Antworten machen dein Profil lebendiger. Leere bleiben unsichtbar.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final id in _promptIds) ...[
            _label(_promptLabel(id)),
            const SizedBox(height: 8),
            TextField(
              controller: _promptControllers[id],
              maxLength: 240,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _promptHint(id),
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                ),
                counterStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
                filled: true,
                fillColor: AppColors.bgMain,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _heightField() {
    return SizedBox(
      width: 140,
      child: TextField(
        keyboardType: TextInputType.number,
        controller: TextEditingController(
          text: _heightCm == null ? '' : '$_heightCm',
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        onChanged: (v) {
          final parsed = int.tryParse(v);
          if (parsed == null) {
            _heightCm = null;
          } else if (parsed >= 120 && parsed <= 230) {
            _heightCm = parsed;
          }
        },
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: '175',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.32)),
          filled: true,
          fillColor: AppColors.bgMain,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }
}
