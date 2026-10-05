import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../constants/app_theme.dart';
import 'quality_badge.dart';
import '../screens/movie_details_screen.dart';

class MovieCard extends StatelessWidget {
  final Movie movie;
  final double? width;
  final double? height;

  const MovieCard({
    super.key,
    required this.movie,
    this.width,
    this.height,
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
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster with Badge Overlay
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  movie.poster.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: movie.poster,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppTheme.surfaceElevated,
                            child: const Center(
                              child: Icon(Icons.movie_outlined, color: AppTheme.textMuted, size: 28),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppTheme.surfaceElevated,
                            child: const Center(
                              child: Icon(Icons.broken_image_outlined, color: AppTheme.textMuted, size: 28),
                            ),
                          ),
                        )
                      : Container(
                          color: AppTheme.surfaceElevated,
                          child: const Center(
                            child: Icon(Icons.movie_creation_outlined, color: AppTheme.textMuted, size: 32),
                          ),
                        ),

                  // Gradient bottom shadow on image
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppTheme.surface.withOpacity(0.9),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top Left Badges
                  Positioned(
                    top: 6,
                    left: 6,
                    child: QualityBadge(
                      quality: movie.quality,
                      isHdtc: movie.isHdtc,
                      ripType: movie.ripType,
                      fontSize: 9,
                    ),
                  ),

                  // Top Right Custom Badge (e.g. New / Hot)
                  if (movie.badge.isNotEmpty)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          movie.badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Title & Info Bar
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                movie.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
