import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../config/mode_config.dart';
import '../localization/app_localizations.dart';
import '../models/post_model.dart';
import '../models/shorts_feed_scope.dart';
import '../models/user_model.dart';
import '../screens/create_post_screen.dart';
import '../screens/profile_screen.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/network_media_headers.dart';
import '../services/place_focus_service.dart';
import '../theme/colors.dart';

class ShortsFeedView extends StatefulWidget {
  const ShortsFeedView({
    super.key,
    required this.scope,
    this.initialLatitude,
    this.initialLongitude,
    this.radiusKm = 4.5,
    this.take = 24,
    this.initialPosts,
    this.initialIndex = 0,
    this.topOverlayOffset = 0,
  });

  final ShortsFeedScope scope;
  final double? initialLatitude;
  final double? initialLongitude;
  final double radiusKm;
  final int take;
  final List<PostModel>? initialPosts;
  final int initialIndex;
  /// Extra top offset to avoid overlapping a parent header/AppBar.
  final double topOverlayOffset;

  @override
  State<ShortsFeedView> createState() => _ShortsFeedViewState();
}

class _ShortsFeedViewState extends State<ShortsFeedView> {
  final _firestoreService = FirestoreService();
  final _locationService = LocationService();
  late final PageController _pageController;

  List<PostModel>? _seededPosts;
  double? _latitude;
  double? _longitude;
  int _currentIndex = 0;

  AppLocalizations get _l10n => context.l10n;
  String get _myUid => AuthService().currentUserId;

