import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../constants/app_theme.dart';
import 'quality_badge.dart';
import '../screens/movie_details_screen.dart';

class HeroBanner extends StatelessWidget {
  final Movie movie;

  const HeroBanner({
    super.key,
    required this.movie,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MovieDetailsScreen(
              slug: movie.slug,
              initialMovie: movie,
            ),
          ),
        );
      },
      child: Container(
        height: 220,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cardBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            movie.poster.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: movie.poster,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  )
                : Container(color: AppTheme.surfaceElevated),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppTheme.background,
                    AppTheme.background.withOpacity(0.8),
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 0.75, 1.0],
                ),
              ),
            ),

            // Content
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'FEATURED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      QualityBadge(
                        quality: movie.quality,
                        isHdtc: movie.isHdtc,
                        ripType: movie.ripType,
                        fontSize: 9,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MovieDetailsScreen(
                                slug: movie.slug,
                                initialMovie: movie,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download / Details', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
