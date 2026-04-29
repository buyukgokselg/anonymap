import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../theme/colors.dart';

class ProfileTabBar extends StatelessWidget {
  const ProfileTabBar({
    super.key,
    required this.controller,
    required this.localizations,
  });

  final TabController controller;
  final AppLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgMain,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: TabBar(
        controller: controller,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: Colors.white, width: 1.5),
          insets: EdgeInsets.symmetric(horizontal: 32),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.3),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            height: 44,
            icon: Icon(Icons.grid_on_rounded, size: 22),
          ),
          Tab(
            height: 44,
            icon: Icon(Icons.smart_display_outlined, size: 22),
          ),
          Tab(
            height: 44,
            icon: Icon(Icons.bookmark_border_rounded, size: 22),
          ),
        ],
      ),
    );
  }
}
