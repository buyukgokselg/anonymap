import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../config/mode_config.dart';
import '../localization/app_localizations.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/network_media_headers.dart';
import '../services/places_service.dart';
import '../services/storage_service.dart';
import '../theme/colors.dart';

enum CreatePostKind { post, short }

extension on CreatePostKind {
  String get postType => this == CreatePostKind.short ? 'short' : 'post';
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({
    super.key,
    required this.kind,
    required this.currentUser,
    this.initialPost,
  });

  final CreatePostKind kind;
  final UserModel currentUser;
  final PostModel? initialPost;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _locationService = LocationService();
  final _placesService = PlacesService();
  final _imagePicker = ImagePicker();

  late final TextEditingController _textController;

  XFile? _selectedMedia;
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoFuture;
  bool _isSubmitting = false;
  bool _isPickingMedia = false;

  // Location picker state
  String _locationLabel = '';
  String _selectedPlaceId = '';
  double? _selectedLat;
  double? _selectedLng;
  List<Map<String, dynamic>> _nearbyPlaces = [];
  bool _loadingPlaces = false;

  // Mode selector state
  String _selectedModeId = '';
  String _selectedModeLabel = '';

  AppLocalizations get _l10n => context.l10n;
  bool get _isShort => widget.kind == CreatePostKind.short;
  bool get _isEditing => widget.initialPost != null;
  PostModel? get _initialPost => widget.initialPost;
  List<String> get _effectivePhotoUrls => _selectedMedia != null
      ? const []
      : (_initialPost?.photoUrls ?? const <String>[]);
  String? get _effectiveVideoUrl => _isShort
      ? (_selectedMedia != null ? null : _initialPost?.videoUrl)
      : null;
  bool get _canSubmit => _isShort
      ? (_selectedMedia != null || (_effectiveVideoUrl?.isNotEmpty == true)) &&
            !_isSubmitting
      : (_textController.text.trim().isNotEmpty ||
                _selectedMedia != null ||
                _effectivePhotoUrls.isNotEmpty ||
                (_initialPost?.videoUrl?.isNotEmpty == true)) &&
            !_isSubmitting;

