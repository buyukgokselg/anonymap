import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/activity_model.dart';
import '../services/activity_service.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import '../theme/colors.dart';
import '../widgets/activity/activity_category_chip.dart';
import '../widgets/activity/activity_category_meta.dart';
import '../widgets/activity/activity_vibe_banner.dart';
import '../widgets/animated_press.dart';
import '../widgets/app_snackbar.dart';

/// Four-step host wizard for creating an Activity:
///   1) Category
///   2) Vibe (title, description, mode, interests)
///   3) Yer & Zaman (location, city, start, end, capacity)
///   4) Katılım kuralları (visibility, join policy, verification, age, gender)
///
/// Submits via [ActivityService.create] and pops the new ActivityModel.
class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({super.key, this.initialCategory});

  final ActivityCategory? initialCategory;

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final PageController _pageController = PageController();

  // Step 1
  ActivityCategory _category = ActivityCategory.sosyal;

  // Step 2
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _mode = 'chill';
  final TextEditingController _interestsController = TextEditingController();
  final List<String> _interests = [];

  // Step 3
  final TextEditingController _locationNameController = TextEditingController();
  final TextEditingController _locationAddressController =
      TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final FocusNode _placeFocus = FocusNode();
  double? _latitude;
  double? _longitude;
  String? _selectedPlaceId;
  String? _selectedPlaceName;
  List<Map<String, dynamic>> _placeCache = [];
  List<Map<String, dynamic>> _placeSuggestions = [];
  bool _loadingPlaces = false;
  bool _showAdvancedFields = false;
  Timer? _placeSearchDebounce;
  final PlacesService _placesService = PlacesService();
  DateTime _startsAt = DateTime.now().add(const Duration(hours: 3));
  DateTime? _endsAt;
  int _maxParticipants = 8;
  bool _hasCapacity = true;

  // Step 4
  ActivityVisibility _visibility = ActivityVisibility.public;
  ActivityJoinPolicy _joinPolicy = ActivityJoinPolicy.open;
  bool _requiresVerification = false;
  RangeValues? _ageRange;
  String _preferredGender = 'any';
  String _recurrenceRule = '';
  DateTime? _recurrenceUntil;

  int _currentStep = 0;
  bool _submitting = false;

  static const _modeOptions = [
    ('chill', 'Chill', AppColors.modeChill),
    ('flirt', 'Flirt', AppColors.modeFlirt),
    ('friends', 'Friends', AppColors.modeFriends),
    ('fun', 'Fun', AppColors.modeFun),
  ];

  static const _genderOptions = [
    ('any', 'Herkes'),
    ('female', 'Kadın'),
    ('male', 'Erkek'),
    ('nonbinary', 'Non-binary'),
  ];

  static const _recurrenceOptions = [
    ('', 'Tek seferlik', Icons.event_rounded),
    ('weekly', 'Haftalık', Icons.replay_rounded),
    ('biweekly', 'İki haftada bir', Icons.swap_calls_rounded),
    ('monthly', 'Aylık', Icons.calendar_month_rounded),
  ];

  static const int _stepCount = 4;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _category = widget.initialCategory!;
      _applyCategoryDefaults(widget.initialCategory!);
    }
    // Rebuild when the place input gains/loses focus so the suggestion panel
    // mounts/unmounts correctly without us having to track focus in extra
    // state. Cheap — only fires on focus transitions.
    _placeFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _onCategorySelected(ActivityCategory next) {
    if (next == _category) return;
    setState(() {
      _category = next;
      _applyCategoryDefaults(next);
    });
  }

  /// Cesaret category nudges hosts toward safer defaults: approval-required
  /// join policy, verified-only participants, and a stricter cap. We only
  /// flip the toggles when the host hasn't manually moved them yet — once
  /// they pass step 1 the values stay sticky.
  void _applyCategoryDefaults(ActivityCategory category) {
    if (category == ActivityCategory.cesaret) {
      _joinPolicy = ActivityJoinPolicy.approvalRequired;
      _requiresVerification = true;
      if (_maxParticipants > 12) {
        _maxParticipants = 8;
      }
    } else if (category == ActivityCategory.anlik) {
      // Anlık etkinlikler hızlı doldurulmalı — onay almayı kaldıralım.
      _joinPolicy = ActivityJoinPolicy.open;
      // Suggest a near-future start so hosts don't accidentally schedule
      // an "Anlık" activity for next week.
      final inTwoHours = DateTime.now().add(const Duration(hours: 2));
      if (_startsAt.isAfter(
        DateTime.now().add(const Duration(hours: 6)),
      )) {
        _startsAt = inTwoHours;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _interestsController.dispose();
    _locationNameController.dispose();
    _locationAddressController.dispose();
    _cityController.dispose();
    _placeFocus.dispose();
    _placeSearchDebounce?.cancel();
    super.dispose();
  }

  void _next() {
    final error = _validateCurrentStep();
    if (error != null) {
      AppSnackbar.showError(context, error);
      return;
    }
    if (_currentStep == _stepCount - 1) {
      unawaited(_submit());
      return;
    }
    setState(() => _currentStep += 1);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    // When the user lands on Step 3 (place & time), eagerly warm the place
    // suggestion cache so the autocomplete feels instant on first tap.
    if (_currentStep == 2 && _placeCache.isEmpty) {
      unawaited(_loadNearbyPlaceSuggestions());
    }
  }

  void _prev() {
    if (_currentStep == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _currentStep -= 1);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  String? _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return null;
      case 1:
        if (_titleController.text.trim().isEmpty) {
          return 'Başlık ekle.';
        }
        if (_titleController.text.trim().length < 4) {
          return 'Başlık biraz daha açıklayıcı olsun.';
        }
        return null;
      case 2:
        if (_locationNameController.text.trim().isEmpty) {
          return 'Buluşma yeri seç.';
        }
        if (_cityController.text.trim().isEmpty) {
          return 'Şehir gerekli.';
        }
        if (_latitude == null || _longitude == null) {
          return 'Koordinat al — konum izni gerekiyor.';
        }
        if (_startsAt.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
          return 'Başlangıç ileri bir zaman olmalı.';
        }
        if (_endsAt != null && !_endsAt!.isAfter(_startsAt)) {
          return 'Bitiş zamanı, başlangıçtan sonra olmalı.';
        }
        return null;
      case 3:
        if (_ageRange != null && _ageRange!.start >= _ageRange!.end) {
          return 'Yaş aralığını gözden geçir.';
        }
        return null;
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final payload = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': activityCategoryWireValue(_category),
        'mode': _mode,
        'locationName': _locationNameController.text.trim(),
        if (_locationAddressController.text.trim().isNotEmpty)
          'locationAddress': _locationAddressController.text.trim(),
        if (_selectedPlaceId != null && _selectedPlaceId!.isNotEmpty)
          'placeId': _selectedPlaceId,
        'latitude': _latitude,
        'longitude': _longitude,
        'city': _cityController.text.trim(),
        'startsAt': _startsAt.toUtc().toIso8601String(),
        if (_endsAt != null) 'endsAt': _endsAt!.toUtc().toIso8601String(),
        'reminderMinutesBefore': 60,
        if (_hasCapacity) 'maxParticipants': _maxParticipants,
        'visibility': activityVisibilityWireValue(_visibility),
        'joinPolicy': activityJoinPolicyWireValue(_joinPolicy),
        'requiresVerification': _requiresVerification,
        'interests': _interests,
        if (_ageRange != null) 'minAge': _ageRange!.start.round(),
        if (_ageRange != null) 'maxAge': _ageRange!.end.round(),
        'preferredGender': _preferredGender,
        'recurrenceRule': _recurrenceRule,
        if (_recurrenceUntil != null)
          'recurrenceUntil': _recurrenceUntil!.toUtc().toIso8601String(),
      };

      final activity = await ActivityService.instance.create(payload);
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Etkinlik yayınlandı 🎉');
      Navigator.of(context).pop(activity);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            _buildStepIndicator(),
            const SizedBox(height: 12),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildCategoryStep(),
                  _buildVibeStep(),
                  _buildPlaceTimeStep(),
                  _buildRulesStep(),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: _prev,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          const Text(
            'Yeni Etkinlik',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          Text(
            '${_currentStep + 1} / $_stepCount',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < _stepCount; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= _currentStep
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            if (i != _stepCount - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final lastStep = _currentStep == _stepCount - 1;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: AnimatedPress(
          onTap: _submitting ? null : _next,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryGlow],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 20,
                  spreadRadius: -3,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    lastStep ? 'Yayınla 🎉' : 'Devam',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Step 1: Category ────────────────────────────────────────────────
  Widget _buildCategoryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Hangi tür buluşma?', 'Kategori, etkinliğin tonunu belirler.'),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final cat in _orderedCategories())
                ActivityCategoryChip(
                  category: cat,
                  variant: ActivityCategoryChipVariant.filter,
                  selected: cat == _category,
                  onTap: () => _onCategorySelected(cat),
                ),
            ],
          ),
          const SizedBox(height: 18),
          ActivityVibeBanner(category: _category),
          const SizedBox(height: 12),
          _categorySubtitleCard(),
        ],
      ),
    );
  }

  Widget _categorySubtitleCard() {
    final meta = ActivityCategoryMeta.of(_category);
    if (meta.subtitle.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(meta.icon, color: meta.color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              meta.subtitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<ActivityCategory> _orderedCategories() => const [
        ActivityCategory.cesaret,
        ActivityCategory.anlik,
        ActivityCategory.sosyal,
        ActivityCategory.yemek,
        ActivityCategory.spor,
        ActivityCategory.doga,
        ActivityCategory.sanat,
        ActivityCategory.egitim,
        ActivityCategory.gece,
        ActivityCategory.seyahat,
        ActivityCategory.other,
      ];

  // ── Step 2: Vibe ────────────────────────────────────────────────────
  Widget _buildVibeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle(
            'Anlat — neyi paylaşıyorsun?',
            'Açık, samimi bir ton herkesin kararını kolaylaştırır.',
          ),
          const SizedBox(height: 18),
          _label('Başlık'),
          const SizedBox(height: 6),
          _textField(
            _titleController,
            hint: 'Örn. "Karanlık Cuma — sessiz yürüyüş"',
            maxLength: 80,
          ),
          const SizedBox(height: 18),
          _label('Açıklama'),
          const SizedBox(height: 6),
          _textField(
            _descriptionController,
            hint: 'Ne hissettiğini, ne yapacağını anlat. Spesifik ol.',
            maxLines: 5,
            maxLength: 800,
          ),
          const SizedBox(height: 18),
          _label('Vibe'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in _modeOptions)
                _modeChip(mode.$1, mode.$2, mode.$3),
            ],
          ),
          const SizedBox(height: 18),
          _label('Etiketler (opsiyonel)'),
          const SizedBox(height: 6),
          _interestsField(),
          if (_interests.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final interest in _interests)
                  _removableChip(interest, () {
                    setState(() => _interests.remove(interest));
                  }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeChip(String id, String label, Color color) {
    final selected = _mode == id;
    return AnimatedPress(
      onTap: () => setState(() => _mode = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.22) : AppColors.bgChip,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _interestsField() {
    return TextField(
      controller: _interestsController,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: _inputDecoration(
        hint: 'Etiket yaz, Enter ile ekle (örn. müzik)',
        prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.textHint),
      ),
      textInputAction: TextInputAction.done,
      inputFormatters: [LengthLimitingTextInputFormatter(24)],
      onSubmitted: (value) {
        final v = value.trim();
        if (v.isEmpty) return;
        if (_interests.length >= 12) return;
        if (!_interests.any((e) => e.toLowerCase() == v.toLowerCase())) {
          setState(() => _interests.add(v));
        }
        _interestsController.clear();
      },
    );
  }

  Widget _removableChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: AppColors.bgChip,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$label',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Place & Time ────────────────────────────────────────────
  Widget _buildPlaceTimeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Yer ve zaman', 'Mekânı ara, seç — gerisi otomatik.'),
          const SizedBox(height: 18),
          _label('Mekân'),
          const SizedBox(height: 6),
          _placePicker(),
          const SizedBox(height: 10),
          _placePickerHelpers(),
          const SizedBox(height: 14),
          _advancedAddressBlock(),
          const SizedBox(height: 18),
          _label('Başlangıç'),
          const SizedBox(height: 6),
          _datetimeTile(
            value: _startsAt,
            onTap: () => _pickDateTime(_startsAt, (picked) {
              setState(() {
                _startsAt = picked;
                if (_endsAt != null && !_endsAt!.isAfter(picked)) {
                  _endsAt = picked.add(const Duration(hours: 2));
                }
              });
            }),
          ),
          const SizedBox(height: 14),
          _label('Bitiş (opsiyonel)'),
          const SizedBox(height: 6),
          _datetimeTile(
            value: _endsAt,
            placeholder: 'Açık uçlu',
            trailing: _endsAt == null
                ? null
                : IconButton(
                    onPressed: () => setState(() => _endsAt = null),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textHint,
                      size: 18,
                    ),
                  ),
            onTap: () => _pickDateTime(
              _endsAt ?? _startsAt.add(const Duration(hours: 2)),
              (picked) => setState(() => _endsAt = picked),
            ),
          ),
          const SizedBox(height: 18),
          _capacityRow(),
        ],
      ),
    );
  }

  /// Single search-driven place input. Tapping it opens a suggestion list
  /// powered by [PlacesService.getNearbyPlaces] anchored on the user's live
  /// (or last-captured) location. Selecting a suggestion auto-fills name,
  /// vicinity, city, lat/lng and place_id; typing freely is still allowed
  /// for users who want to host at a place that isn't on Google.
  Widget _placePicker() {
    final hasSelection = _selectedPlaceId != null;
    final hasCoords = _latitude != null && _longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasSelection
                  ? AppColors.success.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 6),
                child: Icon(
                  hasSelection
                      ? Icons.place_rounded
                      : Icons.search_rounded,
                  color: hasSelection ? AppColors.success : AppColors.textHint,
                  size: 18,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _locationNameController,
                  focusNode: _placeFocus,
                  onChanged: _onPlaceQueryChanged,
                  onTap: () {
                    if (_placeCache.isEmpty) {
                      unawaited(_loadNearbyPlaceSuggestions());
                    } else {
                      _applyPlaceQuery(_locationNameController.text);
                    }
                  },
                  maxLength: 120,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Park, kafe, sahil, sokak ara…',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_loadingPlaces)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: AppColors.textHint,
                    ),
                  ),
                )
              else if (hasSelection)
                IconButton(
                  onPressed: _clearSelectedPlace,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textHint,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
        if (_placeFocus.hasFocus && _placeSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _placeSuggestions.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.04),
              ),
              itemBuilder: (_, i) =>
                  _placeSuggestionTile(_placeSuggestions[i]),
            ),
          ),
        ],
        if (hasSelection || hasCoords) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.gps_fixed_rounded,
                size: 13,
                color: hasCoords
                    ? AppColors.success
                    : AppColors.textHint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasCoords
                      ? (_selectedPlaceName?.isNotEmpty == true
                          ? '${_selectedPlaceName!} · ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                          : 'Koordinat: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}')
                      : 'Koordinat henüz alınmadı',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _placeSuggestionTile(Map<String, dynamic> place) {
    final name = (place['name'] ?? '').toString();
    final vicinity = (place['vicinity'] ?? '').toString();
    return InkWell(
      onTap: () => _selectPlaceSuggestion(place),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.neonCyan.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.place_rounded,
                color: AppColors.neonCyan,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (vicinity.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        vicinity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.textHint,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  /// Quick-action row beneath the search field — "use my location" anchor +
  /// expand toggle for manual address/city edit.
  Widget _placePickerHelpers() {
    return Row(
      children: [
        Expanded(
          child: _placeQuickButton(
            icon: Icons.my_location_rounded,
            label: 'Konumumu kullan',
            onTap: _captureCurrentLocation,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _placeQuickButton(
            icon: _showAdvancedFields
                ? Icons.expand_less_rounded
                : Icons.tune_rounded,
            label: _showAdvancedFields ? 'Gizle' : 'Adres/şehir düzenle',
            onTap: () => setState(
              () => _showAdvancedFields = !_showAdvancedFields,
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeQuickButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppColors.neonCyan),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _advancedAddressBlock() {
    if (!_showAdvancedFields) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Adres (opsiyonel)'),
        const SizedBox(height: 6),
        _textField(
          _locationAddressController,
          hint: 'Sokak, no, mahalle',
          maxLength: 200,
        ),
        const SizedBox(height: 14),
        _label('Şehir'),
        const SizedBox(height: 6),
        _textField(
          _cityController,
          hint: 'Örn. İstanbul',
          maxLength: 60,
        ),
      ],
    );
  }

  Future<void> _captureCurrentLocation() async {
    final position = await LocationService().getCurrentPosition();
    if (!mounted) return;
    if (position == null) {
      AppSnackbar.showError(context, 'Konum izni ya da servisi reddedildi.');
      return;
    }
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      // Reset any place-id selection — user is now anchoring to live coords,
      // and the next search will repopulate suggestions from this point.
      _selectedPlaceId = null;
      _selectedPlaceName = null;
    });
    // Warm the suggestion cache from this anchor so the user sees nearby
    // places immediately when they tap the search field.
    unawaited(_loadNearbyPlaceSuggestions(force: true));
  }

  Future<void> _loadNearbyPlaceSuggestions({bool force = false}) async {
    if (_loadingPlaces) return;
    double? lat = _latitude;
    double? lng = _longitude;
    if (lat == null || lng == null) {
      final pos = await LocationService().getCurrentPosition();
      if (!mounted) return;
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
        // Don't auto-set _latitude/_longitude here — the user hasn't picked a
        // place yet. Coordinates are committed when a suggestion is tapped or
        // when the user explicitly hits "Konumumu kullan".
      }
    }
    if (lat == null || lng == null) return;

    if (!force && _placeCache.isNotEmpty) {
      _applyPlaceQuery(_locationNameController.text);
      return;
    }

    setState(() => _loadingPlaces = true);
    try {
      final results = await _placesService.getNearbyPlaces(
        lat: lat,
        lng: lng,
        modeId: _mode,
        radius: 3000,
        sortBy: 'popular',
      );
      if (!mounted) return;
      setState(() {
        _placeCache = results;
        _loadingPlaces = false;
      });
      _applyPlaceQuery(_locationNameController.text);
    } catch (e) {
      debugPrint('Place suggestion load failed: $e');
      if (mounted) setState(() => _loadingPlaces = false);
    }
  }

  void _onPlaceQueryChanged(String value) {
    // Typing invalidates any previous selection — user is editing.
    if (_selectedPlaceId != null) {
      setState(() {
        _selectedPlaceId = null;
        _selectedPlaceName = null;
      });
    }
    _placeSearchDebounce?.cancel();
    _placeSearchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      _applyPlaceQuery(value);
    });
  }

  void _applyPlaceQuery(String value) {
    final query = value.trim().toLowerCase();
    final base = _placeCache;
    if (base.isEmpty) {
      setState(() => _placeSuggestions = []);
      return;
    }
    if (query.isEmpty) {
      setState(() => _placeSuggestions = base.take(8).toList());
      return;
    }
    final filtered = base.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final vicinity = (p['vicinity'] ?? '').toString().toLowerCase();
      return name.contains(query) || vicinity.contains(query);
    }).take(8).toList();
    setState(() => _placeSuggestions = filtered);
  }

  void _selectPlaceSuggestion(Map<String, dynamic> place) {
    final name = (place['name'] ?? '').toString();
    final vicinity = (place['vicinity'] ?? '').toString();
    final lat = (place['lat'] as num?)?.toDouble();
    final lng = (place['lng'] as num?)?.toDouble();
    final placeId = (place['place_id'] ?? '').toString();
    setState(() {
      _selectedPlaceId = placeId.isNotEmpty ? placeId : null;
      _selectedPlaceName = name;
      _locationNameController.text = name;
      if (vicinity.isNotEmpty && _locationAddressController.text.trim().isEmpty) {
        _locationAddressController.text = vicinity;
      }
      if (_cityController.text.trim().isEmpty) {
        _cityController.text = _extractCityFromVicinity(vicinity);
      }
      if (lat != null && lng != null) {
        _latitude = lat;
        _longitude = lng;
      }
      _placeSuggestions = [];
    });
    _placeFocus.unfocus();
  }

  void _clearSelectedPlace() {
    setState(() {
      _selectedPlaceId = null;
      _selectedPlaceName = null;
      _locationNameController.clear();
      _placeSuggestions = _placeCache.take(8).toList();
    });
    _placeFocus.requestFocus();
  }

  /// Cheap city heuristic — Google Nearby returns vicinity like
  /// "Sokak Adı, Mahalle, İstanbul". We grab the last comma-segment when it
  /// looks like a city (has letters, no digits, ≤30 chars). Falls back to
  /// empty so the user can fill it manually.
  String _extractCityFromVicinity(String vicinity) {
    if (vicinity.isEmpty) return '';
    final parts = vicinity.split(',').map((s) => s.trim()).toList();
    if (parts.isEmpty) return '';
    final last = parts.last;
    if (last.length > 30) return '';
    if (RegExp(r'\d').hasMatch(last)) return '';
    return last;
  }

  Widget _datetimeTile({
    DateTime? value,
    String placeholder = '',
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final label = value == null
        ? placeholder
        : _formatDateTime(value);
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              color: AppColors.neonCyan,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label.isEmpty ? '—' : label,
                style: TextStyle(
                  color: value == null
                      ? AppColors.textSecondary
                      : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime(
    DateTime initial,
    void Function(DateTime) onPicked,
  ) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now.subtract(const Duration(hours: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: _datePickerTheme,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: _datePickerTheme,
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    onPicked(picked);
  }

  Widget _datePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.bgCard,
          onSurface: Colors.white,
        ),
        dialogTheme: const DialogThemeData(backgroundColor: AppColors.bgMain),
      ),
      child: child!,
    );
  }

  Widget _capacityRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _hasCapacity ? 'Kontenjan: $_maxParticipants kişi' : 'Sınırsız',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Switch.adaptive(
              value: _hasCapacity,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => setState(() => _hasCapacity = v),
            ),
          ],
        ),
        if (_hasCapacity)
          Slider(
            value: _maxParticipants.toDouble(),
            min: 2,
            max: 50,
            divisions: 48,
            activeColor: AppColors.primary,
            label: '$_maxParticipants',
            onChanged: (v) => setState(() => _maxParticipants = v.round()),
          ),
      ],
    );
  }

  // ── Step 4: Rules ───────────────────────────────────────────────────
  Widget _buildRulesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Kim katılabilir?', 'Sınırlar koymak güvenli alan kurar.'),
          if (_category == ActivityCategory.cesaret) ...[
            const SizedBox(height: 14),
            _cesaretSafetyHint(),
          ],
          const SizedBox(height: 18),
          _label('Görünürlük'),
          const SizedBox(height: 8),
          _visibilityOptions(),
          const SizedBox(height: 18),
          _label('Katılım'),
          const SizedBox(height: 8),
          _joinPolicyOptions(),
          const SizedBox(height: 18),
          _toggleTile(
            icon: Icons.verified_user_rounded,
            label: 'Doğrulanmış profil zorunlu',
            subtitle: 'Sadece foto-doğrulamalı kullanıcılar katılabilir.',
            value: _requiresVerification,
            onChanged: (v) => setState(() => _requiresVerification = v),
          ),
          const SizedBox(height: 18),
          _label('Yaş aralığı (opsiyonel)'),
          const SizedBox(height: 8),
          _ageRangeRow(),
          const SizedBox(height: 18),
          _label('Tercih edilen cinsiyet'),
          const SizedBox(height: 8),
          _genderOptionsRow(),
          const SizedBox(height: 18),
          _label('Tekrar'),
          const SizedBox(height: 8),
          _recurrenceOptionsRow(),
          if (_recurrenceRule.isNotEmpty) ...[
            const SizedBox(height: 12),
            _recurrenceUntilTile(),
          ],
        ],
      ),
    );
  }

  Widget _recurrenceOptionsRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in _recurrenceOptions)
          AnimatedPress(
            onTap: () => setState(() {
              _recurrenceRule = entry.$1;
              if (_recurrenceRule.isEmpty) _recurrenceUntil = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _recurrenceRule == entry.$1
                    ? AppColors.neonCyan.withValues(alpha: 0.18)
                    : AppColors.bgChip,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _recurrenceRule == entry.$1
                      ? AppColors.neonCyan.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    entry.$3,
                    size: 14,
                    color: _recurrenceRule == entry.$1
                        ? AppColors.neonCyan
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    entry.$2,
                    style: TextStyle(
                      color: _recurrenceRule == entry.$1
                          ? AppColors.neonCyan
                          : Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _recurrenceUntilTile() {
    final label = _recurrenceUntil == null
        ? 'Bitiş tarihi yok — süresiz'
        : 'Bitiş: ${_formatDate(_recurrenceUntil!)}';
    return AnimatedPress(
      onTap: () async {
        final initial = _recurrenceUntil ??
            _startsAt.add(const Duration(days: 90));
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: _startsAt,
          lastDate: _startsAt.add(const Duration(days: 365 * 2)),
          builder: _datePickerTheme,
        );
        if (picked != null && mounted) {
          setState(() => _recurrenceUntil = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_available_rounded,
              color: AppColors.neonCyan,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_recurrenceUntil != null)
              GestureDetector(
                onTap: () => setState(() => _recurrenceUntil = null),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.textHint,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  Widget _visibilityOptions() {
    const items = [
      (ActivityVisibility.public, Icons.public_rounded, 'Herkese açık'),
      (
        ActivityVisibility.friends,
        Icons.handshake_rounded,
        'Sadece arkadaşlar',
      ),
      (
        ActivityVisibility.mutualMatches,
        Icons.favorite_rounded,
        'Sadece eşleşmelerim',
      ),
      (
        ActivityVisibility.inviteOnly,
        Icons.lock_rounded,
        'Sadece davetliler',
      ),
    ];
    return Column(
      children: [
        for (final entry in items)
          _radioTile(
            icon: entry.$2,
            label: entry.$3,
            selected: _visibility == entry.$1,
            onTap: () => setState(() => _visibility = entry.$1),
          ),
      ],
    );
  }

  Widget _joinPolicyOptions() {
    const items = [
      (ActivityJoinPolicy.open, Icons.lock_open_rounded, 'Açık katılım — herkes anında girebilir'),
      (ActivityJoinPolicy.approvalRequired, Icons.how_to_reg_rounded, 'Onay gerekli — istek gönderir, sen seçersin'),
    ];
    return Column(
      children: [
        for (final entry in items)
          _radioTile(
            icon: entry.$2,
            label: entry.$3,
            selected: _joinPolicy == entry.$1,
            onTap: () => setState(() => _joinPolicy = entry.$1),
          ),
      ],
    );
  }

  Widget _cesaretSafetyHint() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryGlow.withValues(alpha: 0.18),
            AppColors.primaryGlow.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryGlow.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_moon_rounded,
            color: AppColors.primaryGlow,
            size: 18,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cesaret için önerilen ayarlar açık',
                  style: TextStyle(
                    color: AppColors.primaryGlow,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Onaylı katılım + doğrulanmış profil — kendini güvende tutman için. İstersen değiştirebilirsin.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ageRangeRow() {
    final range = _ageRange ?? const RangeValues(18, 99);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _ageRange == null
                      ? 'Sınır yok'
                      : '${range.start.round()} – ${range.end.round()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _ageRange != null,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() {
                  _ageRange = v ? const RangeValues(18, 35) : null;
                }),
              ),
            ],
          ),
          if (_ageRange != null)
            RangeSlider(
              values: range,
              min: 18,
              max: 80,
              divisions: 62,
              activeColor: AppColors.primary,
              labels: RangeLabels(
                '${range.start.round()}',
                '${range.end.round()}',
              ),
              onChanged: (values) => setState(() => _ageRange = values),
            ),
        ],
      ),
    );
  }

  Widget _genderOptionsRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in _genderOptions)
          AnimatedPress(
            onTap: () => setState(() => _preferredGender = entry.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _preferredGender == entry.$1
                    ? AppColors.primary.withValues(alpha: 0.22)
                    : AppColors.bgChip,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _preferredGender == entry.$1
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Text(
                entry.$2,
                style: TextStyle(
                  color: _preferredGender == entry.$1
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _radioTile({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedPress(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.14)
                : AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: selected ? 1.0 : 0.85,
                    ),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.success, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ── Generic helpers ─────────────────────────────────────────────────
  Widget _stepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      );

  Widget _textField(
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: _inputDecoration(hint: hint),
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.32)),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: AppColors.bgCard,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    const wd = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final day = '${wd[local.weekday - 1]} ${local.day}.${local.month.toString().padLeft(2, '0')}.${local.year}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}.${local.minute.toString().padLeft(2, '0')}';
    return '$day · $time';
  }
}
