import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../localization/app_localizations.dart';
import '../models/activity_model.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/network_media_headers.dart';
import '../services/storage_service.dart';
import '../theme/colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/activity/activity_category_meta.dart';
import 'activity_detail_screen.dart';
import 'create_activity_screen.dart';
import 'profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _locationService = LocationService();
  final _imagePicker = ImagePicker();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final Set<String> _readMessageIds = <String>{};

  Timer? _typingTimer;
  Timer? _expiryTimer;
  String? _chatId;
  UserModel? _otherUser;
  String _lastMessageSignature = '';
  bool _isBootstrapping = true;
  bool _isSending = false;
  bool _friendRequestSent = false;
  bool _typingActive = false;
  // Temporary chat permanence state
  bool _permanenceRequestSent = false;
  bool _permanenceRequestReceived = false; // other side requested
  Duration _timeRemaining = Duration.zero;
  DateTime? _expiresAt;

  String get _myUid => AuthService().currentUserId;
  String get _otherUid =>
      (widget.user['uid'] ?? widget.user['userId'] ?? '').toString();

  bool get _isAnonymousProfile => widget.user['anonymous'] == true;

  /// Radar'dan "Anonim" seçilerek açılan sohbette true olur.
  /// Chat ekranında küçük bir hint band gösterilir; kullanıcı
  /// hazır hissettiğinde "Kalıcı yap" akışıyla kimliğini açar.
  bool get _isMyAnonymous => widget.user['myAnonymous'] == true;

  String get _displayName {
    if (_isAnonymousProfile) {
      final raw = widget.user['name'] ?? context.l10n.phrase('Anonim Kullanıcı');
      return raw.toString().replaceFirst('@', '');
    }
    final streamed = _otherUser;
    if (streamed != null) {
      return streamed.hasProfile ? streamed.displayName : streamed.username;
    }
    final raw =
        widget.user['name'] ??
        widget.user['displayName'] ??
        widget.user['username'] ??
        context.l10n.t('user');
    return raw.toString().replaceFirst('@', '');
  }

  String get _username {
    if (_isAnonymousProfile) {
      final raw = (widget.user['username'] ?? '@anonymous').toString();
      return raw.startsWith('@') ? raw : '@$raw';
    }
    final streamed = _otherUser;
    if (streamed != null) {
      return '@${streamed.username}';
    }
    final raw = (widget.user['username'] ?? '').toString();
    return raw.startsWith('@') ? raw : '@$raw';
  }

  @override
  void initState() {
    super.initState();
    _chatId = widget.user['chatId']?.toString();
    _bootstrap();
    _messageController.addListener(_handleTypingChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _expiryTimer?.cancel();
    _messageController.removeListener(_handleTypingChanged);
    _messageController.dispose();
    _scrollController.dispose();
    if (_chatId != null && _myUid.isNotEmpty) {
      unawaited(
        _firestoreService.setTyping(_chatId!, _myUid, false).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint('Typing cleanup failed: $error\n$stackTrace');
        }),
      );
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_myUid.isEmpty || _otherUid.isEmpty) {
      if (mounted) {
        setState(() => _isBootstrapping = false);
      }
      return;
    }

    try {
      final futures = <Future<dynamic>>[
        _firestoreService.getUser(_otherUid),
        _chatId == null || _chatId!.isEmpty
            ? _firestoreService.createOrGetDirectChat(
                _myUid,
                _otherUid,
                isTemporary: widget.user['isTemporary'] == true,
              )
            : Future<ChatModel?>.value(null),
        _firestoreService.isFriend(_myUid, _otherUid),
      ];

      final results = await Future.wait(futures);
      final chat = results[1] as ChatModel?;

      if (!mounted) return;
      setState(() {
        _otherUser = results[0] as UserModel?;
        _chatId = _chatId ?? chat?.id;
        _friendRequestSent = results[2] as bool;
        _isBootstrapping = false;
      });

      if (_chatId != null) {
        await _firestoreService.markChatAsRead(_chatId!, _myUid);
      }
    } catch (e, st) {
      debugPrint('Chat bootstrap failed: $e\n$st');
      if (!mounted) return;
      setState(() => _isBootstrapping = false);
      _showSnackBar(context.l10n.phrase('Sohbet yüklenemedi.'), AppColors.error);
    }
  }

  void _handleTypingChanged() {
    final chatId = _chatId;
    if (chatId == null || _myUid.isEmpty) return;

    final shouldType = _messageController.text.trim().isNotEmpty;
    if (shouldType != _typingActive) {
      _typingActive = shouldType;
      _safeSetTyping(chatId, shouldType);
    }

    _typingTimer?.cancel();
    if (!shouldType) {
      return;
    }

    _typingTimer = Timer(const Duration(milliseconds: 900), () {
      if (!_typingActive) return;
      _typingActive = false;
      _safeSetTyping(chatId, false);
    });
  }

  void _safeSetTyping(String chatId, bool isTyping) {
    unawaited(
      _firestoreService.setTyping(chatId, _myUid, isTyping).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('Typing update failed: $error\n$stackTrace');
      }),
    );
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      try {
        if (animated) {
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(target);
        }
      } catch (_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(target);
        }
      }
    });
  }

  String _messageSignature(List<MessageModel> messages) {
    if (messages.isEmpty) return 'empty';
    final last = messages.last;
    return '${messages.length}:${last.id}:${last.createdAt?.millisecondsSinceEpoch ?? 0}';
  }

  Future<void> _sendText() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatId == null || _isSending) return;

    final message = MessageModel(
      id: '',
      senderId: _myUid,
      text: text,
      type: MessageType.text,
      status: MessageStatus.sent,
    );

    setState(() => _isSending = true);
    try {
      _scrollToBottom();
      await _firestoreService
          .sendMessage(_chatId!, message)
          .timeout(const Duration(seconds: 12));
      _messageController.clear();
      _typingActive = false;
      _safeSetTyping(_chatId!, false);
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Message send failed: $e');
      if (!mounted) return;
      _showSnackBar(
        context.l10n.phrase('Mesaj gönderilemedi.'),
        AppColors.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _sendLocation() async {
    if (_chatId == null) return;

    final position = await _locationService.getCurrentPosition();
    if (!mounted) return;
    if (position == null) {
      _showSnackBar(
        context.l10n.phrase('Konum izni gerekli.'),
        AppColors.warning,
      );
      return;
    }

    try {
      await _firestoreService.sendMessage(
        _chatId!,
        MessageModel(
          id: '',
          senderId: _myUid,
          text: context.l10n.phrase('Canlı konum paylaştı'),
          type: MessageType.location,
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Location share failed: $e');
      if (!mounted) return;
      _showSnackBar(
        context.l10n.phrase('Konum paylaşılamadı.'),
        AppColors.error,
      );
    }
  }

  Future<void> _shareProfile() async {
    if (_chatId == null) return;
    final l10n = context.l10n;

    final user = _otherUser;
    final currentUser = AuthService().currentUser;
    final myUsername =
        currentUser?.userName.isNotEmpty == true
            ? currentUser!.userName
            : context.l10n.phrase('kullanıcı');
    final myName = widget.user['myDisplayName']?.toString().trim();

    final parts = <String>[
      l10n.formatPhrase(
        '{name} profilini paylaştı.',
        {'name': myName?.isNotEmpty == true ? myName : myUsername},
      ),
      l10n.formatPhrase('Kullanıcı: @{username}', {'username': myUsername}),
    ];

    if (!_isAnonymousProfile && user != null && user.city.isNotEmpty) {
      parts.add(
        l10n.formatPhrase('Sohbet ettiğin kişi: {city}', {'city': user.city}),
      );
    }

    try {
      await _firestoreService.sendMessage(
        _chatId!,
        MessageModel(
          id: '',
          senderId: _myUid,
          text: parts.join('\n'),
          type: MessageType.system,
        ),
      );
      _showSnackBar(l10n.phrase('Profil kartı paylaşıldı.'), AppColors.success);
    } catch (e) {
      debugPrint('Profile share failed: $e');
      _showSnackBar(
        l10n.phrase('Profil paylaşımı başarısız.'),
        AppColors.error,
      );
    }
  }

  Future<void> _inviteToActivity() async {
    if (_chatId == null) return;
    final l10n = context.l10n;
    final created = await Navigator.of(context).push<ActivityModel>(
      MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
    );
    if (!mounted || created == null) return;

    final start = created.startsAt.toLocal();
    final whenLine =
        '${start.day}.${start.month.toString().padLeft(2, '0')} '
        '${start.hour.toString().padLeft(2, '0')}.${start.minute.toString().padLeft(2, '0')}';
    final inviteText = [
      '🎟️ ${created.title}',
      '$whenLine · ${created.locationName.isEmpty ? created.city : created.locationName}',
      '',
      l10n.phrase('Aramızda buluşalım mı?'),
    ].join('\n');

    try {
      await _firestoreService.sendMessage(
        _chatId!,
        MessageModel(
          id: '',
          senderId: _myUid,
          text: inviteText,
          activityInviteId: created.id,
          activityTitle: created.title,
          activityLocationName: created.locationName.isEmpty
              ? created.city
              : created.locationName,
          activityStartsAt: created.startsAt,
          activityCategory: activityCategoryWireValue(created.category),
        ),
      );
      _showSnackBar(l10n.phrase('Davet gönderildi.'), AppColors.success);
    } catch (e) {
      debugPrint('Activity invite failed: $e');
      _showSnackBar(
        l10n.phrase('Davet gönderilemedi.'),
        AppColors.error,
      );
    }
  }

  Future<void> _sendPostShare(PostModel post) async {
    if (_chatId == null) return;
    final l10n = context.l10n;

    final currentUser = AuthService().currentUser;
    final author = currentUser?.displayName.trim().isNotEmpty == true
        ? currentUser!.displayName.trim()
        : currentUser?.userName ?? context.l10n.phrase('kullanıcı');
    final mediaUrl = post.photoUrls.isNotEmpty
        ? post.photoUrls.first
        : (post.videoUrl ?? '');

    try {
      await _firestoreService.sendMessage(
        _chatId!,
        MessageModel(
          id: '',
          senderId: _myUid,
          text: post.text.trim(),
          type: MessageType.postShare,
          sharedPostId: post.id,
          sharedPostAuthor: author,
          sharedPostLocation: post.location,
          sharedPostVibe: post.vibeTag,
          sharedPostMediaUrl: mediaUrl.isEmpty ? null : mediaUrl,
        ),
      );
      _showSnackBar(l10n.phrase('Gönderi kartı paylaşıldı.'), AppColors.success);
    } catch (e) {
      debugPrint('Post share failed: $e');
      _showSnackBar(
        l10n.phrase('Gönderi paylaşımı başarısız.'),
        AppColors.error,
      );
    }
  }

  Future<void> _openPostShareSheet() async {
    if (_chatId == null || _myUid.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.phrase('Gönderi Paylaş'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                StreamBuilder<List<PostModel>>(
                  stream: _firestoreService.getUserPosts(_myUid),
                  builder: (context, snapshot) {
                    final posts = (snapshot.data ?? const [])
                        .where(
                          (post) =>
                              post.text.trim().isNotEmpty ||
                              post.photoUrls.isNotEmpty ||
                              (post.videoUrl?.isNotEmpty ?? false),
                        )
                        .take(8)
                        .toList();

                    if (posts.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          context.l10n.phrase('Paylaşacak bir gönderi yok.'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.48),
                          ),
                        ),
                      );
                    }

                    return SizedBox(
                      height: 360,
                      child: ListView.separated(
                        itemCount: posts.length,
                        separatorBuilder: (context, index) => Divider(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          final mediaUrl = post.photoUrls.isNotEmpty
                              ? post.photoUrls.first
                              : (post.videoUrl ?? '');

                          return ListTile(
                            onTap: () async {
                              Navigator.pop(context);
                              await _sendPostShare(post);
                            },
                            contentPadding: EdgeInsets.zero,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: mediaUrl.isEmpty
                                  ? Container(
                                      width: 56,
                                      height: 56,
                                      color: AppColors.primary.withValues(
                                        alpha: 0.14,
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.notes_rounded,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Image.network(
                                      mediaUrl,
                                      headers: NetworkMediaHeaders.forUrl(
                                        mediaUrl,
                                      ),
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 56,
                                        height: 56,
                                        color: AppColors.bgSurface,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.broken_image_rounded,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                            ),
                            title: Text(
                              post.text.trim().isEmpty
                                  ? (post.location.isNotEmpty
                                        ? post.location
                                        : context.l10n.phrase(
                                            'Medya gönderisi',
                                          ))
                                  : post.text.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (post.location.isNotEmpty) post.location,
                                if (post.vibeTag.isNotEmpty) post.vibeTag,
                              ].join(' - '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white54,
                              size: 16,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _requestChatPermanence() async {
    final chatId = _chatId;
    if (chatId == null || chatId.isEmpty || _permanenceRequestSent) return;
    setState(() => _permanenceRequestSent = true);
    try {
      final result = await _firestoreService.requestChatPermanence(chatId);
      if (!mounted) return;
      switch (result) {
        case 'accepted':
          _showSnackBar(
            context.l10n.phrase('Sohbet kalıcı hale getirildi! 🎉'),
            AppColors.success,
          );
        case 'pending':
          _showSnackBar(
            context.l10n.phrase('İstek gönderildi. Karşı taraf kabul ederse kalıcı olur.'),
            AppColors.primary,
          );
        case 'already_permanent':
          _showSnackBar(
            context.l10n.phrase('Sohbet zaten kalıcı.'),
            AppColors.success,
          );
        default:
          setState(() => _permanenceRequestSent = false);
          _showSnackBar(
            context.l10n.phrase('İstek gönderilemedi. Tekrar dene.'),
            AppColors.error,
          );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _permanenceRequestSent = false);
      _showSnackBar(context.l10n.phrase('Bir hata oluştu.'), AppColors.error);
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_friendRequestSent || _myUid.isEmpty || _otherUid.isEmpty) return;
    final l10n = context.l10n;

    try {
      await _firestoreService.sendFriendRequest(_myUid, _otherUid);
      if (!mounted) return;
      setState(() => _friendRequestSent = true);
      _showSnackBar(
        l10n.phrase('Arkadaşlık isteği gönderildi.'),
        AppColors.success,
      );
    } catch (e) {
      debugPrint('Friend request failed: $e');
      _showSnackBar(
        l10n.phrase('Arkadaşlık isteği gönderilemedi.'),
        AppColors.error,
      );
    }
  }

  Future<void> _pickAndSendMedia({required bool isVideo}) async {
    if (_chatId == null || _isSending) return;
    final l10n = context.l10n;

    final file = isVideo
        ? await _imagePicker.pickVideo(source: ImageSource.gallery)
        : await _imagePicker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    setState(() => _isSending = true);
    try {
      final extension = isVideo ? 'video' : 'image';
      final url = await _storageService.uploadXFile(
        file: file,
        path:
            'chat_media/${_chatId!}/${DateTime.now().millisecondsSinceEpoch}_$extension',
      );

      await _firestoreService.sendMessage(
        _chatId!,
        MessageModel(
          id: '',
          senderId: _myUid,
          text: isVideo
              ? l10n.phrase('Video paylaştı')
              : l10n.phrase('Fotoğraf paylaştı'),
          type: isVideo ? MessageType.video : MessageType.photo,
          photoUrl: isVideo ? null : url,
          videoUrl: isVideo ? url : null,
        ),
      );

      if (!mounted) return;
      _showSnackBar(
        isVideo
            ? l10n.phrase('Video gönderildi.')
            : l10n.phrase('Fotoğraf gönderildi.'),
        AppColors.success,
      );
    } catch (e) {
      debugPrint('Media send failed: $e');
      _showSnackBar(l10n.phrase('Medya gönderilemedi.'), AppColors.error);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showShareSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetAction(
                  icon: Icons.image_rounded,
                  label: context.l10n.phrase('Resim Paylaş'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendMedia(isVideo: false);
                  },
                ),
                _sheetAction(
                  icon: Icons.videocam_rounded,
                  label: context.l10n.phrase('Video Paylaş'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendMedia(isVideo: true);
                  },
                ),
                _sheetAction(
                  icon: Icons.location_on_rounded,
                  label: context.l10n.phrase('Konum Paylaş'),
                  onTap: () {
                    Navigator.pop(context);
                    _sendLocation();
                  },
                ),
                _sheetAction(
                  icon: Icons.dynamic_feed_rounded,
                  label: context.l10n.phrase('Gönderi Paylaş'),
                  onTap: () {
                    Navigator.pop(context);
                    _openPostShareSheet();
                  },
                ),
                _sheetAction(
                  icon: Icons.event_rounded,
                  label: context.l10n.phrase('Etkinliğe Davet Et'),
                  onTap: () {
                    Navigator.pop(context);
                    _inviteToActivity();
                  },
                ),
                _sheetAction(
                  icon: Icons.person_rounded,
                  label: context.l10n.phrase('Profil Paylaş'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareProfile();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showReactionPicker(MessageModel message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        const reactions = ['🔥', '❤️', '👏', '😂', '👀', '👍'];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: reactions
                  .map(
                    (emoji) => GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await _firestoreService.addReaction(
                          _chatId!,
                          message.id,
                          emoji,
                        );
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMessageActions(MessageModel message) async {
    if (_chatId == null) return;
    final isMine = message.senderId == _myUid;
    final hasText = message.text.trim().isNotEmpty;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!message.isDeleted)
                  _sheetAction(
                    icon: Icons.emoji_emotions_outlined,
                    label: context.l10n.phrase('Tepki ekle'),
                    onTap: () {
                      Navigator.pop(context, 'react');
                    },
                  ),
                if (hasText)
                  _sheetAction(
                    icon: Icons.copy_all_rounded,
                    label: context.l10n.phrase('Metni kopyala'),
                    onTap: () {
                      Navigator.pop(context, 'copy');
                    },
                  ),
                if (isMine && !message.isDeleted)
                  _sheetAction(
                    icon: Icons.undo_rounded,
                    label: context.l10n.phrase('Herkesten kaldır'),
                    onTap: () {
                      Navigator.pop(context, 'unsend');
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    switch (selected) {
      case 'react':
        _showReactionPicker(message);
        return;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.text));
        if (!mounted) return;
        _showSnackBar(context.l10n.phrase('Mesaj kopyalandı.'), AppColors.success);
        return;
      case 'unsend':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.bgCard,
            title: Text(
              context.l10n.phrase('Mesaj herkesten kaldırılsın mı?'),
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              context.l10n.phrase('Bu işlem geri alınamaz ve mesaj herkes için kaybolur.'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.l10n.phrase('İptal')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text(context.l10n.phrase('Kaldır')),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        try {
          await _firestoreService.deleteMessage(
            _chatId!,
            message.id,
            forEveryone: true,
          );
          if (!mounted) return;
          _showSnackBar(
            context.l10n.phrase('Mesaj herkesten kaldırıldı.'),
            AppColors.success,
          );
        } catch (error) {
          if (!mounted) return;
          _showSnackBar(
            context.l10n.phrase('Mesaj kaldırılamadı.'),
            AppColors.error,
          );
          debugPrint('Unsend failed: $error');
        }
        return;
    }
  }

  void _handleMessageEffects(List<MessageModel> messages) {
    if (_chatId == null || _myUid.isEmpty) return;
    final signature = _messageSignature(messages);
    final hasNewSnapshot = signature != _lastMessageSignature;
    if (hasNewSnapshot) {
      _lastMessageSignature = signature;
      _scrollToBottom(animated: messages.length > 1);
    }

    final incomingUnread = messages.where((message) {
      if (message.senderId == _myUid) return false;
      if (_readMessageIds.contains(message.id)) return false;
      return message.status != MessageStatus.read;
    }).toList();

    if (incomingUnread.isNotEmpty) {
      unawaited(_firestoreService.markChatAsRead(_chatId!, _myUid));
    }
    for (final message in incomingUnread) {
      _readMessageIds.add(message.id);
      unawaited(
        _firestoreService.updateMessageStatus(
          _chatId!,
          message.id,
          MessageStatus.read.name,
        ),
      );
    }
  }

  Color _bubbleColor(bool isMe, MessageModel message) {
    if (message.isSystem) return AppColors.warning.withValues(alpha: 0.14);
    return isMe ? AppColors.primary : AppColors.bgSurface;
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--:--';
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildMessageBubble(MessageModel message) {
    final isMe = message.senderId == _myUid;
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          GestureDetector(
            onLongPress: _chatId == null
                ? null
                : () => _showMessageActions(message),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 290),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _bubbleColor(isMe, message),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isMe
                      ? AppColors.primaryGlow.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: alignment,
                children: [
                  if (message.isPhoto && message.photoUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        message.photoUrl!,
                        headers: NetworkMediaHeaders.forUrl(message.photoUrl!),
                        height: 180,
                        width: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (message.isVideo && message.videoUrl != null)
                    Container(
                      width: 220,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.phrase('Video mesaji'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (message.isLocation)
                    Container(
                      width: 220,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.phrase('Canli konum'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${message.latitude?.toStringAsFixed(4)}, ${message.longitude?.toStringAsFixed(4)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (message.isActivityInvite)
                    _ActivityInvitePill(message: message),
                  if (message.isPostShare)
                    Container(
                      width: 220,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((message.sharedPostMediaUrl ?? '').isNotEmpty)
                            Image.network(
                              message.sharedPostMediaUrl!,
                              headers: NetworkMediaHeaders.forUrl(
                                message.sharedPostMediaUrl!,
                              ),
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 120,
                                color: AppColors.bgSurface,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.dynamic_feed_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        l10n.formatPhrase(
                                          '{author} gönderi paylaştı',
                                          {
                                            'author':
                                                message.sharedPostAuthor ??
                                                l10n.phrase('Bir kullanıcı'),
                                          },
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if ((message.sharedPostLocation ?? '')
                                        .isNotEmpty ||
                                    (message.sharedPostVibe ?? '')
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if ((message.sharedPostLocation ?? '')
                                          .isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.06,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            message.sharedPostLocation!,
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      if ((message.sharedPostVibe ?? '')
                                          .isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            message.sharedPostVibe!,
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (message.text.isNotEmpty && !message.isActivityInvite) ...[
                    if (message.isPhoto ||
                        message.isVideo ||
                        message.isLocation ||
                        message.isPostShare)
                      const SizedBox(height: 10),
                    Text(
                      message.text,
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: message.isSystem ? 0.88 : 1,
                        ),
                        fontStyle: message.isDeleted
                            ? FontStyle.italic
                            : FontStyle.normal,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.reaction != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    message.reaction!,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 11,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 6),
                Icon(
                  message.status == MessageStatus.read
                      ? Icons.done_all_rounded
                      : Icons.done_rounded,
                  size: 14,
                  color: message.status == MessageStatus.read
                      ? AppColors.success
                      : Colors.white.withValues(alpha: 0.35),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String text, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: _otherUid.isEmpty || _isAnonymousProfile
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: _otherUid),
                    ),
                  );
                },
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.16),
                backgroundImage:
                    !_isAnonymousProfile &&
                        _otherUser?.profilePhotoUrl.isNotEmpty == true
                    ? NetworkMediaHeaders.imageProvider(
                        _otherUser!.profilePhotoUrl,
                      )
                    : null,
                child:
                    _isAnonymousProfile ||
                        _otherUser?.profilePhotoUrl.isEmpty != false
                    ? Text(
                        _displayName.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StreamBuilder<ChatModel?>(
                  stream: _chatId == null
                      ? null
                      : _firestoreService.getChatStream(_chatId!),
                  builder: (context, snapshot) {
                    final typing = snapshot.data?.typing[_otherUid] == true;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          typing ? context.l10n.phrase('yazıyor...') : _username,
                          style: TextStyle(
                            color: typing
                                ? AppColors.success
                                : Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!_friendRequestSent)
            IconButton(
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Colors.white,
              ),
              onPressed: _sendFriendRequest,
            ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.white,
            ),
            onPressed: _showShareSheet,
          ),
        ],
      ),
      body: _isBootstrapping
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _chatId == null
          ? Center(
              child: Text(
                context.l10n.phrase('Sohbet açılamadı.'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            )
          : Column(
              children: [
                // Radar'dan anonim seçilerek girildiğinde gösterilen hint band.
                // "Kalıcı yap" akışı zaten alttaki temporary banner'da; bu band
                // kullanıcıya hangi modda olduğunu hatırlatır.
                if (_isMyAnonymous)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.modeSosyal.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.modeSosyal.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.theater_comedy_rounded,
                          size: 16,
                          color: AppColors.modeSosyal.withValues(alpha: 0.95),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.phrase(
                              'Anonim moddasın. Hazır hissettiğinde "Kalıcı yap" ile kimliğini açabilirsin.',
                            ),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.84),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                StreamBuilder<ChatModel?>(
                  stream: _firestoreService.getChatStream(_chatId!),
                  builder: (context, snapshot) {
                    final chat = snapshot.data;
                    // Sync expiry timer & permanence state from stream
                    if (chat != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        final newExpiry = chat.expiresAt;
                        if (newExpiry != _expiresAt) {
                          _expiresAt = newExpiry;
                          _expiryTimer?.cancel();
                          if (newExpiry != null && chat.isTemporary) {
                            _expiryTimer = Timer.periodic(
                              const Duration(seconds: 1),
                              (_) {
                                if (!mounted) return;
                                final rem = newExpiry.difference(DateTime.now());
                                setState(() => _timeRemaining = rem.isNegative ? Duration.zero : rem);
                              },
                            );
                          }
                        }
                        // Sync pending permanence from other side
                        final pendingFrom = chat.pendingFriendRequestFromUserId;
                        final otherRequested = pendingFrom != null && pendingFrom != _myUid;
                        if (otherRequested != _permanenceRequestReceived) {
                          setState(() => _permanenceRequestReceived = otherRequested);
                        }
                      });
                    }

                    if (chat?.isTemporary == true && chat?.expiresAt != null) {
                      final remaining = _expiresAt != null
                          ? _timeRemaining
                          : chat!.timeRemaining;
                      final hours = remaining.inHours;
                      final minutes = remaining.inMinutes.remainder(60);
                      final seconds = remaining.inSeconds.remainder(60);
                      final isUrgent = remaining.inHours < 1;
                      final timerColor = isUrgent ? AppColors.error : AppColors.warning;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: timerColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: timerColor.withValues(alpha: 0.22)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.timer_outlined, size: 15, color: timerColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isUrgent
                                        ? context.l10n.formatPhrase(
                                            'Geçici sohbet: {minutes} dk {seconds} sn kaldı',
                                            {'minutes': minutes, 'seconds': seconds},
                                          )
                                        : context.l10n.formatPhrase(
                                            'Geçici sohbet: {hours} sa {minutes} dk kaldı',
                                            {'hours': hours, 'minutes': minutes},
                                          ),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.86),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (!_permanenceRequestSent)
                                  GestureDetector(
                                    onTap: _requestChatPermanence,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        context.l10n.phrase('Kalıcı yap'),
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    context.l10n.phrase('İstek gönderildi'),
                                    style: TextStyle(
                                      color: AppColors.primary.withValues(alpha: 0.7),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Banner: other side requested permanence
                          if (_permanenceRequestReceived && !_permanenceRequestSent)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.handshake_rounded, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      context.l10n.phrase('Karşı taraf sohbeti kalıcı yapmak istiyor!'),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.86),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _requestChatPermanence,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        context.l10n.phrase('Kabul Et'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                Expanded(
                  child: StreamBuilder<List<MessageModel>>(
                    stream: _firestoreService.getMessages(_chatId!),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        debugPrint('Messages stream error: ${snapshot.error}');
                        return Center(
                          child: EmptyStateCard(
                            icon: Icons.wifi_off_rounded,
                            message: context.l10n.phrase(
                              'Mesajlar yüklenemedi. Bağlantını kontrol et.',
                            ),
                          ),
                        );
                      }

                      final messages = snapshot.data ?? const <MessageModel>[];
                      _handleMessageEffects(messages);

                      if (snapshot.connectionState == ConnectionState.waiting &&
                          messages.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }

                      if (messages.isEmpty) {
                        return EmptyStateCard(
                          icon: Icons.forum_rounded,
                          message: context.l10n.phrase(
                            'Mesajlaşma başlatmak için ilk mesajı gönder.',
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 8, bottom: 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(messages[index]);
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _showShareSheet,
                          icon: const Icon(
                            Icons.add_circle_rounded,
                            color: AppColors.primary,
                            size: 30,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendText(),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: context.l10n.phrase('Mesaj yaz...'),
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              filled: true,
                              fillColor: AppColors.bgSurface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _sendText,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: _isSending
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ActivityInvitePill extends StatelessWidget {
  const _ActivityInvitePill({required this.message});

  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    final id = message.activityInviteId;
    if (id == null || id.isEmpty) return const SizedBox.shrink();

    final cat = parseActivityCategory(message.activityCategory);
    final meta = ActivityCategoryMeta.of(cat);
    final title = (message.activityTitle ?? '').isNotEmpty
        ? message.activityTitle!
        : 'Etkinlik daveti';
    final loc = message.activityLocationName ?? '';
    final start = message.activityStartsAt;
    final whenLine = start != null ? _formatWhen(start.toLocal()) : '';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ActivityDetailScreen(activityId: id),
          ),
        );
      },
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: meta.color.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(meta.icon, color: meta.color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Etkinlik daveti',
                        style: TextStyle(
                          color: meta.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        meta.label,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            if (whenLine.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      whenLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (loc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      loc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Detay & katıl',
                    style: TextStyle(
                      color: meta.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: meta.color,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatWhen(DateTime startsAt) {
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
    if (isSameDay) return 'Bugün · $time';
    if (isTomorrow) return 'Yarın · $time';
    return '${startsAt.day}.${startsAt.month.toString().padLeft(2, '0')} · $time';
  }
}
