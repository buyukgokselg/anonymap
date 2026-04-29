import 'package:flutter/material.dart';

import '../../models/activity_model.dart';
import '../../models/activity_rating_model.dart';
import '../../services/activity_service.dart';
import '../../theme/colors.dart';
import '../app_snackbar.dart';

/// Modal bottom sheet for rating a single activity participant or host.
///
/// Returns true via [Navigator.pop] when the rating is submitted successfully,
/// so callers can refresh their pending list / aggregate display.
class ActivityRatingSheet extends StatefulWidget {
  const ActivityRatingSheet({
    super.key,
    required this.activity,
    required this.target,
  });

  final ActivityModel activity;
  final ActivityRatingUser target;

  static Future<bool?> show(
    BuildContext context, {
    required ActivityModel activity,
    required ActivityRatingUser target,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActivityRatingSheet(activity: activity, target: target),
    );
  }

  @override
  State<ActivityRatingSheet> createState() => _ActivityRatingSheetState();
}

class _ActivityRatingSheetState extends State<ActivityRatingSheet> {
  int _score = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_score < 1 || _score > 5) {
      AppSnackbar.showError(context, 'Lütfen 1–5 yıldız arası bir puan seç.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await ActivityService.instance.createRating(
        widget.activity.id,
        ratedUserId: widget.target.id,
        score: _score,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );
      if (!mounted) return;
      if (result == null) {
        AppSnackbar.showError(context, 'Puan gönderilemedi.');
        setState(() => _submitting = false);
        return;
      }
      AppSnackbar.showSuccess(context, 'Teşekkürler — puanın kaydedildi.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
      setState(() => _submitting = false);
    }
  }

  String get _scoreLabel {
    switch (_score) {
      case 1:
        return 'Hiç memnun kalmadım';
      case 2:
        return 'Beklediğimden zayıf';
      case 3:
        return 'Fena değil';
      case 4:
        return 'Güzeldi';
      case 5:
      default:
        return 'Harikaydı! 🤩';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            _buildHeader(),
            const SizedBox(height: 24),
            _buildStars(),
            const SizedBox(height: 8),
            Text(
              _scoreLabel,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            _buildCommentField(),
            const SizedBox(height: 20),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final photoUrl = widget.target.profilePhotoUrl;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.6),
                AppColors.primaryGlow.withValues(alpha: 0.45),
              ],
            ),
          ),
          padding: const EdgeInsets.all(2),
          child: ClipOval(
            child: photoUrl != null && photoUrl.isNotEmpty
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => _initialsAvatar(),
                  )
                : _initialsAvatar(),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.target.displayName.isEmpty
                    ? widget.target.userName
                    : widget.target.displayName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.activity.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _initialsAvatar() {
    final name = widget.target.displayName.isEmpty
        ? widget.target.userName
        : widget.target.displayName;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      color: AppColors.bgSurface,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final value = index + 1;
        final filled = value <= _score;
        return GestureDetector(
          onTap: _submitting ? null : () => setState(() => _score = value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale: filled ? 1.06 : 1.0,
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 40,
                color: filled
                    ? AppColors.warning
                    : AppColors.textHint.withValues(alpha: 0.6),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCommentField() {
    return TextField(
      controller: _commentController,
      enabled: !_submitting,
      minLines: 2,
      maxLines: 4,
      maxLength: 800,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Yorum (isteğe bağlı) — etkinliğin nasıldı?',
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
        filled: true,
        fillColor: AppColors.bgSurface,
        counterStyle: const TextStyle(color: AppColors.textHint, fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Vazgeç'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryGlow],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _submitting ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text(
                            'Puanı Gönder',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
