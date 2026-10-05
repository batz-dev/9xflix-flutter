import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import '../services/download_manager.dart';
import '../models/download_item.dart';
import '../constants/app_theme.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DownloadManager _dm = DownloadManager();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Downloads Manager',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            AnimatedBuilder(
              animation: _dm,
              builder: (context, _) {
                final activeCount = _dm.activeDownloads.length;
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Downloading'),
                      if (activeCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$activeCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _dm,
              builder: (context, _) {
                final compCount = _dm.completedDownloads.length;
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Completed'),
                      if (compCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$compCount',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: _dm,
        builder: (context, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildActiveDownloadsList(),
              _buildCompletedDownloadsList(),
            ],
          );
        },
      ),
    );
  }

  // Active Downloads Tab
  Widget _buildActiveDownloadsList() {
    final active = _dm.activeDownloads;
    if (active.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_done_rounded, color: AppTheme.cardBorder, size: 64),
            SizedBox(height: 14),
            Text(
              'No active downloads right now',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'Click "Download" on any movie to start downloading here',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: active.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = active[index];
        final percent = (item.progress * 100).toInt();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.cardBorder, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster
                  Container(
                    width: 50,
                    height: 75,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: item.poster.isNotEmpty
                        ? CachedNetworkImage(imageUrl: item.poster, fit: BoxFit.cover)
                        : const Icon(Icons.movie, color: AppTheme.textMuted),
                  ),
                  const SizedBox(width: 12),

                  // Title & Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.movieTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.quality,
                                style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.speed,
                              style: const TextStyle(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_formatBytes(item.receivedBytes)} / ${_formatBytes(item.totalBytes)} ($percent%)',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  // Actions: Pause / Resume / Cancel
                  Column(
                    children: [
                      if (item.status == DownloadStatus.downloading)
                        IconButton(
                          icon: const Icon(Icons.pause_circle_filled_rounded, color: AppTheme.accentGold, size: 28),
                          onPressed: () => _dm.pauseDownload(item.id),
                          tooltip: 'Pause',
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.accentGreen, size: 28),
                          onPressed: () => _dm.resumeDownload(item.id),
                          tooltip: 'Resume',
                        ),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: AppTheme.textMuted, size: 20),
                        onPressed: () => _dm.cancelDownload(item.id),
                        tooltip: 'Cancel',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Linear Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.progress > 0 ? item.progress : null,
                  backgroundColor: AppTheme.surfaceElevated,
                  color: item.status == DownloadStatus.downloading ? AppTheme.primary : AppTheme.accentGold,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Completed Downloads Tab
  Widget _buildCompletedDownloadsList() {
    final completed = _dm.completedDownloads;
    if (completed.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, color: AppTheme.cardBorder, size: 64),
            SizedBox(height: 14),
            Text(
              'No completed downloads yet',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'Downloaded movies will be saved locally in Downloads/FlixDirect',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: completed.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = completed[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.cardBorder, width: 0.8),
          ),
          child: Row(
            children: [
              // Poster
              Container(
                width: 50,
                height: 75,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: item.poster.isNotEmpty
                    ? CachedNetworkImage(imageUrl: item.poster, fit: BoxFit.cover)
                    : const Icon(Icons.movie, color: AppTheme.textMuted),
              ),
              const SizedBox(width: 12),

              // Title, Size & Path
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.movieTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.quality,
                            style: const TextStyle(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatBytes(item.totalBytes),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.savePath.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),

              // Play & Delete Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primary, size: 34),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final result = await _dm.openFile(item.id);
                      if (result.type != ResultType.done && mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.surfaceElevated,
                            content: Text('Could not open video: ${result.message}'),
                          ),
                        );
                      }
                    },
                    tooltip: 'Play in Video Player',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textMuted, size: 20),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.surface,
                          title: const Text('Delete File?', style: TextStyle(color: Colors.white, fontSize: 16)),
                          content: Text(
                            'Are you sure you want to remove "${item.movieTitle}" from downloads and device storage?',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _dm.cancelDownload(item.id);
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    tooltip: 'Delete File',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
