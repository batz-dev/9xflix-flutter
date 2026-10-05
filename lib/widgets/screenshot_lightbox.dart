import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_theme.dart';

class ScreenshotLightbox extends StatelessWidget {
  final String imageUrl;
  final int index;

  const ScreenshotLightbox({
    super.key,
    required this.imageUrl,
    this.index = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.95),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Pinch to Zoom Image
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                ),
              ),
            ),
          ),

          // Top Header Bar
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Screenshot #$index',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
