import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class QualityBadge extends StatelessWidget {
  final String quality;
  final bool isHdtc;
  final String ripType;
  final double fontSize;

  const QualityBadge({
    super.key,
    required this.quality,
    this.isHdtc = false,
    this.ripType = '',
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (isHdtc) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.shade600,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.shade900.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_rounded, size: fontSize + 1, color: Colors.black),
            const SizedBox(width: 3),
            Text(
              'HDTC',
              style: TextStyle(
                color: Colors.black,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    final text = ripType.isNotEmpty ? ripType : quality;
    final is1080p = text.contains('1080p') || text.contains('2160p') || text.contains('4K');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: is1080p ? AppTheme.primary : AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: is1080p ? AppTheme.primary : AppTheme.cardBorder,
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
