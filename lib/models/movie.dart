class Movie {
  final String title;
  final String slug;
  final String url;
  final String poster;
  final String badge;
  final String quality;
  final bool isHdtc;
  final String ripType;

  Movie({
    required this.title,
    required this.slug,
    required this.url,
    required this.poster,
    this.badge = '',
    this.quality = 'HD',
    this.isHdtc = false,
    this.ripType = '',
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      url: json['url'] ?? '',
      poster: json['poster'] ?? '',
      badge: json['badge'] ?? '',
      quality: json['quality'] ?? 'HD',
      isHdtc: json['is_hdtc'] ?? false,
      ripType: json['rip_type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'slug': slug,
      'url': url,
      'poster': poster,
      'badge': badge,
      'quality': quality,
      'is_hdtc': isHdtc,
      'rip_type': ripType,
    };
  }
}
