import 'package:flutter/material.dart';

import '../models/health_worker_models.dart';

/// Maps a [RiskLevel] to a triad of colors used across the HW UI.
class RiskColors {
  RiskColors({required this.bg, required this.fg, required this.label});

  final Color bg;
  final Color fg;
  final String label;

  static RiskColors of(RiskLevel level) {
    switch (level) {
      case RiskLevel.critical:
        return RiskColors(bg: const Color(0xFFB71C1C), fg: Colors.white, label: 'CRITICAL');
      case RiskLevel.red:
        return RiskColors(bg: const Color(0xFFE53935), fg: Colors.white, label: 'HIGH RISK');
      case RiskLevel.yellow:
        return RiskColors(bg: const Color(0xFFFFC107), fg: const Color(0xFF5D4037), label: 'MODERATE');
      case RiskLevel.green:
        return RiskColors(bg: const Color(0xFF43A047), fg: Colors.white, label: 'HEALTHY');
    }
  }
}

/// Pill-shaped risk chip used on dashboard cards.
class RiskChip extends StatelessWidget {
  const RiskChip({super.key, required this.level, this.compact = false});

  final RiskLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = RiskColors.of(level);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 3 : 6),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        c.label,
        style: TextStyle(
          color: c.fg,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 10 : 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