  String _copy({
    required String tr,
    required String en,
    required String de,
  }) {
    return switch (_l10n.languageCode) {
      'en' => en,
      'de' => de,
      _ => tr,
    };
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _seededPosts = widget.initialPosts == null
        ? null
        : List<PostModel>.from(widget.initialPosts!);
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
    _currentIndex = widget.initialIndex.clamp(0, 1000);
    if (widget.initialPosts == null &&
        (_latitude == null || _longitude == null)) {
      unawaited(_loadLocation());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (!mounted || position == null) return;
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
    });
  }

  Future<void> _toggleLike(PostModel post) async {
    if (_myUid.isEmpty) return;
    await _firestoreService.toggleLike(post.id, _myUid);
  }

  Future<void> _toggleSave(PostModel post) async {
    if (_myUid.isEmpty) return;
    await _firestoreService.toggleSavePost(post.id, _myUid);
  }

  Future<void> _sharePost(PostModel post) async {
    final author = post.userDisplayName.isNotEmpty
        ? post.userDisplayName
        : _l10n.t('user');
    final text = [
      '$author ${_l10n.t('posts')}',
      if (post.text.isNotEmpty) post.text,
      if (post.location.isNotEmpty) '${_l10n.phrase('Konum')}: ${post.location}',
      if (post.userMode.isNotEmpty)
        '${_l10n.phrase('Mod')}: ${_l10n.modeLabel(post.userMode)}',
    ].join('\n');

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: '$author ${_l10n.t('shorts_scope_global')}',
        ),
      );
    } catch (_) {}
  }

  Future<void> _editOwnedPost(PostModel post) async {
    final session = AuthService().currentUser;
    if (session == null || post.userId != _myUid) return;

    final currentUser = UserModel(
      uid: session.userId,
      email: session.email,
      userName: session.userName,
      displayName: session.displayName,
      profilePhotoUrl: session.profilePhotoUrl,
      mode: session.mode,
    );

    final didUpdate = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          kind: post.type == 'short'
              ? CreatePostKind.short
              : CreatePostKind.post,
          currentUser: currentUser,
          initialPost: post,
        ),
        fullscreenDialog: true,
      ),
    );
    if (didUpdate != true || !mounted) return;
  }

  Future<void> _deleteOwnedPost(PostModel post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          post.type == 'short'
              ? _l10n.phrase('Bu short silinsin mi?')
              : _l10n.phrase('Bu gönderi silinsin mi?'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          _l10n.phrase('Bu işlem geri alınamaz.'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(_l10n.phrase('Sil')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await _firestoreService.deletePost(post.id, _myUid);
    if (!mounted || !success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.phrase('Silme işlemi tamamlanamadı.')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_seededPosts != null) {
      var shouldClose = false;
      setState(() {
        _seededPosts!.removeWhere((entry) => entry.id == post.id);
        if (_seededPosts!.isEmpty) {
          shouldClose = true;
          return;
        }
        _currentIndex = _currentIndex.clamp(0, _seededPosts!.length - 1);
      });
      if (shouldClose && mounted) {
        Navigator.of(context).maybePop();
      }
    }
  }

  Widget _buildOwnerMenu(PostModel post) {
    return PopupMenuButton<String>(
      tooltip: _l10n.phrase('İçerik seçenekleri'),
      color: AppColors.bgCard,
      icon: Icon(
        Icons.more_horiz_rounded,
        color: Colors.white.withValues(alpha: 0.88),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          unawaited(_editOwnedPost(post));
          return;
        }
        if (value == 'delete') {
          unawaited(_deleteOwnedPost(post));
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'edit',
          child: Text(_l10n.phrase('Düzenle')),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(_l10n.phrase('Sil')),
        ),
      ],
    );
  }

  Future<void> _copyCommentText(String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _copy(
            tr: 'Yorum panoya kopyalandı.',
            en: 'Comment copied to clipboard.',
            de: 'Kommentar wurde in die Zwischenablage kopiert.',
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _editComment(PostModel post, Map<String, dynamic> comment) async {
    final commentId = comment['id']?.toString() ?? '';
    final initialText = comment['text']?.toString().trim() ?? '';
    if (commentId.isEmpty || initialText.isEmpty || _myUid.isEmpty) return;

    final controller = TextEditingController(text: initialText);
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _copy(
            tr: 'Yorumu düzenle',
            en: 'Edit comment',
            de: 'Kommentar bearbeiten',
          ),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 2,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: _copy(
              tr: 'Yorum yaz...',
              en: 'Write a comment...',
              de: 'Kommentar schreiben...',
            ),
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.32)),
            filled: true,
            fillColor: AppColors.bgMain,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_copy(tr: 'Vazgeç', en: 'Cancel', de: 'Abbrechen')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(_copy(tr: 'Kaydet', en: 'Save', de: 'Speichern')),
          ),
        ],
      ),
    );

    final nextText = controller.text.trim();
    controller.dispose();

    if (submitted != true || nextText.isEmpty || nextText == initialText) return;

    final updated = await _firestoreService.updatePostComment(
      post.id,
      commentId,
      _myUid,
      nextText,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated != null
              ? _copy(
                  tr: 'Yorum güncellendi.',
                  en: 'Comment updated.',
                  de: 'Kommentar aktualisiert.',
                )
              : _copy(
                  tr: 'Yorum güncellenemedi.',
                  en: 'Comment could not be updated.',
                  de: 'Kommentar konnte nicht aktualisiert werden.',
                ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: updated != null ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _deleteComment(PostModel post, Map<String, dynamic> comment) async {
    final commentId = comment['id']?.toString() ?? '';
    if (commentId.isEmpty || _myUid.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _copy(
            tr: 'Bu yorum silinsin mi?',
            en: 'Delete this comment?',
            de: 'Diesen Kommentar löschen?',
          ),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          _copy(
            tr: 'Bu işlem geri alınamaz.',
            en: 'This action cannot be undone.',
            de: 'Diese Aktion kann nicht rückgängig gemacht werden.',
          ),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_copy(tr: 'Vazgeç', en: 'Cancel', de: 'Abbrechen')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(_copy(tr: 'Sil', en: 'Delete', de: 'Löschen')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final deleted = await _firestoreService.deletePostComment(
      post.id,
      commentId,
      _myUid,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? _copy(
                  tr: 'Yorum silindi.',
                  en: 'Comment deleted.',
                  de: 'Kommentar gelöscht.',
                )
              : _copy(
                  tr: 'Yorum silinemedi.',
                  en: 'Comment could not be deleted.',
                  de: 'Kommentar konnte nicht gelöscht werden.',
                ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: deleted ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _reportCommentUser(Map<String, dynamic> comment) async {
    final targetUid = comment['userId']?.toString() ?? '';
    final commentText = comment['text']?.toString().trim() ?? '';
    if (_myUid.isEmpty || targetUid.isEmpty || targetUid == _myUid) return;

    final detailsCtrl = TextEditingController();
    String reason = 'Inappropriate content';

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _copy(
            tr: 'Kullanıcıyı şikayet et',
            en: 'Report user',
            de: 'Nutzer melden',
          ),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                dropdownColor: AppColors.bgSurface,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bgMain,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Harassment',
                    child: Text(
                      _copy(
                        tr: 'Rahatsız edici davranış',
                        en: 'Harassment',
                        de: 'Belästigendes Verhalten',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Fake profile',
                    child: Text(
                      _copy(
                        tr: 'Sahte profil',
                        en: 'Fake profile',
                        de: 'Fake-Profil',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Inappropriate content',
                    child: Text(
                      _copy(
                        tr: 'İstenmeyen içerik',
                        en: 'Inappropriate content',
                        de: 'Unangemessener Inhalt',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Safety concern',
                    child: Text(
                      _copy(
                        tr: 'Güvenlik endişesi',
                        en: 'Safety concern',
                        de: 'Sicherheitsbedenken',
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => reason = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsCtrl,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _copy(
                    tr: 'Kısa bir not ekleyebilirsin',
                    en: 'You can add a short note',
                    de: 'Du kannst eine kurze Notiz hinzufügen',
                  ),
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  filled: true,
                  fillColor: AppColors.bgMain,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_copy(tr: 'Vazgeç', en: 'Cancel', de: 'Abbrechen')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: Text(_copy(tr: 'Gönder', en: 'Send', de: 'Senden')),
          ),
        ],
      ),
    );

    if (submitted != true) {
      detailsCtrl.dispose();
      return;
    }

    try {
      final details = [
        if (detailsCtrl.text.trim().isNotEmpty) detailsCtrl.text.trim(),
        if (commentText.isNotEmpty) 'Comment: $commentText',
      ].join('\n\n');

      await _firestoreService.createUserReport(
        reporterUid: _myUid,
        targetUid: targetUid,
        reason: reason,
        details: details,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              tr: 'Şikayet kaydı oluşturuldu.',
              en: 'Report submitted.',
              de: 'Meldung wurde erstellt.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e, st) {
      debugPrint('Comment report failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              tr: 'Şikayet gönderilemedi.',
              en: 'Report could not be sent.',
              de: 'Meldung konnte nicht gesendet werden.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      detailsCtrl.dispose();
    }
  }

  Widget _buildCommentMenu(PostModel post, Map<String, dynamic> comment) {
    final commenterUid = comment['userId']?.toString() ?? '';
    final isMine = commenterUid.isNotEmpty && commenterUid == _myUid;
    final commentText = comment['text']?.toString() ?? '';

    return PopupMenuButton<String>(
      color: AppColors.bgSurface,
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 20,
        color: Colors.white.withValues(alpha: 0.42),
      ),
      onSelected: (value) {
        switch (value) {
          case 'copy':
            unawaited(_copyCommentText(commentText));
            return;
          case 'edit':
            unawaited(_editComment(post, comment));
            return;
          case 'delete':
            unawaited(_deleteComment(post, comment));
            return;
          case 'report':
            unawaited(_reportCommentUser(comment));
            return;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'copy',
          child: Text(_copy(tr: 'Kopyala', en: 'Copy', de: 'Kopieren')),
        ),
        if (isMine)
          PopupMenuItem<String>(
            value: 'edit',
            child: Text(_copy(tr: 'Düzenle', en: 'Edit', de: 'Bearbeiten')),
          ),
        if (isMine)
          PopupMenuItem<String>(
            value: 'delete',
            child: Text(_copy(tr: 'Sil', en: 'Delete', de: 'Löschen')),
          ),
        if (!isMine && commenterUid.isNotEmpty)
          PopupMenuItem<String>(
            value: 'report',
            child: Text(_copy(tr: 'Şikayet Et', en: 'Report', de: 'Melden')),
          ),
      ],
    );
  }

  Future<void> _openCommentsSheet(PostModel post) async {
    final controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.84,
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    _l10n.t('comments'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${post.commentsCount}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _firestoreService.getPostComments(post.id),
                  builder: (context, snapshot) {
                    final comments = snapshot.data ?? const [];
                    if (comments.isEmpty) {
                      return Center(
                        child: Text(
                          _l10n.phrase('İlk yorumu sen yaz.'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.38),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: comments.length,
                      separatorBuilder: (context, index) => Divider(
                        color: Colors.white.withValues(alpha: 0.05),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final title =
                            comment['userDisplayName']?.toString().trim().isNotEmpty == true
                            ? comment['userDisplayName']!.toString()
                            : _l10n.t('user');
                        final avatarUrl =
                            comment['userProfilePhotoUrl']?.toString() ?? '';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.14,
                            ),
                            backgroundImage: avatarUrl.isNotEmpty
                                ? NetworkMediaHeaders.imageProvider(avatarUrl)
                                : null,
                            child: avatarUrl.isEmpty
                                ? Text(
                                    title.characters.first.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          trailing: _buildCommentMenu(post, comment),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              comment['text']?.toString() ?? '',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                height: 1.45,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: _l10n.phrase('Yorum yaz'),
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                        filled: true,
                        fillColor: AppColors.bgMain,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
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
                  FilledButton(
                    onPressed: () async {
                      final text = controller.text.trim();
                      if (text.isEmpty || _myUid.isEmpty) return;
                      await _firestoreService.addPostComment(post.id, _myUid, text);
                      controller.clear();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(54, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDistance(double? meters) {
    if (meters == null) {
      return _l10n.phrase('Şehir geneli');
    }
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  ModeConfig? _modeConfigFor(String modeId) {
    final index = ModeConfig.all.indexWhere((entry) => entry.id == modeId);
    if (index < 0) return null;
    return ModeConfig.all[index];
  }

  List<_ShortsChipData> _buildScopeChips(PostModel post) {
    final chips = <_ShortsChipData>[
      _ShortsChipData(
        label: widget.scope.isPersonal
            ? _l10n.t('shorts_scope_personal')
            : _l10n.t('shorts_scope_global'),
        color: widget.scope.isPersonal
            ? AppColors.modeSosyal
            : AppColors.primary,
        icon: widget.scope.isPersonal
            ? Icons.auto_awesome_rounded
            : Icons.public_rounded,
      ),
    ];

    final modeConfig = _modeConfigFor(post.userMode);
    if (modeConfig != null) {
      chips.add(
        _ShortsChipData(
          label: _l10n.modeLabel(modeConfig.id),
          color: modeConfig.color,
          icon: modeConfig.icon,
        ),
      );
    }

    chips.add(
      _ShortsChipData(
        label: _formatDistance(post.distanceMeters),
        color: Colors.white,
        icon: Icons.place_rounded,
      ),
    );

    return chips;
  }

  String _resolveAuthor(PostModel post) {
    if (post.userDisplayName.trim().isNotEmpty) {
      return post.userDisplayName.trim();
    }
    return _l10n.t('user');
  }

  void _openAuthorProfile(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(userId: post.userId),
      ),
    );
  }

  Future<void> _focusPlace(PostModel post) async {
    if (post.placeId.isEmpty && post.location.trim().isEmpty) {
      return;
    }
    await PlaceFocusService.instance.focusPlace(
      placeId: post.placeId,
      placeName: post.location,
      latitude: post.lat,
      longitude: post.lng,
    );
  }

  Widget _buildEmptyState() {
    final title = widget.scope.isPersonal
        ? _l10n.t('shorts_personal_empty')
        : _l10n.t('shorts_global_empty');
    final subtitle = widget.scope.isPersonal
        ? _l10n.t('shorts_personal_subtitle')
        : _l10n.t('shorts_global_subtitle');

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.smart_display_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _copy(
                tr: 'Shorts yüklenemedi',
                en: 'Could not load shorts',
                de: 'Shorts konnten nicht geladen werden',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _copy(
                tr: 'Bağlantını kontrol et ve tekrar dene.',
                en: 'Check your connection and try again.',
                de: 'Überprüfe deine Verbindung und versuche es erneut.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => setState(() {}),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _copy(
                    tr: 'Tekrar Dene',
                    en: 'Try Again',
                    de: 'Erneut versuchen',
                  ),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final resolvedColor = color ?? Colors.white;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, color: resolvedColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildShortCard(PostModel post, {required bool active}) {
    final author = _resolveAuthor(post);
    final scopeChips = _buildScopeChips(post);

    return Stack(
      fit: StackFit.expand,
      children: [
        _ShortsMediaStage(
          imageUrls: post.photoUrls,
          videoUrl: post.videoUrl,
          active: active,
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x22000000),
                Colors.transparent,
                Color(0xCC000000),
              ],
            ),
          ),
        ),
        Positioned(
          top: 18 + widget.topOverlayOffset,
          left: 16,
          right: 90,
          child: SafeArea(
            bottom: false,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: scopeChips
                  .map(
                    (chip) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: chip.color.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(chip.icon, size: 13, color: chip.color),
                          const SizedBox(width: 6),
                          Text(
                            chip.label,
                            style: TextStyle(
                              color: chip.color == Colors.white
                                  ? Colors.white
                                  : chip.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        Positioned(
          top: 24 + widget.topOverlayOffset,
          right: 16,
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (post.userId == _myUid) _buildOwnerMenu(post),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.26),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _l10n.relativeShort(
                      DateTime.now().difference(post.createdAt ?? DateTime.now()),
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 118,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _buildActionButton(
                  icon: post.isLikedBy(_myUid)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '${post.likesCount}',
                  onTap: () => _toggleLike(post),
                  color: post.isLikedBy(_myUid)
                      ? AppColors.primary
                      : Colors.white,
                ),
                const SizedBox(height: 14),
                _buildActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${post.commentsCount}',
                  onTap: () => _openCommentsSheet(post),
                ),
                const SizedBox(height: 14),
                _buildActionButton(
                  icon: post.savedByCurrentUser
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: _l10n.phrase('Kaydet'),
                  onTap: () => _toggleSave(post),
                ),
                const SizedBox(height: 14),
                _buildActionButton(
                  icon: Icons.ios_share_rounded,
                  label: _l10n.phrase('Paylaş'),
                  onTap: () => _sharePost(post),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 92,
          bottom: 28,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _openAuthorProfile(post),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.14,
                        ),
                        backgroundImage: post.userProfilePhotoUrl.isNotEmpty
                            ? NetworkMediaHeaders.imageProvider(
                                post.userProfilePhotoUrl,
                              )
                            : null,
                        child: post.userProfilePhotoUrl.isEmpty
                            ? Text(
                                author.characters.first.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.location.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _focusPlace(post),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.place_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              post.location,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (post.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    post.text.trim(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 15,
                      height: 1.38,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final seededPosts = _seededPosts;
    if (seededPosts != null) {
      if (seededPosts.isEmpty) {
        return _buildEmptyState();
      }
      if (_currentIndex >= seededPosts.length) {
        _currentIndex = seededPosts.length - 1;
      }
      return PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: seededPosts.length,
        onPageChanged: (index) {
            if (mounted) setState(() => _currentIndex = index);
          },
        itemBuilder: (context, index) =>
            _buildShortCard(seededPosts[index], active: index == _currentIndex),
      );
    }

    return StreamBuilder<List<PostModel>>(
      stream: _firestoreService.getShortsFeed(
        scope: widget.scope,
        latitude: _latitude,
        longitude: _longitude,
        radiusKm: widget.radiusKm,
        take: widget.take,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError && !snapshot.hasData) {
          return _buildErrorState();
        }

        final posts = snapshot.data ?? const <PostModel>[];
        if (posts.isEmpty) {
          return _buildEmptyState();
        }

        if (_currentIndex >= posts.length) {
          _currentIndex = posts.length - 1;
        }

        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: posts.length,
          onPageChanged: (index) {
            if (mounted) setState(() => _currentIndex = index);
          },
          itemBuilder: (context, index) =>
              _buildShortCard(posts[index], active: index == _currentIndex),
        );
      },
    );
  }
}

class _ShortsChipData {
  const _ShortsChipData({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

class _ShortsMediaStage extends StatefulWidget {
  const _ShortsMediaStage({
    required this.imageUrls,
    required this.videoUrl,
    required this.active,
  });

  final List<String> imageUrls;
  final String? videoUrl;
  final bool active;

  @override
  State<_ShortsMediaStage> createState() => _ShortsMediaStageState();
}

class _ShortsMediaStageState extends State<_ShortsMediaStage> {
  VideoPlayerController? _controller;
  Future<void>? _initialization;

  bool get _hasVideo => widget.videoUrl != null && widget.videoUrl!.isNotEmpty;
  String get _imageUrl => widget.imageUrls.isNotEmpty ? widget.imageUrls.first : '';

  @override
  void initState() {
    super.initState();
    _configureController();
  }

  @override
  void didUpdateWidget(covariant _ShortsMediaStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _configureController();
    } else {
      _syncPlayback();
    }
  }

  void _configureController() {
    if (!_hasVideo) return;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl!),
      httpHeaders: NetworkMediaHeaders.forUrl(widget.videoUrl!) ?? const {},
    );
    controller
      ..setLooping(true)
      ..setVolume(0);
    _controller = controller;
    _initialization = controller.initialize().then((_) {
      if (!mounted) return;
      _syncPlayback();
      setState(() {});
    });
  }

  void _syncPlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.active) {
      unawaited(controller.play());
    } else {
      unawaited(controller.pause());
    }
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    _initialization = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasVideo && _controller != null) {
      return FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _controller!.value.isInitialized) {
            return FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            );
          }

          return _imageUrl.isNotEmpty
              ? Image.network(
                  _imageUrl,
                  headers: NetworkMediaHeaders.forUrl(_imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildFallback(),
                )
              : _buildFallback(showLoader: true);
        },
      );
    }

    if (_imageUrl.isNotEmpty) {
      return Image.network(
        _imageUrl,
        headers: NetworkMediaHeaders.forUrl(_imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    }

    return _buildFallback();
  }

  Widget _buildFallback({bool showLoader = false}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF131428), Color(0xFF090A14)],
        ),
      ),
      child: Center(
        child: showLoader
            ? const CircularProgressIndicator(color: AppColors.primary)
            : Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
      ),
    );
  }
}
