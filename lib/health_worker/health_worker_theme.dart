import 'package:flutter/material.dart';

/// Shared palette and widgets for the health worker portal.
abstract final class HwTheme {
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryDeep = Color(0xFF1B5E20);
  static const Color accent = Color(0xFF00897B);
  static const Color background = Color(0xFFF1F8E9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF1B3A1F);
  static const Color textMuted = Color(0xFF5D7A62);
  static const Color border = Color(0xFFE0F2E0);

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF43A047), primary, primaryDeep],
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
        color: color ?? surface,
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
}

class HwSoftCard extends StatelessWidget {
  const HwSoftCard({
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
      decoration: HwTheme.softCard(),
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
