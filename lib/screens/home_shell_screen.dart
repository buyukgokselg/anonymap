import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/colors.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'profile_screen.dart';

/// PulseCity ana shell — 3 sekmeli alt nav (Harita / Sohbet / Profil).
///
/// HomeScreen, InboxScreen ve ProfileScreen IndexedStack içinde tutulur,
/// böylece sekmeler arası geçişte state korunur.
class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 2);
  }

  String _copy({
    required String tr,
    required String en,
    required String de,
  }) {
    return switch (context.l10n.languageCode) {
      'en' => en,
      'de' => de,
      _ => tr,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bgMain,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          InboxScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.map_rounded,
                label: _copy(tr: 'Harita', en: 'Map', de: 'Karte'),
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.chat_bubble_rounded,
                label: _copy(tr: 'Sohbet', en: 'Chat', de: 'Chat'),
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.person_rounded,
                label: _copy(tr: 'Profil', en: 'Profile', de: 'Profil'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _currentIndex == index;
    final color = selected ? AppColors.primary : Colors.white.withValues(alpha: 0.5);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
