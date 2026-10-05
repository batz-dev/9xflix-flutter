import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/download_option.dart';
import '../models/mirror_links.dart';
import '../providers/movies_provider.dart';
import '../services/download_manager.dart';
import '../services/platform/download_storage.dart';
import '../constants/app_theme.dart';

class DownloadBottomSheet extends StatefulWidget {
  final DownloadOption option;
  final String movieTitle;
  final String poster;

  const DownloadBottomSheet({
    super.key,
    required this.option,
    required this.movieTitle,
    required this.poster,
  });

  @override
  State<DownloadBottomSheet> createState() => _DownloadBottomSheetState();
}

class _DownloadBottomSheetState extends State<DownloadBottomSheet> {
  bool _isLoading = true;
  MirrorLinks? _links;
  String? _error;
  String? _resolvingMirror;

  @override
  void initState() {
    super.initState();
    _resolveLink();
  }

  Future<void> _resolveLink() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final provider = Provider.of<MoviesProvider>(context, listen: false);
    final result = await provider.resolveDownload(widget.option.intermediateUrl);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.status == 'success') {
          _links = result;
        } else {
          _error = result.error ?? 'Failed to resolve download mirrors';
        }
      });
    }
  }

  void _triggerDownload(String url) async {
    final dm = DownloadManager();
    await dm.startDownload(
      movieTitle: widget.movieTitle,
      quality: widget.option.quality,
      size: widget.option.size,
      downloadUrl: url,
      poster: widget.poster,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surfaceElevated,
          content: Row(
            children: [
              const Icon(Icons.downloading_rounded, color: AppTheme.accentGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Downloading ${widget.option.quality} to FlixDirect folder',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View',
            textColor: AppTheme.primary,
            onPressed: () {
              // Can navigate to Downloads tab
            },
          ),
        ),
      );
    }
  }

  Future<void> _handleGofileDownload(String gofileUrl) async {
    // 1. If high-speed direct CDN stream (R2, HubCloud, Pixeldrain) is already available:
    final directStream = _links?.bestDirectVideoUrl;
    if (directStream != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surfaceElevated,
          content: Text('Starting direct download for ${widget.movieTitle}...'),
          duration: const Duration(seconds: 2),
        ),
      );
      _triggerDownload(directStream);
      return;
    }

    // 2. Otherwise try to resolve Gofile streaming link
    setState(() => _resolvingMirror = 'gofile');
    try {
      final provider = Provider.of<MoviesProvider>(context, listen: false);
      final directUrl = await provider.resolveGofileDownload(
        gofileUrl,
        fileName: '${widget.movieTitle}_${widget.option.quality}.mkv',
      );

      if (!mounted) return;

      if (directUrl != null && directUrl.isNotEmpty) {
        _triggerDownload(directUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.surfaceElevated,
            content: Text('Direct stream not ready yet for this mirror. Please use another mirror or retry.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.surfaceElevated,
          content: Text('Could not start direct stream. Please try another mirror.'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _resolvingMirror = null);
      }
    }
  }

  void _handleMirrorDownload(String name, String url) {
    // 1. If url itself is direct video stream (or Pixeldrain)
    String effectiveUrl = url;
    if (url.contains('pixeldrain.com/u/')) {
      final pxId = url.replaceAll(RegExp(r'/+$'), '').split('/').last;
      effectiveUrl = 'https://pixeldrain.com/api/file/$pxId';
    }

    if (effectiveUrl.contains('.mkv') ||
        effectiveUrl.contains('.mp4') ||
        effectiveUrl.contains('workers.dev') ||
        effectiveUrl.contains('pixeldrain.com/api/file') ||
        effectiveUrl.contains('hubcloud') ||
        effectiveUrl.contains('indi-files')) {
      _triggerDownload(effectiveUrl);
      return;
    }

    // 2. If direct video stream is available for this movie
    final directStream = _links?.bestDirectVideoUrl;
    if (directStream != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surfaceElevated,
          content: Text('Starting direct download for ${widget.movieTitle}...'),
          duration: const Duration(seconds: 2),
        ),
      );
      _triggerDownload(directStream);
      return;
    }

    // 3. Inform user if stream is still synchronizing (don't redirect without asking)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.surfaceElevated,
        content: Text('Direct stream for $name is synchronizing. Use browser icon to visit host.'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.option.quality,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (widget.option.size.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          widget.option.size,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 250,
                    child: Text(
                      widget.movieTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.cardBorder, height: 1),
          const SizedBox(height: 16),

          // Content
          if (_isLoading) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
                    SizedBox(height: 14),
                    Text(
                      'Bypassing ads & resolving direct CDN link...',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade800),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _resolveLink,
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.primary),
                  label: const Text('Try Again', style: TextStyle(color: AppTheme.primary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _triggerDownload(widget.option.intermediateUrl),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: const Text('Open Host Directly', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceElevated,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ] else if (_links != null) ...[
            // Direct High-Speed Download Card
            if (_links!.bestDownloadUrl != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accentGreen.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: AppTheme.accentGreen, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _links!.linkType ?? 'Cloudflare R2 Direct CDN',
                            style: const TextStyle(
                              color: AppTheme.accentGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Highest speed, 0 waiting time, resume support',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _triggerDownload(_links!.bestDownloadUrl!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Download', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Fast Mirrors
            const Text(
              'ALTERNATIVE MIRRORS',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),

            // PixelDrain
            if (_links!.pixeldrain != null)
              _buildMirrorRow(
                name: 'PixelDrain Direct Mirror',
                icon: Icons.bolt_rounded,
                color: Colors.amber,
                url: _links!.pixeldrain!,
              ),

            // Gofile
            if (_links!.gofile != null)
              _buildMirrorRow(
                name: 'Gofile Fast Mirror',
                icon: Icons.cloud_rounded,
                color: AppTheme.accentBlue,
                url: _links!.gofile!,
                isGofile: true,
              ),

            // VikingFile
            if (_links!.vikingfile != null)
              _buildMirrorRow(
                name: 'VikingFile Mirror',
                icon: Icons.storage_rounded,
                color: AppTheme.accentPurple,
                url: _links!.vikingfile!,
              ),

            // FilePress
            if (_links!.filepress != null)
              _buildMirrorRow(
                name: 'FilePress Mirror',
                icon: Icons.folder_zip_rounded,
                color: Colors.cyan,
                url: _links!.filepress!,
              ),

            // UploadHub
            if (_links!.uploadhub != null)
              _buildMirrorRow(
                name: 'UploadHub Mirror',
                icon: Icons.cloud_upload_rounded,
                color: Colors.orange,
                url: _links!.uploadhub!,
              ),

            const SizedBox(height: 12),

            // Copy Link Button
            if (_links!.bestDownloadUrl != null)
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _links!.bestDownloadUrl!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppTheme.surfaceElevated,
                      content: Text('Direct download link copied to clipboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.textSecondary),
                label: const Text('Copy Direct URL', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.cardBorder),
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildMirrorRow({
    required String name,
    required IconData icon,
    required Color color,
    required String url,
    bool isGofile = false,
  }) {
    final isResolvingThis = _resolvingMirror == (isGofile ? 'gofile' : name);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder, width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isGofile ? 'Direct Fast Stream' : 'Bypassed Mirror',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded, size: 18, color: AppTheme.textMuted),
            tooltip: 'Open in browser',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => DownloadStorage.instance.openDownloadedItem('', url),
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: isResolvingThis
                ? null
                : () {
                    if (isGofile) {
                      _handleGofileDownload(url);
                    } else {
                      _handleMirrorDownload(name, url);
                    }
                  },
            icon: isResolvingThis
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded, size: 14),
            label: Text(
              isResolvingThis ? 'Resolving...' : 'Download',
              style: TextStyle(
                color: isResolvingThis ? AppTheme.textMuted : color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surface,
              side: BorderSide(color: color.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
