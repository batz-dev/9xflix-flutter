import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';
import 'platform/download_storage.dart';

export 'platform/download_storage.dart' show OpenMediaResult;

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
    if (!kIsWeb) {
      await _verifyLocalFiles();
    }
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

    final savePath = await DownloadStorage.instance.getDownloadSavePath(fileName);
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

    if (kIsWeb) {
      await DownloadStorage.instance.openDownloadedItem(savePath, downloadUrl);
      item.status = DownloadStatus.completed;
      item.progress = 1.0;
      item.speed = 'Browser Download';
      notifyListeners();
      await _persistItems();
      return item;
    }

    _executeDownload(item);
    return item;
  }

  Future<void> _executeDownload(DownloadItem item) async {
    if (kIsWeb) {
      item.status = DownloadStatus.completed;
      item.progress = 1.0;
      item.speed = 'Browser Download';
      notifyListeners();
      await _persistItems();
      return;
    }

    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;

    item.status = DownloadStatus.downloading;
    notifyListeners();

    _lastSpeedTimes[item.id] = DateTime.now();
    _lastSpeedBytes[item.id] = 0;

    try {
      final startBytes = await DownloadStorage.instance.getFileLength(item.savePath);

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

      int received = startBytes;
      await DownloadStorage.instance.saveStreamToFile(
        stream: response.data!.stream,
        filePath: item.savePath,
        append: startBytes > 0,
        isCancelled: () => cancelToken.isCancelled,
        onChunk: (chunkLen) {
          received += chunkLen;
          item.receivedBytes = received;

          if (total > 0) {
            item.progress = received / total;
          }

          // Calculate download speed every 600ms
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
        },
      );

      if (cancelToken.isCancelled) return;

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
      if (!kIsWeb) {
        await DownloadStorage.instance.deleteFile(item.savePath);
      }
      _items.removeAt(idx);
      notifyListeners();
      await _persistItems();
    }
  }

  // Open / Play downloaded video file or stream
  Future<OpenMediaResult> openFile(String id) async {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      final item = _items[idx];
      return await DownloadStorage.instance.openDownloadedItem(item.savePath, item.downloadUrl);
    }
    return const OpenMediaResult(false, 'Item not found');
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
    if (kIsWeb) return;
    for (final item in _items) {
      if (item.status == DownloadStatus.completed) {
        final exists = await DownloadStorage.instance.fileExists(item.savePath);
        if (!exists) {
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
