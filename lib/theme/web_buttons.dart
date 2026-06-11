import 'package:flutter/material.dart';

import 'maternal_theme.dart';

/// Screen-size buckets for responsive web UI.
enum WebBreakpoint { compact, medium, expanded }

abstract final class WebBreakpoints {
  static WebBreakpoint of(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 600) return WebBreakpoint.compact;
    if (w < 1024) return WebBreakpoint.medium;
    return WebBreakpoint.expanded;
  }

  static bool isCompact(BuildContext context) => of(context) == WebBreakpoint.compact;
  static bool isExpanded(BuildContext context) => of(context) == WebBreakpoint.expanded;
}

/// Responsive padding, height, and typography for primary actions.
class WebPrimaryButton extends StatelessWidget {
  const WebPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? color;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bp = WebBreakpoints.of(context);
    final accent = color ?? MaternalTheme.primaryPink;
    final height = switch (bp) {
      WebBreakpoint.compact => 48.0,
      WebBreakpoint.medium => 44.0,
      WebBreakpoint.expanded => 42.0,
    };
    final fontSize = switch (bp) {
      WebBreakpoint.compact => 15.0,
      WebBreakpoint.medium => 14.0,
      WebBreakpoint.expanded => 14.0,
    };
    final hPad = switch (bp) {
      WebBreakpoint.compact => 20.0,
      WebBreakpoint.medium => 18.0,
      WebBreakpoint.expanded => 16.0,
    };
    final radius = switch (bp) {
      WebBreakpoint.compact => 14.0,
      WebBreakpoint.medium => 12.0,
      WebBreakpoint.expanded => 10.0,
    };

    final child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white.withValues(alpha: 0.9)),
          )
        : (icon == null
            ? Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: fontSize + 2),
                  const SizedBox(width: 8),
                  Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700)),
                ],
              ));

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, Color.lerp(accent, Colors.black, 0.12)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: bp == WebBreakpoint.compact ? 14 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );

    if (!expand || bp == WebBreakpoint.expanded) {
      return Align(alignment: Alignment.center, child: button);
    }
    return SizedBox(width: double.infinity, child: button);
  }
}

/// Outlined secondary action — scales with screen width.
class WebOutlineButton extends StatelessWidget {
  const WebOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bp = WebBreakpoints.of(context);
    final accent = color ?? MaternalTheme.primaryPink;
    final height = switch (bp) {
      WebBreakpoint.compact => 46.0,
      WebBreakpoint.medium => 42.0,
      WebBreakpoint.expanded => 40.0,
    };
    final fontSize = switch (bp) {
      WebBreakpoint.compact => 14.0,
      WebBreakpoint.medium => 13.5,
      WebBreakpoint.expanded => 13.0,
    };
    final radius = switch (bp) {
      WebBreakpoint.compact => 14.0,
      WebBreakpoint.medium => 12.0,
      WebBreakpoint.expanded => 10.0,
    };

    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent.withValues(alpha: 0.6), width: 1.5),
        minimumSize: Size(expand ? double.infinity : 0, height),
        padding: EdgeInsets.symmetric(horizontal: bp == WebBreakpoint.compact ? 20 : 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
      ),
      child: icon == null
          ? Text(label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: fontSize + 2),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// Role / portal card with hover animation — width adapts to breakpoint.
class WebRoleCard extends StatefulWidget {
  const WebRoleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.themeColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color themeColor;
  final VoidCallback onTap;

  @override
  State<WebRoleCard> createState() => _WebRoleCardState();
}

class _WebRoleCardState extends State<WebRoleCard> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final bp = WebBreakpoints.of(context);
    final iconSize = switch (bp) {
      WebBreakpoint.compact => 32.0,
      WebBreakpoint.medium => 28.0,
      WebBreakpoint.expanded => 26.0,
    };
    final titleSize = switch (bp) {
      WebBreakpoint.compact => 20.0,
      WebBreakpoint.medium => 18.0,
      WebBreakpoint.expanded => 17.0,
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _active = true),
      onExit: (_) => setState(() => _active = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.all(bp == WebBreakpoint.compact ? 20 : 16),
          decoration: BoxDecoration(
            color: _active ? widget.themeColor.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(bp == WebBreakpoint.compact ? 20 : 16),
            border: Border.all(
              color: _active ? widget.themeColor.withValues(alpha: 0.4) : const Color(0xFFEEEEEE),
              width: _active ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.themeColor.withValues(alpha: _active ? 0.22 : 0.08),
                blurRadius: _active ? 18 : 10,
                offset: Offset(0, _active ? 8 : 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(bp == WebBreakpoint.compact ? 14 : 10),
                decoration: BoxDecoration(
                  color: widget.themeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, size: iconSize, color: widget.themeColor),
              ),
              SizedBox(width: bp == WebBreakpoint.compact ? 18 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        color: widget.themeColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: bp == WebBreakpoint.compact ? 13 : 12,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: bp == WebBreakpoint.compact ? 18 : 16,
                color: _active ? widget.themeColor : widget.themeColor.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact professional role chip for doctor / health worker row.
class WebProRoleButton extends StatefulWidget {
  const WebProRoleButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<WebProRoleButton> createState() => _WebProRoleButtonState();
}

class _WebProRoleButtonState extends State<WebProRoleButton> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final bp = WebBreakpoints.of(context);
    final compact = bp == WebBreakpoint.compact;
    final vPad = compact ? 14.0 : 11.0;
    final hPad = compact ? 16.0 : 14.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _active = true),
      onExit: (_) => setState(() => _active = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: _active ? widget.color.withValues(alpha: 0.14) : widget.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(compact ? 14 : 12),
            border: Border.all(color: widget.color.withValues(alpha: _active ? 0.5 : 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: compact ? 20 : 18, color: widget.color),
              SizedBox(width: compact ? 10 : 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: compact ? 14 : 13,
                  fontWeight: FontWeight.w700,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
