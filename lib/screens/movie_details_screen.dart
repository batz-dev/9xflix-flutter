import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/movie.dart';
import '../models/movie_details.dart';
import '../models/download_option.dart';
import '../providers/movies_provider.dart';
import '../services/storage_service.dart';
import '../constants/app_theme.dart';
import '../widgets/quality_badge.dart';
import '../widgets/screenshot_lightbox.dart';
import '../widgets/download_bottom_sheet.dart';

class MovieDetailsScreen extends StatefulWidget {
  final String slug;
  final Movie? initialMovie;

  const MovieDetailsScreen({
    super.key,
    required this.slug,
    this.initialMovie,
  });

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  bool _isLoading = true;
  MovieDetails? _details;
  String? _error;
  bool _isWatchlisted = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _checkWatchlist();
  }

  Future<void> _checkWatchlist() async {
    final watchlisted = await StorageService.isWatchlisted(widget.slug);
    if (mounted) setState(() => _isWatchlisted = watchlisted);
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final provider = Provider.of<MoviesProvider>(context, listen: false);
    final details = await provider.getMovieDetails(widget.slug);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (details.error != null && details.title.isEmpty) {
          _error = details.error;
        } else {
          _details = details;
        }
      });
    }
  }

  void _openDownloadModal(DownloadOption option) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DownloadBottomSheet(
        option: option,
        movieTitle: _details?.cleanTitle ?? widget.initialMovie?.title ?? 'Movie',
        poster: _details?.poster ?? widget.initialMovie?.poster ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final poster = _details?.poster ?? widget.initialMovie?.poster ?? '';
    final title = _details?.cleanTitle.isNotEmpty == true
        ? _details!.cleanTitle
        : (widget.initialMovie?.title ?? 'Movie Details');
    final rawTitle = _details?.title ?? widget.initialMovie?.title ?? '';

    return Scaffold(
      body: _isLoading && _details == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text('Fetching details & download links...', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadDetails,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    // Backdrop Header with Poster & Title
                    SliverAppBar(
                      expandedHeight: 320,
                      pinned: true,
                      backgroundColor: AppTheme.background,
                      actions: [
                        IconButton(
                          icon: Icon(
                            _isWatchlisted ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: _isWatchlisted ? AppTheme.primary : Colors.white,
                          ),
                          onPressed: () async {
                            if (widget.initialMovie != null) {
                              await StorageService.toggleWatchlist(widget.initialMovie!);
                              setState(() => _isWatchlisted = !_isWatchlisted);
                            }
                          },
                        ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Backdrop Image
                            if (poster.isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: poster,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                              ),

                            // Dark Gradient
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    AppTheme.background,
                                    AppTheme.background.withOpacity(0.85),
                                    Colors.black.withOpacity(0.4),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.5, 0.8, 1.0],
                                ),
                              ),
                            ),

                            // Poster & Metadata Overlay
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Poster Card
                                  Container(
                                    width: 90,
                                    height: 135,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.cardBorder, width: 1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.5),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: poster.isNotEmpty
                                        ? CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover)
                                        : Container(color: AppTheme.surfaceElevated),
                                  ),
                                  const SizedBox(width: 14),

                                  // Title & Rip Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            if (_details?.isHdtc == true)
                                              const QualityBadge(quality: 'HDTC', isHdtc: true)
                                            else if (_details?.ripType.isNotEmpty == true)
                                              QualityBadge(quality: _details!.ripType),
                                            if (_details?.cleanYear.isNotEmpty == true) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.surfaceElevated,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                                                ),
                                                child: Text(
                                                  _details!.cleanYear,
                                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                            if (_details?.imdbRating.isNotEmpty == true) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade900.withOpacity(0.3),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.amber.shade600, width: 0.8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.star_rounded, size: 12, color: AppTheme.accentGold),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      _details!.imdbRating,
                                                      style: const TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: -0.4,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          rawTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Details Body
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Genres & Languages
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_details?.languages.isNotEmpty == true)
                                  _buildTag(Icons.translate_rounded, _details!.languages, AppTheme.accentBlue),
                                if (_details?.genres.isNotEmpty == true)
                                  _buildTag(Icons.local_movies_rounded, _details!.genres, AppTheme.accentPurple),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // HDTC Warning Alert
                            if (_details?.isHdtc == true)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade900.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.shade700),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: AppTheme.accentGold, size: 20),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'HDTC Theater Print: Official digital print (WEB-DL) will be updated when released.',
                                        style: TextStyle(color: AppTheme.accentGold, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Storyline
                            if (_details?.plot.isNotEmpty == true) ...[
                              const Text(
                                'OVERVIEW',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                                ),
                                child: Text(
                                  _details!.plot,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Director & Cast
                            if (_details?.director.isNotEmpty == true || _details?.stars.isNotEmpty == true) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_details?.director.isNotEmpty == true)
                                      Row(
                                        children: [
                                          const Text('Director: ', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                          Expanded(
                                            child: Text(
                                              _details!.director,
                                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (_details?.director.isNotEmpty == true && _details?.stars.isNotEmpty == true)
                                      const Divider(color: AppTheme.cardBorder, height: 16),
                                    if (_details?.stars.isNotEmpty == true)
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Cast: ', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                          Expanded(
                                            child: Text(
                                              _details!.stars,
                                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Direct Downloads Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.download_rounded, color: AppTheme.primary, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Direct Downloads',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGreen.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Cloudflare R2 CDN',
                                    style: TextStyle(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (_details?.downloads.isEmpty == true)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Text('No direct download links found on this page.', style: TextStyle(color: AppTheme.textMuted)),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _details!.downloads.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final dl = _details!.downloads[index];
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                                          ),
                                          child: Text(
                                            dl.quality,
                                            style: const TextStyle(
                                              color: AppTheme.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                dl.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (dl.size.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  dl.size,
                                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () => _openDownloadModal(dl),
                                          icon: const Icon(Icons.bolt_rounded, size: 16, color: Colors.amberAccent),
                                          label: const Text('Download', style: TextStyle(fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                            const SizedBox(height: 28),

                            // Real Screenshots Gallery
                            if (_details?.screenshots.isNotEmpty == true) ...[
                              Row(
                                children: [
                                  const Icon(Icons.photo_library_rounded, color: AppTheme.primary, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Screenshots (SS)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_details!.screenshots.length} photos',
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 180,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _details!.screenshots.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final imgUrl = _details!.screenshots[index];
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ScreenshotLightbox(
                                              imageUrl: imgUrl,
                                              index: index + 1,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: 280,
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceElevated,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            CachedNetworkImage(
                                              imageUrl: imgUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => const Center(
                                                child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
                                              ),
                                              errorWidget: (_, __, ___) => const Center(
                                                child: Icon(Icons.broken_image, color: AppTheme.textMuted),
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 6,
                                              right: 6,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.7),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.zoom_in_rounded, color: Colors.white, size: 12),
                                                    SizedBox(width: 3),
                                                    Text('Zoom', style: TextStyle(color: Colors.white, fontSize: 10)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
