import 'package:flutter/material.dart';

import '../config/mode_config.dart';
import '../localization/app_localizations.dart';
import '../models/highlight_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/network_media_headers.dart';
import '../services/place_focus_service.dart';
import '../theme/colors.dart';

class StoryStatusViewerScreen extends StatefulWidget {
  final List<HighlightModel> highlights;
  final int initialSegmentIndex;

  const StoryStatusViewerScreen({
    super.key,
    required this.highlights,
    this.initialSegmentIndex = 0,
  });

  @override
  State<StoryStatusViewerScreen> createState() =>
      _StoryStatusViewerScreenState();
}

class _StorySegment {
  final HighlightModel story;
  final String mediaUrl;

  const _StorySegment({required this.story, required this.mediaUrl});
}

class _StoryStatusViewerScreenState extends State<StoryStatusViewerScreen>
    with SingleTickerProviderStateMixin {
  static const _storyDuration = Duration(seconds: 5);

  late final AnimationController _progressController;
  late final List<_StorySegment> _segments;
  late int _segmentIndex;
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final Set<String> _markedStoryIds = <String>{};

  AppLocalizations get _l10n => context.l10n;

  _StorySegment get _currentSegment => _segments[_segmentIndex];
  HighlightModel get _currentStory => _currentSegment.story;

  @override
  void initState() {
    super.initState();
    _segments = _buildSegments(widget.highlights);
    _segmentIndex = widget.initialSegmentIndex.clamp(
      0,
      _segments.isEmpty ? 0 : _segments.length - 1,
    );
    _progressController =
        AnimationController(vsync: this, duration: _storyDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _advance();
            }
          });
    _restartProgress();
    _markCurrentStoryViewed();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  List<_StorySegment> _buildSegments(List<HighlightModel> highlights) {
    final segments = <_StorySegment>[];
    for (final story in highlights) {
      final media = story.storyMedia;
      if (media.isEmpty) {
        continue;
      }
      for (final url in media) {
        segments.add(_StorySegment(story: story, mediaUrl: url));
      }
    }
    return segments;
  }

  void _restartProgress() {
    if (_segments.isEmpty) return;
    _progressController
      ..stop()
      ..forward(from: 0);
  }

  Future<void> _advance() async {
    if (!mounted || _segments.isEmpty) return;
    if (_segmentIndex >= _segments.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _segmentIndex += 1);
    _restartProgress();
    _markCurrentStoryViewed();
  }

  Future<void> _goBack() async {
    if (_segments.isEmpty) return;
    if (_segmentIndex == 0) {
      _restartProgress();
      return;
    }
    setState(() => _segmentIndex -= 1);
    _restartProgress();
    _markCurrentStoryViewed();
  }

  bool get _isOwnEntry => _authService.currentUserId == _currentStory.userId;
  bool get _isStoryEntry => _currentStory.isStory;

  Future<void> _markCurrentStoryViewed() async {
    final storyId = _currentStory.id;
    if (!_isStoryEntry ||
        storyId.isEmpty ||
        _isOwnEntry ||
        _markedStoryIds.contains(storyId)) {
      return;
    }
    _markedStoryIds.add(storyId);
    try {
      await _firestoreService.markStoryViewed(storyId);
    } catch (e) {
      debugPrint('Mark story viewed failed: $e');
      _markedStoryIds.remove(storyId);
    }
  }

  Future<void> _deleteCurrentEntry() async {
    if (!_isOwnEntry || _currentStory.id.isEmpty) return;

    final isStory = _currentStory.isStory;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isStory ? _storyDeleteTitle : _highlightDeleteTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          isStory ? _storyDeleteBody : _highlightDeleteBody,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(_deleteLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (isStory) {
        await _firestoreService.deleteStory(_currentStory.userId, _currentStory.id);
      } else {
        await _firestoreService.deleteHighlight(_currentStory.userId, _currentStory.id);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Delete story/highlight failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isStory ? _storyDeleteError : _highlightDeleteError),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showViewersSheet() {
    final viewers = _currentStory.viewers;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _l10n.t('story_viewers_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_currentStory.viewCount} ${_l10n.t('story_viewers_count_suffix')}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (viewers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _l10n.t('story_viewers_empty'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: viewers.length,
                      separatorBuilder: (_, _) =>
                          Divider(color: Colors.white.withValues(alpha: 0.06)),
                      itemBuilder: (context, index) {
                        final viewer = viewers[index];
                        final displayName = viewer.displayName.isNotEmpty
                            ? viewer.displayName
                            : viewer.userName;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.bgMain,
                            backgroundImage: viewer.profilePhotoUrl.isNotEmpty
                                ? NetworkMediaHeaders.imageProvider(
                                    viewer.profilePhotoUrl,
                                  )
                                : null,
                            child: viewer.profilePhotoUrl.isEmpty
                                ? Text(
                                    displayName.isNotEmpty
                                        ? displayName.characters.first
                                              .toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : null,
                          ),
                          title: Text(
                            displayName.isNotEmpty
                                ? displayName
                                : _l10n.t('user'),
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            viewer.viewedAt == null
                                ? ''
                                : _formatViewedAt(viewer.viewedAt!),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.42),
                            ),
                          ),
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
  }

  String _formatViewedAt(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}.${local.month}.${local.year} $hh:$mm';
  }

  Color get _modeColor {
    final modeId = _currentStory.modeTag;
    if (modeId.isEmpty) return AppColors.primary;
    return ModeConfig.all
        .firstWhere(
          (mode) => mode.id == modeId,
          orElse: () => ModeConfig.all.first,
        )
        .color;
  }

  Color get _textColor {
    final raw = _currentStory.textColorHex.replaceAll('#', '');
    final normalized = raw.length == 6 ? 'FF$raw' : raw;
    return Color(int.tryParse(normalized, radix: 16) ?? 0xFFFFFFFF);
  }

  String get _headerTitle {
    if (_currentStory.isHighlight) {
      final highlightTitle = _currentStory.title.trim();
      if (highlightTitle.isNotEmpty) {
        return highlightTitle;
      }
      if (!_currentStory.showLocationOverlay &&
          _currentStory.locationLabel.isNotEmpty) {
        return _currentStory.locationLabel;
      }
      return _highlightLabel;
    }

    if (!_currentStory.showLocationOverlay &&
        _currentStory.locationLabel.isNotEmpty) {
      return _currentStory.locationLabel;
    }
    return _storyLabel;
  }

  String get _headerSubtitle {
    if (_currentStory.isHighlight &&
        !_currentStory.showLocationOverlay &&
        _currentStory.locationLabel.isNotEmpty &&
        _currentStory.title.trim().isNotEmpty) {
      return _currentStory.locationLabel;
    }
    if (!_currentStory.showModeOverlay && _currentStory.modeTag.isNotEmpty) {
      return _l10n.modeLabel(_currentStory.modeTag);
    }
    return '';
  }

  bool get _hasLocationFocusTarget =>
      _currentStory.locationLabel.trim().isNotEmpty ||
      _currentStory.placeId.trim().isNotEmpty;

  Future<void> _focusCurrentPlace() async {
    if (!_hasLocationFocusTarget) return;
    await PlaceFocusService.instance.focusPlace(
      placeId: _currentStory.placeId,
      placeName: _currentStory.locationLabel,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_segments.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final title = _currentStory.title.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _progressController.stop(),
        onLongPressEnd: (_) => _restartProgress(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Image.network(
                _currentSegment.mediaUrl,
                headers: NetworkMediaHeaders.forUrl(_currentSegment.mediaUrl),
                key: ValueKey('${_currentStory.id}:$_segmentIndex'),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.bgCard,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 40,
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.52),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _goBack,
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _advance,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                    child: Column(
                      children: [
                        Row(
                          children: List.generate(_segments.length, (
                            progressIndex,
                          ) {
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: progressIndex == _segments.length - 1
                                      ? 0
                                      : 4,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    minHeight: 3.5,
                                    value: progressIndex < _segmentIndex
                                        ? 1
                                        : progressIndex > _segmentIndex
                                        ? 0
                                        : _progressController.value,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.18,
                                    ),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _hasLocationFocusTarget
                                    ? _focusCurrentPlace
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _headerTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (_headerSubtitle.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          _headerSubtitle,
                                          style: TextStyle(
                                            color: _modeColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_isOwnEntry && _isStoryEntry)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: _showViewersSheet,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.remove_red_eye_outlined,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_currentStory.viewCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (_isOwnEntry)
                              PopupMenuButton<String>(
                                color: AppColors.bgCard,
                                icon: const Icon(
                                  Icons.more_horiz_rounded,
                                  color: Colors.white,
                                ),
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _deleteCurrentEntry();
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text(
                                      _currentStory.isStory
                                          ? _deleteStoryMenuLabel
                                          : _deleteHighlightMenuLabel,
                                    ),
                                  ),
                                ],
                              ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment(
                      _currentStory.textOffsetX.clamp(-0.82, 0.82),
                      _currentStory.textOffsetY.clamp(-0.78, 0.78),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (title.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.26),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.08,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 14,
                                      color: Colors.black54,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_currentStory.showModeOverlay ||
                              _currentStory.showLocationOverlay) ...[
                            SizedBox(height: title.isNotEmpty ? 10 : 0),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_currentStory.showModeOverlay &&
                                    _currentStory.modeTag.isNotEmpty)
                                  _ViewerPill(
                                    icon: Icons.bolt_rounded,
                                    label: _l10n.modeLabel(
                                      _currentStory.modeTag,
                                    ),
                                    color: _modeColor,
                                  ),
                                if (_currentStory.showLocationOverlay &&
                                    _currentStory.locationLabel.isNotEmpty)
                                  _ViewerPill(
                                    icon: Icons.place_rounded,
                                    label: _currentStory.locationLabel,
                                    color: Colors.white,
                                    onTap: _focusCurrentPlace,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _storyLabel => switch (_l10n.languageCode) {
    'en' => 'Story',
    'de' => 'Story',
    _ => 'Durum',
  };

  String get _highlightLabel => switch (_l10n.languageCode) {
    'en' => 'Highlight',
    'de' => 'Highlight',
    _ => 'Öne çıkan',
  };

  String get _cancelLabel => switch (_l10n.languageCode) {
    'en' => 'Cancel',
    'de' => 'Abbrechen',
    _ => 'Vazgeç',
  };

  String get _deleteLabel => switch (_l10n.languageCode) {
    'en' => 'Delete',
    'de' => 'Löschen',
    _ => 'Sil',
  };

  String get _deleteStoryMenuLabel => switch (_l10n.languageCode) {
    'en' => 'Delete story',
    'de' => 'Story löschen',
    _ => 'Durumu sil',
  };

  String get _deleteHighlightMenuLabel => switch (_l10n.languageCode) {
    'en' => 'Delete highlight',
    'de' => 'Highlight löschen',
    _ => 'Öne çıkanı sil',
  };

  String get _storyDeleteTitle => switch (_l10n.languageCode) {
    'en' => 'Delete this story?',
    'de' => 'Diese Story löschen?',
    _ => 'Bu durum silinsin mi?',
  };

  String get _highlightDeleteTitle => switch (_l10n.languageCode) {
    'en' => 'Delete this highlight?',
    'de' => 'Dieses Highlight löschen?',
    _ => 'Bu öne çıkan silinsin mi?',
  };

  String get _storyDeleteBody => switch (_l10n.languageCode) {
    'en' => 'This story will be removed immediately.',
    'de' => 'Diese Story wird sofort entfernt.',
    _ => 'Bu durum hemen kaldırılacak.',
  };

  String get _highlightDeleteBody => switch (_l10n.languageCode) {
    'en' => 'This highlight will be removed immediately.',
    'de' => 'Dieses Highlight wird sofort entfernt.',
    _ => 'Bu öne çıkan hemen kaldırılacak.',
  };

  String get _storyDeleteError => switch (_l10n.languageCode) {
    'en' => 'Story could not be deleted.',
    'de' => 'Story konnte nicht gelöscht werden.',
    _ => 'Durum silinemedi.',
  };

  String get _highlightDeleteError => switch (_l10n.languageCode) {
    'en' => 'Highlight could not be deleted.',
    'de' => 'Highlight konnte nicht gelöscht werden.',
    _ => 'Öne çıkan silinemedi.',
  };
}

class _ViewerPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ViewerPill({
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
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
