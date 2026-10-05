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
        html.window.open(downloadUrl, '_blank');
        return const OpenMediaResult(true, 'Opened stream in new tab');
      } catch (e) {
        return OpenMediaResult(false, e.toString());
      }
    }
    return const OpenMediaResult(false, 'No URL available');
  }
}
