import 'package:flutter/material.dart';

import '../menu_ui.dart';

class LanActionButton extends StatelessWidget {
  const LanActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.ui,
    required this.color,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final double ui;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MenuPressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 14 * ui,
          vertical: 9 * ui,
        ),
        decoration: BoxDecoration(
          color: onTap != null ? color : color.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8 * ui),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8 * ui,
                    spreadRadius: 1 * ui,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14 * ui, color: Colors.black87),
            SizedBox(width: 6 * ui),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Orbitron',
                color: Colors.black87,
                fontSize: 11 * ui,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8 * ui,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
