import 'download_storage_stub.dart'
    if (dart.library.io) 'download_storage_io.dart'
    if (dart.library.html) 'download_storage_web.dart';

class OpenMediaResult {
  final bool success;
  final String message;
  const OpenMediaResult(this.success, [this.message = '']);
}

abstract class DownloadStorage {
  static final DownloadStorage instance = getDownloadStorage();

  Future<String> getDownloadSavePath(String fileName);
  Future<int> getFileLength(String filePath);
  Future<bool> fileExists(String filePath);
  Future<void> deleteFile(String filePath);
  Future<void> saveStreamToFile({
    required Stream<List<int>> stream,
    required String filePath,
    required bool append,
    required bool Function() isCancelled,
    required void Function(int chunkLength) onChunk,
  });
  Future<OpenMediaResult> openDownloadedItem(String filePath, String downloadUrl);
}
