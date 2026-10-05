enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
}

class DownloadItem {
  final String id;
  final String title;
  final String movieTitle;
  final String poster;
  final String quality;
  final String size;
  final String downloadUrl;
  final String savePath;
  double progress; // 0.0 to 1.0
  DownloadStatus status;
  String speed; // e.g. "4.2 MB/s"
  int receivedBytes;
  int totalBytes;
  final DateTime createdAt;

  DownloadItem({
    required this.id,
    required this.title,
    required this.movieTitle,
    required this.poster,
    required this.quality,
    required this.size,
    required this.downloadUrl,
    required this.savePath,
    this.progress = 0.0,
    this.status = DownloadStatus.queued,
    this.speed = '0 KB/s',
    this.receivedBytes = 0,
    this.totalBytes = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      movieTitle: json['movie_title'] ?? '',
      poster: json['poster'] ?? '',
      quality: json['quality'] ?? '',
      size: json['size'] ?? '',
      downloadUrl: json['download_url'] ?? '',
      savePath: json['save_path'] ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.failed,
      ),
      receivedBytes: json['received_bytes'] ?? 0,
      totalBytes: json['total_bytes'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'movie_title': movieTitle,
      'poster': poster,
      'quality': quality,
      'size': size,
      'download_url': downloadUrl,
      'save_path': savePath,
      'progress': progress,
      'status': status.name,
      'received_bytes': receivedBytes,
      'total_bytes': totalBytes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
