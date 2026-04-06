import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;
  bool _otherTyping = false;

  final List<Map<String, dynamic>> _messages = [];

  // Hızlı mesaj önerileri
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
    // Karşı taraftan otomatik merhaba
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _messages.add({
            'text': 'Merhaba! 👋',
            'isMe': false,
            'time': _getCurrentTime(),
            'reaction': null,
          });
        });
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
      });
      _isTyping = false;
    });

    if (quickMsg == null) _messageController.clear();
    _scrollToBottom();

    // Demo: karşı taraf yazıyor + cevap
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _otherTyping = true);
    });
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _otherTyping = false;
          _messages.add({
            'text': _getAutoReply(text),
            'isMe': false,
            'time': _getCurrentTime(),
            'reaction': null,
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
    return 'Harika! Devam et 😄';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
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
          onTap: () => _showUserProfile(),
          child: Row(
            children: [
              // Avatar
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
                        Flexible(
                          child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                        ),
                        if (isAnon) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.visibility_off_rounded, size: 12, color: Colors.white.withOpacity(0.25)),
                        ],
                      ],
                    ),
                    _otherTyping
                        ? Text('yazıyor...', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w500))
                        : Text(user['dist'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: Colors.white.withOpacity(0.4), size: 20),
            onPressed: () => _showUserProfile(),
          ),
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: Colors.white.withOpacity(0.4), size: 20),
            onPressed: () => _showOptionsSheet(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Uyumluluk Banner ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_rounded, size: 12, color: AppColors.primary.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text(
                  '%$compatibility uyum',
                  style: TextStyle(fontSize: 12, color: AppColors.primary.withOpacity(0.7), fontWeight: FontWeight.w600),
                ),
                if (interests.isNotEmpty) ...[
                  Text('  ·  ', style: TextStyle(color: Colors.white.withOpacity(0.15))),
                  Flexible(
                    child: Text(
                      interests.take(3).join(', '),
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Mesajlar ──
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
                      final msg = _messages[index];
                      return _buildMessageBubble(msg, index, color, isAnon, user['emoji'] ?? '🧑');
                    },
                  ),
          ),

          // ── Hızlı Mesajlar (ilk mesajda) ──
          if (_messages.length <= 2)
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _quickMessages.length,
                itemBuilder: (_, i) {
                  return GestureDetector(
                    onTap: () => _sendMessage(_quickMessages[i]),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Text(_quickMessages[i], style: TextStyle(fontSize: 13, color: AppColors.primary.withOpacity(0.8), fontWeight: FontWeight.w500)),
                    ),
                  );
                },
              ),
            ),

          // ── Mesaj Girişi ──
          Container(
            padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.04))),
            ),
            child: Row(
              children: [
                // Ek butonlar
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                    child: Icon(Icons.add_rounded, size: 22, color: Colors.white.withOpacity(0.3)),
                  ),
                ),
                const SizedBox(width: 8),
                // Input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgChip,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
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
                        final typing = v.trim().isNotEmpty;
                        if (typing != _isTyping) setState(() => _isTyping = typing);
                      },
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Gönder
                GestureDetector(
                  onTap: _sendMessage,
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

  // ── Boş Chat ──
  Widget _buildEmptyChat(String name, Color color, bool isAnon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
        ],
      ),
    );
  }

  // ── Mesaj Balonu ──
  Widget _buildMessageBubble(Map<String, dynamic> msg, int index, Color userColor, bool isAnon, String emoji) {
    final isMe = msg['isMe'] as bool;
    final reaction = msg['reaction'] as String?;

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
                    decoration: BoxDecoration(shape: BoxShape.circle, color: userColor.withOpacity(0.1), border: Border.all(color: userColor.withOpacity(0.3), width: 1)),
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
                    child: Text(msg['text'], style: TextStyle(fontSize: 15, color: isMe ? Colors.white : Colors.white.withOpacity(0.85), height: 1.4)),
                  ),
                ),
              ],
            ),
            // Reaction + Time
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
                  Text(msg['time'], style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.2))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Yazıyor Göstergesi ──
  Widget _buildTypingIndicator(Color color, bool isAnon, String? emoji) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
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
              children: List.generate(3, (i) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 600 + i * 200),
                  builder: (_, value, child) {
                    return Container(
                      width: 8, height: 8,
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15 + value * 0.15),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reaction Picker ──
  void _showReactionPicker(int index) {
    HapticFeedback.mediumImpact();
    final reactions = ['❤️', '😂', '😮', '👍', '🔥', '😢'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: reactions.map((r) {
              final isSelected = _messages[index]['reaction'] == r;
              return GestureDetector(
                onTap: () => _addReaction(index, r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(r, style: const TextStyle(fontSize: 28)),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── Kullanıcı Profili ──
  void _showUserProfile() {
    final user = widget.user;
    final isAnon = user['anonymous'] == true;
    final color = user['color'] as Color;
    final name = isAnon ? 'Anonim Kullanıcı' : (user['name'] ?? 'Anonim');
    final interests = user['commonInterests'] as List<String>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              if (!isAnon && user['username'] != null)
                Text(user['username'], style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.4))),
              const SizedBox(height: 12),
              // Info row
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _profileInfoChip(Icons.location_on_rounded, user['dist'] ?? ''),
                const SizedBox(width: 12),
                _profileInfoChip(Icons.favorite_rounded, 'Pulse ${user['pulse'] ?? 0}'),
                const SizedBox(width: 12),
                _profileInfoChip(Icons.circle, user['mode'] ?? '', color: color),
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
              // Uyumluluk
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
            ],
          ),
        );
      },
    );
  }

  Widget _profileInfoChip(IconData icon, String text, {Color? color}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color ?? Colors.white.withOpacity(0.3)),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 12, color: color ?? Colors.white.withOpacity(0.4), fontWeight: FontWeight.w500)),
    ]);
  }

  // ── Options Sheet ──
  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              _optionItem(Icons.person_add_rounded, 'Arkadaş Ekle', AppColors.modeSosyal, () => Navigator.pop(context)),
              _optionItem(Icons.notifications_off_rounded, 'Bildirimleri Kapat', Colors.white.withOpacity(0.5), () => Navigator.pop(context)),
              _optionItem(Icons.report_rounded, 'Şikayet Et', AppColors.warning, () { Navigator.pop(context); _showReportDialog(); }),
              _optionItem(Icons.block_rounded, 'Engelle', AppColors.error, () { Navigator.pop(context); _showBlockDialog(); }),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }

  Widget _optionItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.bgMain.withOpacity(0.5), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 14),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
        ]),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name engellenecek:', style: TextStyle(color: Colors.white.withOpacity(0.5))),
            const SizedBox(height: 12),
            _blockInfoRow('Tüm mesajlar her iki tarafta kalıcı olarak silinir'),
            _blockInfoRow('Karşı taraf seni bir daha göremez'),
            _blockInfoRow('Uçtan uca şifreli log yasal süreçler için saklanır'),
            _blockInfoRow('72 saat içinde tüm yedeklerden temizlenir'),
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
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Vazgeç', style: TextStyle(color: Colors.white.withOpacity(0.4)))),
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('Engelle ve Sil', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _blockInfoRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary.withOpacity(0.5)),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45), height: 1.3))),
      ]),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Şikayet Et', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700)),
        content: Text('Bu kullanıcıyı şikayet etmek istediğine emin misin? Ekibimiz inceleyecek.', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Vazgeç', style: TextStyle(color: Colors.white.withOpacity(0.4)))),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Şikayet Et', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}