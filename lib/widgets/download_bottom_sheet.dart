import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/download_option.dart';
import '../models/mirror_links.dart';
import '../providers/movies_provider.dart';
import '../services/download_manager.dart';
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
            Center(
              child: TextButton.icon(
                onPressed: _resolveLink,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.primary),
                label: const Text('Try Again', style: TextStyle(color: AppTheme.primary)),
              ),
            ),
          ] else if (_links != null) ...[
            // Cloudflare R2 Direct Card
            if (_links!.r2 != null && _links!.r2Status == 'active') ...[
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cloudflare R2 Direct CDN',
                            style: TextStyle(
                              color: AppTheme.accentGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Highest speed, 0 waiting time, resume support',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _triggerDownload(_links!.r2!),
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

            // Gofile
            if (_links!.gofile != null)
              _buildMirrorRow(
                name: 'Gofile High-Speed Mirror',
                icon: Icons.cloud_rounded,
                color: AppTheme.accentBlue,
                url: _links!.gofile!,
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
  }) {
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
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _triggerDownload(url),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surface,
              side: BorderSide(color: color.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Get', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
