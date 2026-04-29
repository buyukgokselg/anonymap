import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../models/activity_model.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/activity_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/network_media_headers.dart';
import '../theme/colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/shimmer_loading.dart';
import 'activity_detail_screen.dart';
import 'activity_group_chat_screen.dart';
import 'chat_screen.dart';
import 'my_activities_screen.dart';
import 'profile_screen.dart';

class InboxScreen extends StatefulWidget {
  /// [embedded]: HomeShellScreen sekmesi olarak gösterildiğinde true
  /// olmalı — leading "geri" oku gizlenir.
  const InboxScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _firestoreService = FirestoreService();
  final Map<String, Future<UserModel?>> _userFutures = {};

  String get _myUid => AuthService().currentUserId;

  Future<UserModel?> _getUser(String uid) {
    return _userFutures.putIfAbsent(uid, () => _firestoreService.getUser(uid));
  }

  String _formatRelative(DateTime? dateTime) {
    final l10n = context.l10n;
    if (dateTime == null) return l10n.t('now').toLowerCase();
    final now = DateTime.now();
    return l10n.relativeShort(now.difference(dateTime));
  }

  // ─── Yeni mesaj arama ───
  Future<void> _openNewMessageSheet() async {
    final controller = TextEditingController();
    final results = ValueNotifier<List<UserModel>>(<UserModel>[]);
    var loading = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final l10n = context.l10n;
        Future<void> runSearch(String query) async {
          if (query.trim().length < 2 || loading) return;
          loading = true;
          results.value = await _firestoreService.searchUsers(
            query,
            excludeUid: _myUid,
          );
          loading = false;
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        l10n.phrase('Yeni Mesaj'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Search field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    onChanged: runSearch,
                    decoration: InputDecoration(
                      hintText: l10n.phrase('Kişi ara...'),
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: AppColors.bgCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Results
                Expanded(
                  child: ValueListenableBuilder<List<UserModel>>(
                    valueListenable: results,
                    builder: (context, users, _) {
                      if (users.isEmpty) {
                        return Center(
                          child: Text(
                            l10n.phrase('Kullanıcı adını yaz ve ara.'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final name = user.hasProfile
                              ? user.displayName
                              : user.username;
                          return ListTile(
                            onTap: () async {
                              final chat =
                                  await _firestoreService.createOrGetDirectChat(
                                _myUid,
                                user.uid,
                                isTemporary: false,
                              );
                              if (!mounted || !context.mounted) return;
                              Navigator.pop(context);
                              _openChat(chat, user);
                            },
                            leading: _buildAvatar(user, radius: 22),
                            title: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              '@${user.username}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 13,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
    results.dispose();
  }

  // ─── Arşivlenmiş sohbetleri göster ───
  void _openArchivedChats(List<ChatModel> archivedChats) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ArchivedChatsScreen(
          chats: archivedChats,
          firestoreService: _firestoreService,
          myUid: _myUid,
          getUser: _getUser,
          openChat: _openChat,
          formatRelative: _formatRelative,
          buildAvatar: _buildAvatar,
          l10n: context.l10n,
        ),
      ),
    );
  }

  // ─── Sohbet aç ───
  void _openChat(ChatModel chat, UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          user: {
            'uid': user.uid,
            'chatId': chat.id,
            'name': user.hasProfile ? user.displayName : user.username,
            'username': '@${user.username}',
            'bio': user.bio,
            'isTemporary': chat.isTemporary,
          },
        ),
      ),
    );
  }

  // ─── İstek yanıtla ───
  Future<void> _respondToRequest(
    Map<String, dynamic> request,
    bool accept,
  ) async {
    final fromUid = request['fromUid']?.toString() ?? '';
    final requestId = request['id']?.toString() ?? '';
    if (fromUid.isEmpty || requestId.isEmpty || _myUid.isEmpty) return;

    if (accept) {
      await _firestoreService.acceptFriendRequest(requestId, _myUid, fromUid);
      final chat = await _firestoreService.createOrGetDirectChat(
        _myUid,
        fromUid,
        isTemporary: false,
      );
      await _firestoreService.convertToFriendChat(chat.id);
    } else {
      await _firestoreService.declineFriendRequest(requestId);
    }
  }

  // ─── Swipe to archive / delete ───
  Future<bool> _confirmDismiss(ChatModel chat, DismissDirection dir) async {
    if (dir == DismissDirection.endToStart) {
      // Sil
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            context.l10n.phrase('Sohbeti sil'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: Text(
            context.l10n.phrase('Bu sohbet kalıcı olarak silinecek.'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                context.l10n.phrase('Vazgeç'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Sil',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _firestoreService.deleteChatForMe(chat.id);
        return true;
      }
      return false;
    } else {
      // Arşivle
      await _firestoreService.setChatArchived(chat.id, true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.phrase('Sohbet arşivlendi')),
            backgroundColor: AppColors.bgCard,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: context.l10n.phrase('Geri Al'),
              textColor: AppColors.primary,
              onPressed: () => _firestoreService.setChatArchived(chat.id, false),
            ),
          ),
        );
      }
      return true;
    }
  }

  // ─── Avatar helper ───
  Widget _buildAvatar(UserModel user, {double radius = 26}) {
    final name = user.hasProfile ? user.displayName : user.username;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.14),
      backgroundImage: user.profilePhotoUrl.isNotEmpty
          ? NetworkMediaHeaders.imageProvider(user.profilePhotoUrl)
          : null,
      child: user.profilePhotoUrl.isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.7,
              ),
            )
          : null,
    );
  }

