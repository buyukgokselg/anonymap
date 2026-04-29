import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../config/mode_config.dart';
import '../localization/app_localizations.dart';
import '../models/post_model.dart';
import '../models/shorts_feed_scope.dart';
import '../models/user_model.dart';
import '../navigation/app_route_observer.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/network_media_headers.dart';
import '../services/place_focus_service.dart';
import '../services/places_service.dart';
import '../theme/colors.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/shorts_feed_view.dart';
import 'create_post_screen.dart';
import 'shorts_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  final _firestoreService = FirestoreService();
  final _placesService = PlacesService();
  final _locationService = LocationService();
  final _searchController = TextEditingController();
  final Map<String, Future<UserModel?>> _userCache = {};

  late TabController _tabController;

  bool _showSearch = false;
  bool _loadingPlaces = true;
  int _selectedMode = 0;
  double? _currentLat;
  double? _currentLng;
  List<Map<String, dynamic>> _places = [];

  String get _myUid => AuthService().currentUserId;
  ModeConfig get _currentMode => ModeConfig.all[_selectedMode];
  AppLocalizations get _l10n => context.l10n;

  @override
  void initState() {
    super.initState();
    _selectedMode = _modeIndexForId(AuthService().currentUser?.mode);
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (mounted && !_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadPlaces();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPush() {
    _syncModeFromSession(refreshPlaces: true);
  }

  @override
  void didPopNext() {
    _syncModeFromSession(refreshPlaces: true);
  }

  int _modeIndexForId(String? modeId) {
    final index = ModeConfig.all.indexWhere((mode) => mode.id == modeId);
    return index >= 0 ? index : 0;
  }

  void _syncModeFromSession({bool refreshPlaces = false}) {
    final nextIndex = _modeIndexForId(AuthService().currentUser?.mode);
    if (nextIndex != _selectedMode) {
      setState(() => _selectedMode = nextIndex);
    }
    if (refreshPlaces) {
      unawaited(_loadPlaces());
    }
  }

  Future<void> _loadPlaces() async {
    setState(() => _loadingPlaces = true);
    try {
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        if (!mounted) return;
        setState(() => _loadingPlaces = false);
        return;
      }

      final rawPlaces = await _placesService.getNearbyPlaces(
        lat: position.latitude,
        lng: position.longitude,
        modeId: _currentMode.id,
      );
      final communitySignals = await _firestoreService
          .getCommunitySignalsForPlaces(rawPlaces);
      final merged = _placesService.mergePulseSignals(
        rawPlaces,
        communitySignals: communitySignals,
      );

      if (!mounted) return;
      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
        _places = merged;
        _loadingPlaces = false;
      });
    } catch (e, st) {
      debugPrint('Discover place load failed: $e\n$st');
      if (!mounted) return;
      setState(() => _loadingPlaces = false);
    }
  }

  Future<UserModel?> _getUser(String uid) {
    return _userCache.putIfAbsent(uid, () => _firestoreService.getUser(uid));
  }

  List<Map<String, dynamic>> get _filteredPlaces {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _places;
    return _places.where((place) {
      final name = place['name']?.toString().toLowerCase() ?? '';
      final vicinity = place['vicinity']?.toString().toLowerCase() ?? '';
      return name.contains(query) || vicinity.contains(query);
    }).toList();
  }

  Future<void> _toggleLike(PostModel post) async {
    if (_myUid.isEmpty) return;
    await _firestoreService.toggleLike(post.id, _myUid);
  }

  Future<void> _toggleSave(PostModel post) async {
    if (_myUid.isEmpty) return;
    await _firestoreService.toggleSavePost(post.id, _myUid);
  }

  Future<void> _sharePost(PostModel post, UserModel? user) async {
    final author = user?.hasProfile == true
        ? user!.displayName
        : user?.username ?? 'PulseCity';
    final text = [
      '$author ${_l10n.t('posts')}',
      if (post.text.isNotEmpty) post.text,
      if (post.location.isNotEmpty)
        '${_l10n.phrase('Konum')}: ${post.location}',
      if (post.vibeTag.isNotEmpty) post.vibeTag,
    ].join('\n');

    await SharePlus.instance.share(
      ShareParams(text: text, subject: '$author ${_l10n.phrase('Gönderi')}'),
    );
  }

  Future<void> _focusPostPlace(PostModel post) async {
    if (post.placeId.isEmpty && post.location.trim().isEmpty) return;
    await PlaceFocusService.instance.focusPlace(
      placeId: post.placeId,
      placeName: post.location,
      latitude: post.lat,
      longitude: post.lng,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _editPost(PostModel post) async {
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            post.type == 'short'
                ? _l10n.phrase('Short güncellendi.')
                : _l10n.phrase('Gönderi güncellendi.'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
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
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (post.type == 'short'
                      ? _l10n.phrase('Short silindi.')
                      : _l10n.phrase('Gönderi silindi.'))
                : _l10n.phrase('Silme işlemi tamamlanamadı.'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
  }

  Widget _buildOwnerMenu(PostModel post) {
    return PopupMenuButton<String>(
      tooltip: _l10n.phrase('İçerik seçenekleri'),
      color: AppColors.bgCard,
      icon: Icon(
        Icons.more_horiz_rounded,
        color: Colors.white.withValues(alpha: 0.55),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          unawaited(_editPost(post));
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.tr3(
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
          context.tr3(
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
            hintText: context.tr3(
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
            child: Text(_l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(
              context.tr3(
                tr: 'Kaydet',
                en: 'Save',
                de: 'Speichern',
              ),
            ),
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

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            updated != null
                ? context.tr3(
                    tr: 'Yorum güncellendi.',
                    en: 'Comment updated.',
                    de: 'Kommentar aktualisiert.',
                  )
                : context.tr3(
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
          context.tr3(
            tr: 'Bu yorum silinsin mi?',
            en: 'Delete this comment?',
            de: 'Diesen Kommentar löschen?',
          ),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          context.tr3(
            tr: 'Bu işlem geri alınamaz.',
            en: 'This action cannot be undone.',
            de: 'Diese Aktion kann nicht rückgängig gemacht werden.',
          ),
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
            child: Text(
              context.tr3(
                tr: 'Sil',
                en: 'Delete',
                de: 'Löschen',
              ),
            ),
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

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            deleted
                ? context.tr3(
                    tr: 'Yorum silindi.',
                    en: 'Comment deleted.',
                    de: 'Kommentar gelöscht.',
                  )
                : context.tr3(
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
          context.tr3(
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
                      context.tr3(
                        tr: 'Rahatsız edici davranış',
                        en: 'Harassment',
                        de: 'Belästigendes Verhalten',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Fake profile',
                    child: Text(
                      context.tr3(
                        tr: 'Sahte profil',
                        en: 'Fake profile',
                        de: 'Fake-Profil',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Inappropriate content',
                    child: Text(
                      context.tr3(
                        tr: 'İstenmeyen içerik',
                        en: 'Inappropriate content',
                        de: 'Unangemessener Inhalt',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Safety concern',
                    child: Text(
                      context.tr3(
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
                  hintText: context.tr3(
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
            child: Text(
              context.tr3(
                tr: 'Vazgeç',
                en: 'Cancel',
                de: 'Abbrechen',
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: Text(
              context.tr3(
                tr: 'Gönder',
                en: 'Send',
                de: 'Senden',
              ),
            ),
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_l10n.phrase('Şikayet kaydı oluşturuldu.')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
    } catch (e, st) {
      debugPrint('Comment report failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_l10n.phrase('Şikayet gönderilemedi.')),
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
          child: Text(
            context.tr3(
              tr: 'Kopyala',
              en: 'Copy',
              de: 'Kopieren',
            ),
          ),
        ),
        if (isMine)
          PopupMenuItem<String>(
            value: 'edit',
            child: Text(_l10n.t('section_edit')),
          ),
        if (isMine)
          PopupMenuItem<String>(
            value: 'delete',
            child: Text(
              context.tr3(
                tr: 'Sil',
                en: 'Delete',
                de: 'Löschen',
              ),
            ),
          ),
        if (!isMine && commenterUid.isNotEmpty)
          PopupMenuItem<String>(
            value: 'report',
            child: Text(_l10n.phrase('Şikayet Et')),
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
                    style: TextStyle(
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
                        final commenterUid =
                            comment['userId']?.toString() ?? '';
                        return FutureBuilder<UserModel?>(
                          future: _getUser(commenterUid),
                          builder: (context, userSnapshot) {
                            final commenter = userSnapshot.data;
                            final title = commenter?.hasProfile == true
                                ? commenter!.displayName
                                : commenter?.username ?? _l10n.t('user');
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 6,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.14,
                                ),
                                backgroundImage:
                                    commenter?.profilePhotoUrl.isNotEmpty ==
                                        true
                                    ? NetworkMediaHeaders.imageProvider(
                                        commenter!.profilePhotoUrl,
                                      )
                                    : null,
                                child:
                                    commenter?.profilePhotoUrl.isEmpty != false
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
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  comment['text']?.toString() ?? '',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            );
                          },
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
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _l10n.phrase('Yorum yaz...'),
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        filled: true,
                        fillColor: AppColors.bgSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _myUid.isEmpty
                        ? null
                        : () async {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            controller.clear();
                            await _firestoreService.addPostComment(
                              post.id,
                              _myUid,
                              text,
                            );
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: Text(_l10n.phrase('Gönder')),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: _l10n.phrase('Mekan ara'),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        border: InputBorder.none,
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDiscoverHero() {
    final modeColor = _currentMode.color;
    final topPlace = _filteredPlaces.isNotEmpty ? _filteredPlaces.first : null;
    final topPulse = (topPlace?['pulse_score'] as num?)?.toInt() ?? 0;
    final liveCount = _filteredPlaces
        .where((place) => place['open_now'] == true)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              modeColor.withValues(alpha: 0.22),
              AppColors.bgSurface,
              AppColors.bgCard,
            ],
          ),
          border: Border.all(color: modeColor.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: modeColor.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_currentMode.icon, size: 14, color: modeColor),
                      const SizedBox(width: 6),
                      Text(
                        _l10n.modeLabel(_currentMode.id),
                        style: TextStyle(
                          color: modeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.tr3(
                          tr: 'Canlı keşif',
                          en: 'Live discovery',
                          de: 'Live-Discovery',
                        ),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              context.tr3(
                tr: 'Şehirde şu an öne çıkan akışı keşfet',
                en: 'Explore the flow rising in the city right now',
                de: 'Entdecke den Flow, der in der Stadt gerade steigt',
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr3(
                tr:
                    'Shorts, gönderiler, trend yerler ve kısa vadeli tahminler seçtiğin moda göre tek akışta birleşiyor.',
                en:
                    'Shorts, posts, trending places, and short-term forecasts blend into one stream shaped by your mode.',
                de:
                    'Shorts, Posts, Trend-Orte und Kurzfrist-Prognosen laufen in einem Stream zusammen, abgestimmt auf deinen Modus.',
              ),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricChip(
                  context.tr3(
                    tr: '${_filteredPlaces.length} aktif nokta',
                    en: '${_filteredPlaces.length} active spots',
                    de: '${_filteredPlaces.length} aktive Spots',
                  ),
                  modeColor,
                ),
                _metricChip(
                  context.tr3(
                    tr: '$liveCount şu an açık',
                    en: '$liveCount open now',
                    de: '$liveCount jetzt offen',
                  ),
                  AppColors.success,
                ),
                if (topPulse > 0)
                  _metricChip(
                    context.tr3(
                      tr: 'Tepe pulse $topPulse',
                      en: 'Top pulse $topPulse',
                      de: 'Top-Pulse $topPulse',
                    ),
                    AppColors.primary,
                  ),
              ],
            ),
            if (topPlace != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: modeColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        color: modeColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topPlace['name']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            topPlace['vicinity']?.toString() ??
                                context.tr3(
                                  tr: 'Çevrende yükselen yer',
                                  en: 'Rising around you',
                                  de: 'Steigt in deiner Nähe',
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.42),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$topPulse',
                      style: TextStyle(
                        color: modeColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _l10n.t('discover'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        Text(
          context.tr3(
            tr: '\u015eehir ak\u0131\u015f\u0131n\u0131 ke\u015ffet',
            en: 'Explore the city flow',
            de: 'Entdecke den Stadtfluss',
          ),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoverHeroPanel() {
    final modeColor = _currentMode.color;
    final topPlace = _filteredPlaces.isNotEmpty ? _filteredPlaces.first : null;
    final topPulse = (topPlace?['pulse_score'] as num?)?.toInt() ?? 0;
    final liveCount = _filteredPlaces
        .where((place) => place['open_now'] == true)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              modeColor.withValues(alpha: 0.22),
              AppColors.bgSurface,
              AppColors.bgCard,
            ],
          ),
          border: Border.all(color: modeColor.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: modeColor.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_currentMode.icon, size: 14, color: modeColor),
                      const SizedBox(width: 6),
                      Text(
                        _l10n.modeLabel(_currentMode.id),
                        style: TextStyle(
                          color: modeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.tr3(
                      tr: 'Canl\u0131 ke\u015fif',
                      en: 'Live discovery',
                      de: 'Live-Discovery',
                    ),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              context.tr3(
                tr: '\u015eehirde \u015fu an \u00f6ne \u00e7\u0131kan ak\u0131\u015f\u0131 ke\u015ffet',
                en: 'Explore the flow rising in the city right now',
                de: 'Entdecke den Flow, der in der Stadt gerade steigt',
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr3(
                tr:
                    'Shorts, g\u00f6nderiler, trend yerler ve k\u0131sa vadeli tahminler se\u00e7ti\u011fin moda g\u00f6re tek ak\u0131\u015fta birle\u015fiyor.',
                en:
                    'Shorts, posts, trending places, and short-term forecasts blend into one stream shaped by your mode.',
                de:
                    'Shorts, Posts, Trend-Orte und Kurzfrist-Prognosen laufen in einem Stream zusammen, abgestimmt auf deinen Modus.',
              ),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricChip(
                  context.tr3(
                    tr: '${_filteredPlaces.length} aktif nokta',
                    en: '${_filteredPlaces.length} active spots',
                    de: '${_filteredPlaces.length} aktive Spots',
                  ),
                  modeColor,
                ),
                _metricChip(
                  context.tr3(
                    tr: '$liveCount \u015fu an a\u00e7\u0131k',
                    en: '$liveCount open now',
                    de: '$liveCount jetzt offen',
                  ),
                  AppColors.success,
                ),
                if (topPulse > 0)
                  _metricChip(
                    context.tr3(
                      tr: 'Tepe pulse $topPulse',
                      en: 'Top pulse $topPulse',
                      de: 'Top-Pulse $topPulse',
                    ),
                    AppColors.primary,
                  ),
              ],
            ),
            if (topPlace != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: modeColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        color: modeColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topPlace['name']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            topPlace['vicinity']?.toString() ??
                                context.tr3(
                                  tr: '\u00c7evrende y\u00fckselen yer',
                                  en: 'Rising around you',
                                  de: 'Steigt in deiner N\u00e4he',
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.42),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$topPulse',
                      style: TextStyle(
                        color: modeColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    if (_tabController.index == 0) {
      return _buildPersonalShortsStrip();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: ModeConfig.all.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final mode = ModeConfig.all[index];
            final selected = index == _selectedMode;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedMode = index);
                _loadPlaces();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            mode.color.withValues(alpha: 0.18),
                            AppColors.bgCard,
                          ],
                        )
                      : null,
                  color: selected ? null : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? mode.color.withValues(alpha: 0.36)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      mode.icon,
                      size: 16,
                      color: selected
                          ? mode.color
                          : Colors.white.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _l10n.modeLabel(mode.id),
                      style: TextStyle(
                        color: selected
                            ? mode.color
                            : Colors.white.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPersonalShortsStrip() {
    final sessionModeId = AuthService().currentUser?.mode ?? _currentMode.id;
    final mode = ModeConfig.all.firstWhere(
      (entry) => entry.id == sessionModeId,
      orElse: () => ModeConfig.all.first,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: mode.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: mode.color.withValues(alpha: 0.22)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(mode.icon, size: 14, color: mode.color),
                  const SizedBox(width: 8),
                  Text(
                    _l10n.modeLabel(mode.id),
                    style: TextStyle(
                      color: mode.color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _l10n.t('shorts_personal_hint'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ShortsScreen(scope: ShortsFeedScope.global),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              child: Text(
                _l10n.t('shorts_scope_global'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.explore_off_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildForecasts() {
    if (_filteredPlaces.isEmpty || _currentLat == null || _currentLng == null) {
      return const [];
    }

    return _placesService.buildHourlyForecast(
      _filteredPlaces,
      modeId: _currentMode.id,
      userLat: _currentLat!,
      userLng: _currentLng!,
    );
  }

  Widget _buildForecastHeatStrip(List<Map<String, dynamic>> forecasts) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _l10n.phrase('Önümüzdeki Saatler').toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.25),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: forecasts.take(5).map((forecast) {
              final score = (forecast['score'] as int? ?? 0).clamp(0, 100);
              final color = score >= 80
                  ? AppColors.pulseVeryHigh
                  : score >= 65
                  ? AppColors.pulseHigh
                  : AppColors.pulseMedium;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      Text(
                        forecast['label']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.42),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: score / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _detailMetric(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgMain,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlaceSheet(Map<String, dynamic> place) {
    final pulse = (place['pulse_score'] as num?)?.toInt() ?? 0;
    final googlePulse = (place['google_pulse_score'] as num?)?.toInt() ?? 0;
    final communityScore = (place['community_score'] as num?)?.toInt() ?? 0;
    final community = place['community_signals'] as Map<String, dynamic>? ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place['name']?.toString() ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              place['vicinity']?.toString() ?? '',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricChip('Pulse $pulse', AppColors.primary),
                _metricChip(
                  '${_l10n.phrase('Google')} $googlePulse',
                  AppColors.warning,
                ),
                _metricChip(
                  '${_l10n.phrase('Topluluk')} $communityScore',
                  AppColors.modeSosyal,
                ),
                _metricChip(
                  _l10n.densityLabel(place['density_label'] ?? 'Orta'),
                  AppColors.modeTopluluk,
                ),
                _metricChip(
                  _l10n.trendLabel(place['trend_label'] ?? 'Sabit'),
                  AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _detailMetric(
                  _l10n.phrase('Puan'),
                  (place['rating'] as num?)?.toStringAsFixed(1) ?? '0.0',
                ),
                _detailMetric(
                  _l10n.phrase('Yorum'),
                  '${(place['user_ratings_total'] as num?)?.toInt() ?? 0}',
                ),
                _detailMetric(
                  _l10n.phrase('Açık'),
                  place['open_now'] == true
                      ? _l10n.phrase('Evet')
                      : _l10n.phrase('Hayır'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (community.isNotEmpty)
              Text(
                '${community['posts'] ?? 0} post, ${community['shorts'] ?? 0} short, ${community['likes'] ?? 0} beğeni, ${community['comments'] ?? 0} yorum, ${community['creators'] ?? 0} üretici',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortsTab() {
    return ShortsFeedView(
      scope: ShortsFeedScope.personal,
      initialLatitude: _currentLat,
      initialLongitude: _currentLng,
    );
  }

  Widget _buildPostsTab() {
    return StreamBuilder<List<PostModel>>(
      stream: _firestoreService.getFeedPosts(type: 'post'),
      builder: (context, snapshot) {
        final posts = snapshot.data ?? const <PostModel>[];
        if (posts.isEmpty) {
          return _buildEmptyState(_l10n.phrase('Henüz paylaşım yok'));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: posts.length,
          itemBuilder: (_, index) => _buildPostCard(posts[index]),
        );
      },
    );
  }

  Widget _buildPostCard(PostModel post) {
    return FutureBuilder<UserModel?>(
      future: _getUser(post.userId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final author = user?.hasProfile == true ? user!.displayName : user?.username ?? _l10n.t('user');
        final previewUrl = post.photoUrls.isNotEmpty
            ? post.photoUrls.first
            : (post.videoUrl?.isNotEmpty == true ? post.videoUrl! : '');
        final likeColor = post.isLikedBy(_myUid)
            ? AppColors.primary
            : Colors.white.withValues(alpha: 0.82);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (previewUrl.isNotEmpty)
                AspectRatio(
                  aspectRatio: 1.08,
                  child: Image.network(
                    previewUrl,
                    headers: NetworkMediaHeaders.forUrl(previewUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.bgMain,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white24,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                          backgroundImage: user?.profilePhotoUrl.isNotEmpty == true
                              ? NetworkMediaHeaders.imageProvider(
                                  user!.profilePhotoUrl,
                                )
                              : null,
                          child: user?.profilePhotoUrl.isNotEmpty == true
                              ? null
                              : Text(
                                  author.characters.first.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (post.location.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: InkWell(
                                    onTap: () => _focusPostPlace(post),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        post.location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.46),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (post.userId == _myUid) _buildOwnerMenu(post),
                      ],
                    ),
                    if (post.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        post.text.trim(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildFeedAction(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: '${post.commentsCount}',
                          onTap: () => _openCommentsSheet(post),
                        ),
                        _buildFeedAction(
                          icon: post.savedByCurrentUser
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          label: _l10n.phrase('Kaydet'),
                          onTap: () => _toggleSave(post),
                        ),
                        _buildFeedAction(
                          icon: post.isLikedBy(_myUid)
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: '${post.likesCount}',
                          onTap: () => _toggleLike(post),
                          color: likeColor,
                        ),
                        _buildFeedAction(
                          icon: Icons.ios_share_rounded,
                          label: _l10n.phrase('Paylaş'),
                          onTap: () => _sharePost(post, user),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final resolvedColor = color ?? Colors.white.withValues(alpha: 0.82);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: resolvedColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: resolvedColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTrendingTab() {
    if (_loadingPlaces) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: List.generate(4, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ShimmerCard(),
        )),
      );
    }

    final places = _filteredPlaces;
    if (places.isEmpty) {
      return ListView(
        children: [_buildEmptyState(_l10n.phrase('Yakında canlı mekan bulunamadı'))],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: places.length,
      itemBuilder: (_, index) {
        final place = places[index];
        final pulse = (place['pulse_score'] as num?)?.toInt() ?? 0;
        return InkWell(
          onTap: () => _openPlaceSheet(place),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place['name']?.toString() ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        place['vicinity']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _metricChip(
                            _l10n.densityLabel(
                              place['density_label'] ?? 'Orta',
                            ),
                            AppColors.modeTopluluk,
                          ),
                          _metricChip(
                            _l10n.trendLabel(place['trend_label'] ?? 'Sabit'),
                            AppColors.success,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Text(
                      '$pulse',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                    Text(
                      'Pulse',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHotspotsTab() {
    if (_loadingPlaces) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: List.generate(4, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ShimmerCard(),
        )),
      );
    }

    final hotspots = _filteredPlaces.where(
      (place) => place['open_now'] == true,
    );
    final items = hotspots.take(10).toList();
    if (items.isEmpty) {
      return ListView(
        children: [_buildEmptyState(_l10n.phrase('Şu an açık hotspot bulunamadı'))],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: items.map((place) {
        final pulse = (place['pulse_score'] as num?)?.toInt() ?? 0;
        final google = (place['google_pulse_score'] as num?)?.toInt() ?? 0;
        final community = (place['community_score'] as num?)?.toInt() ?? 0;
        return InkWell(
          onTap: () => _openPlaceSheet(place),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.14),
                  AppColors.bgCard,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        place['name']?.toString() ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _metricChip(_l10n.phrase('Açık'), AppColors.success),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  place['vicinity']?.toString() ?? '',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _detailMetric('Pulse', '$pulse'),
                    _detailMetric(_l10n.phrase('Google'), '$google'),
                    _detailMetric(_l10n.phrase('Topluluk'), '$community'),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildForecastTab() {
    if (_loadingPlaces) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: List.generate(3, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ShimmerCard(),
        )),
      );
    }

    if (_filteredPlaces.isEmpty || _currentLat == null || _currentLng == null) {
      return ListView(
        children: [_buildEmptyState(_l10n.phrase('Tahmin üretmek için yeterli veri yok'))],
      );
    }

    final forecasts = _buildForecasts();

    if (forecasts.isEmpty) {
      return ListView(
        children: [_buildEmptyState(_l10n.phrase('Tahmin üretmek için yeterli veri yok'))],
      );
    }

    final currentForecast = forecasts.first;
    final currentPlace =
        currentForecast['place'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    final explanation = _placesService.explainPulseDrivers(
      currentPlace,
      modeLabel: _l10n.modeLabel(_currentMode.id),
    );
    final insights = forecasts.take(3).map((forecast) {
      final place = forecast['place'] as Map<String, dynamic>;
      final score = forecast['score'] as int? ?? 0;
      final confidence = forecast['confidence'] as int? ?? 0;
      final density = _l10n.densityLabel(place['density_label'] ?? 'Orta');
      final trend = _l10n.trendLabel(place['trend_label'] ?? 'Sabit');
      final distance = place['distance_label']?.toString() ?? '';
      return {
        'time': forecast['label'],
        'place': place['name']?.toString() ?? '',
        'score': score,
        'confidence': confidence,
        'summary': distance.isNotEmpty
            ? '$trend • $density • $distance'
            : '$trend • $density',
      };
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.12),
                AppColors.bgCard,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _l10n.phrase('Tahmin Motoru'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _l10n.phrase(
                        'Google puanı, yorum hacmi, açık durumu, anlık pulse ve topluluk sinyallerini saat etkisiyle harmanlar.',
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.35),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildForecastHeatStrip(forecasts),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _l10n.phrase('Mode Uygunluğu').toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.25),
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _currentMode.color.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _currentMode.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_currentMode.icon, color: _currentMode.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _l10n.formatPhrase(
                            '{mode} modu için en güçlü aday',
                            {'mode': _l10n.modeLabel(_currentMode.id)},
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _currentMode.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentPlace['name']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _metricChip(
                    'Pulse ${currentForecast['score']}',
                    AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${_l10n.trendLabel(currentPlace['trend_label'] ?? 'Sabit')} • ${_l10n.densityLabel(currentPlace['density_label'] ?? 'Orta')}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                explanation,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.46),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: forecasts.take(4).map((forecast) {
                  final score = forecast['score'] as int? ?? 0;
                  final active = identical(forecast, currentForecast);
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.bgMain,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            forecast['label']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 50,
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 20,
                              height: (score.clamp(8, 100) / 100) * 48,
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.primary
                                    : _currentMode.color.withValues(
                                        alpha: 0.65,
                                      ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$score',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _l10n.phrase('Zaman Tahminleri').toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.25),
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...insights.map((insight) {
          final score = insight['score'] as int? ?? 0;
          final confidence = insight['confidence'] as int? ?? 0;
          final color = score >= 80
              ? AppColors.pulseVeryHigh
              : score >= 65
              ? AppColors.pulseHigh
              : AppColors.pulseMedium;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        size: 20,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight['time']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${insight['place']} • ${_l10n.phrase('Güven')} %$confidence',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: confidence / 100,
                            strokeWidth: 3,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.06,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              color.withValues(alpha: 0.7),
                            ),
                          ),
                          Text(
                            '$score',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  insight['summary']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.58),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: AppColors.bgMain,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: _showSearch ? _buildSearchField() : _buildDiscoverTitle(),
            actions: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                    }
                  });
                },
                icon: Icon(
                  _showSearch ? Icons.close_rounded : Icons.search_rounded,
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(child: _buildDiscoverHeroPanel()),
          SliverToBoxAdapter(child: _buildModeSelector()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabDelegate(
              child: Container(
                color: AppColors.bgMain,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          _currentMode.color.withValues(alpha: 0.22),
                          AppColors.primary.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                    labelColor: Colors.white,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.42),
                    tabs: [
                      const Tab(text: 'Shorts'),
                      Tab(text: _l10n.t('posts')),
                      const Tab(text: 'Trending'),
                      Tab(text: _l10n.t('live')),
                      Tab(text: _l10n.phrase('Tahmin')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildShortsTab(),
            _buildPostsTab(),
            RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.bgCard,
              onRefresh: _loadPlaces,
              child: _buildTrendingTab(),
            ),
            RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.bgCard,
              onRefresh: _loadPlaces,
              child: _buildHotspotsTab(),
            ),
            RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.bgCard,
              onRefresh: _loadPlaces,
              child: _buildForecastTab(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabDelegate({required this.child});

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyTabDelegate oldDelegate) => false;
}
