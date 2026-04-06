import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;
  bool _otherTyping = false;
  bool _isTempChat = true;
  bool _friendRequestSent = false;
  bool _photoPermissionGranted = false;
  bool _photoPermissionPending = false;
  late DateTime _chatExpiry;

  final List<Map<String, dynamic>> _messages = [];

  final List<String> _quickMessages = [
    'Merhaba! 👋',
    'Nasılsın?',
    'Neredesin şu an?',
    'Buluşalım mı?',
    'İlgi alanların harika!',
  ];

  @override
  void initState() {
    super.initState();
    _chatExpiry = DateTime.now().add(const Duration(hours: 24));

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _messages.add({
            'text': 'Merhaba! 👋',
            'isMe': false,
            'time': _getCurrentTime(),
            'reaction': null,
            'status': 'read',
          });
        });
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? quickMsg]) {
    final text = quickMsg ?? _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();

    setState(() {
      _messages.add({
        'text': text,
        'isMe': true,
        'time': _getCurrentTime(),
        'reaction': null,
        'status': 'sent',
      });
      _isTyping = false;
    });

    if (quickMsg == null) _messageController.clear();
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _messages.last['status'] = 'delivered');
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _messages.last['status'] = 'read';
          _otherTyping = true;
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _otherTyping = false;
          _messages.add({
            'text': _getAutoReply(text),
            'isMe': false,
            'time': _getCurrentTime(),
            'reaction': null,
            'status': 'read',
          });
        });
        _scrollToBottom();
      }
    });
  }

  String _getAutoReply(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('merhaba') || lower.contains('hey') || lower.contains('selam')) return 'Hey! Nasılsın? 😊';
    if (lower.contains('nasıl')) return 'İyiyim teşekkürler! Sen nasılsın?';
    if (lower.contains('nerede')) return 'Sternschanze civarındayım, sen?';
    if (lower.contains('buluş')) return 'Olur, nerede buluşalım? ☕';
    if (lower.contains('ilgi')) return 'Teşekkürler! Seninkiler de çok güzel 🎵';
    if (lower.contains('konum')) return 'Teşekkürler, görüyorum! Yakınmışız 📍';
    if (lower.contains('fotoğraf') || lower.contains('foto')) return 'Güzel fotoğraf! 📸';
    return 'Harika! Devam et 😄';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _addReaction(int index, String emoji) {
    HapticFeedback.lightImpact();
    setState(() {
      _messages[index]['reaction'] = _messages[index]['reaction'] == emoji ? null : emoji;
    });
    Navigator.pop(context);
  }

  void _shareLocation() {
    HapticFeedback.mediumImpact();
    setState(() {
      _messages.add({
        'text': 'Mevcut konumumu paylaştım 📍',
        'isMe': true,
        'time': _getCurrentTime(),
        'reaction': null,
        'status': 'sent',
        'isLocation': true,
      });
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _messages.last['status'] = 'delivered');
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _messages.last['status'] = 'read');
    });
  }

  void _handlePhotoTap() {
    if (_photoPermissionGranted) {
      _sendPhoto();
      return;
    }

    if (_photoPermissionPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Fotoğraf izni bekleniyor. Karşı taraf henüz onaylamadı.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _photoPermissionPending = true;
      _messages.add({
        'text': 'Fotoğraf göndermek için izin istedi',
        'isMe': true,
        'time': _getCurrentTime(),
        'reaction': null,
        'status': 'sent',
        'isPhotoRequest': true,
        'photoApproved': false,
      });
    });
    _scrollToBottom();

    // Demo: karşı taraf 3 saniye sonra onaylıyor
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        setState(() {
          _photoPermissionPending = false;
          _photoPermissionGranted = true;
          final idx = _messages.lastIndexWhere((m) => m['isPhotoRequest'] == true && m['isMe'] == true);
          if (idx != -1) {
            _messages[idx]['status'] = 'read';
            _messages[idx]['photoApproved'] = true;
          }
          _messages.add({
            'text': 'Fotoğraf izni kabul edildi ✅ Artık fotoğraf gönderebilirsin.',
            'isMe': false,
            'time': _getCurrentTime(),
            'reaction': null,
            'status': 'read',
            'isSystemMessage': true,
          });
        });
        _scrollToBottom();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Fotoğraf izni onaylandı! Şimdi gönderebilirsin.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });
  }

  void _sendPhoto() {
    HapticFeedback.lightImpact();
    setState(() {
      _messages.add({
        'text': '📸 Fotoğraf gönderildi',
        'isMe': true,
        'time': _getCurrentTime(),
        'reaction': null,
        'status': 'sent',
        'isPhoto': true,
      });
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _messages.last['status'] = 'delivered');
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _messages.last['status'] = 'read');
    });
  }

  void _sendDisappearingMessage(String text) {
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _messages.add({
        'text': text,
        'isMe': true,
        'time': _getCurrentTime(),
        'reaction': null,
        'status': 'sent',
        'disappearing': true,
      });
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _messages.last['status'] = 'delivered');
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _messages.last['status'] = 'read');
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isAnon = user['anonymous'] == true;
    final color = user['color'] as Color;
    final name = isAnon ? 'Anonim Kullanıcı' : (user['name'] ?? 'Anonim');
    final compatibility = user['compatibility'] ?? 0;
    final interests = user['commonInterests'] as List<String>? ?? [];

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _showUserProfile,
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                  border: Border.all(color: color.withOpacity(0.4), width: 1.5),
                ),
                child: isAnon
                    ? Icon(Icons.person_rounded, size: 18, color: color.withOpacity(0.5))
                    : Center(child: Text(user['emoji'] ?? '🧑', style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                        if (isAnon) ...[const SizedBox(width: 4), Icon(Icons.visibility_off_rounded, size: 12, color: Colors.white.withOpacity(0.25))],
                      ],
                    ),
                    _otherTyping
                        ? const Text('yazıyor...', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w500))
                        : Text(user['dist'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: Icon(Icons.info_outline_rounded, color: Colors.white.withOpacity(0.4), size: 20), onPressed: _showUserProfile),
          IconButton(icon: Icon(Icons.more_vert_rounded, color: Colors.white.withOpacity(0.4), size: 20), onPressed: _showOptionsSheet),
        ],
      ),
      body: Column(
        children: [
          // Uyumluluk
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: AppColors.bgCard, border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_rounded, size: 12, color: AppColors.primary.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text('%$compatibility uyum', style: TextStyle(fontSize: 12, color: AppColors.primary.withOpacity(0.7), fontWeight: FontWeight.w600)),
                if (interests.isNotEmpty) ...[
                  Text('  ·  ', style: TextStyle(color: Colors.white.withOpacity(0.15))),
                  Flexible(child: Text(interests.take(3).join(', '), style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3)), overflow: TextOverflow.ellipsis)),
                ],
              ],
            ),
          ),

          if (_isTempChat) _buildExpiryBanner(),

          // Mesajlar
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyChat(name, color, isAnon)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _messages.length + (_otherTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_otherTyping && index == _messages.length) {
                        return _buildTypingIndicator(color, isAnon, user['emoji']);
                      }
                      return _buildMessageBubble(_messages[index], index, color, isAnon, user['emoji'] ?? '🧑');
                    },
                  ),
          ),

          // Hızlı mesajlar
          if (_messages.length <= 2)
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _quickMessages.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _sendMessage(_quickMessages[i]),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
                    child: Text(_quickMessages[i], style: TextStyle(fontSize: 13, color: AppColors.primary.withOpacity(0.8), fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ),

          // Mesaj girişi
          Container(
            padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
            decoration: BoxDecoration(color: AppColors.bgCard, border: Border(top: BorderSide(color: Colors.white.withOpacity(0.04)))),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showAttachmentOptions,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                    child: Icon(Icons.add_rounded, size: 22, color: Colors.white.withOpacity(0.3)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.bgChip, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.06))),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Mesaj yaz...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (v) {
                        final t = v.trim().isNotEmpty;
                        if (t != _isTyping) setState(() => _isTyping = t);
                      },
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isTyping ? () => _sendMessage() : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _isTyping ? AppColors.primary : Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      boxShadow: _isTyping ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12)] : null,
                    ),
                    child: Icon(
                      _isTyping ? Icons.send_rounded : Icons.mic_rounded,
                      size: 20,
                      color: _isTyping ? Colors.white : Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // MESAJ BALONU
  // ══════════════════════════════════════
  Widget _buildMessageBubble(Map<String, dynamic> msg, int index, Color userColor, bool isAnon, String emoji) {
    final isMe = msg['isMe'] as bool;
    final reaction = msg['reaction'] as String?;
    final isDisappearing = msg['disappearing'] == true;
    final isLocation = msg['isLocation'] == true;
    final isPhotoRequest = msg['isPhotoRequest'] == true;
    final isPhoto = msg['isPhoto'] == true;
    final isSystem = msg['isSystemMessage'] == true;
    final status = msg['status'] as String? ?? 'sent';

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12)),
            child: Text(msg['text'], style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w500)),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showReactionPicker(index),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: userColor.withOpacity(0.1),
                      border: Border.all(color: userColor.withOpacity(0.3), width: 1),
                    ),
                    child: isAnon
                        ? Icon(Icons.person_rounded, size: 14, color: userColor.withOpacity(0.4))
                        : Center(child: Text(emoji, style: const TextStyle(fontSize: 12))),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.primary : AppColors.bgCard,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      border: isMe ? null : Border.all(color: Colors.white.withOpacity(0.06)),
                      boxShadow: isMe ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 8)] : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isDisappearing)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.timer_rounded, size: 11, color: isMe ? Colors.white.withOpacity(0.6) : AppColors.warning.withOpacity(0.6)),
                              const SizedBox(width: 4),
                              Text('Kaybolan mesaj · 10sn', style: TextStyle(fontSize: 10, color: isMe ? Colors.white.withOpacity(0.6) : AppColors.warning.withOpacity(0.6), fontWeight: FontWeight.w500)),
                            ]),
                          ),
                        if (isLocation)
                          Container(
                            width: 180, height: 90,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.white.withOpacity(0.1) : AppColors.bgMain.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.location_on_rounded, size: 24, color: isMe ? Colors.white.withOpacity(0.7) : AppColors.primary.withOpacity(0.7)),
                              const SizedBox(height: 4),
                              Text('Mevcut Konum', style: TextStyle(fontSize: 11, color: isMe ? Colors.white.withOpacity(0.6) : Colors.white.withOpacity(0.5), fontWeight: FontWeight.w500)),
                              Text('53.5488° N, 9.9872° E', style: TextStyle(fontSize: 9, color: isMe ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.3))),
                            ]),
                          ),
                        if (isPhotoRequest)
                          Container(
                            width: 180, height: 100,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.white.withOpacity(0.1) : AppColors.bgMain.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(
                                msg['photoApproved'] == true ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                                size: 24,
                                color: msg['photoApproved'] == true ? AppColors.success : Colors.white.withOpacity(0.4),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg['photoApproved'] == true ? 'İzin Onaylandı' : 'Onay Bekleniyor...',
                                style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: msg['photoApproved'] == true ? AppColors.success : Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ]),
                          ),
                        if (isPhoto)
                          Container(
                            width: 180, height: 130,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.white.withOpacity(0.1) : AppColors.bgMain.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.image_rounded, size: 36, color: isMe ? Colors.white.withOpacity(0.5) : AppColors.modeSosyal.withOpacity(0.5)),
                              const SizedBox(height: 6),
                              Text('Fotoğraf', style: TextStyle(fontSize: 12, color: isMe ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.4), fontWeight: FontWeight.w500)),
                            ]),
                          ),
                        Text(msg['text'], style: TextStyle(fontSize: 15, color: isMe ? Colors.white : Colors.white.withOpacity(0.85), height: 1.4)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(left: isMe ? 0 : 34, top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (reaction != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.06))),
                      child: Text(reaction, style: const TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(msg['time'] ?? '', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.2))),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(status),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'sent':
        return Icon(Icons.check_rounded, size: 13, color: Colors.white.withOpacity(0.25));
      case 'delivered':
        return Icon(Icons.done_all_rounded, size: 13, color: Colors.white.withOpacity(0.25));
      case 'read':
        return const Icon(Icons.done_all_rounded, size: 13, color: AppColors.modeSosyal);
      default:
        return const SizedBox.shrink();
    }
  }

  // ══════════════════════════════════════
  // DİĞER WIDGETLAR
  // ══════════════════════════════════════

  Widget _buildEmptyChat(String name, Color color, bool isAnon) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.1), border: Border.all(color: color.withOpacity(0.2))),
          child: isAnon
              ? Icon(Icons.person_rounded, size: 32, color: color.withOpacity(0.4))
              : Center(child: Text(widget.user['emoji'] ?? '🧑', style: const TextStyle(fontSize: 32))),
        ),
        const SizedBox(height: 16),
        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 6),
        Text('Sohbete başla! İlk mesajını gönder.', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.35))),
      ]),
    );
  }

  Widget _buildTypingIndicator(Color color, bool isAnon, String? emoji) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.1), border: Border.all(color: color.withOpacity(0.3), width: 1)),
          child: isAnon
              ? Icon(Icons.person_rounded, size: 14, color: color.withOpacity(0.4))
              : Center(child: Text(emoji ?? '🧑', style: const TextStyle(fontSize: 12))),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4)),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) => Container(
              width: 7, height: 7,
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.2)),
            )),
          ),
        ),
      ]),
    );
  }

  Widget _buildExpiryBanner() {
    final remaining = _chatExpiry.difference(DateTime.now());
    final hours = remaining.inHours.clamp(0, 24);
    final minutes = (remaining.inMinutes % 60).clamp(0, 59);
    final isUrgent = hours < 6;
    final bannerColor = isUrgent ? AppColors.error : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: bannerColor.withOpacity(0.08), border: Border(bottom: BorderSide(color: bannerColor.withOpacity(0.15)))),
      child: Row(children: [
        Icon(Icons.schedule_rounded, size: 15, color: bannerColor.withOpacity(0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(text: TextSpan(style: TextStyle(fontSize: 12, color: bannerColor.withOpacity(0.8)), children: [
            TextSpan(text: '${hours}sa ${minutes}dk kaldı', style: const TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: ' · Arkadaş ekle veya sohbet silinecek'),
          ])),
        ),
        if (!_friendRequestSent)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _friendRequestSent = true);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Arkadaşlık isteği gönderildi!'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              child: const Text('Ekle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_rounded, size: 12, color: AppColors.success),
              SizedBox(width: 4),
              Text('Gönderildi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
            ]),
          ),
      ]),
    );
  }

  // ══════════════════════════════════════
  // EK SEÇENEKLERİ
  // ══════════════════════════════════════

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.06))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _attachOption(Icons.location_on_rounded, 'Konum', AppColors.success, () { Navigator.pop(context); _shareLocation(); }),
          _attachOption(Icons.timer_rounded, 'Kaybolan', AppColors.warning, () { Navigator.pop(context); _showDisappearingInput(); }),
          _attachOption(
            Icons.camera_alt_rounded,
            _photoPermissionGranted ? 'Fotoğraf ✓' : (_photoPermissionPending ? 'Bekleniyor' : 'Fotoğraf'),
            _photoPermissionGranted ? AppColors.success : (_photoPermissionPending ? AppColors.warning : AppColors.modeSosyal),
            () { Navigator.pop(context); _handlePhotoTap(); },
          ),
          _attachOption(Icons.mic_rounded, 'Sesli', AppColors.modeEglence, () { Navigator.pop(context); }),
        ]),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle), child: Icon(icon, size: 24, color: color)),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w500)),
      ]),
    );
  }

  void _showDisappearingInput() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.timer_rounded, size: 20, color: AppColors.warning),
          SizedBox(width: 8),
          Text('Kaybolan Mesaj', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Bu mesaj okunduktan 10 saniye sonra her iki tarafta da silinecek.', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4), height: 1.4)),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(color: AppColors.bgMain, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.06))),
            child: TextField(
              controller: ctrl, autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(hintText: 'Mesajını yaz...', hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)), border: InputBorder.none, contentPadding: const EdgeInsets.all(14)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('İptal', style: TextStyle(color: Colors.white.withOpacity(0.4)))),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) _sendDisappearingMessage(ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Gönder', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // REACTION PICKER
  // ══════════════════════════════════════

  void _showReactionPicker(int index) {
    HapticFeedback.mediumImpact();
    final reactions = ['❤️', '😂', '😮', '👍', '🔥', '😢'];
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: reactions.map((r) {
          final selected = _messages[index]['reaction'] == r;
          return GestureDetector(
            onTap: () => _addReaction(index, r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150), padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: selected ? AppColors.primary.withOpacity(0.2) : Colors.transparent, shape: BoxShape.circle),
              child: Text(r, style: const TextStyle(fontSize: 28)),
            ),
          );
        }).toList()),
      ),
    );
  }

  // ══════════════════════════════════════
  // SHEETS & DIALOGS
  // ══════════════════════════════════════

  void _showUserProfile() {
    final user = widget.user;
    final isAnon = user['anonymous'] == true;
    final color = user['color'] as Color;
    final name = isAnon ? 'Anonim Kullanıcı' : (user['name'] ?? 'Anonim');
    final interests = user['commonInterests'] as List<String>? ?? [];

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15), border: Border.all(color: color.withOpacity(0.3), width: 2)),
            child: isAnon
                ? Icon(Icons.person_rounded, size: 34, color: color.withOpacity(0.5))
                : Center(child: Text(user['emoji'] ?? '🧑', style: const TextStyle(fontSize: 34))),
          ),
          const SizedBox(height: 14),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          if (!isAnon && user['username'] != null) Text(user['username'], style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.4))),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _infoChip(Icons.location_on_rounded, user['dist'] ?? ''),
            const SizedBox(width: 12),
            _infoChip(Icons.favorite_rounded, 'Pulse ${user['pulse'] ?? 0}'),
            const SizedBox(width: 12),
            _infoChip(Icons.circle, user['mode'] ?? '', color: color),
          ]),
          if (user['bio'] != null && !isAnon) ...[
            const SizedBox(height: 14),
            Text(user['bio'], textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5), height: 1.4)),
          ],
          if (interests.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: interests.map((i) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.success.withOpacity(0.2))),
              child: Text(i, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
            )).toList()),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.favorite_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('%${user['compatibility'] ?? 0} Uyumluluk', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ]),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ]),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, {Color? color}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color ?? Colors.white.withOpacity(0.3)),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 12, color: color ?? Colors.white.withOpacity(0.4), fontWeight: FontWeight.w500)),
    ]);
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          _optionRow(Icons.person_add_rounded, 'Arkadaş Ekle', AppColors.modeSosyal, () => Navigator.pop(context)),
          _optionRow(Icons.notifications_off_rounded, 'Bildirimleri Kapat', Colors.white.withOpacity(0.5), () => Navigator.pop(context)),
          _optionRow(Icons.report_rounded, 'Şikayet Et', AppColors.warning, () { Navigator.pop(context); _showReportDialog(); }),
          _optionRow(Icons.block_rounded, 'Engelle', AppColors.error, () { Navigator.pop(context); _showBlockDialog(); }),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ]),
      ),
    );
  }

  Widget _optionRow(IconData icon, String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.bgMain.withOpacity(0.5), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [Icon(icon, size: 20, color: color), const SizedBox(width: 14), Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color))]),
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Şikayet Et', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700)),
        content: Text('Bu kullanıcıyı şikayet etmek istediğine emin misin?', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Vazgeç', style: TextStyle(color: Colors.white.withOpacity(0.4)))),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Şikayet Et', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    final name = widget.user['anonymous'] == true ? 'Bu kullanıcıyı' : widget.user['name'] ?? 'Bu kullanıcıyı';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Engelle', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$name engellenecek:', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          const SizedBox(height: 12),
          _blockInfo('Tüm mesajlar her iki tarafta kalıcı olarak silinir'),
          _blockInfo('Karşı taraf seni bir daha göremez'),
          _blockInfo('Uçtan uca şifreli log yasal süreçler için saklanır'),
          _blockInfo('72 saat içinde tüm yedeklerden temizlenir'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.bgMain.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.lock_rounded, size: 14, color: AppColors.primary.withOpacity(0.5)),
              const SizedBox(width: 8),
              Expanded(child: Text('Loglar uçtan uca şifrelidir. Mahkeme kararı olmadan kimse erişemez.', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3), height: 1.4))),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Vazgeç', style: TextStyle(color: Colors.white.withOpacity(0.4)))),
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('Engelle ve Sil', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _blockInfo(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary.withOpacity(0.5)),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45), height: 1.3))),
      ]),
    );
  }
}