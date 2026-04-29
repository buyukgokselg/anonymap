import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../config/mode_config.dart';
import '../localization/app_localizations.dart';
import '../models/immersive_media.dart';
import '../services/network_media_headers.dart';
import '../services/place_focus_service.dart';
import '../theme/colors.dart';

/// Full-screen immersive viewer with 2-axis navigation.
///
/// * Vertical swipe → switch category (e.g. Photos → Stories → Shorts).
/// * Horizontal swipe → move between items inside the active category.
///
/// Stories auto-advance using a 5-second progress controller (tap left / right
/// to scrub). Shorts autoplay their video and advance on completion. Photos
/// remain static until the user swipes.
class ImmersiveProfileViewerScreen extends StatefulWidget {
  final List<ImmersiveMediaCategory> categories;
  final int initialCategoryIndex;
  final int initialItemIndex;
  final Color accentColor;
  final String ownerDisplayName;
  final String ownerProfilePhotoUrl;
  final bool isOwnProfile;

  const ImmersiveProfileViewerScreen({
    super.key,
    required this.categories,
    this.initialCategoryIndex = 0,
    this.initialItemIndex = 0,
    this.accentColor = AppColors.primary,
    this.ownerDisplayName = '',
    this.ownerProfilePhotoUrl = '',
    this.isOwnProfile = false,
  });

  @override
  State<ImmersiveProfileViewerScreen> createState() =>
      _ImmersiveProfileViewerScreenState();
}

