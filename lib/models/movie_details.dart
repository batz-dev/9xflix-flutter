import 'download_option.dart';

class MovieDetails {
  final String title;
  final String cleanTitle;
  final String cleanYear;
  final String poster;
  final Map<String, String> metadata;
  final String plot;
  final List<String> screenshots;
  final List<DownloadOption> downloads;
  final bool isHdtc;
  final String ripType;
  final String? error;

  MovieDetails({
    required this.title,
    required this.cleanTitle,
    required this.cleanYear,
    required this.poster,
    required this.metadata,
    required this.plot,
    required this.screenshots,
    required this.downloads,
    this.isHdtc = false,
    this.ripType = '',
    this.error,
  });

  factory MovieDetails.fromJson(Map<String, dynamic> json) {
    final metaMap = <String, String>{};
    if (json['metadata'] is Map) {
      (json['metadata'] as Map).forEach((k, v) {
        metaMap[k.toString()] = v.toString();
      });
    }

    final ssList = <String>[];
    if (json['screenshots'] is List) {
      for (final s in json['screenshots']) {
        if (s is Map && s['image_url'] != null) {
          ssList.add(s['image_url'].toString());
        } else if (s is String) {
          ssList.add(s);
        }
      }
    }

    final dlList = <DownloadOption>[];
    if (json['downloads'] is List) {
      for (final d in json['downloads']) {
        if (d is Map<String, dynamic>) {
          dlList.add(DownloadOption.fromJson(d));
        }
      }
    }

    return MovieDetails(
      title: json['title'] ?? '',
      cleanTitle: json['clean_title'] ?? json['title'] ?? '',
      cleanYear: json['clean_year'] ?? '',
      poster: json['poster'] ?? '',
      metadata: metaMap,
      plot: json['plot'] ?? '',
      screenshots: ssList,
      downloads: dlList,
      isHdtc: json['is_hdtc'] ?? false,
      ripType: json['rip_type'] ?? '',
      error: json['error'],
    );
  }

  String get imdbRating => metadata['imdb'] ?? '';
  String get genres => metadata['genres'] ?? '';
  String get languages => metadata['languages'] ?? '';
  String get director => metadata['director'] ?? '';
  String get stars => metadata['stars'] ?? '';
}