  // ─── Grup (aktivite) chat item ───
  Widget _buildGroupChatItem(ChatModel chat) {
    final unread = chat.myUnread(_myUid);
    final title = chat.title.isNotEmpty
        ? chat.title
        : context.l10n.phrase('Etkinlik sohbeti');
    final lastMsg = chat.lastMessage.isNotEmpty
        ? chat.lastMessage
        : context.l10n.phrase('Sohbet başlatıldı');
    return InkWell(
      onTap: () => _openGroupChat(chat),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.55),
                    AppColors.primaryGlow.withValues(alpha: 0.35),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.forum_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: unread > 0
                                ? FontWeight.w800
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatRelative(chat.lastMessageTime),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unread > 0
                                ? Colors.white.withValues(alpha: 0.78)
                                : Colors.white.withValues(alpha: 0.45),
                            fontSize: 12.5,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGroupChat(ChatModel chat) async {
    final activityId = chat.activityId;
    if (activityId == null || activityId.isEmpty) return;
    final activity = await ActivityService.instance.getActivity(activityId);
    if (!mounted) return;
    if (activity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.phrase('Etkinlik bulunamadı.')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityGroupChatScreen(
          activity: activity,
          chat: chat,
        ),
      ),
    );
  }

  // ─── Ana chat item ───
  Widget _buildChatItem(ChatModel chat) {
    final otherUid = chat.otherParticipant(_myUid);
    return FutureBuilder<UserModel?>(
      future: _getUser(otherUid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) return const SizedBox(height: 72);

        final name = user.hasProfile ? user.displayName : user.username;
        final unread = chat.myUnread(_myUid);
        final lastMsg = chat.lastMessage.isNotEmpty
            ? chat.lastMessage
            : context.l10n.phrase('Sohbet başlatıldı');
        final isMine = chat.lastSenderId == _myUid;

        return Dismissible(
          key: ValueKey(chat.id),
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 24),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.archive_rounded, color: AppColors.warning),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_rounded, color: AppColors.error),
          ),
          confirmDismiss: (dir) => _confirmDismiss(chat, dir),
          child: InkWell(
            onTap: () => _openChat(chat, user),
            onLongPress: () => _showChatActions(chat, user),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      _buildAvatar(user),
                      if (chat.isTemporary && !chat.isExpired)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.bgMain,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.schedule_rounded,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // İçerik
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight:
                                      unread > 0 ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Text(
                              _formatRelative(chat.lastMessageTime),
                              style: TextStyle(
                                color: unread > 0
                                    ? AppColors.primary
                                    : Colors.white.withValues(alpha: 0.35),
                                fontSize: 12,
                                fontWeight: unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isMine ? 'Sen: $lastMsg' : lastMsg,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: unread > 0
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : Colors.white.withValues(alpha: 0.45),
                                  fontSize: 13,
                                  fontWeight: unread > 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (unread > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  unread > 99 ? '99+' : '$unread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Long-press menü ───
  void _showChatActions(ChatModel chat, UserModel user) {
    final l10n = context.l10n;
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // User info header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildAvatar(user, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user.hasProfile ? user.displayName : user.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            _actionTile(
              icon: Icons.archive_outlined,
              label: l10n.phrase('Arşivle'),
              onTap: () {
                Navigator.pop(ctx);
                _firestoreService.setChatArchived(chat.id, true);
              },
            ),
            _actionTile(
              icon: Icons.person_rounded,
              label: l10n.phrase('Profili gör'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: user.uid),
                  ),
                );
              },
            ),
            _actionTile(
              icon: Icons.delete_outline_rounded,
              label: l10n.phrase('Sohbeti sil'),
              color: AppColors.error,
              onTap: () async {
                Navigator.pop(ctx);
                await _firestoreService.deleteChatForMe(chat.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
    );
  }

  // ─── İstek banner (Instagram tarzı) ───
  Widget _buildRequestsBanner(List<Map<String, dynamic>> requests) {
    if (requests.isEmpty) return const SizedBox.shrink();

    final firstUser = requests.first['user'] as UserModel;

    return InkWell(
      onTap: () => _openRequestsSheet(requests),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // Stacked avatars
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                children: [
                  _buildAvatar(firstUser, radius: 22),
                  if (requests.length > 1)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.bgMain,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${requests.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.phrase('Arkadaşlık İstekleri'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.formatPhrase(
                      '{count} yeni istek',
                      {'count': requests.length},
                    ),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  // ─── İstek sheet ───
  void _openRequestsSheet(List<Map<String, dynamic>> requests) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    context.l10n.phrase('Arkadaşlık İstekleri'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${requests.length}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: requests.length,
                itemBuilder: (_, i) {
                  final request = requests[i];
                  final user = request['user'] as UserModel;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProfileScreen(userId: user.uid),
                              ),
                            );
                          },
                          child: _buildAvatar(user, radius: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.hasProfile
                                    ? user.displayName
                                    : user.username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '@${user.username}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Kabul et
                        SizedBox(
                          height: 34,
                          child: FilledButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _respondToRequest(request, true);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              context.l10n.phrase('Kabul'),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Reddet
                        SizedBox(
                          height: 34,
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _respondToRequest(request, false);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              context.l10n.phrase('Sil'),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Arşiv banner ───
  Widget _buildArchivedBanner(List<ChatModel> archivedChats) {
    if (archivedChats.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: () => _openArchivedChats(archivedChats),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(
                Icons.archive_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.phrase('Arşivlenen Sohbetler'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${archivedChats.length} ${context.l10n.phrase('sohbet')}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  // ─── BUILD ───
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          context.tr3(tr: 'Mesajlar', en: 'Messages', de: 'Nachrichten'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.edit_square,
              color: Colors.white,
              size: 22,
            ),
            tooltip: context.tr3(
              tr: 'Yeni mesaj',
              en: 'New message',
              de: 'Neue Nachricht',
            ),
            onPressed: _openNewMessageSheet,
          ),
        ],
      ),
      body: _myUid.isEmpty
          ? Center(
              child: Text(
                context.l10n.phrase('Mesajları görmek için giriş gerekli.'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream:
                  _firestoreService.getPendingFriendRequestsDetailed(_myUid),
              builder: (context, requestSnapshot) {
                final requests = requestSnapshot.data ?? const [];
                return StreamBuilder<List<ChatModel>>(
                  stream: _firestoreService.getChats(_myUid),
                  builder: (context, chatSnapshot) {
                    if (chatSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !chatSnapshot.hasData) {
                      return ListView(
                        padding: const EdgeInsets.all(20),
                        children: List.generate(
                          5,
                          (_) => const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: ShimmerCard(),
                          ),
                        ),
                      );
                    }

                    final allChats = (chatSnapshot.data ?? const [])
                        .where((chat) => !chat.isExpired)
                        .toList();

                    final groupChats = allChats
                        .where((chat) =>
                            chat.isActivityGroup && !chat.isArchived)
                        .toList()
                      ..sort((a, b) {
                        final aTime = a.lastMessageTime ?? a.createdAt;
                        final bTime = b.lastMessageTime ?? b.createdAt;
                        if (aTime == null && bTime == null) return 0;
                        if (aTime == null) return 1;
                        if (bTime == null) return -1;
                        return bTime.compareTo(aTime);
                      });
                    final activeChats = allChats
                        .where((chat) =>
                            !chat.isArchived && !chat.isActivityGroup)
                        .toList();
                    final archivedChats = allChats
                        .where((chat) =>
                            chat.isArchived && !chat.isActivityGroup)
                        .toList();

                    if (requests.isEmpty &&
                        activeChats.isEmpty &&
                        groupChats.isEmpty &&
                        archivedChats.isEmpty) {
                      return Center(
                        child: EmptyStateCard(
                          icon: Icons.chat_bubble_outline_rounded,
                          message: context.l10n.phrase(
                            'Henüz mesajın yok. Yeni bir sohbet başlat!',
                          ),
                          actionLabel: context.l10n.phrase('Yeni Mesaj'),
                          onAction: _openNewMessageSheet,
                        ),
                      );
                    }

                    return RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.bgCard,
                      onRefresh: () async {
                        // Stream zaten canlı, sadece haptic
                        HapticFeedback.mediumImpact();
                      },
                      child: ListView(
                        children: [
                          // Arama çubuğu
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                            child: GestureDetector(
                              onTap: _openNewMessageSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.bgCard,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      color:
                                          Colors.white.withValues(alpha: 0.35),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      context.l10n.phrase('Ara...'),
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.35),
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Etkinlik özeti
                          const _InboxActivitiesStrip(),

                          // İstekler banner
                          _buildRequestsBanner(requests),

                          // Arşiv banner
                          _buildArchivedBanner(archivedChats),

                          if (requests.isNotEmpty || archivedChats.isNotEmpty)
                            Divider(
                              color: Colors.white.withValues(alpha: 0.06),
                              height: 1,
                              indent: 20,
                              endIndent: 20,
                            ),

                          // Grup sohbetleri
                          if (groupChats.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                              child: Text(
                                context.tr3(
                                  tr: 'Grup sohbetleri',
                                  en: 'Group chats',
                                  de: 'Gruppen-Chats',
                                ),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            ...groupChats.map(_buildGroupChatItem),
                          ],

                          // Mesaj başlığı
                          if (activeChats.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                              child: Text(
                                context.tr3(
                                  tr: 'Mesajlar',
                                  en: 'Messages',
                                  de: 'Nachrichten',
                                ),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),

                          // Chat listesi
                          ...activeChats.map(_buildChatItem),

                          const SizedBox(height: 80),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

// ─── Arşivlenmiş sohbetler ekranı ───
class _ArchivedChatsScreen extends StatelessWidget {
  final List<ChatModel> chats;
  final FirestoreService firestoreService;
  final String myUid;
  final Future<UserModel?> Function(String) getUser;
  final void Function(ChatModel, UserModel) openChat;
  final String Function(DateTime?) formatRelative;
  final Widget Function(UserModel, {double radius}) buildAvatar;
  final AppLocalizations l10n;

  const _ArchivedChatsScreen({
    required this.chats,
    required this.firestoreService,
    required this.myUid,
    required this.getUser,
    required this.openChat,
    required this.formatRelative,
    required this.buildAvatar,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.phrase('Arşivlenen Sohbetler'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: chats.isEmpty
          ? Center(
              child: EmptyStateCard(
                icon: Icons.archive_outlined,
                message: l10n.phrase('Arşivde sohbet yok.'),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final otherUid = chat.otherParticipant(myUid);
                return FutureBuilder<UserModel?>(
                  future: getUser(otherUid),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    if (user == null) return const SizedBox(height: 72);

                    final name =
                        user.hasProfile ? user.displayName : user.username;

                    return Dismissible(
                      key: ValueKey(chat.id),
                      direction: DismissDirection.startToEnd,
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 24),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.unarchive_rounded,
                          color: AppColors.success,
                        ),
                      ),
                      onDismissed: (_) {
                        firestoreService.setChatArchived(chat.id, false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text(l10n.phrase('Sohbet arşivden çıkarıldı')),
                            backgroundColor: AppColors.bgCard,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      child: InkWell(
                        onTap: () => openChat(chat, user),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              buildAvatar(user),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      chat.lastMessage.isNotEmpty
                                          ? chat.lastMessage
                                          : l10n.phrase('Sohbet başlatıldı'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.45),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatRelative(chat.lastMessageTime),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _InboxActivitiesStrip extends StatefulWidget {
  const _InboxActivitiesStrip();

  @override
  State<_InboxActivitiesStrip> createState() => _InboxActivitiesStripState();
}

class _InboxActivitiesStripState extends State<_InboxActivitiesStrip> {
  final ActivityService _service = ActivityService.instance;
  StreamSubscription<void>? _listSub;
  List<ActivityModel> _hosting = const [];
  List<ActivityModel> _joined = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    _listSub = _service.listChanged.listen((_) => _fetch());
  }

  @override
  void dispose() {
    _listSub?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final results = await Future.wait([
        _service.listHosting(),
        _service.listJoined(),
      ]);
      if (!mounted) return;
      setState(() {
        _hosting = results[0].items;
        _joined = results[1].items;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final pending = _joined
        .where((a) => a.viewerStatus == ActivityViewerStatus.requested)
        .toList();
    final approved = _joined
        .where((a) => a.viewerStatus == ActivityViewerStatus.approved)
        .toList();
    final upcoming = [..._hosting, ...approved]
        .where((a) => !a.isPast && !a.isCancelled)
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    if (upcoming.isEmpty && pending.isEmpty) return const SizedBox.shrink();

    final highlight = upcoming.isNotEmpty ? upcoming.first : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyActivitiesScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primaryGlow.withValues(alpha: 0.22),
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
                  Icons.event_rounded,
                  color: AppColors.primaryGlow,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Etkinliklerin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (pending.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${pending.length} bekleyen',
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      highlight != null
                          ? '${highlight.title} \u00b7 ${_inboxFormatWhen(highlight.startsAt.toLocal())}'
                          : '${pending.length} bekleyen istek',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hosting.isNotEmpty
                          ? '${_hosting.length} d\u00fczenliyorsun \u00b7 ${approved.length} onayl\u0131'
                          : '${approved.length} onayl\u0131 kat\u0131l\u0131m',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (highlight != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ActivityDetailScreen(
                          activityId: highlight.id,
                          initialActivity: highlight,
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white.withValues(alpha: 0.55),
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _inboxFormatWhen(DateTime startsAt) {
  final now = DateTime.now();
  final isSameDay = now.year == startsAt.year &&
      now.month == startsAt.month &&
      now.day == startsAt.day;
  final tomorrow = now.add(const Duration(days: 1));
  final isTomorrow = tomorrow.year == startsAt.year &&
      tomorrow.month == startsAt.month &&
      tomorrow.day == startsAt.day;
  final time =
      '${startsAt.hour.toString().padLeft(2, '0')}.${startsAt.minute.toString().padLeft(2, '0')}';
  if (isSameDay) return 'Bug\u00fcn $time';
  if (isTomorrow) return 'Yar\u0131n $time';
  return '${startsAt.day}.${startsAt.month.toString().padLeft(2, '0')} $time';
}