class _ImmersiveProfileViewerScreenState
    extends State<ImmersiveProfileViewerScreen>
    with SingleTickerProviderStateMixin {
  static const _storyDuration = Duration(seconds: 5);

  late final PageController _verticalController;
  // One horizontal controller per category, lazily created.
  final Map<int, PageController> _horizontalControllers = {};
  // Per-category "current item" pointer so vertical swipe doesn't reset.
  final Map<int, int> _horizontalIndexes = {};

  late final AnimationController _progressController;

  // Video pool keyed by "cat:item" → VideoPlayerController.
  final Map<String, VideoPlayerController> _videoPool = {};

  late int _categoryIndex;
  late int _itemIndex;
  bool _chromeVisible = true;
  bool _isPaused = false;

  AppLocalizations get _l10n => context.l10n;

  List<ImmersiveMediaCategory> get _categories => widget.categories
      .where((c) => c.isNotEmpty)
      .toList(growable: false);

  ImmersiveMediaCategory? get _currentCategory =>
      _categoryIndex >= 0 && _categoryIndex < _categories.length
          ? _categories[_categoryIndex]
          : null;

  ImmersiveMediaItem? get _currentItem {
    final cat = _currentCategory;
    if (cat == null) return null;
    if (_itemIndex < 0 || _itemIndex >= cat.items.length) return null;
    return cat.items[_itemIndex];
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _categoryIndex = widget.initialCategoryIndex.clamp(
      0,
      _categories.isEmpty ? 0 : _categories.length - 1,
    );
    _itemIndex = widget.initialItemIndex.clamp(
      0,
      _currentCategory == null || _currentCategory!.items.isEmpty
          ? 0
          : _currentCategory!.items.length - 1,
    );
    _horizontalIndexes[_categoryIndex] = _itemIndex;

    _verticalController = PageController(initialPage: _categoryIndex);

    _progressController =
        AnimationController(vsync: this, duration: _storyDuration)
          ..addListener(() {
            if (mounted) setState(() {});
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _advanceHorizontal();
            }
          });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activateCurrent();
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _progressController.dispose();
    _verticalController.dispose();
    for (final ctrl in _horizontalControllers.values) {
      ctrl.dispose();
    }
    for (final video in _videoPool.values) {
      video.dispose();
    }
    super.dispose();
  }

  PageController _horizontalControllerFor(int categoryIndex, int initialItem) {
    return _horizontalControllers.putIfAbsent(
      categoryIndex,
      () => PageController(initialPage: initialItem),
    );
  }

  String _videoKey(int c, int i) => '$c:$i';

  Future<VideoPlayerController?> _prepareVideo(int c, int i) async {
    final cat = _categories[c];
    if (i < 0 || i >= cat.items.length) return null;
    final item = cat.items[i];
    if (!item.isVideo) return null;

    final key = _videoKey(c, i);
    final existing = _videoPool[key];
    if (existing != null) return existing;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(item.mediaUrl),
      httpHeaders:
          NetworkMediaHeaders.forUrl(item.mediaUrl) ?? const <String, String>{},
    );
    _videoPool[key] = controller;
    try {
      await controller.initialize();
      await controller.setLooping(item.kind == ImmersiveMediaKind.shortVideo);
      if (!mounted) return controller;
      setState(() {});
      return controller;
    } catch (e) {
      debugPrint('Immersive video init failed: $e');
      _videoPool.remove(key);
      await controller.dispose();
      return null;
    }
  }

  void _gcVideos() {
    // Keep only videos for current ± 1 item in current category.
    final keep = <String>{
      _videoKey(_categoryIndex, _itemIndex),
      _videoKey(_categoryIndex, _itemIndex - 1),
      _videoKey(_categoryIndex, _itemIndex + 1),
    };
    final stale = _videoPool.keys.where((k) => !keep.contains(k)).toList();
    for (final k in stale) {
      _videoPool.remove(k)?.dispose();
    }
  }

  void _activateCurrent() {
    final item = _currentItem;
    _progressController.stop();

    // Pause all videos, play only the current one.
    for (final v in _videoPool.values) {
      if (v.value.isPlaying) {
        v.pause();
      }
    }

    if (item == null) return;

    if (item.isVideo) {
      _prepareVideo(_categoryIndex, _itemIndex).then((ctrl) {
        if (!mounted || ctrl == null) return;
        if (_currentItem?.id != item.id) return;
        ctrl.seekTo(Duration.zero);
        if (!_isPaused) ctrl.play();
      });
    }

    if (item.isStorySegment && !item.isVideo) {
      _progressController
        ..reset()
        ..forward();
    }

    _gcVideos();

    // Preload adjacent items' videos.
    _prepareVideo(_categoryIndex, _itemIndex + 1);
  }

  void _advanceHorizontal() {
    final cat = _currentCategory;
    if (cat == null) return;
    if (_itemIndex < cat.items.length - 1) {
      final target = _itemIndex + 1;
      _horizontalControllerFor(_categoryIndex, 0).animateToPage(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    // End of category → advance to next non-empty category, else pop.
    if (_categoryIndex < _categories.length - 1) {
      _verticalController.animateToPage(
        _categoryIndex + 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _onHorizontalPageChanged(int category, int page) {
    if (category != _categoryIndex) {
      _horizontalIndexes[category] = page;
      return;
    }
    setState(() {
      _itemIndex = page;
      _horizontalIndexes[category] = page;
      _isPaused = false;
    });
    _activateCurrent();
  }

  void _onVerticalPageChanged(int page) {
    setState(() {
      _categoryIndex = page;
      _itemIndex = _horizontalIndexes[page] ?? 0;
      _isPaused = false;
    });
    _activateCurrent();
  }

  void _handleTap(TapUpDetails details, Size size) {
    final item = _currentItem;
    if (item == null) return;

    if (item.isStorySegment && !item.isVideo) {
      // Story image: tap left/right for prev/next segment.
      final isLeft = details.localPosition.dx < size.width * 0.33;
      if (isLeft) {
        _scrubHorizontal(-1);
      } else {
        _scrubHorizontal(1);
      }
      return;
    }

    if (item.isVideo) {
      // Toggle video play/pause.
      final ctrl = _videoPool[_videoKey(_categoryIndex, _itemIndex)];
      if (ctrl == null) return;
      if (ctrl.value.isPlaying) {
        ctrl.pause();
        setState(() => _isPaused = true);
      } else {
        ctrl.play();
        setState(() => _isPaused = false);
      }
      return;
    }

    // Photo: toggle chrome.
    setState(() => _chromeVisible = !_chromeVisible);
  }

  void _scrubHorizontal(int delta) {
    final cat = _currentCategory;
    if (cat == null) return;
    final target = _itemIndex + delta;
    if (target < 0) {
      _progressController
        ..reset()
        ..forward();
      return;
    }
    if (target >= cat.items.length) {
      _advanceHorizontal();
      return;
    }
    _horizontalControllerFor(_categoryIndex, 0).animateToPage(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  void _onLongPressStart() {
    final item = _currentItem;
    if (item == null) return;
    if (item.isStorySegment && !item.isVideo) {
      _progressController.stop();
    } else if (item.isVideo) {
      final ctrl = _videoPool[_videoKey(_categoryIndex, _itemIndex)];
      ctrl?.pause();
    }
    setState(() => _chromeVisible = false);
  }

  void _onLongPressEnd() {
    final item = _currentItem;
    if (item == null) return;
    if (item.isStorySegment && !item.isVideo) {
      _progressController.forward();
    } else if (item.isVideo && !_isPaused) {
      final ctrl = _videoPool[_videoKey(_categoryIndex, _itemIndex)];
      ctrl?.play();
    }
    setState(() => _chromeVisible = true);
  }

  Color _modeColor(String? tag) {
    if (tag == null || tag.isEmpty) return widget.accentColor;
    return ModeConfig.all
        .firstWhere(
          (mode) => mode.id == tag,
          orElse: () => ModeConfig.all.first,
        )
        .color;
  }

  String _categoryLabel(ImmersiveMediaCategory cat) {
    switch (cat.id) {
      case 'photos':
        return _l10n.phrase('Fotoğraflar');
      case 'stories':
        return _l10n.phrase('Storyler');
      case 'highlights':
        return _l10n.phrase('Öne çıkanlar');
      case 'shorts':
        return _l10n.phrase('Shorts');
      default:
        return cat.label;
    }
  }

  Future<void> _focusPlace() async {
    final item = _currentItem;
    if (item == null) return;
    final hasTarget = (item.locationLabel?.isNotEmpty ?? false) ||
        (item.placeId?.isNotEmpty ?? false);
    if (!hasTarget) return;
    await PlaceFocusService.instance.focusPlace(
      placeId: item.placeId ?? '',
      placeName: item.locationLabel ?? '',
    );
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    if (_categories.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              // Outer vertical PageView: categories
              PageView.builder(
                controller: _verticalController,
                scrollDirection: Axis.vertical,
                onPageChanged: _onVerticalPageChanged,
                physics: const PageScrollPhysics(),
                itemCount: _categories.length,
                itemBuilder: (_, catIndex) {
                  final cat = _categories[catIndex];
                  final initialItem =
                      _horizontalIndexes[catIndex] ?? 0;
                  return PageView.builder(
                    controller:
                        _horizontalControllerFor(catIndex, initialItem),
                    onPageChanged: (page) =>
                        _onHorizontalPageChanged(catIndex, page),
                    itemCount: cat.items.length,
                    physics: const PageScrollPhysics(),
                    itemBuilder: (_, itemIndex) {
                      final item = cat.items[itemIndex];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => _handleTap(details, size),
                        onLongPressStart: (_) => _onLongPressStart(),
                        onLongPressEnd: (_) => _onLongPressEnd(),
                        child: _buildMedia(item, catIndex, itemIndex),
                      );
                    },
                  );
                },
              ),

              // Vertical gradient for top/bottom chrome legibility
              IgnorePointer(
                ignoring: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.52),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.62),
                      ],
                      stops: const [0, 0.18, 0.75, 1],
                    ),
                  ),
                ),
              ),

              // Chrome (top bar + bottom actions + progress + category rail)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _chromeVisible ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_chromeVisible,
                  child: SafeArea(
                    child: Column(
                      children: [
                        _buildProgressBar(),
                        const SizedBox(height: 8),
                        _buildTopBar(),
                        const Spacer(),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),

              // Category indicator rail on the left edge
              if (_chromeVisible) _buildCategoryRail(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMedia(ImmersiveMediaItem item, int catIndex, int itemIndex) {
    if (item.isVideo) {
      final key = _videoKey(catIndex, itemIndex);
      final ctrl = _videoPool[key];
      if (ctrl == null) {
        // Trigger prepare (ignore returned future; setState via prepare)
        _prepareVideo(catIndex, itemIndex);
        return _buildPlaceholder(item);
      }
      if (!ctrl.value.isInitialized) {
        return _buildPlaceholder(item);
      }
      return Center(
        child: AspectRatio(
          aspectRatio: ctrl.value.aspectRatio,
          child: VideoPlayer(ctrl),
        ),
      );
    }

    // Image (photo or story image)
    return Center(
      child: Image.network(
        item.mediaUrl,
        headers: NetworkMediaHeaders.forUrl(item.mediaUrl),
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => _buildPlaceholder(item),
      ),
    );
  }

  Widget _buildPlaceholder(ImmersiveMediaItem item) {
    final thumb = item.thumbnailUrl ?? '';
    return Center(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumb.isNotEmpty)
            Image.network(
              thumb,
              headers: NetworkMediaHeaders.forUrl(thumb),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          Container(color: Colors.black.withValues(alpha: 0.32)),
          const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Chrome widgets
  // ==========================================================================

  Widget _buildProgressBar() {
    final cat = _currentCategory;
    if (cat == null) return const SizedBox.shrink();

    // Only stories show per-segment progress. Photos / shorts show a single
    // subtle "x of y" counter instead (rendered in the top bar).
    final firstKind = cat.items.first.kind;
    final isStoryCat = firstKind == ImmersiveMediaKind.storyImage ||
        firstKind == ImmersiveMediaKind.storyVideo;

    if (!isStoryCat) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: List.generate(cat.items.length, (i) {
          final value = i < _itemIndex
              ? 1.0
              : i > _itemIndex
                  ? 0.0
                  : _progressController.value;
          return Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(right: i == cat.items.length - 1 ? 0 : 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  value: value,
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTopBar() {
    final cat = _currentCategory;
    if (cat == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildOwnerAvatar(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.ownerDisplayName.isNotEmpty
                            ? widget.ownerDisplayName
                            : _l10n.t('user'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: widget.accentColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        _categoryLabel(cat),
                        style: TextStyle(
                          color: widget.accentColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_itemIndex + 1} / ${cat.items.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerAvatar() {
    final url = widget.ownerProfilePhotoUrl;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bgCard,
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: url.isEmpty
            ? Icon(
                Icons.person_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: 20,
              )
            : Image.network(
                url,
                headers: NetworkMediaHeaders.forUrl(url),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.person_rounded,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
      ),
    );
  }

  Widget _buildFooter() {
    final item = _currentItem;
    if (item == null) return const SizedBox.shrink();

    final caption = item.caption?.trim() ?? '';
    final location = item.locationLabel?.trim() ?? '';
    final mode = item.modeTag ?? '';
    final accent = _modeColor(mode);

    final hasAnything =
        caption.isNotEmpty || location.isNotEmpty || mode.isNotEmpty;
    if (!hasAnything) return const SizedBox(height: 14);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (mode.isNotEmpty)
                _ImmersivePill(
                  icon: Icons.bolt_rounded,
                  label: _l10n.modeLabel(mode),
                  color: accent,
                ),
              if (location.isNotEmpty)
                _ImmersivePill(
                  icon: Icons.place_rounded,
                  label: location,
                  color: Colors.white,
                  onTap: _focusPlace,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRail() {
    if (_categories.length < 2) return const SizedBox.shrink();
    return Positioned(
      right: 10,
      top: 0,
      bottom: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_categories.length, (i) {
            final isActive = i == _categoryIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: isActive ? 4 : 3,
                height: isActive ? 22 : 14,
                decoration: BoxDecoration(
                  color: isActive
                      ? widget.accentColor
                      : Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ImmersivePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ImmersivePill({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color == Colors.white ? Colors.white : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
