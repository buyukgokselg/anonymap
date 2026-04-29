import 'dart:async';

import 'package:flutter/material.dart';

import '../models/activity_model.dart';
import '../models/activity_rating_model.dart';
import '../services/activity_service.dart';
import '../theme/colors.dart';
import '../widgets/activity/activity_rating_sheet.dart';
import '../widgets/animated_press.dart';
import '../widgets/app_snackbar.dart';

/// Lists past activities the viewer has joined/hosted but hasn't rated yet,
/// grouped per-activity with a row per rateable counterpart.
class PendingRatingsScreen extends StatefulWidget {
  const PendingRatingsScreen({super.key});

  @override
  State<PendingRatingsScreen> createState() => _PendingRatingsScreenState();
}

class _PendingRatingsScreenState extends State<PendingRatingsScreen> {
  bool _loading = false;
  String? _error;
  List<PendingRatingItem> _items = const [];

  /// `${activityId}::${userId}` → true after a successful submit, so the row
  /// disappears without a roundtrip.
  final Set<String> _rated = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ActivityService.instance.listPendingRatings();
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _rated.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSheet(
    ActivityModel activity,
    ActivityRatingUser target,
  ) async {
    final ok = await ActivityRatingSheet.show(
      context,
      activity: activity,
      target: target,
    );
    if (ok == true && mounted) {
      setState(() => _rated.add('${activity.id}::${target.id}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _items
        .map(
          (group) => PendingRatingItem(
            activity: group.activity,
            rateableUsers: group.rateableUsers
                .where((u) => !_rated.contains('${group.activity.id}::${u.id}'))
                .toList(growable: false),
          ),
        )
        .where((g) => g.rateableUsers.isNotEmpty)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        title: const Text(
          'Değerlendirme bekleyenler',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.bgCard,
        onRefresh: _load,
        child: _buildBody(visibleItems),
      ),
    );
  }

  Widget _buildBody(List<PendingRatingItem> visibleItems) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null && _items.isEmpty) {
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
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _load,
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }
    if (visibleItems.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.success,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Tüm puanlar verildi 🎉',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Geçmiş etkinliklerinde tanıştığın kişileri puanlamayı bitirdin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: visibleItems.length,
      itemBuilder: (_, i) => _buildGroup(visibleItems[i]),
    );
  }

  Widget _buildGroup(PendingRatingItem group) {
    final activity = group.activity;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.4),
                        AppColors.primaryGlow.withValues(alpha: 0.25),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_rounded,
                    color: Colors.white,
                    size: 22,
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
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${activity.locationName} · ${_formatDate(activity.startsAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.divider,
            indent: 16,
            endIndent: 16,
          ),
          ...group.rateableUsers.map(
            (target) => _buildUserRow(activity, target),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildUserRow(ActivityModel activity, ActivityRatingUser target) {
    final photo = target.profilePhotoUrl;
    return AnimatedPress(
      onTap: () => _openSheet(activity, target),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 38,
                height: 38,
                child: photo != null && photo.isNotEmpty
                    ? Image.network(
                        photo,
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, s) => _initials(target),
                      )
                    : _initials(target),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    target.displayName.isEmpty
                        ? target.userName
                        : target.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (target.ratingCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.warning,
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            target.ratingAverage.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            ' · ${target.ratingCount} puan',
                            style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryGlow],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Puanla',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

  Widget _initials(ActivityRatingUser target) {
    final name = target.displayName.isEmpty
        ? target.userName
        : target.displayName;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      color: AppColors.bgSurface,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  String _formatDate(DateTime when) {
    final months = [
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
    final m = months[when.month - 1];
    return '${when.day} $m';
  }

  // ignore: unused_element
  void _showError(String msg) {
    AppSnackbar.showError(context, msg);
  }
}
