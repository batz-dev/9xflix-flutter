import 'dart:async';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'download_storage.dart';

DownloadStorage getDownloadStorage() => DownloadStorageIO();

class DownloadStorageIO implements DownloadStorage {
  @override
  Future<String> getDownloadSavePath(String fileName) async {
    try {
      if (Platform.isAndroid) {
        final dir = Directory('/storage/emulated/0/Download/FlixDirect');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return '${dir.path}/$fileName';
      }
    } catch (_) {}

    final dir = await getApplicationDocumentsDirectory();
    final subDir = Directory('${dir.path}/FlixDirect');
    if (!await subDir.exists()) {
      await subDir.create(recursive: true);
    }
    return '${subDir.path}/$fileName';
  }

  @override
  Future<int> getFileLength(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return 0;
  }

  @override
  Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (_) {}
    return false;
  }

  @override
  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  @override
  Future<void> saveStreamToFile({
    required Stream<List<int>> stream,
    required String filePath,
    required bool append,
    required bool Function() isCancelled,
    required void Function(int chunkLength) onChunk,
  }) async {
    final file = File(filePath);
    final raf = await file.open(mode: append ? FileMode.append : FileMode.write);
    try {
      await for (final chunk in stream) {
        if (isCancelled()) {
          break;
        }
        await raf.writeFrom(chunk);
        onChunk(chunk.length);
      }
    } finally {
      await raf.close();
    }
  }

  @override
  Future<OpenMediaResult> openDownloadedItem(String filePath, String downloadUrl) async {
    try {
      final res = await OpenFilex.open(filePath);
      return OpenMediaResult(res.type == ResultType.done, res.message);
    } catch (e) {
      return OpenMediaResult(false, e.toString());
    }
  }
}
