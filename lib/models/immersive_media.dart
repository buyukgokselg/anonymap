import 'highlight_model.dart';
import 'post_model.dart';

/// The kind of media displayed inside the immersive viewer. The viewer uses
/// this to choose the renderer (image vs. video) and to decide whether to
/// auto-advance (stories) or stay static (photos) or autoplay (shorts).
enum ImmersiveMediaKind {
  photo,
  storyImage,
  storyVideo,
  shortVideo,
}

/// A single media item to be rendered by the immersive viewer.
class ImmersiveMediaItem {
  final String id;
  final ImmersiveMediaKind kind;
  final String mediaUrl;
  final String? thumbnailUrl;

  // Rich context (optional, surfaced in overlay)
  final String? caption;
  final String? locationLabel;
  final String? placeId;
  final String? modeTag;

  // Optional backing models (used for actions: delete/edit/view viewers etc.)
  final HighlightModel? highlight;
  final PostModel? post;

  const ImmersiveMediaItem({
    required this.id,
    required this.kind,
    required this.mediaUrl,
    this.thumbnailUrl,
    this.caption,
    this.locationLabel,
    this.placeId,
    this.modeTag,
    this.highlight,
    this.post,
  });

  bool get isVideo =>
      kind == ImmersiveMediaKind.shortVideo ||
      kind == ImmersiveMediaKind.storyVideo;

  bool get isStorySegment =>
      kind == ImmersiveMediaKind.storyImage ||
      kind == ImmersiveMediaKind.storyVideo;
}

/// One column in the immersive viewer's 2-axis grid. The user swipes up/down
/// between categories and left/right between items inside a category.
class ImmersiveMediaCategory {
  final String id;
  final String label;
  final List<ImmersiveMediaItem> items;

  const ImmersiveMediaCategory({
    required this.id,
    required this.label,
    required this.items,
  });

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
}
