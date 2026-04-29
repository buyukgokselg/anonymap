import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/mode_config.dart';
import '../localization/app_localizations.dart';
import '../services/location_service.dart';
import '../services/pulse_api_service.dart';
import '../theme/colors.dart';
import 'profile_screen.dart';

/// Dating swipe-stack (Tinder tarzı).
///
/// Kullanıcı kartları mevcut mod eşleşmesine ve kimya skoruna göre sıralanır.
class DiscoverPeopleScreen extends StatefulWidget {
  const DiscoverPeopleScreen({super.key});

  @override
  State<DiscoverPeopleScreen> createState() => _DiscoverPeopleScreenState();
}

class _DiscoverPeopleScreenState extends State<DiscoverPeopleScreen>
    with SingleTickerProviderStateMixin {
  final List<_PersonCard> _queue = [];
  final _api = PulseApiService.instance;
  final _location = LocationService();
  late final AnimationController _flingController;
  Offset _dragOffset = Offset.zero;
  _SwipeDir? _lockedDir;
  bool _loading = true;
  String? _errorMessage;
  int _skip = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  double? _lat;
  double? _lng;

  // Filter state — defaults mean "no user-specified filter".
  double _filterRadiusKm = 25;
  int _filterMinAge = 18;
  int _filterMaxAge = 55;
  String? _filterMode; // null = any
  bool _filterVerifiedOnly = false;

  // Rewind state. Captures the last swiped card and its direction so the
  // user can undo a recent pass (sparks cannot be safely rewound).
  _PersonCard? _lastSwipedCard;
  _SwipeDir? _lastSwipedDir;

  @override
  void initState() {
    super.initState();
    _flingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _bootstrap();
  }

  @override
  void dispose() {
    _flingController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final position = await _location.getCurrentPosition();
    _lat = position?.latitude;
    _lng = position?.longitude;
    await _loadPage(reset: true);
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _errorMessage = null;
        _skip = 0;
        _hasMore = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final result = await _api.getDiscoverPeople(
        latitude: _lat,
        longitude: _lng,
        radiusKm: _filterRadiusKm,
        take: 10,
        skip: _skip,
        mode: _filterMode,
        minAge: _filterMinAge,
        maxAge: _filterMaxAge,
        verifiedOnly: _filterVerifiedOnly ? true : null,
      );
      final items = (result['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => _PersonCard.fromMap(Map<String, dynamic>.from(item)))
          .toList();
      if (!mounted) return;
      setState(() {
        if (reset) _queue.clear();
        _queue.addAll(items);
        _skip += items.length;
        _hasMore = (result['cursor'] as String? ?? '').isNotEmpty;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _commitSwipe(_SwipeDir dir) {
    HapticFeedback.lightImpact();
    // Capture the top card before the animation completes so the spark
    // call below is not affected by _queue.removeAt(0).
    final target = _queue.isNotEmpty ? _queue.first : null;
    setState(() {
      _lockedDir = dir;
    });
    _flingController.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        if (_queue.isNotEmpty) _queue.removeAt(0);
        _dragOffset = Offset.zero;
        _lockedDir = null;
        _lastSwipedCard = target;
        _lastSwipedDir = dir;
      });
      _flingController.reset();
      if (target != null && target.id.isNotEmpty) {
        if (dir == _SwipeDir.left) {
          unawaited(_passPerson(target));
        } else {
          unawaited(_sparkPerson(target));
        }
      }
      // Prefetch next page when running low.
      if (_queue.length <= 3 && _hasMore && !_loadingMore) {
        _loadPage();
      }
    });
  }

  Future<void> _rewindLastSwipe() async {
    final card = _lastSwipedCard;
    final dir = _lastSwipedDir;
    if (card == null || dir == null) return;

    final l10n = AppLocalizations.of(context);

    if (dir != _SwipeDir.left) {
      // Spark undo is intentionally unsupported — the other side may have
      // already seen/accepted the like.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.phrase('Sadece geç kararı geri alınabilir.')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _queue.insert(0, card);
      _lastSwipedCard = null;
      _lastSwipedDir = null;
    });
    final removed = await _api.undoDiscoverPass(card.id);
    if (!mounted) return;
    if (!removed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.phrase('Geri alma başarısız oldu.')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sparkPerson(_PersonCard card) async {
    try {
      final response = await _api.createMatch(
        otherUserId: card.id,
        compatibility: card.chemistryScore,
      );
      if (!mounted || response == null) return;
      final status = (response['status'] ?? '').toString();
      if (status == 'accepted') {
        _showMutualMatchDialog(card);
      }
    } catch (error, stack) {
      debugPrint('Spark error: $error\n$stack');
      if (!mounted) return;
      // User's affirmative action failed — surface it so they can retry.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr3(
              tr: 'Beğeni gönderilemedi. Bağlantını kontrol et.',
              en: "Couldn't send your spark. Check your connection.",
              de: 'Spark konnte nicht gesendet werden. Verbindung prüfen.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _passPerson(_PersonCard card) async {
    try {
      await _api.recordDiscoverPass(card.id);
    } catch (error, stack) {
      // Pass failure is acceptable to swallow — user already moved on
      // to the next card. We log for diagnostics only.
      debugPrint('Pass error: $error\n$stack');
    }
  }

  void _showMutualMatchDialog(_PersonCard card) {
    final l10n = AppLocalizations.of(context);
    final modeColor = ModeConfig.byId(card.modeId).color;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: modeColor.withValues(alpha: 0.55),
              width: 1.4,
            ),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_rounded, color: modeColor, size: 48),
              const SizedBox(height: 8),
              Text(
                l10n.phrase('Eşleştiniz!'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          content: Text(
            '${card.displayName} • ${l10n.phrase('İlk mesajı sen at')}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                l10n.phrase('Keşfe devam'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: modeColor),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.phrase('Devam')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(l10n),
            Expanded(child: _buildBody(l10n, context)),
            _buildActionRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.modeFlirt),
      );
    }
    if (_errorMessage != null && _queue.isEmpty) {
      return _buildError(l10n);
    }
    if (_queue.isEmpty) {
      return _buildEmpty(l10n);
    }
    return _buildStack(context);
  }

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text(
              l10n.phrase('Eşleşmeler yüklenemedi'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => _loadPage(reset: true),
              child: Text(l10n.phrase('Tekrar dene')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _glassButton(Icons.arrow_back_rounded, () => Navigator.pop(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.phrase('Keşfet'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  l10n.phrase('Sana uygun insanlar'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _glassButton(Icons.tune_rounded, _openFilterSheet),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final l10n = AppLocalizations.of(context);
    final changed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        double radius = _filterRadiusKm;
        RangeValues ageRange = RangeValues(
          _filterMinAge.toDouble(),
          _filterMaxAge.toDouble(),
        );
        String? mode = _filterMode;
        bool verifiedOnly = _filterVerifiedOnly;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      l10n.phrase('Keşif filtreleri'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.phrase(
                          'Sana gösterilen kartları kişiselleştir.'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _filterLabel(
                      '${l10n.phrase('Mesafe')}: ${radius.round()} km',
                    ),
                    Slider(
                      min: 1,
                      max: 200,
                      divisions: 199,
                      value: radius,
                      activeColor: AppColors.modeFlirt,
                      label: '${radius.round()} km',
                      onChanged: (v) => setSheetState(() => radius = v),
                    ),
                    const SizedBox(height: 8),
                    _filterLabel(
                      '${l10n.phrase('Yaş')}: ${ageRange.start.round()} – ${ageRange.end.round()}',
                    ),
                    RangeSlider(
                      min: 18,
                      max: 80,
                      divisions: 62,
                      values: ageRange,
                      activeColor: AppColors.modeFlirt,
                      labels: RangeLabels(
                        '${ageRange.start.round()}',
                        '${ageRange.end.round()}',
                      ),
                      onChanged: (v) => setSheetState(() => ageRange = v),
                    ),
                    const SizedBox(height: 8),
                    _filterLabel(l10n.phrase('Mod')),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _modeChip(
                          label: l10n.phrase('Tümü'),
                          selected: mode == null,
                          color: AppColors.textSecondary,
                          onTap: () => setSheetState(() => mode = null),
                        ),
                        for (final m in ModeConfig.all)
                          _modeChip(
                            label: l10n.modeLabel(m.id),
                            selected: mode == m.id,
                            color: m.color,
                            onTap: () => setSheetState(() => mode = m.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      value: verifiedOnly,
                      onChanged: (v) =>
                          setSheetState(() => verifiedOnly = v),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.modeFlirt,
                      title: Text(
                        l10n.phrase('Sadece doğrulanmış profiller'),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        l10n.phrase(
                            'Fotoğrafı doğrulanmış kişileri göster.'),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                radius = 25;
                                ageRange = const RangeValues(18, 55);
                                mode = null;
                                verifiedOnly = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              side: BorderSide(
                                  color: Colors.white
                                      .withValues(alpha: 0.14)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              l10n.phrase('Sıfırla'),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              _filterRadiusKm = radius;
                              _filterMinAge = ageRange.start.round();
                              _filterMaxAge = ageRange.end.round();
                              _filterMode = mode;
                              _filterVerifiedOnly = verifiedOnly;
                              Navigator.of(sheetContext).pop(true);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.modeFlirt,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              l10n.phrase('Uygula'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (changed == true && mounted) {
      await _loadPage(reset: true);
    }
  }

  Widget _filterLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _modeChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : AppColors.bgMain,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.textPrimary
                : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _glassButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Icon(icon, color: AppColors.textPrimary, size: 18),
        ),
      ),
    );
  }

  Widget _buildStack(BuildContext context) {
    final visible = _queue.take(3).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = visible.length - 1; i >= 0; i--)
                _buildCard(visible[i], i, size),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(_PersonCard person, int stackIndex, Size size) {
    final isTop = stackIndex == 0;
    final scale = 1 - (stackIndex * 0.04);
    final offsetY = stackIndex * 14.0;

    Widget card = _PersonCardTile(person: person, overlay: _overlayForTop());

    if (!isTop) {
      return Positioned.fill(
        child: Transform.translate(
          offset: Offset(0, offsetY),
          child: Transform.scale(scale: scale, child: card),
        ),
      );
    }

    final angle = (_dragOffset.dx / size.width) * 0.18;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => _openPersonProfile(person),
        onLongPress: () => _openSafetySheet(person),
        onPanUpdate: (details) {
          setState(() => _dragOffset += details.delta);
        },
        onPanEnd: (details) {
          final threshold = size.width * 0.25;
          if (_dragOffset.dx > threshold) {
            _commitSwipe(_SwipeDir.right);
          } else if (_dragOffset.dx < -threshold) {
            _commitSwipe(_SwipeDir.left);
          } else if (_dragOffset.dy < -threshold) {
            _commitSwipe(_SwipeDir.up);
          } else {
            setState(() => _dragOffset = Offset.zero);
          }
        },
        child: Transform.translate(
          offset: _dragOffset,
          child: Transform.rotate(angle: angle, child: card),
        ),
      ),
    );
  }

  void _openPersonProfile(_PersonCard person) {
    if (person.id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          userId: person.id,
          compatibilityScore: person.chemistryScore,
        ),
      ),
    );
  }

  Future<void> _openSafetySheet(_PersonCard person) async {
    if (person.id.isEmpty) return;
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: AppColors.error),
              title: Text(
                l10n.phrase('Şikayet et'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                l10n.phrase('Uygunsuz içerik veya davranış bildir.'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _reportPerson(person);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: AppColors.error),
              title: Text(
                l10n.phrase('Engelle'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                l10n.phrase(
                    'Bu kişi bir daha karşına çıkmaz ve seninle iletişim kuramaz.'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _blockPerson(person);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded,
                  color: AppColors.textSecondary),
              title: Text(
                l10n.phrase('Vazgeç'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              onTap: () => Navigator.pop(sheetContext),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _blockPerson(_PersonCard person) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(
          l10n.phrase('Kullanıcıyı engelle?'),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '${person.displayName} ${l10n.phrase('engellensin mi? Bu işlem geri alınabilir.')}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.phrase('Vazgeç')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.phrase('Engelle'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final ok = await _api.blockUser(person.id);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _queue.removeWhere((item) => item.id == person.id);
          if (_lastSwipedCard?.id == person.id) {
            _lastSwipedCard = null;
            _lastSwipedDir = null;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.phrase('Kullanıcı engellendi.')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.phrase('Engelleme başarısız oldu.')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error, stack) {
      debugPrint('Block error: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.phrase('Engelleme başarısız oldu.')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _reportPerson(_PersonCard person) async {
    final l10n = AppLocalizations.of(context);
    final reasons = <_ReportReason>[
      _ReportReason('spam', l10n.phrase('Spam veya sahte profil')),
      _ReportReason('inappropriate', l10n.phrase('Uygunsuz içerik')),
      _ReportReason('harassment', l10n.phrase('Taciz veya tehdit')),
      _ReportReason('underage', l10n.phrase('Reşit olmayabilir')),
      _ReportReason('other', l10n.phrase('Diğer')),
    ];

    final picked = await showModalBottomSheet<_ReportReason>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.phrase('Şikayet sebebini seç'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            for (final reason in reasons)
              ListTile(
                title: Text(
                  reason.label,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
                onTap: () => Navigator.pop(sheetContext, reason),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;

    try {
      final ok = await _api.reportUser(
        targetUserId: person.id,
        reason: picked.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? l10n.phrase('Şikayetin alındı. Teşekkürler.')
                : l10n.phrase('Şikayet gönderilemedi.'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error, stack) {
      debugPrint('Report error: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.phrase('Şikayet gönderilemedi.')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget? _overlayForTop() {
    if (_lockedDir != null) {
      return _decisionTag(_lockedDir!, 1);
    }
    if (_dragOffset.dx.abs() < 20 && _dragOffset.dy.abs() < 20) return null;
    if (_dragOffset.dy < -60 && _dragOffset.dy.abs() > _dragOffset.dx.abs()) {
      return _decisionTag(_SwipeDir.up, (_dragOffset.dy.abs() / 160).clamp(0, 1).toDouble());
    }
    if (_dragOffset.dx > 20) {
      return _decisionTag(_SwipeDir.right, (_dragOffset.dx / 160).clamp(0, 1).toDouble());
    }
    if (_dragOffset.dx < -20) {
      return _decisionTag(_SwipeDir.left, (_dragOffset.dx.abs() / 160).clamp(0, 1).toDouble());
    }
    return null;
  }

  Widget _decisionTag(_SwipeDir dir, double opacity) {
    final (label, color, align) = switch (dir) {
      _SwipeDir.right => ('GÖRÜŞMEK İSTERİM', AppColors.success, Alignment.topLeft),
      _SwipeDir.left => ('GEÇ', AppColors.error, Alignment.topRight),
      _SwipeDir.up => ('SÜPER EŞLEŞME', AppColors.modeFlirt, Alignment.topCenter),
    };

    return IgnorePointer(
      child: Align(
        alignment: align,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Transform.rotate(
            angle: dir == _SwipeDir.right
                ? -0.18
                : dir == _SwipeDir.left
                    ? 0.18
                    : 0,
            child: Opacity(
              opacity: opacity,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color, width: 3),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    final canRewind =
        _lastSwipedCard != null && _lastSwipedDir == _SwipeDir.left;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionButton(
            Icons.undo_rounded,
            canRewind ? AppColors.primary : AppColors.textSecondary,
            46,
            canRewind ? _rewindLastSwipe : () {},
            dimmed: !canRewind,
          ),
          _actionButton(Icons.close_rounded, AppColors.error, 54, () {
            if (_queue.isNotEmpty) _commitSwipe(_SwipeDir.left);
          }),
          _actionButton(Icons.favorite_rounded, AppColors.modeFlirt, 68, () {
            if (_queue.isNotEmpty) _commitSwipe(_SwipeDir.up);
          }),
          _actionButton(Icons.check_rounded, AppColors.success, 54, () {
            if (_queue.isNotEmpty) _commitSwipe(_SwipeDir.right);
          }),
        ],
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    Color color,
    double size,
    VoidCallback onTap, {
    bool dimmed = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Opacity(
          opacity: dimmed ? 0.45 : 1.0,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: dimmed ? 0.2 : 0.4),
                width: 2,
              ),
              boxShadow: dimmed
                  ? const []
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
            ),
            child: Icon(icon, color: color, size: size * 0.42),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    // Detect whether the empty state is "natural" (no filters) or filter-induced.
    // We treat any non-default filter as restrictive enough to suggest a reset.
    final hasActiveFilter = _filterRadiusKm != 25 ||
        _filterMinAge != 18 ||
        _filterMaxAge != 55 ||
        _filterMode != null ||
        _filterVerifiedOnly;

    final title = hasActiveFilter
        ? l10n.phrase('Filtreyle eşleşen kimse yok')
        : l10n.phrase('Yeni eşleşmeler geliyor');
    final subtitle = hasActiveFilter
        ? l10n.phrase(
            'Filtrelerini gevşetmeyi dene veya biraz sonra tekrar uğra.',
          )
        : l10n.phrase(
            'Az sonra tekrar uğra — bölgendeki kişileri güncel tutuyoruz.',
          );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_outline_rounded,
              color: AppColors.modeFlirt.withValues(alpha: 0.7),
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (hasActiveFilter)
              FilledButton.tonal(
                onPressed: () async {
                  setState(() {
                    _filterRadiusKm = 25;
                    _filterMinAge = 18;
                    _filterMaxAge = 55;
                    _filterMode = null;
                    _filterVerifiedOnly = false;
                  });
                  await _loadPage(reset: true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor:
                      AppColors.modeFlirt.withValues(alpha: 0.18),
                  foregroundColor: AppColors.modeFlirt,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                child: Text(l10n.phrase('Filtreleri sıfırla')),
              )
            else
              FilledButton.tonal(
                onPressed: () => _loadPage(reset: true),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      AppColors.modeFlirt.withValues(alpha: 0.18),
                  foregroundColor: AppColors.modeFlirt,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                child: Text(l10n.phrase('Yenile')),
              ),
          ],
        ),
      ),
    );
  }
}

class _PersonCardTile extends StatelessWidget {
  const _PersonCardTile({required this.person, this.overlay});

  final _PersonCard person;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final mode = ModeConfig.byId(person.modeId);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: AppColors.bgCard,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  mode.color.withValues(alpha: 0.35),
                  AppColors.bgCard,
                  mode.color.withValues(alpha: 0.12),
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: _ModeBadge(mode: mode),
          ),
          if (person.hostingActivityCount > 0)
            Positioned(
              top: 52,
              left: 16,
              child: _HostingBadge(count: person.hostingActivityCount),
            ),
          Positioned(
            top: 16,
            right: 16,
            child: _ChemistryBadge(score: person.chemistryScore),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        person.displayName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${person.age}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place_rounded,
                          color: AppColors.textSecondary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${person.distanceKm.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('·',
                          style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.6))),
                      const SizedBox(width: 10),
                      Text(
                        mode.tagline,
                        style: TextStyle(
                          color: mode.color,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    person.bio,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary.withValues(alpha: 0.85),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ?overlay,
        ],
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode});

  final ModeConfig mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: mode.color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mode.color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mode.icon, color: mode.color, size: 12),
          const SizedBox(width: 5),
          Text(
            mode.label.toUpperCase(),
            style: TextStyle(
              color: mode.color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChemistryBadge extends StatelessWidget {
  const _ChemistryBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? AppColors.modeFlirt
        : score >= 60
            ? AppColors.neonCyan
            : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            '%$score',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HostingBadge extends StatelessWidget {
  const _HostingBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 etkinlik' : '$count etkinlik';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryGlow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGlow.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_rounded,
            color: AppColors.primaryGlow,
            size: 11,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryGlow,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

enum _SwipeDir { left, right, up }

class _ReportReason {
  const _ReportReason(this.id, this.label);
  final String id;
  final String label;
}

class _PersonCard {
  _PersonCard({
    required this.id,
    required this.displayName,
    required this.age,
    required this.bio,
    required this.distanceKm,
    required this.modeId,
    required this.chemistryScore,
    required this.hostingActivityCount,
  });

  factory _PersonCard.fromMap(Map<String, dynamic> data) {
    final rawDistance = data['distanceKm'];
    final distance = rawDistance is num ? rawDistance.toDouble() : 0.0;
    final rawAge = data['age'];
    final age = rawAge is num ? rawAge.toInt() : 0;
    final rawScore = data['chemistryScore'];
    final score = rawScore is num ? rawScore.toInt() : 0;
    final rawHosting = data['hostingActivityCount'];
    final hosting = rawHosting is num ? rawHosting.toInt() : 0;
    return _PersonCard(
      id: (data['id'] ?? '').toString(),
      displayName: (data['displayName'] ?? '').toString(),
      age: age,
      bio: (data['bio'] ?? '').toString(),
      distanceKm: distance,
      modeId: ModeConfig.normalizeId((data['mode'] ?? '').toString()),
      chemistryScore: score,
      hostingActivityCount: hosting,
    );
  }

  final String id;
  final String displayName;
  final int age;
  final String bio;
  final double distanceKm;
  final String modeId;
  final int chemistryScore;
  final int hostingActivityCount;
}
