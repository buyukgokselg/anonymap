import 'dart:async';

import 'package:flutter/material.dart';

import '../models/activity_model.dart';
import '../services/activity_service.dart';
import '../theme/colors.dart';
import '../widgets/animated_press.dart';
import 'activity_detail_screen.dart';

/// Caller'ın düzenlediği + onaylı katıldığı tüm etkinlikleri ay görünümünde
/// gösterir. Bir gün seçildiğinde altta o güne ait etkinlik listesi açılır.
///
/// Hand-rolled calendar — `table_calendar`/`intl` gibi bağımlılık eklemeden
/// uygulamanın el yazısı (handcrafted) tasarımına uygun.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _trMonths = [
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
  // Pazartesi ilk gün — Türk takvim alışkanlığı.
  static const _trWeekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  bool _loading = true;
  Object? _error;

  /// `yyyy-MM-dd` → o günkü etkinlikler (host + joined birleşik, set).
  final Map<String, List<ActivityModel>> _byDay =
      <String, List<ActivityModel>>{};

  StreamSubscription<void>? _listSub;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
    _listSub = ActivityService.instance.listChanged.listen(
      (_) => unawaited(_load(silent: true)),
    );
  }

  @override
  void dispose() {
    _listSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final svc = ActivityService.instance;
      final results = await Future.wait([
        svc.listHosting(),
        svc.listJoined(),
      ]);
      final all = <String, ActivityModel>{};
      for (final list in results) {
        for (final a in list.items) {
          all[a.id] = a;
        }
      }
      final byDay = <String, List<ActivityModel>>{};
      for (final a in all.values) {
        if (a.isCancelled) continue;
        final key = _dayKey(a.startsAt);
        byDay.putIfAbsent(key, () => []).add(a);
      }
      for (final list in byDay.values) {
        list.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      }
      if (!mounted) return;
      setState(() {
        _byDay
          ..clear()
          ..addAll(byDay);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  String _dayKey(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  void _shiftMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + delta,
      );
    });
  }

  void _selectDay(DateTime day) {
    setState(() => _selectedDay = day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        title: const Text(
          'Takvim',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded, color: Colors.white),
            tooltip: 'Bugün',
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _focusedMonth = DateTime(now.year, now.month);
                _selectedDay = DateTime(now.year, now.month, now.day);
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.bgCard,
        onRefresh: () => _load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildMonthHeader(),
            _buildWeekdayHeader(),
            _buildGrid(),
            const SizedBox(height: 12),
            _buildSelectedDayHeader(),
            ..._buildSelectedDayBody(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    final monthName = _trMonths[_focusedMonth.month - 1];
    final isCurrent = _focusedMonth.year == DateTime.now().year &&
        _focusedMonth.month == DateTime.now().month;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(14)),
        ),
        child: Row(
          children: [
            _navArrow(Icons.chevron_left_rounded, () => _shiftMonth(-1)),
            Expanded(
              child: Center(
                child: Column(
                  children: [
                    Text(
                      '$monthName ${_focusedMonth.year}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isCurrent)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          'Bu ay',
                          style: TextStyle(
                            color: AppColors.primaryGlow,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _navArrow(Icons.chevron_right_rounded, () => _shiftMonth(1)),
          ],
        ),
      ),
    );
  }

  Widget _navArrow(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: List.generate(
          7,
          (i) => Expanded(
            child: Center(
              child: Text(
                _trWeekdays[i],
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    // Pazartesi=1..Pazar=7. Boş başlangıç hücresi sayısı:
    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final leadingBlanks = (firstOfMonth.weekday - 1);
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;

    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_focusedMonth.year, _focusedMonth.month, d);
      cells.add(_buildDayCell(day));
    }
    // 6 satır olacak şekilde tail blanks (görsel hizalama).
    while (cells.length % 7 != 0 || cells.length < 42) {
      cells.add(const SizedBox.shrink());
      if (cells.length >= 42) break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.count(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        childAspectRatio: 0.85,
        children: cells,
      ),
    );
  }

  Widget _buildDayCell(DateTime day) {
    final today = DateTime.now();
    final isToday = day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    final isSelected = day.year == _selectedDay.year &&
        day.month == _selectedDay.month &&
        day.day == _selectedDay.day;
    final activities = _byDay[_dayKey(day)] ?? const <ActivityModel>[];
    final hasHosted = activities.any((a) => a.viewerIsHost);
    final hasJoined = activities.any((a) =>
        a.viewerStatus == ActivityViewerStatus.approved && !a.viewerIsHost);

    return AnimatedPress(
      onTap: () => _selectDay(day),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(70)
              : (isToday ? AppColors.bgCard : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGlow
                : (isToday ? AppColors.primary.withAlpha(80) : Colors.transparent),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isToday ? AppColors.primaryGlow : Colors.white),
                fontSize: 14,
                fontWeight:
                    isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            if (activities.isEmpty)
              const SizedBox(height: 6)
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasHosted) _dot(AppColors.primary),
                  if (hasHosted && hasJoined) const SizedBox(width: 3),
                  if (hasJoined) _dot(AppColors.modeFriends),
                  if (!hasHosted && !hasJoined && activities.isNotEmpty)
                    _dot(AppColors.textSecondary),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _buildSelectedDayHeader() {
    final monthName = _trMonths[_selectedDay.month - 1];
    final activities = _byDay[_dayKey(_selectedDay)] ?? const [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Text(
            '${_selectedDay.day} $monthName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.bgChip,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${activities.length} etkinlik',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSelectedDayBody() {
    if (_loading && _byDay.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ];
    }
    if (_error != null && _byDay.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppColors.textHint),
              const SizedBox(height: 8),
              Text(
                'Etkinlikler yüklenemedi',
                style: TextStyle(
                  color: Colors.white.withAlpha(220),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    final activities = _byDay[_dayKey(_selectedDay)] ?? const [];
    if (activities.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(14)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  color: AppColors.textHint,
                  size: 22,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bu gün için planlanmış bir etkinlik yok.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      for (final a in activities)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: _CalendarActivityTile(activity: a),
        ),
    ];
  }
}

class _CalendarActivityTile extends StatelessWidget {
  const _CalendarActivityTile({required this.activity});

  final ActivityModel activity;

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final isHost = activity.viewerIsHost;
    final accent = isHost ? AppColors.primary : AppColors.modeFriends;
    final roleLabel = isHost ? 'Düzenliyorsun' : 'Katılıyorsun';

    return AnimatedPress(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ActivityDetailScreen(activityId: activity.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withAlpha(60)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: accent.withAlpha(50),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withAlpha(100)),
              ),
              child: Column(
                children: [
                  Text(
                    _formatTime(activity.startsAt),
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (activity.endsAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(activity.endsAt!),
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.locationName.isEmpty
                        ? activity.city
                        : activity.locationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withAlpha(48),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                            color: accent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
