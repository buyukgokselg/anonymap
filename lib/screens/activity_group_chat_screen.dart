import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/activity_model.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/colors.dart';
import '../widgets/animated_press.dart';
import '../widgets/app_snackbar.dart';

/// Group chat for an Activity.
///
/// Backend already creates one ChatThread per Activity (Kind = "activity")
/// and adds host + every approved participant. This screen reuses the
/// existing ChatThread message stream (FirestoreService.getMessages) but
/// renders it with a multi-author group layout — sender name on each
/// message bubble, simple input, no 1:1 typing indicators.
class ActivityGroupChatScreen extends StatefulWidget {
  const ActivityGroupChatScreen({
    super.key,
    required this.activity,
    required this.chat,
  });

  final ActivityModel activity;
  final ChatModel chat;

  @override
  State<ActivityGroupChatScreen> createState() =>
      _ActivityGroupChatScreenState();
}

class _ActivityGroupChatScreenState extends State<ActivityGroupChatScreen> {
  final _firestoreService = FirestoreService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<List<MessageModel>>? _messagesSub;
  List<MessageModel> _messages = const [];
  bool _isLoading = true;
  bool _isSending = false;

  String get _myUid => AuthService().currentUserId;
  String get _chatId => widget.chat.id;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_chatId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      await _firestoreService.markChatAsRead(_chatId, _myUid);
    } catch (e) {
      debugPrint('GroupChat markChatAsRead failed: $e');
    }
    _messagesSub = _firestoreService.getMessages(_chatId).listen(
          _handleMessages,
          onError: (Object error, StackTrace _) {
            debugPrint('GroupChat messages stream error: $error');
          },
        );
  }

  void _handleMessages(List<MessageModel> messages) {
    if (!mounted) return;
    final sorted = [...messages]..sort(
        (a, b) => (a.createdAt ?? DateTime(1970))
            .compareTo(b.createdAt ?? DateTime(1970)),
      );
    setState(() {
      _messages = sorted;
      _isLoading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || _chatId.isEmpty) return;
    final myUid = _myUid;
    if (myUid.isEmpty) return;

    setState(() => _isSending = true);
    HapticFeedback.lightImpact();
    try {
      await _firestoreService.sendMessage(
        _chatId,
        MessageModel(
          id: '',
          senderId: myUid,
          text: text,
          type: MessageType.text,
          createdAt: DateTime.now(),
        ),
      );
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Mesaj gönderilemedi: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.activity.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.activity.currentParticipantCount + 1} kişi · grup sohbeti',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessageList(),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.neonCyan.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: AppColors.neonCyan,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sohbet yeni',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Etkinlik öncesi tanışın, plan yapın, buluşmayı kolaylaştırın.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMine = msg.senderId == _myUid;
        final prev = index > 0 ? _messages[index - 1] : null;
        final showSender = !isMine &&
            (prev == null || prev.senderId != msg.senderId);
        return Padding(
          padding: EdgeInsets.only(top: showSender ? 12 : 4),
          child: _buildBubble(msg, isMine: isMine, showSender: showSender),
        );
      },
    );
  }

  Widget _buildBubble(
    MessageModel msg, {
    required bool isMine,
    required bool showSender,
  }) {
    final bubbleColor = isMine ? AppColors.primary : AppColors.bgCard;
    final textColor = isMine ? Colors.white : Colors.white;
    final senderName = msg.senderDisplayName.isEmpty
        ? 'Anonim'
        : msg.senderDisplayName;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isMine) ...[
          _avatar(msg.senderProfilePhotoUrl, senderName, visible: showSender),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showSender)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 3),
                  child: Text(
                    senderName,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(isMine ? 14 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 14),
                  ),
                  border: isMine
                      ? null
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                ),
                child: Text(
                  msg.text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar(String url, String name, {required bool visible}) {
    if (!visible) {
      return const SizedBox(width: 28);
    }
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bgChip,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        image: url.isNotEmpty
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: url.isNotEmpty
          ? null
          : Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(22),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Gruba yaz...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.34),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedPress(
              onTap: _isSending ? null : _send,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryGlow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
