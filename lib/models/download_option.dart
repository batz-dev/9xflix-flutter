class DownloadOption {
  final String title;
  final String quality;
  final String size;
  final String intermediateUrl;
  final String host;

  DownloadOption({
    required this.title,
    required this.quality,
    required this.size,
    required this.intermediateUrl,
    required this.host,
  });

  factory DownloadOption.fromJson(Map<String, dynamic> json) {
    return DownloadOption(
      title: json['title'] ?? '',
      quality: json['quality'] ?? 'HD',
      size: json['size'] ?? '',
      intermediateUrl: json['intermediate_url'] ?? '',
      host: json['host'] ?? 'Indishare',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'quality': quality,
      'size': size,
      'intermediate_url': intermediateUrl,
      'host': host,
    };
  }
}
