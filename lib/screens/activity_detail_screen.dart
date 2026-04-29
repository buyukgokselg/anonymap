import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/activity_model.dart';
import '../services/activity_service.dart';
import '../theme/colors.dart';
import '../widgets/activity/activity_category_chip.dart';
import '../widgets/activity/activity_category_meta.dart';
import '../widgets/activity/activity_countdown_pill.dart';
import '../widgets/activity/activity_join_button.dart';
import '../widgets/activity/activity_ratings_panel.dart';
import '../widgets/activity/activity_vibe_banner.dart';
import '../widgets/activity/participant_avatar_stack.dart';
import '../widgets/animated_press.dart';
import '../widgets/app_snackbar.dart';
import 'activity_group_chat_screen.dart';

/// Full-page detail view for an activity.
///
/// Shows host info, full description, time/place, participants (avatar stack +
/// expandable list for hosts to approve/decline), share button, and the
/// context-aware join CTA. Listens to [ActivityService] so realtime
/// participant changes (joins, approvals, cancellations) update live.
class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({
    super.key,
    required this.activityId,
    this.initialActivity,
  });

  final String activityId;
  final ActivityModel? initialActivity;

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  ActivityModel? _activity;
  List<ActivityParticipationModel>? _participants;
  bool _loading = false;
  bool _participantsLoading = false;
  bool _actionInFlight = false;
  StreamSubscription<String>? _activitySub;

  @override
  void initState() {
    super.initState();
    _activity = widget.initialActivity ??
        ActivityService.instance.cachedActivity(widget.activityId);
    _activitySub =
        ActivityService.instance.activityChanged.listen(_onActivityChanged);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _activitySub?.cancel();
    super.dispose();
  }

  void _onActivityChanged(String activityId) {
    if (activityId != widget.activityId) return;
    final fresh = ActivityService.instance.cachedActivity(widget.activityId);
    if (fresh == null) return;
    if (!mounted) return;
    setState(() => _activity = fresh);
    if (fresh.viewerIsHost) {
      unawaited(_refreshParticipants());
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final activity = await ActivityService.instance.getActivity(
        widget.activityId,
        useCache: false,
      );
      if (!mounted) return;
      setState(() => _activity = activity);
      if (activity != null && activity.viewerIsHost) {
        unawaited(_refreshParticipants());
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshParticipants() async {
    if (_participantsLoading) return;
    setState(() => _participantsLoading = true);
    try {
      final list = await ActivityService.instance.listParticipants(
        widget.activityId,
      );
      if (!mounted) return;
      setState(() => _participants = list);
    } finally {
      if (mounted) setState(() => _participantsLoading = false);
    }
  }

  Future<void> _withAction(Future<void> Function() body) async {
    if (_actionInFlight) return;
    setState(() => _actionInFlight = true);
    try {
      await body();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _onJoin() async {
    final activity = _activity;
    if (activity == null) return;
    String? message;
    if (activity.joinPolicy == ActivityJoinPolicy.approvalRequired) {
      message = await _promptForJoinMessage();
      if (message == null) return; // user cancelled
    }
    await _withAction(() async {
      final participation =
          await ActivityService.instance.join(activity.id, message: message);
      if (!mounted) return;
      final approved =
          participation?.status == ActivityParticipationStatus.approved;
      AppSnackbar.showSuccess(
        context,
        approved ? 'Katıldın 🎉' : 'İstek gönderildi',
      );
    });
  }

  Future<void> _onLeave() async {
    final activity = _activity;
    if (activity == null) return;
    final confirmed = await _confirmDialog(
      title: 'Etkinlikten çık',
      body: 'Etkinlikten ayrılmak istediğine emin misin?',
      confirmLabel: 'Çık',
      destructive: true,
    );
    if (!confirmed) return;
    await _withAction(() async {
      await ActivityService.instance.leave(activity.id);
      if (!mounted) return;
      AppSnackbar.showInfo(context, 'Etkinlikten ayrıldın.');
    });
  }

  Future<void> _onCancelRequest() async {
    final activity = _activity;
    if (activity == null) return;
    await _withAction(() async {
      await ActivityService.instance.leave(activity.id);
      if (!mounted) return;
      AppSnackbar.showInfo(context, 'İstek iptal edildi.');
    });
  }

  Future<void> _onCancelActivity() async {
    final activity = _activity;
    if (activity == null) return;
    final reason = await _promptForCancelReason();
    if (reason == null) return;
    await _withAction(() async {
      final ok = await ActivityService.instance.cancel(
        activity.id,
        reason: reason.isEmpty ? null : reason,
      );
      if (!mounted) return;
      if (ok) {
        AppSnackbar.showInfo(context, 'Etkinlik iptal edildi.');
      }
    });
  }

  Future<void> _openGroupChat() async {
    final activity = _activity;
    if (activity == null) return;
    if (_actionInFlight) return;
    setState(() => _actionInFlight = true);
    try {
      final chat = await ActivityService.instance.getGroupChat(activity.id);
      if (!mounted) return;
      if (chat == null) {
        AppSnackbar.showError(context, 'Grup sohbeti açılamadı.');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActivityGroupChatScreen(
            activity: activity,
            chat: chat,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _onShare() async {
    final activity = _activity;
    if (activity == null) return;
    final lines = [
      activity.title,
      _formatLong(activity.startsAt, activity.endsAt),
      activity.locationName.isNotEmpty
          ? activity.locationName
          : activity.city,
    ];
    await SharePlus.instance.share(ShareParams(
      text: lines.join('\n'),
      subject: activity.title,
    ));
  }

  Future<void> _openMap() async {
    final activity = _activity;
    if (activity == null) return;
    final lat = activity.latitude;
    final lng = activity.longitude;
    final query =
        activity.locationName.isNotEmpty ? activity.locationName : '$lat,$lng';
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
      '${Uri.encodeQueryComponent(query)}&center=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _respondParticipation(
    ActivityParticipationModel participation, {
    required bool approve,
  }) async {
    final activity = _activity;
    if (activity == null) return;
    String? note;
    if (!approve) {
      note = await _promptForResponseNote();
      if (note == null) return;
    }
    await _withAction(() async {
      await ActivityService.instance.respondJoin(
        activity.id,
        participation.id,
        approve: approve,
        responseNote: note,
      );
      await _refreshParticipants();
      if (!mounted) return;
      AppSnackbar.showSuccess(
        context,
        approve ? 'Katılımcı onaylandı.' : 'İstek reddedildi.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activity;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        bottom: false,
        child: activity == null
            ? _loadingState()
            : RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.bgCard,
                onRefresh: _refresh,
                child: _buildContent(activity),
              ),
      ),
      bottomNavigationBar: activity == null ? null : _buildBottomBar(activity),
    );
  }

  Widget _loadingState() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_busy_rounded,
              color: AppColors.textHint,
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'Etkinlik bulunamadı',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'İptal edilmiş veya silinmiş olabilir.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: _refresh,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ActivityModel activity) {
    final meta = ActivityCategoryMeta.of(activity.category);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildCover(activity, meta)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activity.isCancelled) ...[
                  _cancelledBanner(activity),
                  const SizedBox(height: 16),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActivityCategoryChip(category: activity.category),
                    if (activity.category == ActivityCategory.anlik &&
                        !activity.isCancelled)
                      ActivityCountdownPill(
                        startsAt: activity.startsAt,
                        endsAt: activity.endsAt,
                      ),
                    if (activity.requiresVerification)
                      _miniBadge(
                        Icons.verified_rounded,
                        'Doğrulamalı',
                        AppColors.neonCyan,
                      ),
                    if (activity.isRecurring)
                      _miniBadge(
                        Icons.replay_rounded,
                        _recurrenceLabel(activity.recurrenceRule),
                        AppColors.neonCyan,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  activity.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 14),
                _buildHostCard(activity),
                if (activity.category == ActivityCategory.cesaret ||
                    activity.category == ActivityCategory.anlik) ...[
                  const SizedBox(height: 14),
                  ActivityVibeBanner(category: activity.category),
                ],
                const SizedBox(height: 18),
                _buildInfoBlock(activity),
                if (activity.description.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _sectionTitle('Hakkında'),
                  const SizedBox(height: 8),
                  Text(
                    activity.description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (activity.interests.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _sectionTitle('İlgi alanları'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activity.interests.map(_interestChip).toList(),
                  ),
                ],
                const SizedBox(height: 22),
                _sectionTitle('Katılımcılar'),
                const SizedBox(height: 12),
                _buildParticipantsBlock(activity),
                if (!activity.isCancelled &&
                    (activity.viewerIsHost ||
                        activity.viewerStatus ==
                            ActivityViewerStatus.approved)) ...[
                  const SizedBox(height: 12),
                  _buildGroupChatTile(activity),
                ],
                if (activity.isPast && !activity.isCancelled) ...[
                  const SizedBox(height: 18),
                  ActivityRatingsPanel(activity: activity),
                ],
                if (activity.category == ActivityCategory.cesaret) ...[
                  const SizedBox(height: 16),
                  _cesaretSafetyFooter(),
                ],
                if (activity.viewerIsHost) ...[
                  const SizedBox(height: 22),
                  _buildHostActions(activity),
                ],
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCover(ActivityModel activity, ActivityCategoryMeta meta) {
    final cover = activity.coverImageUrl;
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cover != null && cover.isNotEmpty)
            Image.network(
              cover,
              fit: BoxFit.cover,
              errorBuilder: (_, e, s) => _coverFallback(meta),
            )
          else
            _coverFallback(meta),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                  AppColors.bgMain,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: _circleIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: [
                _circleIconButton(
                  icon: Icons.ios_share_rounded,
                  onTap: _onShare,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverFallback(ActivityCategoryMeta meta) {
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
          color: Colors.white.withValues(alpha: 0.3),
          size: 80,
        ),
      ),
    );
  }

  Widget _circleIconButton({required IconData icon, required VoidCallback onTap}) {
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  String _recurrenceLabel(String rule) {
    switch (rule) {
      case 'weekly':
        return 'Her hafta';
      case 'biweekly':
        return 'İki haftada bir';
      case 'monthly':
        return 'Her ay';
      default:
        return 'Tekrarlı';
    }
  }

  Widget _miniBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cancelledBanner(ActivityModel activity) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Etkinlik iptal edildi',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                if ((activity.cancellationReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    activity.cancellationReason!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostCard(ActivityModel activity) {
    final url = activity.hostPhotoUrl;
    final name = activity.hostDisplayName.isEmpty
        ? 'Anonim'
        : activity.hostDisplayName;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.bgChip,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: url != null && url.isNotEmpty
                ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, e, s) {
                    return const Icon(
                      Icons.person_rounded,
                      color: AppColors.textHint,
                      size: 22,
                    );
                  })
                : const Icon(
                    Icons.person_rounded,
                    color: AppColors.textHint,
                    size: 22,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Text(
                      'Etkinlik sahibi',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (activity.hostRatingCount > 0) ...[
                      const SizedBox(width: 8),
                      _buildHostRatingChip(activity),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostRatingChip(ActivityModel activity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.warning, size: 12),
          const SizedBox(width: 3),
          Text(
            activity.hostRatingAverage.toStringAsFixed(1),
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '· ${activity.hostRatingCount}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock(ActivityModel activity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          _infoRow(
            icon: Icons.schedule_rounded,
            color: AppColors.neonCyan,
            label: 'Zaman',
            value: _formatLong(activity.startsAt, activity.endsAt),
          ),
          const SizedBox(height: 10),
          _divider(),
          const SizedBox(height: 10),
          _infoRow(
            icon: Icons.location_on_rounded,
            color: AppColors.modeFun,
            label: 'Yer',
            value: activity.locationName.isNotEmpty
                ? activity.locationName
                : activity.city,
            secondary: activity.locationAddress,
            trailing: AnimatedPress(
              onTap: _openMap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.modeFun.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.modeFun.withValues(alpha: 0.45),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.map_rounded,
                      color: AppColors.modeFun,
                      size: 13,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Yol tarifi',
                      style: TextStyle(
                        color: AppColors.modeFun,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _divider(),
          const SizedBox(height: 10),
          _infoRow(
            icon: Icons.tune_rounded,
            color: AppColors.modeChill,
            label: 'Mod',
            value: _modeLabel(activity.mode),
          ),
          const SizedBox(height: 10),
          _divider(),
          const SizedBox(height: 10),
          _infoRow(
            icon: Icons.lock_open_rounded,
            color: AppColors.modeFriends,
            label: 'Katılım',
            value: _joinPolicyLabel(activity.joinPolicy),
          ),
          if (activity.minAge != null || activity.maxAge != null) ...[
            const SizedBox(height: 10),
            _divider(),
            const SizedBox(height: 10),
            _infoRow(
              icon: Icons.cake_rounded,
              color: AppColors.modeFlirt,
              label: 'Yaş',
              value: _ageLabel(activity.minAge, activity.maxAge),
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.05),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    String? secondary,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              if (secondary != null && secondary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  secondary,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _interestChip(String interest) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.bgChip,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        '#$interest',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _sectionTitle(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildParticipantsBlock(ActivityModel activity) {
    final cap = activity.maxParticipants;
    final cur = activity.currentParticipantCount;
    final countLabel = cap == null ? '$cur kişi' : '$cur / $cap';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          ParticipantAvatarStack(
            users: activity.sampleParticipants,
            totalCount: activity.currentParticipantCount,
            avatarSize: 36,
            maxVisible: 4,
            borderColor: AppColors.bgCard,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  countLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cap == null
                      ? 'Açık katılım'
                      : 'Maksimum $cap kişilik',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupChatTile(ActivityModel activity) {
    final count = activity.currentParticipantCount + 1;
    return AnimatedPress(
      onTap: _actionInFlight ? null : _openGroupChat,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.22),
              AppColors.primaryGlow.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.45),
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.forum_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Grup sohbeti',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$count kişi · plan yapın, tanışın',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
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
    );
  }

  Widget _cesaretSafetyFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.primaryGlow.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryGlow.withValues(alpha: 0.35),
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
                  'Cesaret rehberi',
                  style: TextStyle(
                    color: AppColors.primaryGlow,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '• Kendi sınırını bilmek de cesarettir.\n'
                  '• Kimse açıklama yapmak zorunda değil.\n'
                  '• Rahatsız edici biri olursa hemen rapor et — bildirim host\'a değil bize gelir.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostActions(ActivityModel activity) {
    final pending = (_participants ?? const [])
        .where((p) => p.status == ActivityParticipationStatus.requested)
        .toList(growable: false);
    final approved = (_participants ?? const [])
        .where((p) => p.status == ActivityParticipationStatus.approved)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Sahip paneli'),
        const SizedBox(height: 12),
        if (_participantsLoading && _participants == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else ...[
          if (pending.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.hourglass_top_rounded,
                        color: AppColors.warning,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${pending.length} bekleyen istek',
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final p in pending)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _participantRow(p, showActions: true),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (approved.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${approved.length} onaylı katılımcı',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final p in approved)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _participantRow(p, showActions: false),
                    ),
                ],
              ),
            ),
          ],
          if (pending.isEmpty && approved.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: const Text(
                'Henüz katılımcı yok. Etkinliğini paylaşıp arkadaşlarını davet edebilirsin.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
        ],
        if (!activity.isCancelled) ...[
          const SizedBox(height: 18),
          AnimatedPress(
            onTap: _onCancelActivity,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.45),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Etkinliği iptal et',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _participantRow(
    ActivityParticipationModel participation, {
    required bool showActions,
  }) {
    final url = participation.userPhotoUrl;
    final name = participation.userDisplayName.isEmpty
        ? 'Anonim'
        : participation.userDisplayName;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.bgChip,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: url != null && url.isNotEmpty
              ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, e, s) {
                  return const Icon(
                    Icons.person_rounded,
                    color: AppColors.textHint,
                    size: 18,
                  );
                })
              : const Icon(
                  Icons.person_rounded,
                  color: AppColors.textHint,
                  size: 18,
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if ((participation.joinMessage ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  participation.joinMessage!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showActions) ...[
          const SizedBox(width: 8),
          AnimatedPress(
            onTap: _actionInFlight
                ? null
                : () =>
                    _respondParticipation(participation, approve: false),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.bgChip,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.error,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 6),
          AnimatedPress(
            onTap: _actionInFlight
                ? null
                : () =>
                    _respondParticipation(participation, approve: true),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryGlow],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar(ActivityModel activity) {
    if (activity.viewerIsHost) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shield_rounded,
                  color: AppColors.neonCyan,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  activity.isCancelled
                      ? 'Bu etkinlik iptal edildi'
                      : 'Sen bu etkinliğin sahibisin',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: SizedBox(
          width: double.infinity,
          child: ActivityJoinButton(
            activity: activity,
            onJoin: _onJoin,
            onLeave: _onLeave,
            onCancelRequest: _onCancelRequest,
            loading: _actionInFlight,
          ),
        ),
      ),
    );
  }

  Future<String?> _promptForJoinMessage() async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sahibe kısa bir mesaj',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Neden katılmak istediğini birkaç cümleyle anlat. Onay sürecini hızlandırır.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 240,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Selam, ben…',
                hintStyle: const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.bgChip,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Vazgeç'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(controller.text.trim());
                    },
                    child: const Text(
                      'Gönder',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<String?> _promptForCancelReason() async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Etkinliği iptal et',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Katılımcılar iptal sebebini bildirim olarak görür. Boş bırakabilirsin.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 240,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'İptal sebebi (opsiyonel)',
                hintStyle: const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.bgChip,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Vazgeç'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(controller.text.trim());
                    },
                    child: const Text(
                      'İptal et',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<String?> _promptForResponseNote() async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reddet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kibarca bir not bırakabilirsin. Boş bırakırsan sadece "reddedildi" denir.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 200,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Not (opsiyonel)',
                hintStyle: const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.bgChip,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Vazgeç'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(controller.text.trim());
                    },
                    child: const Text(
                      'Reddet',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          body,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: destructive ? AppColors.error : AppColors.primary,
            ),
            child: Text(
              confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  static String _formatLong(DateTime startsAt, DateTime? endsAt) {
    const months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    const weekdays = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    final start = startsAt.toLocal();
    final dayLabel =
        '${weekdays[start.weekday - 1]}, ${start.day} ${months[start.month - 1]}';
    final time =
        '${start.hour.toString().padLeft(2, '0')}.${start.minute.toString().padLeft(2, '0')}';
    if (endsAt == null) return '$dayLabel · $time';
    final end = endsAt.toLocal();
    final endTime =
        '${end.hour.toString().padLeft(2, '0')}.${end.minute.toString().padLeft(2, '0')}';
    return '$dayLabel · $time → $endTime';
  }

  static String _modeLabel(String mode) {
    switch (mode.toLowerCase()) {
      case 'flirt':
        return 'Flört modu';
      case 'friends':
        return 'Arkadaş modu';
      case 'fun':
        return 'Eğlence modu';
      case 'chill':
      default:
        return 'Sakin mod';
    }
  }

  static String _joinPolicyLabel(ActivityJoinPolicy policy) {
    return policy == ActivityJoinPolicy.approvalRequired
        ? 'Onaylı katılım'
        : 'Açık katılım';
  }

  static String _ageLabel(int? min, int? max) {
    if (min != null && max != null) return '$min – $max yaş';
    if (min != null) return '$min+ yaş';
    if (max != null) return '$max yaşa kadar';
    return '—';
  }
}
