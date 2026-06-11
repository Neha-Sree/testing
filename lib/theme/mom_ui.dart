import 'package:flutter/material.dart';

/// Soft, simple styling for the mother-facing LifeNest app.
abstract final class MomUi {
  static const Color pink = Color(0xFFF06292);
  static const Color pinkDeep = Color(0xFFEC407A);
  static const Color background = Color(0xFFFFF8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF3D2C4A);
  static const Color textMuted = Color(0xFF8E7A9A);
  static const Color border = Color(0xFFF3E5F0);

  static const LinearGradient heroGradient = LinearGradient(
    colors: [pink, pinkDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static TextStyle get greeting => const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: text,
        letterSpacing: -0.3,
      );

  static TextStyle get subtitle => const TextStyle(
        fontSize: 14,
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      );

  static Widget embeddedHeader({
    required IconData icon,
    required String title,
    VoidCallback? onRefresh,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
      child: Row(
        children: [
          Icon(icon, color: pink, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: sectionTitle)),
          if (onRefresh != null)
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, color: textMuted, size: 22),
              tooltip: 'Refresh',
            ),
        ],
      ),
    );
  }
}

/// Rounded white card used across mother screens.
class MomSoftCard extends StatelessWidget {
  const MomSoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
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
      decoration: MomUi.softCard(),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: card,
      ),
    );
  }
}
