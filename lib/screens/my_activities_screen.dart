import 'dart:async';

import 'package:flutter/material.dart';

import '../models/activity_model.dart';
import '../models/activity_rating_model.dart';
import '../services/activity_service.dart';
import '../theme/colors.dart';
import '../widgets/activity/activity_card.dart';
import '../widgets/animated_press.dart';
import '../widgets/app_snackbar.dart';
import 'activity_detail_screen.dart';
import 'calendar_screen.dart';
import 'create_activity_screen.dart';
import 'pending_ratings_screen.dart';

/// Personal activity hub with three tabs:
///   • Düzenliyorum  — activities the viewer is hosting
///   • Katılıyorum   — approved participation
///   • Bekleyen      — sent requests still awaiting host approval
///
/// Refreshes on pull-down and reacts to [ActivityService.listChanged] so
/// realtime joins/leaves/cancellations stay in sync.
class MyActivitiesScreen extends StatefulWidget {
  const MyActivitiesScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<MyActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  StreamSubscription<void>? _listSub;

  bool _hostingLoading = false;
  bool _joinedLoading = false;
  String? _hostingError;
  String? _joinedError;

  List<ActivityModel> _hosting = const [];
  List<ActivityModel> _joinedAll = const [];

  /// How many distinct (activity, user) pairs are still awaiting a rating.
  int _pendingRatingPairs = 0;
  List<PendingRatingItem> _pendingRatings = const [];

