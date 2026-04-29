import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/colors.dart';

/// Live-updating countdown pill for time-sensitive ("Anlık") activities.
///
/// Renders one of:
///   • "ŞİMDİ" (within ±10m of [startsAt])
///   • "X dk kaldı" / "X sa kaldı" / "X gün kaldı"
///   • "Başladı" (after start, before end)
///   • "Bitti" (after end, if provided — otherwise after start +6h cutoff)
///
/// The widget self-ticks once per minute so dashboards stay accurate without
/// the parent rebuilding.
class ActivityCountdownPill extends StatefulWidget {
  const ActivityCountdownPill({
    super.key,
    required this.startsAt,
    this.endsAt,
    this.compact = false,
    this.color,
  });

  final DateTime startsAt;
  final DateTime? endsAt;
  final bool compact;
  final Color? color;

  @override
  State<ActivityCountdownPill> createState() => _ActivityCountdownPillState();
}

class _ActivityCountdownPillState extends State<ActivityCountdownPill> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.color ?? AppColors.neonCyan;
    final descriptor = _describe();
    final fontSize = widget.compact ? 10.5 : 12.0;
    final hPad = widget.compact ? 8.0 : 10.0;
    final vPad = widget.compact ? 4.0 : 5.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: descriptor.urgent ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withValues(alpha: descriptor.urgent ? 0.65 : 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            descriptor.icon,
            color: accent,
            size: widget.compact ? 11 : 13,
          ),
          SizedBox(width: widget.compact ? 4 : 5),
          Text(
            descriptor.label,
            style: TextStyle(
              color: accent,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  _CountdownDescriptor _describe() {
    final now = DateTime.now();
    final start = widget.startsAt.toLocal();
    final end = widget.endsAt?.toLocal();
    final diff = start.difference(now);
    final inProgressEnd = end ?? start.add(const Duration(hours: 6));

    if (now.isAfter(inProgressEnd)) {
      return const _CountdownDescriptor(
        label: 'Bitti',
        icon: Icons.history_rounded,
        urgent: false,
      );
    }
    if (now.isAfter(start.subtract(const Duration(minutes: 10))) &&
        now.isBefore(start.add(const Duration(minutes: 10)))) {
      return const _CountdownDescriptor(
        label: 'ŞİMDİ',
        icon: Icons.bolt_rounded,
        urgent: true,
      );
    }
    if (now.isAfter(start)) {
      return const _CountdownDescriptor(
        label: 'Başladı',
        icon: Icons.play_arrow_rounded,
        urgent: true,
      );
    }
    final mins = diff.inMinutes;
    if (mins < 60) {
      return _CountdownDescriptor(
        label: '$mins dk kaldı',
        icon: Icons.timer_rounded,
        urgent: true,
      );
    }
    final hours = diff.inHours;
    if (hours < 24) {
      return _CountdownDescriptor(
        label: '$hours sa kaldı',
        icon: Icons.schedule_rounded,
        urgent: hours < 6,
      );
    }
    final days = diff.inDays;
    return _CountdownDescriptor(
      label: '$days gün kaldı',
      icon: Icons.event_rounded,
      urgent: false,
    );
  }
}

class _CountdownDescriptor {
  const _CountdownDescriptor({
    required this.label,
    required this.icon,
    required this.urgent,
  });

  final String label;
  final IconData icon;
  final bool urgent;
}
