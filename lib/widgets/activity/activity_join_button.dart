import 'package:flutter/material.dart';

import '../../models/activity_model.dart';
import '../../theme/colors.dart';
import '../animated_press.dart';

/// Context-aware CTA button for an activity. Renders one of:
/// - "Sahibi" (host, disabled)
/// - "Etkinlik iptal edildi" (cancelled, disabled)
/// - "Etkinlik dolu" (full, disabled)
/// - "İstek bekleniyor" (pending approval — tappable for [onCancelRequest])
/// - "Katıldın ✓" (approved — tappable for [onLeave])
/// - "İstek gönder" (approval-required policy)
/// - "Katıl" (open policy, default)
///
/// Pass [loading] = true to render a spinner; the button stays the same width.
class ActivityJoinButton extends StatelessWidget {
  const ActivityJoinButton({
    super.key,
    required this.activity,
    this.onJoin,
    this.onLeave,
    this.onCancelRequest,
    this.loading = false,
    this.compact = false,
  });

  final ActivityModel activity;
  final VoidCallback? onJoin;
  final VoidCallback? onLeave;
  final VoidCallback? onCancelRequest;
  final bool loading;

  /// Compact version is shorter (used inside cards). Detail view uses the
  /// full-width version.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final state = _resolveState();
    final colors = _colorsFor(state);

    final tapHandler = loading ? null : _resolveOnTap(state);

    return AnimatedPress(
      onTap: tapHandler,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: compact ? 36 : 48,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 22,
        ),
        constraints: BoxConstraints(minWidth: compact ? 0 : 140),
        decoration: BoxDecoration(
          gradient: colors.gradient,
          color: colors.gradient == null ? colors.background : null,
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
          border: colors.border == null
              ? null
              : Border.all(color: colors.border!, width: 1.2),
          boxShadow: colors.glow == null
              ? null
              : [
                  BoxShadow(
                    color: colors.glow!,
                    blurRadius: 18,
                    spreadRadius: -3,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(colors.foreground),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.icon != null) ...[
                      Icon(state.icon, size: compact ? 15 : 17, color: colors.foreground),
                      const SizedBox(width: 7),
                    ],
                    Text(
                      state.label,
                      style: TextStyle(
                        color: colors.foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 12.5 : 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  _JoinState _resolveState() {
    if (activity.viewerIsHost) {
      return const _JoinState(
        label: 'Sahibi',
        icon: Icons.shield_rounded,
        kind: _JoinKind.disabled,
      );
    }
    if (activity.isCancelled) {
      return const _JoinState(
        label: 'İptal edildi',
        icon: Icons.block_rounded,
        kind: _JoinKind.disabled,
      );
    }
    switch (activity.viewerStatus) {
      case ActivityViewerStatus.approved:
        return const _JoinState(
          label: 'Katıldın',
          icon: Icons.check_circle_rounded,
          kind: _JoinKind.success,
        );
      case ActivityViewerStatus.requested:
        return const _JoinState(
          label: 'İstek bekleniyor',
          icon: Icons.hourglass_top_rounded,
          kind: _JoinKind.pending,
        );
      case ActivityViewerStatus.declined:
        return const _JoinState(
          label: 'Reddedildi',
          icon: Icons.do_not_disturb_alt_rounded,
          kind: _JoinKind.disabled,
        );
      case ActivityViewerStatus.host:
        return const _JoinState(
          label: 'Sahibi',
          icon: Icons.shield_rounded,
          kind: _JoinKind.disabled,
        );
      case ActivityViewerStatus.cancelled:
      case ActivityViewerStatus.none:
        if (activity.isFull) {
          return const _JoinState(
            label: 'Dolu',
            icon: Icons.lock_rounded,
            kind: _JoinKind.disabled,
          );
        }
        if (activity.joinPolicy == ActivityJoinPolicy.approvalRequired) {
          return const _JoinState(
            label: 'İstek gönder',
            icon: Icons.send_rounded,
            kind: _JoinKind.primary,
          );
        }
        return const _JoinState(
          label: 'Katıl',
          icon: Icons.add_rounded,
          kind: _JoinKind.primary,
        );
    }
  }

  VoidCallback? _resolveOnTap(_JoinState state) {
    switch (state.kind) {
      case _JoinKind.disabled:
        return null;
      case _JoinKind.success:
        return onLeave;
      case _JoinKind.pending:
        return onCancelRequest;
      case _JoinKind.primary:
        return onJoin;
    }
  }

  _ButtonColors _colorsFor(_JoinState state) {
    switch (state.kind) {
      case _JoinKind.primary:
        return _ButtonColors(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryGlow],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          foreground: Colors.white,
          glow: AppColors.primary.withValues(alpha: 0.45),
        );
      case _JoinKind.success:
        return _ButtonColors(
          background: AppColors.success.withValues(alpha: 0.18),
          border: AppColors.success.withValues(alpha: 0.55),
          foreground: AppColors.success,
        );
      case _JoinKind.pending:
        return _ButtonColors(
          background: AppColors.warning.withValues(alpha: 0.16),
          border: AppColors.warning.withValues(alpha: 0.5),
          foreground: AppColors.warning,
        );
      case _JoinKind.disabled:
        return _ButtonColors(
          background: AppColors.bgChip.withValues(alpha: 0.55),
          border: Colors.white.withValues(alpha: 0.06),
          foreground: AppColors.textHint,
        );
    }
  }
}

enum _JoinKind { primary, success, pending, disabled }

class _JoinState {
  const _JoinState({
    required this.label,
    required this.icon,
    required this.kind,
  });

  final String label;
  final IconData? icon;
  final _JoinKind kind;
}

class _ButtonColors {
  _ButtonColors({
    this.gradient,
    this.background,
    this.border,
    required this.foreground,
    this.glow,
  });

  final Gradient? gradient;
  final Color? background;
  final Color? border;
  final Color foreground;
  final Color? glow;
}