  String? _busyId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _listSub = ActivityService.instance.listChanged.listen((_) {
      unawaited(_refresh());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _listSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([_loadHosting(), _loadJoined(), _loadPendingRatings()]);
  }

  Future<void> _loadPendingRatings() async {
    try {
      final res = await ActivityService.instance.listPendingRatings();
      if (!mounted) return;
      final pairs = res.items.fold<int>(
        0,
        (sum, group) => sum + group.rateableUsers.length,
      );
      setState(() {
        _pendingRatings = res.items;
        _pendingRatingPairs = pairs;
      });
    } catch (e) {
      // non-blocking — banner just stays hidden if this errors out
      if (!mounted) return;
      setState(() => _pendingRatingPairs = 0);
    }
  }

  Future<void> _openPendingRatings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PendingRatingsScreen()),
    );
    if (!mounted) return;
    unawaited(_loadPendingRatings());
  }

  Future<void> _loadHosting() async {
    if (_hostingLoading) return;
    setState(() {
      _hostingLoading = true;
      _hostingError = null;
    });
    try {
      final res = await ActivityService.instance.listHosting();
      if (!mounted) return;
      setState(() => _hosting = res.items);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _hostingError = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _hostingLoading = false);
    }
  }

  Future<void> _loadJoined() async {
    if (_joinedLoading) return;
    setState(() {
      _joinedLoading = true;
      _joinedError = null;
    });
    try {
      final res = await ActivityService.instance.listJoined();
      if (!mounted) return;
      setState(() => _joinedAll = res.items);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _joinedError = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _joinedLoading = false);
    }
  }

  Future<void> _openDetail(ActivityModel activity) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(
          activityId: activity.id,
          initialActivity: activity,
        ),
      ),
    );
    if (!mounted) return;
    unawaited(_refresh());
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<ActivityModel>(
      MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
    );
    if (!mounted) return;
    if (created != null) {
      unawaited(_refresh());
      _tabController.animateTo(0);
    }
  }

  Future<void> _withBusy(
    String activityId,
    Future<void> Function() body,
  ) async {
    if (_busyId != null) return;
    setState(() => _busyId = activityId);
    try {
      await body();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _leaveOrCancelRequest(ActivityModel activity) async {
    await _withBusy(activity.id, () async {
      await ActivityService.instance.leave(activity.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final joined = _joinedAll
        .where((a) => a.viewerStatus == ActivityViewerStatus.approved)
        .toList(growable: false);
    final pending = _joinedAll
        .where((a) => a.viewerStatus == ActivityViewerStatus.requested)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        title: const Text(
          'Etkinliklerim',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
            ),
            tooltip: 'Takvim',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CalendarScreen(),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryGlow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: 0.2,
                ),
                tabs: [
                  Tab(text: 'Düzenliyorum (${_hosting.length})'),
                  Tab(text: 'Katılıyorum (${joined.length})'),
                  Tab(text: 'Bekleyen (${pending.length})'),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Yeni etkinlik',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          if (_pendingRatingPairs > 0) _buildPendingRatingBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _hostingTab(),
                _joinedTab(joined),
                _pendingTab(pending),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRatingBanner() {
    final activitiesCount = _pendingRatings.length;
    final pairLabel = _pendingRatingPairs == 1
        ? '1 kişiyi'
        : '$_pendingRatingPairs kişiyi';
    final activityLabel = activitiesCount == 1
        ? '1 etkinlikten'
        : '$activitiesCount etkinlikten';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: AnimatedPress(
        onTap: _openPendingRatings,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.22),
                AppColors.primaryGlow.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.32),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Değerlendirme bekliyor',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$activityLabel $pairLabel puanlamadın.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hostingTab() {
    if (_hostingLoading && _hosting.isEmpty) return _loadingView();
    if (_hostingError != null && _hosting.isEmpty) {
      return _errorView(_hostingError!, _loadHosting);
    }
    if (_hosting.isEmpty) {
      return _emptyView(
        icon: Icons.add_circle_outline_rounded,
        title: 'Henüz etkinlik düzenlemedin',
        body:
            'Cesaret, anlık veya planlı bir etkinlik başlat — insanları gerçek hayatta buluştur.',
        actionLabel: 'Yeni etkinlik',
        onAction: _openCreate,
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      onRefresh: _loadHosting,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _hosting.length,
        itemBuilder: (_, i) {
          final a = _hosting[i];
          return ActivityCard(
            activity: a,
            actionLoading: _busyId == a.id,
            onTap: () => _openDetail(a),
          );
        },
      ),
    );
  }

  Widget _joinedTab(List<ActivityModel> joined) {
    if (_joinedLoading && _joinedAll.isEmpty) return _loadingView();
    if (_joinedError != null && _joinedAll.isEmpty) {
      return _errorView(_joinedError!, _loadJoined);
    }
    if (joined.isEmpty) {
      return _emptyView(
        icon: Icons.event_available_rounded,
        title: 'Henüz katıldığın etkinlik yok',
        body:
            'Keşfet sekmesinde sana uygun etkinlikleri tara — bir tanesine "Katıl" demeniz yeterli.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      onRefresh: _loadJoined,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: joined.length,
        itemBuilder: (_, i) {
          final a = joined[i];
          return ActivityCard(
            activity: a,
            actionLoading: _busyId == a.id,
            onTap: () => _openDetail(a),
            onLeave: () => _leaveOrCancelRequest(a),
          );
        },
      ),
    );
  }

  Widget _pendingTab(List<ActivityModel> pending) {
    if (_joinedLoading && _joinedAll.isEmpty) return _loadingView();
    if (_joinedError != null && _joinedAll.isEmpty) {
      return _errorView(_joinedError!, _loadJoined);
    }
    if (pending.isEmpty) {
      return _emptyView(
        icon: Icons.hourglass_empty_rounded,
        title: 'Bekleyen istek yok',
        body: 'Onay isteyen etkinliklere katılma isteği gönderdiğinde burada görünür.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      onRefresh: _loadJoined,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: pending.length,
        itemBuilder: (_, i) {
          final a = pending[i];
          return ActivityCard(
            activity: a,
            actionLoading: _busyId == a.id,
            onTap: () => _openDetail(a),
            onCancelRequest: () => _leaveOrCancelRequest(a),
          );
        },
      ),
    );
  }

  Widget _loadingView() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _errorView(String message, Future<void> Function() onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.textHint,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView({
    required IconData icon,
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(icon, color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              AnimatedPress(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryGlow],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: -4,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
