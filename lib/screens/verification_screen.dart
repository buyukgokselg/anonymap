import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/pulse_api_service.dart';
import '../services/storage_service.dart';
import '../theme/colors.dart';
import '../widgets/app_snackbar.dart';

/// 4-step photo verification wizard:
///   0) Intro / why-verify
///   1) Pick a gesture (smile, peace, thumbs, wave)
///   2) Capture or pick selfie
///   3) Review + submit
///
/// On submit, uploads the selfie to the backend storage, calls
/// `POST /api/users/me/photo-verification`, and renders a success
/// state. Backend auto-approves in dev environment.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final PageController _pageController = PageController();
  final ImagePicker _picker = ImagePicker();

  static const _stepCount = 4;
  int _currentStep = 0;

  String _gesture = 'smile';
  XFile? _selfieFile;

  bool _submitting = false;
  bool _submitted = false;
  String _resolvedStatus = 'none';
  bool _resolvedVerified = false;

  Future<void> _next() async {
    if (_currentStep == _stepCount - 1) {
      await _submit();
      return;
    }
    if (_currentStep == 2 && _selfieFile == null) {
      AppSnackbar.showError(context, 'Önce bir selfie ekle.');
      return;
    }
    setState(() => _currentStep += 1);
    _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    HapticFeedback.lightImpact();
  }

  void _prev() {
    if (_currentStep == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _currentStep -= 1);
    _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 88,
        maxWidth: 1280,
      );
      if (file != null) {
        setState(() => _selfieFile = file);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, 'Kamera açılamadı: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1280,
      );
      if (file != null) {
        setState(() => _selfieFile = file);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, 'Galeri açılamadı: $e');
    }
  }

  Future<void> _submit() async {
    final file = _selfieFile;
    if (file == null) {
      AppSnackbar.showError(context, 'Önce bir selfie ekle.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final uid = AuthService().currentUserId;
      final url = await StorageService().uploadXFile(
        file: file,
        path: 'verification/$uid',
      );
      final result = await PulseApiService.instance.submitPhotoVerification(
        selfieUrl: url,
        gesture: _gesture,
      );
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _resolvedStatus = (result?['status'] ?? 'pending').toString();
        _resolvedVerified = result?['isPhotoVerified'] == true;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, 'Doğrulama gönderilemedi: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: _submitted ? _buildSuccess() : _buildWizard(),
      ),
    );
  }

  Widget _buildWizard() {
    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 8),
        _buildStepIndicator(),
        const SizedBox(height: 12),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentStep = i),
            children: [
              _buildIntroStep(),
              _buildGestureStep(),
              _buildSelfieStep(),
              _buildReviewStep(),
            ],
          ),
        ),
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: _prev,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          const Text(
            'Profil doğrulaması',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          Text(
            '${_currentStep + 1} / $_stepCount',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < _stepCount; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                height: 4,
                decoration: BoxDecoration(
                  gradient: i <= _currentStep
                      ? const LinearGradient(
                          colors: [AppColors.primary, AppColors.neonCyan],
                        )
                      : null,
                  color: i <= _currentStep
                      ? null
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            if (i != _stepCount - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final lastStep = _currentStep == _stepCount - 1;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _next,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    lastStep ? 'Gönder' : 'Devam',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Step 0 — Intro ─────────────────────────────────────────────────────────

  Widget _buildIntroStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 132,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.neonCyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.32),
                  blurRadius: 26,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.verified_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Mavi rozetin var olsun',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hızlı bir selfie ile profilinin gerçek olduğunu kanıtla. '
            'Doğrulanan profiller keşif akışında öne çıkar ve eşleşme oranı yükselir.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          _buildBenefitRow(
            Icons.bolt_rounded,
            'Daha fazla görünürlük',
            'Discover akışında doğrulanmış filtresine takılırsın.',
          ),
          const SizedBox(height: 12),
          _buildBenefitRow(
            Icons.shield_rounded,
            'Gerçek insanlar arası güven',
            'Karşı tarafın da rozetli olduğunu görürsün.',
          ),
          const SizedBox(height: 12),
          _buildBenefitRow(
            Icons.lock_clock_rounded,
            'Sadece moderasyon görür',
            'Selfie\'n profile yansıtılmaz, herkese kapalı kalır.',
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.neonCyan, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 1 — Gesture pick ──────────────────────────────────────────────────

  Widget _buildGestureStep() {
    const gestures = <_GestureOption>[
      _GestureOption('smile', 'Gülümse', '😊', 'Doğal bir gülüş yeterli'),
      _GestureOption('peace', 'Peace işareti', '✌️', 'İki parmakla kameraya'),
      _GestureOption('thumbs_up', 'Başparmak', '👍', 'Yukarı kaldır'),
      _GestureOption('wave', 'El salla', '👋', 'Açık avuçla'),
      _GestureOption('wink', 'Göz kırp', '😉', 'Bir gözünü kapat'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bir hareket seç',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Selfie\'de seçtiğin hareketi yapman, fotoğrafın gerçek zamanlı '
            'olduğunu kanıtlar.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ...gestures.map((g) => _buildGestureTile(g)),
        ],
      ),
    );
  }

  Widget _buildGestureTile(_GestureOption g) {
    final selected = _gesture == g.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          setState(() => _gesture = g.id);
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? null : AppColors.bgCard,
            gradient: selected
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryGlow],
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.06),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.32),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: selected ? 0.18 : 0.06,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(g.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      g.hint,
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: selected ? 0.85 : 0.55,
                        ),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 2 — Selfie capture ────────────────────────────────────────────────

  Widget _buildSelfieStep() {
    final file = _selfieFile;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selfie çek',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Yüzün net görünsün, seçtiğin hareketi yap. Şapka, gözlük veya '
            'maske olmasın.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppColors.bgCard,
                border: Border.all(
                  color: file == null
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.neonCyan.withValues(alpha: 0.5),
                  width: file == null ? 1 : 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: file == null
                  ? _buildSelfiePlaceholder()
                  : Image.file(
                      File(file.path),
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCaptureButton(
                  icon: Icons.photo_camera_rounded,
                  label: 'Kamera',
                  onTap: _pickFromCamera,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCaptureButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Galeri',
                  onTap: _pickFromGallery,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelfiePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.face_retouching_natural_rounded,
          size: 56,
          color: Colors.white.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 10),
        Text(
          'Selfie henüz eklenmedi',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.neonCyan),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 3 — Review ────────────────────────────────────────────────────────

  Widget _buildReviewStep() {
    final file = _selfieFile;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Son kontrol',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Gönderdiğinde selfie\'n güvenli sunucuda saklanır ve sadece '
            'moderasyon ekibi görür.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          if (file != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.file(File(file.path), fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 16),
          _buildReviewRow('Hareket', _gestureLabel(_gesture)),
          const SizedBox(height: 8),
          _buildReviewRow(
            'Onay süresi',
            'Genellikle 24 saat içinde sonuç bildirimi gelir.',
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _gestureLabel(String id) {
    return switch (id) {
      'peace' => 'Peace işareti ✌️',
      'thumbs_up' => 'Başparmak 👍',
      'wave' => 'El salla 👋',
      'wink' => 'Göz kırp 😉',
      _ => 'Gülümse 😊',
    };
  }

  // ── Success ────────────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    final approved = _resolvedVerified || _resolvedStatus == 'approved';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: approved
                    ? const [AppColors.primary, AppColors.neonCyan]
                    : [AppColors.primary, AppColors.primaryGlow],
              ),
              boxShadow: [
                BoxShadow(
                  color: (approved ? AppColors.neonCyan : AppColors.primary)
                      .withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              approved ? Icons.verified_rounded : Icons.hourglass_top_rounded,
              size: 68,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            approved ? 'Profilin doğrulandı 🎉' : 'Başvurun gönderildi',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            approved
                ? 'Mavi rozetin artık profilinde. Discover akışında doğrulanmış '
                      'kullanıcılar arasında öne çıkıyorsun.'
                : 'Selfie\'n moderasyon kuyruğunda. Onay sonucu bildirimle '
                      'sana iletilecek — genellikle 24 saat içinde.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Tamam',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GestureOption {
  final String id;
  final String label;
  final String emoji;
  final String hint;
  const _GestureOption(this.id, this.label, this.emoji, this.hint);
}
