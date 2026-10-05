// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'download_storage.dart';

DownloadStorage getDownloadStorage() => DownloadStorageWeb();

class DownloadStorageWeb implements DownloadStorage {
  @override
  Future<String> getDownloadSavePath(String fileName) async {
    return fileName;
  }

  @override
  Future<int> getFileLength(String filePath) async {
    return 0;
  }

  @override
  Future<bool> fileExists(String filePath) async {
    return false;
  }

  @override
  Future<void> deleteFile(String filePath) async {
    // No local filesystem on web
  }

  @override
  Future<void> saveStreamToFile({
    required Stream<List<int>> stream,
    required String filePath,
    required bool append,
    required bool Function() isCancelled,
    required void Function(int chunkLength) onChunk,
  }) async {
    // Browser manages downloads directly
  }

  @override
  Future<OpenMediaResult> openDownloadedItem(String filePath, String downloadUrl) async {
    if (downloadUrl.isNotEmpty) {
      try {
        final fileName = filePath.split('/').last;
        String finalUrl = downloadUrl;

        final isDirectMedia = downloadUrl.contains('.mkv') ||
            downloadUrl.contains('.mp4') ||
            downloadUrl.contains('workers.dev') ||
            downloadUrl.contains('hubcloud') ||
            downloadUrl.contains('pixeldrain.com') ||
            downloadUrl.contains('indi-files') ||
            downloadUrl.contains('/api/gofile-dl') ||
            downloadUrl.contains('/api/download');

        if (isDirectMedia && !downloadUrl.startsWith('/api/') && !downloadUrl.contains('/api/download')) {
          final origin = html.window.location.origin;
          String targetUrl = downloadUrl;
          if (targetUrl.contains('pixeldrain.com/u/')) {
            final pxId = targetUrl.replaceAll(RegExp(r'/+$'), '').split('/').last;
            targetUrl = 'https://pixeldrain.com/api/file/$pxId';
          }
          finalUrl = '$origin/api/download?url=${Uri.encodeQueryComponent(targetUrl)}&name=${Uri.encodeQueryComponent(fileName)}';
        }

        if (isDirectMedia) {
          final anchor = html.AnchorElement(href: finalUrl)
            ..download = fileName;
          html.document.body?.children.add(anchor);
          anchor.click();
          anchor.remove();
          return const OpenMediaResult(true, 'Started download');
        } else {
          html.window.open(downloadUrl, '_blank');
          return const OpenMediaResult(true, 'Opened link in new tab');
        }
      } catch (e) {
        try {
          html.window.open(downloadUrl, '_blank');
          return const OpenMediaResult(true, 'Opened link in new tab');
        } catch (e2) {
          return OpenMediaResult(false, e2.toString());
        }
      }
    }
    return const OpenMediaResult(false, 'No URL available');
  }
}
