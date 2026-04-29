import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/activity_model.dart';
import '../../screens/activity_detail_screen.dart';
import '../../screens/create_activity_screen.dart';
import '../../screens/my_activities_screen.dart';
import '../../services/activity_service.dart';
import '../../theme/colors.dart';
import '../animated_press.dart';
import 'activity_category_meta.dart';

/// Compact horizontal rail of activities a given user is hosting.
///
/// Used on profile screens — both own profile (with "Yeni" CTA) and others'
/// profiles (host's upcoming events). Self-loads via [ActivityService.search]
/// and listens to [ActivityService.listChanged] for live refresh after
/// create/cancel/update.
class ActivityProfileRail extends StatefulWidget {
  const ActivityProfileRail({
    super.key,
    required this.hostUserId,
    required this.isOwnProfile,
    this.title = 'Düzenlediği etkinlikler',
    this.emptyOwnHint =
        'İlk etkinliğini paylaş — yeni insanlarla buluşman bir tık uzakta.',
    this.limit = 6,
  });

  final String hostUserId;
  final bool isOwnProfile;
  final String title;
  final String emptyOwnHint;
  final int limit;

  @override
  State<ActivityProfileRail> createState() => _ActivityProfileRailState();
}

class _ActivityProfileRailState extends State<ActivityProfileRail> {
  final ActivityService _service = ActivityService.instance;
  StreamSubscription<void>? _listSub;

  bool _loading = true;
  Object? _error;
  List<ActivityModel> _items = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
    _listSub = _service.listChanged.listen((_) => _fetch(silent: true));
  }

  @override
  void didUpdateWidget(covariant ActivityProfileRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hostUserId != widget.hostUserId) {
      _fetch();
    }
  }

  @override
  void dispose() {
    _listSub?.cancel();
    super.dispose();
  }

  Future<void> _fetch({bool silent = false}) async {
    if (widget.hostUserId.isEmpty) return;
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final res = await _service.search(
        ActivityListQueryParams(
          hostUserId: widget.hostUserId,
          limit: widget.limit,
        ),
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _shell(child: _loadingTiles());
    if (_error != null) {
      // Sessizce gizle — rail'lar profilde opsiyonel.
      if (!widget.isOwnProfile) return const SizedBox.shrink();
      return _shell(child: _errorState());
    }
    if (_items.isEmpty) {
      if (!widget.isOwnProfile) return const SizedBox.shrink();
      return _shell(child: _ownEmptyState());
    }

    return _shell(
      child: SizedBox(
        height: 168,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _items.length + (widget.isOwnProfile ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, index) {
            if (widget.isOwnProfile && index == _items.length) {
              return _newTile();
            }
            return _ActivityRailTile(
              activity: _items[index],
              onTap: () => _openDetail(_items[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _shell({required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (widget.isOwnProfile && _items.isNotEmpty)
                GestureDetector(
                  onTap: _openMyActivities,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tümü',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                )
              else if (_items.isNotEmpty)
                Text(
                  '${_items.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        child,
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _loadingTiles() {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, _) {
          return Container(
            width: 220,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Etkinlikler yüklenemedi.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _fetch,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ownEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedPress(
        onTap: _openCreate,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryGlow.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.primaryGlow,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Etkinlik düzenle',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.emptyOwnHint,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _newTile() {
    return AnimatedPress(
      onTap: _openCreate,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primaryGlow.withValues(alpha: 0.35),
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.primaryGlow,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Yeni etkinlik',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(ActivityModel a) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(
          activityId: a.id,
          initialActivity: a,
        ),
      ),
    );
  }

  void _openCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
    );
  }

  void _openMyActivities() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyActivitiesScreen()),
    );
  }
}

class _ActivityRailTile extends StatelessWidget {
  const _ActivityRailTile({required this.activity, required this.onTap});

  final ActivityModel activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = ActivityCategoryMeta.of(activity.category);
    final cover = activity.coverImageUrl;

    return AnimatedPress(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: activity.isCancelled
                ? AppColors.error.withValues(alpha: 0.35)
                : meta.color.withValues(alpha: 0.22),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 78,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null && cover.isNotEmpty)
                    Image.network(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _gradient(meta),
                    )
                  else
                    _gradient(meta),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: meta.color.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(meta.icon, size: 11, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            meta.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (activity.isCancelled)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'İptal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  else if (activity.isRecurring)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.replay_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatWhen(activity.startsAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.group_rounded,
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _peopleLabel(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _peopleLabel() {
    final cap = activity.maxParticipants;
    final cur = activity.currentParticipantCount;
    return cap == null ? '$cur kişi' : '$cur / $cap';
  }

  Widget _gradient(ActivityCategoryMeta meta) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            meta.color.withValues(alpha: 0.55),
            AppColors.bgCard,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          meta.icon,
          size: 32,
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }

  static String _formatWhen(DateTime startsAt) {
    final local = startsAt.toLocal();
    final now = DateTime.now();
    final isSameDay = now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = tomorrow.year == local.year &&
        tomorrow.month == local.month &&
        tomorrow.day == local.day;

    final time =
        '${local.hour.toString().padLeft(2, '0')}.${local.minute.toString().padLeft(2, '0')}';
    if (isSameDay) return 'Bugün · $time';
    if (isTomorrow) return 'Yarın · $time';
    return '${local.day}.${local.month.toString().padLeft(2, '0')} · $time';
  }
}
