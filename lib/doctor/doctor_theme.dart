import 'package:flutter/material.dart';

import '../services/mom_api_base_url.dart';

/// Shared palette for the doctor portal (medical blue / teal accents).
abstract final class DoctorTheme {
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryDeep = Color(0xFF1565C0);
  static const Color accentTeal = Color(0xFF00897B);
  static const Color criticalRed = Color(0xFFD32F2F);
  static const Color warningYellow = Color(0xFFF9A825);
  static const Color healthyGreen = Color(0xFF43A047);
  static const Color surfaceWhite = Colors.white;
  static const Color surfaceMuted = Color(0xFFF0F7FF);
  static const Color text = Color(0xFF1A2B4A);
  static const Color textMuted = Color(0xFF6B7C93);
  static const Color border = Color(0xFFE3EDF7);

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF42A5F5), primary, primaryDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static TextStyle get greeting => const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: text,
        letterSpacing: -0.3,
      );

  static TextStyle get subtitle => const TextStyle(
        fontSize: 13,
        color: textMuted,
        height: 1.35,
      );

  static TextStyle get sectionTitle => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: text,
      );

  static TextStyle get caption => const TextStyle(
        fontSize: 12,
        color: textMuted,
      );

  static BoxDecoration softCard({Color? color}) => BoxDecoration(
        color: color ?? surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      );

  static Color levelColor(String? level) {
    switch ((level ?? '').toLowerCase()) {
      case 'critical':
        return criticalRed;
      case 'red':
        return criticalRed.withValues(alpha: 0.85);
      case 'yellow':
        return warningYellow;
      case 'green':
        return healthyGreen;
      default:
        return primary;
    }
  }
}

/// Builds a public URL for a mother's profile image stored under `/uploads`.
String doctorMotherImageUrl(String? storedPath) {
  if (storedPath == null || storedPath.isEmpty) {
    return '';
  }
  var clean = storedPath.replaceAll(r'\', '/');
  final lower = clean.toLowerCase();
  final idx = lower.indexOf('uploads/');
  if (idx >= 0) {
    clean = clean.substring(idx + 'uploads/'.length);
  }
  return momUploadUrl(clean);
}

/// Rounded white card used across doctor portal screens.
class DoctorSoftCard extends StatelessWidget {
  const DoctorSoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: DoctorTheme.softCard(),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: card,
      ),
    );
  }
}