  @override
  void initState() {
    super.initState();
    final initialPost = _initialPost;
    _textController = TextEditingController(text: initialPost?.text ?? '')
      ..addListener(_handleFieldChange);

    // Init location from existing post or empty
    _locationLabel = initialPost?.location ?? '';
    _selectedPlaceId = initialPost?.placeId ?? '';
    _selectedLat = initialPost?.lat;
    _selectedLng = initialPost?.lng;

    // Init mode from existing post or user's current mode
    final initModeId = initialPost?.userMode.isNotEmpty == true
        ? initialPost!.userMode
        : widget.currentUser.mode;
    _selectedModeId = initModeId;
    final modeConfig = ModeConfig.all.where((m) => m.id == initModeId);
    _selectedModeLabel = modeConfig.isNotEmpty ? modeConfig.first.label : '';

    // Fetch nearby places
    unawaited(_fetchNearbyPlaces());

    if (_isShort && initialPost?.videoUrl?.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_prepareVideoPreviewFromUrl(initialPost!.videoUrl!));
        }
      });
    } else if (_isShort && !_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_pickFromCamera());
        }
      });
    }
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_handleFieldChange)
      ..dispose();
    _disposeVideoController();
    super.dispose();
  }

  void _handleFieldChange() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchNearbyPlaces() async {
    setState(() => _loadingPlaces = true);
    try {
      final position = await _locationService
          .getCurrentPosition()
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      if (!mounted || position == null) return;

      final places = await _placesService.getNearbyPlaces(
        lat: position.latitude,
        lng: position.longitude,
        modeId: _selectedModeId.isNotEmpty
            ? _selectedModeId
            : ModeConfig.defaultId,
        radius: 1500,
      );
      if (!mounted) return;
      setState(() => _nearbyPlaces = places);
    } catch (e) {
      debugPrint('Nearby places fetch failed: $e');
    } finally {
      if (mounted) setState(() => _loadingPlaces = false);
    }
  }

  void _showLocationPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.place_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      _l10n.phrase('Konum seç'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    if (_locationLabel.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _locationLabel = '';
                            _selectedPlaceId = '';
                            _selectedLat = null;
                            _selectedLng = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          _l10n.phrase('Kaldır'),
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              if (_loadingPlaces)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else if (_nearbyPlaces.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _l10n.phrase('Yakında mekan bulunamadı'),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _nearbyPlaces.length,
                    separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (_, i) {
                      final place = _nearbyPlaces[i];
                      final name = (place['name'] ?? '').toString();
                      final vicinity = (place['vicinity'] ?? '').toString();
                      final isSelected = _selectedPlaceId == (place['place_id'] ?? '').toString();
                      final rating = (place['rating'] as num?)?.toDouble() ?? 0;
                      final openNow = place['open_now'] == true;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.place_rounded,
                            color: isSelected ? AppColors.primary : Colors.white54,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            if (vicinity.isNotEmpty) vicinity,
                            if (rating > 0) '★ ${rating.toStringAsFixed(1)}',
                            if (openNow) _l10n.phrase('Açık'),
                          ].join(' · '),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                            : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        onTap: () {
                          setState(() {
                            _locationLabel = name;
                            _selectedPlaceId = (place['place_id'] ?? '').toString();
                            _selectedLat = (place['lat'] as num?)?.toDouble();
                            _selectedLng = (place['lng'] as num?)?.toDouble();
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showModePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _l10n.phrase('Mod seç'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 14),
              // "None" option
              _buildModeOption(
                id: '',
                label: _l10n.phrase('Mod yok'),
                icon: Icons.close_rounded,
                color: Colors.white38,
                ctx: ctx,
              ),
              ...ModeConfig.all.map((mode) => _buildModeOption(
                id: mode.id,
                label: mode.label,
                icon: mode.icon,
                color: mode.color,
                ctx: ctx,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required String id,
    required String label,
    required IconData icon,
    required Color color,
    required BuildContext ctx,
  }) {
    final isSelected = _selectedModeId == id;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 0.22 : 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? color : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: color, size: 22)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: () {
        setState(() {
          _selectedModeId = id;
          _selectedModeLabel = label;
        });
        Navigator.pop(ctx);
      },
    );
  }

  Future<void> _pickFromCamera() async {
    if (_isPickingMedia) return;
    setState(() => _isPickingMedia = true);
    try {
      final file = _isShort
          ? await _imagePicker.pickVideo(
              source: ImageSource.camera,
              preferredCameraDevice: CameraDevice.rear,
              maxDuration: const Duration(seconds: 90),
            )
          : await _imagePicker.pickImage(
              source: ImageSource.camera,
              preferredCameraDevice: CameraDevice.rear,
              imageQuality: 88,
            );
      if (!mounted || file == null) return;
      await _setSelectedMedia(file);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        _l10n.phrase('Kamera açılamadı. Lütfen tekrar dene.'),
        color: AppColors.error,
      );
      debugPrint('Camera pick failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isPickingMedia = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isPickingMedia) return;
    setState(() => _isPickingMedia = true);
    try {
      final file = _isShort
          ? await _imagePicker.pickVideo(source: ImageSource.gallery)
          : await _imagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 88,
            );
      if (!mounted || file == null) return;
      await _setSelectedMedia(file);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        _l10n.phrase('Galeri açılamadı. Lütfen tekrar dene.'),
        color: AppColors.error,
      );
      debugPrint('Gallery pick failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isPickingMedia = false);
      }
    }
  }

  Future<void> _setSelectedMedia(XFile file) async {
    _selectedMedia = file;
    if (_isShort) {
      await _prepareVideoPreviewFromFile(file);
    } else {
      _disposeVideoController();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _prepareVideoPreviewFromFile(XFile file) async {
    final controller = VideoPlayerController.file(
      File(file.path),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    await _attachVideoController(controller);
  }

  Future<void> _prepareVideoPreviewFromUrl(String videoUrl) async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    await _attachVideoController(controller);
  }

  Future<void> _attachVideoController(VideoPlayerController controller) async {
    _disposeVideoController();
    _videoController = controller;
    _initializeVideoFuture = controller.initialize().then((_) async {
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted || _videoController != controller) return;
      await controller.play();
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _disposeVideoController() {
    final controller = _videoController;
    _videoController = null;
    _initializeVideoFuture = null;
    controller?.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    if (_isShort &&
        _selectedMedia == null &&
        (_effectiveVideoUrl?.isNotEmpty != true)) {
      _showSnackBar(
        _l10n.phrase('Önce bir short videosu seç.'),
        color: AppColors.warning,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String? uploadedUrl;
      if (_selectedMedia != null) {
        final extension = _extensionFor(_selectedMedia!);
        uploadedUrl = await _storageService.uploadXFile(
          file: _selectedMedia!,
          path:
              'users/${widget.currentUser.uid}/${_isShort ? 'shorts' : 'posts'}/${DateTime.now().millisecondsSinceEpoch}.$extension',
        );
      }

      final draft = PostModel(
        id: _initialPost?.id ?? '',
        userId: widget.currentUser.uid,
        userDisplayName: widget.currentUser.displayName,
        userProfilePhotoUrl: widget.currentUser.profilePhotoUrl,
        text: _textController.text.trim(),
        location: _locationLabel,
        placeId: _selectedPlaceId,
        lat: _selectedLat,
        lng: _selectedLng,
        photoUrls: !_isShort
            ? (uploadedUrl != null ? [uploadedUrl] : _effectivePhotoUrls)
            : const [],
        videoUrl: _isShort ? (uploadedUrl ?? _effectiveVideoUrl) : null,
        vibeTag: _selectedModeId.isNotEmpty ? '#$_selectedModeId' : '',
        rating: _initialPost?.rating ?? 0,
        type: widget.kind.postType,
        userMode: _selectedModeId,
        createdAt: _initialPost?.createdAt,
        updatedAt: DateTime.now(),
      );

      final savedPost = _isEditing
          ? await _firestoreService.updatePost(draft, widget.currentUser.uid)
          : await _firestoreService.createPost(draft);

      if (savedPost == null) {
        throw Exception(
          _isEditing
              ? _l10n.phrase('Paylaşım güncellenemedi.')
              : _l10n.phrase('Paylaşım oluşturulamadı.'),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
        color: AppColors.error,
      );
      debugPrint('Create/update post failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _extensionFor(XFile file) {
    final sanitized = file.path.split('?').first;
    final dotIndex = sanitized.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == sanitized.length - 1) {
      return _isShort ? 'mp4' : 'jpg';
    }
    return sanitized.substring(dotIndex + 1).toLowerCase();
  }

  void _showSnackBar(String message, {required Color color}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final previewHeight = _isShort ? 420.0 : 280.0;
    final compact = MediaQuery.of(context).size.height < 760;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        leading: IconButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
        title: Text(
          _isEditing
              ? (_isShort
                    ? _l10n.phrase('Shorts düzenle')
                    : _l10n.phrase('Gönderiyi düzenle'))
              : (_isShort
                    ? _l10n.phrase('Shorts oluştur')
                    : _l10n.phrase('Gönderi oluştur')),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton(
              onPressed: _canSubmit ? _submit : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isEditing
                          ? _l10n.phrase('Güncelle')
                          : (_isShort
                                ? _l10n.phrase('Yayınla')
                                : _l10n.phrase('Paylaş')),
                      style: TextStyle(
                        color: _canSubmit
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.28),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, compact ? 18 : 24),
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 14),
                  _buildPreviewPanel(height: previewHeight),
                  const SizedBox(height: 14),
                  _buildModeContextRow(),
                  const SizedBox(height: 14),
                  _buildComposerCard(compact: compact),
                ],
              ),
            ),
            _buildBottomToolbar(compact: compact),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final headline = _isEditing
        ? (_isShort
              ? _l10n.phrase('Short videonu düzenle')
              : _l10n.phrase('Gönderini düzenle'))
        : (_isShort
              ? _l10n.phrase('Kameradan başlayıp anı yayınla')
              : _l10n.phrase('Metinle başla, medyayla güçlendir'));
    final subtitle = _isEditing
        ? (_isShort
              ? _l10n.phrase(
                  'Açıklama, konum ve vibe bilgisini güncelle. İstersen videonu değiştir.',
                )
              : _l10n.phrase(
                  'Metni, konumu ve görselini güncelleyerek paylaşımını tazele.',
                ))
        : (_isShort
              ? _l10n.phrase(
                  'Instagram hissinde kısa video akışı için önce çek, sonra açıklama ve konum ekle.',
                )
              : _l10n.phrase(
                  'X benzeri hızlı paylaşım oluştur. İstersen fotoğraf ve mekan bilgisi ekle.',
                ));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.16),
            child: Text(
              widget.currentUser.displayName.isNotEmpty
                  ? widget.currentUser.displayName.characters.first
                        .toUpperCase()
                  : '@',
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
                  headline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    height: 1.4,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel({required double height}) {
    final media = _selectedMedia;
    final existingPhotoUrl = _effectivePhotoUrls.isNotEmpty
        ? _effectivePhotoUrls.first
        : '';
    final existingVideoUrl = _effectiveVideoUrl;
    final hasMedia =
        media != null || existingPhotoUrl.isNotEmpty || (existingVideoUrl?.isNotEmpty == true);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: hasMedia
              ? AppColors.primary.withValues(alpha: 0.26)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!hasMedia)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.18),
                      AppColors.bgSurface,
                      AppColors.bgMain,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isShort
                          ? Icons.videocam_rounded
                          : Icons.photo_camera_back_rounded,
                      size: 44,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _isShort
                          ? _l10n.phrase('Short videonu burada göreceksin')
                          : _l10n.phrase('Gönderi medyan burada görünecek'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isShort
                          ? _l10n.phrase(
                              'Önce kamera açılır. İstersen galeriden de video ekleyebilirsin.',
                            )
                          : _l10n.phrase(
                              'Metin paylaşabilir ya da fotoğraf/kamera ile görsel ekleyebilirsin.',
                            ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.46),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              )
            else if (_isShort)
              FutureBuilder<void>(
                future: _initializeVideoFuture,
                builder: (context, snapshot) {
                  final controller = _videoController;
                  if (controller == null ||
                      snapshot.connectionState != ConnectionState.done ||
                      !controller.value.isInitialized) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  return FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  );
                },
              )
            else
              media != null
                  ? Image.file(File(media.path), fit: BoxFit.cover)
                  : Image.network(
                      existingPhotoUrl,
                      headers: NetworkMediaHeaders.forUrl(existingPhotoUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.bgMain,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white24,
                          size: 34,
                        ),
                      ),
                    ),
            Positioned(
              top: 14,
              left: 14,
              child: _buildPreviewBadge(
                icon: _isShort
                    ? Icons.play_arrow_rounded
                    : Icons.article_rounded,
                label: _isShort
                    ? _l10n.phrase('Shorts önizleme')
                    : _l10n.phrase('Gönderi önizleme'),
              ),
            ),
            if (hasMedia)
              Positioned(
                top: 14,
                right: 14,
                child: Row(
                  children: [
                    _buildCircleAction(
                      icon: Icons.photo_library_outlined,
                      onTap: _pickFromGallery,
                    ),
                    const SizedBox(width: 8),
                    _buildCircleAction(
                      icon: _isShort
                          ? Icons.videocam_rounded
                          : Icons.camera_alt_rounded,
                      onTap: _pickFromCamera,
                    ),
                    const SizedBox(width: 8),
                    _buildCircleAction(
                      icon: Icons.delete_outline_rounded,
                      onTap: () {
                        _disposeVideoController();
                        setState(() => _selectedMedia = null);
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeContextRow() {
    final modeColor = _selectedModeId.isNotEmpty
        ? (ModeConfig.all.where((m) => m.id == _selectedModeId).firstOrNull?.color ?? AppColors.primary)
        : Colors.white38;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        GestureDetector(
          onTap: _showModePicker,
          child: _buildContextChip(
            icon: Icons.bolt_rounded,
            label: _selectedModeLabel.isNotEmpty
                ? _selectedModeLabel
                : _l10n.phrase('Mod seç'),
            color: modeColor,
          ),
        ),
        GestureDetector(
          onTap: _showLocationPicker,
          child: _buildContextChip(
            icon: Icons.place_rounded,
            label: _locationLabel.isNotEmpty
                ? _locationLabel
                : _l10n.phrase('Konum seç'),
          ),
        ),
      ],
    );
  }

  Widget _buildComposerCard({required bool compact}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isShort
                ? _l10n.phrase('Açıklama ve bağlam')
                : _l10n.phrase('Metin ve bağlam'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            maxLines: _isShort ? 3 : 7,
            minLines: _isShort ? 2 : 5,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: _isShort
                  ? _l10n.phrase('Kısa açıklama ekle')
                  : _l10n.phrase('Şehirde şu an ne oluyor?'),
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.24)),
              filled: true,
              fillColor: AppColors.bgMain,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.all(18),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPickerTile(
                  icon: Icons.place_rounded,
                  label: _locationLabel.isNotEmpty
                      ? _locationLabel
                      : _l10n.phrase('Konum seç'),
                  filled: _locationLabel.isNotEmpty,
                  onTap: _showLocationPicker,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPickerTile(
                  icon: Icons.bolt_rounded,
                  label: _selectedModeLabel.isNotEmpty
                      ? _selectedModeLabel
                      : _l10n.phrase('Mod seç'),
                  filled: _selectedModeId.isNotEmpty,
                  color: _selectedModeId.isNotEmpty
                      ? (ModeConfig.all.where((m) => m.id == _selectedModeId).firstOrNull?.color)
                      : null,
                  onTap: _showModePicker,
                ),
              ),
            ],
          ),
          if (compact)
            const SizedBox(height: 6)
          else
            const SizedBox(height: 10),
          Text(
            _isShort
                ? _l10n.phrase(
                    'Kamera-first akış açık. İstersen editörün altından yeni video ekleyebilir veya konumunu güncelleyebilirsin.',
                  )
                : _l10n.phrase(
                    'Post akışı metin-first çalışır. Medya eklemek tamamen isteğe bağlıdır.',
                  ),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar({required bool compact}) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, compact ? 10 : 14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isPickingMedia ? null : _pickFromGallery,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  _isShort
                      ? _l10n.phrase('Galeriden ekle')
                      : _l10n.phrase('Görsel ekle'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isPickingMedia ? null : _pickFromCamera,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: Icon(
                  _isShort ? Icons.videocam_rounded : Icons.camera_alt_rounded,
                ),
                label: Text(
                  _isShort
                      ? _l10n.phrase('Kamerayı aç')
                      : _l10n.phrase('Kamera'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerTile({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
    Color? color,
  }) {
    final accent = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: filled ? accent.withValues(alpha: 0.08) : AppColors.bgMain,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: filled ? accent.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: filled ? accent : Colors.white38, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : Colors.white.withValues(alpha: 0.34),
                  fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextChip({required IconData icon, required String label, Color? color}) {
    final accent = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded, size: 14, color: Colors.white.withValues(alpha: 0.3)),
        ],
      ),
    );
  }

  Widget _buildPreviewBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.32),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}


