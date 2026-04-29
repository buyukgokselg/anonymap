import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/post_model.dart';
import '../models/shorts_feed_scope.dart';
import '../widgets/shorts_feed_view.dart';

class ShortsScreen extends StatelessWidget {
  const ShortsScreen({
    super.key,
    this.scope = ShortsFeedScope.global,
    this.initialPosts,
    this.initialIndex = 0,
    this.title,
    this.subtitle,
  });

  final ShortsFeedScope scope;
  final List<PostModel>? initialPosts;
  final int initialIndex;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPersonal = scope.isPersonal;
    final resolvedTitle = title ??
        (isPersonal
        ? l10n.t('shorts_personal_title')
        : l10n.t('shorts_global_title'));
    final resolvedSubtitle = subtitle ??
        (isPersonal
        ? l10n.t('shorts_personal_subtitle')
        : l10n.t('shorts_global_subtitle'));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ShortsFeedView(
            scope: scope,
            initialPosts: initialPosts,
            initialIndex: initialIndex,
            topOverlayOffset: 64,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCircleButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.32),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resolvedTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              resolvedSubtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.62),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.36),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
