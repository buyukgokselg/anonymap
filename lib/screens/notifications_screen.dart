import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/notifications_inbox_service.dart';
import '../theme/colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationsInboxService.instance;
  final ScrollController _scrollController = ScrollController();
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _service.refresh(unreadOnly: _unreadOnly);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _service.loadMore();
    }
  }

  Future<void> _handleTap(AppNotification n) async {
    if (!n.isRead) {
      await _service.markRead(n.id);
    }
    final link = n.deepLink;
    if (link == null || link.isEmpty || !mounted) return;
    // Deep link routing lives in the host app — for now we just pop the
    // screen so the bell badge updates while the user navigates manually.
    // TODO(activity-deeplinks): wire to root navigator once routes settle.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        title: const Text(
          'Bildirimler',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _unreadOnly ? 'Tümünü göster' : 'Sadece okunmamışlar',
            icon: Icon(
              _unreadOnly
                  ? Icons.mark_email_read_outlined
                  : Icons.mark_email_unread_outlined,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              setState(() => _unreadOnly = !_unreadOnly);
              _service.refresh(unreadOnly: _unreadOnly);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            color: AppColors.bgCard,
            onSelected: (value) {
              if (value == 'mark-all') {
                _service.markAllRead();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'mark-all',
                child: Row(
                  children: [
                    Icon(Icons.done_all, color: AppColors.textPrimary, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Tümünü okundu işaretle',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _service,
        builder: (context, _) {
          final items = _service.items;
          if (_service.loading && items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (items.isEmpty) {
            return _EmptyState(unreadOnly: _unreadOnly);
          }
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.bgCard,
            onRefresh: () => _service.refresh(unreadOnly: _unreadOnly),
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: items.length + (_service.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index >= items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  );
                }
                final n = items[index];
                return Dismissible(
                  key: ValueKey('notif_${n.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                  ),
                  onDismissed: (_) => _service.delete(n.id),
                  child: _NotificationTile(
                    notification: n,
                    onTap: () => _handleTap(n),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final actorName = notification.actor?['displayName']?.toString();
    final photo = notification.actor?['profilePhotoUrl']?.toString();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: notification.isRead
                ? AppColors.bgCard
                : AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: notification.isRead
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.primary.withValues(alpha: 0.32),
              width: notification.isRead ? 1 : 1.4,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                photoUrl: photo,
                fallbackIcon: _iconFor(notification.type),
                fallbackColor: _colorFor(notification.type),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: AppColors.textPrimary,
                        ),
                        children: [
                          if (actorName != null && actorName.isNotEmpty) ...[
                            TextSpan(
                              text: actorName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: ' '),
                          ],
                          TextSpan(text: notification.body),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 6),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    this.photoUrl,
    required this.fallbackIcon,
    required this.fallbackColor,
  });

  final String? photoUrl;
  final IconData fallbackIcon;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fallbackColor.withValues(alpha: 0.18),
        image: hasPhoto
            ? DecorationImage(
                image: NetworkImage(photoUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : Icon(fallbackIcon, color: fallbackColor, size: 20),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.unreadOnly});

  final bool unreadOnly;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(
          unreadOnly ? Icons.mark_email_read_rounded : Icons.notifications_none_rounded,
          size: 80,
          color: AppColors.textMuted.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 16),
        Text(
          unreadOnly
              ? 'Tüm bildirimleri okudun ✨'
              : 'Henüz bildirimin yok',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Eşleşmeler, arkadaşlık istekleri ve etkinlik haberleri burada görünecek.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textHint, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }
}

IconData _iconFor(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.matchCreated:
      return Icons.favorite_rounded;
    case AppNotificationType.friendRequestReceived:
    case AppNotificationType.friendRequestAccepted:
      return Icons.person_add_alt_1_rounded;
    case AppNotificationType.messageReceived:
      return Icons.chat_bubble_rounded;
    case AppNotificationType.activityJoinRequested:
    case AppNotificationType.activityJoinAccepted:
    case AppNotificationType.activityJoinDeclined:
    case AppNotificationType.activityCancelled:
    case AppNotificationType.activityReminder:
    case AppNotificationType.activityUpdated:
    case AppNotificationType.activityNewParticipant:
      return Icons.event_rounded;
    case AppNotificationType.signalNearby:
      return Icons.radar_rounded;
    case AppNotificationType.verificationApproved:
      return Icons.verified_rounded;
    case AppNotificationType.verificationRejected:
      return Icons.gpp_bad_rounded;
    case AppNotificationType.system:
      return Icons.notifications_rounded;
  }
}

Color _colorFor(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.matchCreated:
      return AppColors.modeFlirt;
    case AppNotificationType.friendRequestReceived:
    case AppNotificationType.friendRequestAccepted:
      return AppColors.modeFriends;
    case AppNotificationType.messageReceived:
      return AppColors.neonCyan;
    case AppNotificationType.activityJoinRequested:
    case AppNotificationType.activityJoinAccepted:
    case AppNotificationType.activityNewParticipant:
      return AppColors.modeFun;
    case AppNotificationType.activityCancelled:
    case AppNotificationType.activityJoinDeclined:
      return AppColors.error;
    case AppNotificationType.activityReminder:
    case AppNotificationType.activityUpdated:
      return AppColors.modeChill;
    case AppNotificationType.signalNearby:
      return AppColors.neonCyan;
    case AppNotificationType.verificationApproved:
      return AppColors.success;
    case AppNotificationType.verificationRejected:
      return AppColors.error;
    case AppNotificationType.system:
      return AppColors.primary;
  }
}

String _relativeTime(DateTime when) {
  final now = DateTime.now();
  final diff = now.difference(when);
  if (diff.inSeconds < 60) return 'Az önce';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
  if (diff.inHours < 24) return '${diff.inHours} sa';
  if (diff.inDays < 7) return '${diff.inDays} gün';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} hafta';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} ay';
  return '${(diff.inDays / 365).floor()} yıl';
}
