import 'dart:math';
import 'package:flutter/material.dart';
import 'cute_footer.dart';
import 'name_input_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  String _generateId(String prefix) {
    // Generate a secure random 5 digit number string (padded with zeros if needed)
    final random = Random();
    final number = random.nextInt(100000); // 0 to 99999
    final fiveDigitNumber = number.toString().padLeft(5, '0');
    return '$prefix$fiveDigitNumber';
  }

  void _handleRoleSelection(
    BuildContext context,
    String title,
    String prefix,
    MaterialColor color,
  ) {
    final newId = _generateId(prefix);

    // Navigate to the name input screen before going to dashboard
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            NameInputScreen(role: title, generatedId: newId, themeColor: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 80,
                        color: Colors.pink.shade400,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome to Life Nest',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.pink.shade900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please select your role to continue',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.pink.shade700,
                        ),
                      ),
                      const SizedBox(height: 40),
                      HoverCard(
                        title: 'Mother',
                        icon: Icons.pregnant_woman,
                        themeColor: Colors.pink,
                        onTap: () => _handleRoleSelection(
                          context,
                          'Mother',
                          'MUM',
                          Colors.pink,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Medical Professionals',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.pink.shade300,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () => _handleRoleSelection(
                              context,
                              'Doctor',
                              'DOC',
                              Colors.blue,
                            ),
                            icon: Icon(
                              Icons.medical_services,
                              size: 18,
                              color: Colors.blue.shade600,
                            ),
                            label: Text(
                              'Doctor',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              backgroundColor: Colors.blue.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          TextButton.icon(
                            onPressed: () => _handleRoleSelection(
                              context,
                              'Health Worker',
                              'HWN',
                              Colors.green,
                            ),
                            icon: Icon(
                              Icons.health_and_safety,
                              size: 18,
                              color: Colors.green.shade600,
                            ),
                            label: Text(
                              'Health Worker',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              backgroundColor: Colors.green.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            CuteFooter(color: Colors.pink.shade300),
          ],
        ),
      ),
    );
  }
}

class HoverCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final MaterialColor themeColor;
  final VoidCallback onTap;

  const HoverCard({
    super.key,
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.onTap,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _isPressedOrHovered = false;

  void _updateState(bool isActive) {
    setState(() => _isPressedOrHovered = isActive);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isPressedOrHovered
        ? widget.themeColor.shade50
        : Colors.white;
    final shadowColor = widget.themeColor.withAlpha(51);
    final borderColor = _isPressedOrHovered
        ? widget.themeColor.shade300
        : Colors.transparent;
    final iconBgColor = widget.themeColor.shade50;
    final iconColor = widget.themeColor.shade600;
    final textColor = widget.themeColor.shade800;
    final arrowColor = _isPressedOrHovered
        ? widget.themeColor.shade600
        : widget.themeColor.shade300;

    return MouseRegion(
      onEnter: (_) => _updateState(true),
      onExit: (_) => _updateState(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _updateState(true),
        onTapUp: (_) => _updateState(false),
        onTapCancel: () => _updateState(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 30),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withValues(
                  alpha: _isPressedOrHovered ? 0.6 : 0.15,
                ),
                blurRadius: _isPressedOrHovered ? 15 : 10,
                offset: Offset(0, _isPressedOrHovered ? 8 : 4),
              ),
            ],
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, size: 32, color: iconColor),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: arrowColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
