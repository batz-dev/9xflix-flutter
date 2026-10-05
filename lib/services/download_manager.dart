import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(minutes: 60),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ),
  );

  final List<DownloadItem> _items = [];
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, DateTime> _lastSpeedTimes = {};
  final Map<String, int> _lastSpeedBytes = {};

  List<DownloadItem> get items => List.unmodifiable(_items);
  List<DownloadItem> get activeDownloads =>
      _items.where((i) => i.status == DownloadStatus.downloading || i.status == DownloadStatus.queued).toList();
  List<DownloadItem> get completedDownloads =>
      _items.where((i) => i.status == DownloadStatus.completed).toList();

  Future<void> init() async {
    await _loadPersistedItems();
    await _verifyLocalFiles();
  }

  // Start new download
  Future<DownloadItem> startDownload({
    required String movieTitle,
    required String quality,
    required String size,
    required String downloadUrl,
    required String poster,
  }) async {
    final sanitizedTitle = movieTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final ext = downloadUrl.contains('.mkv') ? '.mkv' : '.mp4';
    final fileName = '${sanitizedTitle}_$quality$ext';

    final saveDir = await _getDownloadDirectory();
    final savePath = '${saveDir.path}/$fileName';

    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final item = DownloadItem(
      id: id,
      title: fileName,
      movieTitle: movieTitle,
      poster: poster,
      quality: quality,
      size: size,
      downloadUrl: downloadUrl,
      savePath: savePath,
      status: DownloadStatus.queued,
    );

    _items.insert(0, item);
    notifyListeners();
    await _persistItems();

    _executeDownload(item);
    return item;
  }

  Future<void> _executeDownload(DownloadItem item) async {
    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;

    item.status = DownloadStatus.downloading;
    notifyListeners();

    _lastSpeedTimes[item.id] = DateTime.now();
    _lastSpeedBytes[item.id] = 0;

    try {
      final file = File(item.savePath);
      int startBytes = 0;
      if (await file.exists()) {
        startBytes = await file.length();
      }

      final options = Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        maxRedirects: 5,
        headers: startBytes > 0 ? {'Range': 'bytes=$startBytes-'} : {},
      );

      final response = await _dio.get<ResponseBody>(
        item.downloadUrl,
        options: options,
        cancelToken: cancelToken,
      );

      final totalHeader = response.headers.value('content-length');
      int total = totalHeader != null ? int.tryParse(totalHeader) ?? 0 : 0;
      total += startBytes;
      item.totalBytes = total;

      final raf = await file.open(mode: startBytes > 0 ? FileMode.append : FileMode.write);
      final stream = response.data!.stream;

      int received = startBytes;

      await for (final chunk in stream) {
        if (cancelToken.isCancelled) {
          await raf.close();
          return;
        }

        await raf.writeFrom(chunk);
        received += chunk.length;
        item.receivedBytes = received;

        if (total > 0) {
          item.progress = received / total;
        }

        // Calculate download speed every 500ms
        final now = DateTime.now();
        final lastTime = _lastSpeedTimes[item.id] ?? now;
        final elapsed = now.difference(lastTime).inMilliseconds;

        if (elapsed >= 600) {
          final lastBytes = _lastSpeedBytes[item.id] ?? 0;
          final bytesDiff = received - lastBytes;
          final speedBytesPerSec = (bytesDiff / (elapsed / 1000.0));

          if (speedBytesPerSec > 1024 * 1024) {
            item.speed = '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
          } else {
            item.speed = '${(speedBytesPerSec / 1024).toStringAsFixed(0)} KB/s';
          }

          _lastSpeedTimes[item.id] = now;
          _lastSpeedBytes[item.id] = received;
          notifyListeners();
        }
      }

      await raf.close();

      item.status = DownloadStatus.completed;
      item.progress = 1.0;
      item.speed = 'Done';
      _cancelTokens.remove(item.id);
      notifyListeners();
      await _persistItems();

    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        item.status = DownloadStatus.paused;
        item.speed = 'Paused';
      } else {
        item.status = DownloadStatus.failed;
        item.speed = 'Error: ${e.message}';
      }
      _cancelTokens.remove(item.id);
      notifyListeners();
      await _persistItems();
    } catch (e) {
      item.status = DownloadStatus.failed;
      item.speed = 'Failed';
      _cancelTokens.remove(item.id);
      notifyListeners();
      await _persistItems();
    }
  }

  // Pause download
  void pauseDownload(String id) {
    if (_cancelTokens.containsKey(id)) {
      _cancelTokens[id]?.cancel();
      _cancelTokens.remove(id);
    }
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _items[idx].status = DownloadStatus.paused;
      _items[idx].speed = 'Paused';
      notifyListeners();
      _persistItems();
    }
  }

  // Resume download
  void resumeDownload(String id) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      final item = _items[idx];
      item.status = DownloadStatus.queued;
      notifyListeners();
      _executeDownload(item);
    }
  }

  // Cancel and delete download
  Future<void> cancelDownload(String id) async {
    if (_cancelTokens.containsKey(id)) {
      _cancelTokens[id]?.cancel();
      _cancelTokens.remove(id);
    }

    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      final item = _items[idx];
      final file = File(item.savePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      _items.removeAt(idx);
      notifyListeners();
      await _persistItems();
    }
  }

  // Open / Play downloaded video file in external video player (VLC / MX Player)
  Future<OpenResult> openFile(String id) async {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      final item = _items[idx];
      return await OpenFilex.open(item.savePath);
    }
    return OpenResult(type: ResultType.fileNotFound, message: 'Item not found');
  }

  // Directory handling
  Future<Directory> _getDownloadDirectory() async {
    Directory? dir;
    try {
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download/FlixDirect');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    } catch (_) {
      // Fallback
    }

    dir = await getApplicationDocumentsDirectory();
    final subDir = Directory('${dir.path}/FlixDirect');
    if (!await subDir.exists()) {
      await subDir.create(recursive: true);
    }
    return subDir;
  }

  // Persistence
  Future<void> _persistItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _items.map((i) => i.toJson()).toList();
      await prefs.setString('flix_downloads', json.encode(jsonList));
    } catch (_) {}
  }

  Future<void> _loadPersistedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('flix_downloads');
      if (raw != null) {
        final list = json.decode(raw) as List;
        _items.clear();
        for (final item in list) {
          _items.add(DownloadItem.fromJson(item));
        }
      }
    } catch (_) {}
  }

  Future<void> _verifyLocalFiles() async {
    for (final item in _items) {
      if (item.status == DownloadStatus.completed) {
        final file = File(item.savePath);
        if (!await file.exists()) {
          item.status = DownloadStatus.failed;
          item.speed = 'File deleted';
        }
      } else if (item.status == DownloadStatus.downloading) {
        item.status = DownloadStatus.paused;
        item.speed = 'Paused';
      }
    }
    notifyListeners();
  }
}
