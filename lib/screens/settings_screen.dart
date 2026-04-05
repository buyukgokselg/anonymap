import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';
import 'legal/terms_screen.dart';
import 'legal/privacy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  bool _isVisible = true;
  bool _ghostMode = false;
  bool _notifications = true;
  bool _locationSharing = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    try {
      final data = await _firestoreService.getUserProfile(uid);
      if (mounted && data != null) {
        setState(() {
          _isVisible = data['isVisible'] ?? true;
          _ghostMode = data['privacyLevel'] == 'ghost';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ayarlar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Gizlilik ──
            _sectionHeader('GİZLİLİK & GÖRÜNÜRLÜk'),
            const SizedBox(height: 10),
            _buildToggle(
              Icons.visibility_rounded,
              'Görünürlük',
              'Aggregate verilere katkı yap',
              _isVisible,
              (v) async {
                setState(() => _isVisible = v);
                final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                if (uid.isNotEmpty) {
                  await _firestoreService.updateVisibility(uid, v);
                }
              },
            ),
            _buildToggle(
              Icons.shield_rounded,
              'Ghost Mode',
              'Hiçbir veri paylaşma, sadece izle',
              _ghostMode,
              (v) async {
                setState(() {
                  _ghostMode = v;
                  if (v) _isVisible = false;
                });
                final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                if (uid.isNotEmpty) {
                  await _firestoreService.updateProfile(uid, {
                    'privacyLevel': v ? 'ghost' : 'full',
                    'isVisible': !v,
                  });
                }
              },
            ),
            _buildToggle(
              Icons.location_on_rounded,
              'Konum Paylaşımı',
              'Arka planda konum verisi gönder',
              _locationSharing,
              (v) => setState(() => _locationSharing = v),
            ),

            const SizedBox(height: 20),

            // ── Bildirimler ──
            _sectionHeader('BİLDİRİMLER'),
            const SizedBox(height: 10),
            _buildToggle(
              Icons.notifications_rounded,
              'Push Bildirimler',
              'Hotspot ve öneri bildirimleri',
              _notifications,
              (v) => setState(() => _notifications = v),
            ),

            const SizedBox(height: 20),

            // ── Hukuki ──
            _sectionHeader('HUKUKİ'),
            const SizedBox(height: 10),
            _buildMenuItem(
              Icons.description_rounded,
              'Kullanım Koşulları',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TermsScreen())),
            ),
            _buildMenuItem(
              Icons.privacy_tip_rounded,
              'Gizlilik Politikası',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PrivacyScreen())),
            ),
            _buildMenuItem(
              Icons.download_rounded,
              'Verilerimi İndir',
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Yakında aktif olacak.'),
                    backgroundColor: AppColors.bgCard,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Hesap ──
            _sectionHeader('HESAP'),
            const SizedBox(height: 10),
            _buildMenuItem(
              Icons.logout_rounded,
              'Çıkış Yap',
              () => _showLogoutDialog(),
            ),
            _buildMenuItem(
              Icons.delete_forever_rounded,
              'Hesabı Sil',
              () => _showDeleteDialog(),
              color: AppColors.error,
            ),

            const SizedBox(height: 32),
            Center(
              child: Text(
                'PulseCity v1.0.0',
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withOpacity(0.15)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white.withOpacity(0.25),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildToggle(IconData icon, String title, String subtitle,
      bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.3))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white.withOpacity(0.3),
            inactiveTrackColor: Colors.white.withOpacity(0.08),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap,
      {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (color ?? Colors.white).withOpacity(0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18,
                  color: color ?? Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(width: 14),
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color ?? Colors.white)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: Colors.white.withOpacity(0.15)),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Çıkış Yap',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Çıkış yapmak istediğine emin misin?',
            style: TextStyle(color: Colors.white.withOpacity(0.5))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('İptal',
                  style:
                      TextStyle(color: Colors.white.withOpacity(0.4)))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Çıkış Yap',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hesabı Sil',
            style: TextStyle(
                color: AppColors.error, fontWeight: FontWeight.w700)),
        content: Text(
            'Bu işlem geri alınamaz. Tüm verilerin silinecek. Emin misin?',
            style: TextStyle(color: Colors.white.withOpacity(0.5))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('İptal',
                  style:
                      TextStyle(color: Colors.white.withOpacity(0.4)))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final uid =
                    FirebaseAuth.instance.currentUser?.uid ?? '';
                if (uid.isNotEmpty) {
                  await _firestoreService.deleteUserProfile(uid);
                }
                await FirebaseAuth.instance.currentUser?.delete();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          'Hesap silinemedi. Yeniden giriş yapıp tekrar dene.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              }
            },
            child: const Text('Hesabı Sil',
                style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}