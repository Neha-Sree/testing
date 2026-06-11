import 'package:flutter/material.dart';

class CuteFooter extends StatelessWidget {
  final Color color;

  const CuteFooter({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.spa_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            'Nurturing lives with love',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.favorite_rounded, size: 16, color: color),
        ],
      ),
    );
  }
}
