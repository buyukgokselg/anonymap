import 'package:flutter/material.dart';

import '../../theme/colors.dart';

/// Overlapping circular avatar stack with optional "+N" overflow chip.
///
/// Used on activity cards/detail to show approved participants. Accepts the
/// raw user maps from the API (UserSummaryDto fields: id, displayName,
/// profilePhotoUrl) so we don't have to reify a separate model just for
/// avatars.
class ParticipantAvatarStack extends StatelessWidget {
  const ParticipantAvatarStack({
    super.key,
    required this.users,
    required this.totalCount,
    this.maxVisible = 4,
    this.avatarSize = 28,
    this.borderColor,
  });

  final List<Map<String, dynamic>> users;
  final int totalCount;
  final int maxVisible;
  final double avatarSize;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final ringColor = borderColor ?? AppColors.bgCard;
    final visible = users.take(maxVisible).toList();
    final overflow = totalCount - visible.length;

    if (visible.isEmpty && overflow <= 0) {
      return _emptyAvatar(ringColor);
    }

    final overlap = avatarSize * 0.32;
    final stackWidth = visible.isEmpty
        ? avatarSize
        : avatarSize + (visible.length - 1) * (avatarSize - overlap)
            + (overflow > 0 ? (avatarSize - overlap) : 0);

    return SizedBox(
      width: stackWidth,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * (avatarSize - overlap),
              child: _avatarFor(visible[i], ringColor),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * (avatarSize - overlap),
              child: _overflowChip(overflow, ringColor),
            ),
        ],
      ),
    );
  }

  Widget _avatarFor(Map<String, dynamic> user, Color ringColor) {
    final url = (user['profilePhotoUrl'] ?? user['photoUrl'] ?? '').toString();
    final initials = _initialsOf(user);

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bgChip,
        border: Border.all(color: ringColor, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: avatarSize * 0.36,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: avatarSize * 0.36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _overflowChip(int count, Color ringColor) {
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.85),
        border: Border.all(color: ringColor, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '+$count',
        style: TextStyle(
          color: Colors.white,
          fontSize: avatarSize * 0.32,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _emptyAvatar(Color ringColor) {
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bgChip,
        border: Border.all(color: ringColor, width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        color: Colors.white.withValues(alpha: 0.4),
        size: avatarSize * 0.55,
      ),
    );
  }

  String _initialsOf(Map<String, dynamic> user) {
    final name = (user['displayName'] ?? user['userName'] ?? '').toString().trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
