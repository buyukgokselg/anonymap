import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../theme/colors.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'profile_screen.dart';
import 'signal_screen.dart';

/// PulseCity ana shell — 4 sekmeli alt nav (Harita / Radar / Sohbet / Profil).
///
/// IndexedStack içindeki sekmeler arası geçişte state korunur.
/// Radar (SignalScreen) ve Sohbet (InboxScreen) `embedded: true` ile
/// gösterilir; bu modda kendi AppBar'larındaki "geri" oku gizlenir.
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
    _currentIndex = widget.initialIndex.clamp(0, 3);
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

  Future<bool> _confirmExit() async {
    final l10n = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.bgCard,
              title: Text(
                l10n.t('exit_app_title'),
                style: const TextStyle(color: Colors.white),
              ),
              content: Text(
                l10n.t('exit_app_message'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.t('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: Text(l10n.t('exit_app_confirm')),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Sekme 0 (Harita) değilse önce Harita'ya dön.
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        // Harita'da iken çıkış onayı iste.
        if (await _confirmExit()) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: AppColors.bgMain,
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            HomeScreen(),
            SignalScreen(embedded: true),
            InboxScreen(embedded: true),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.map_rounded,
                label: _copy(tr: 'Harita', en: 'Map', de: 'Karte'),
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.wifi_tethering_rounded,
                label: _copy(tr: 'Radar', en: 'Radar', de: 'Radar'),
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.chat_bubble_rounded,
                label: _copy(tr: 'Sohbet', en: 'Chat', de: 'Chat'),
              ),
              _buildNavItem(
                index: 3,
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
