import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/movie.dart';
import '../models/movie_details.dart';
import '../models/mirror_links.dart';
import '../models/download_option.dart';

class ScraperService {
  static const String defaultBaseUrl = "https://9xflix.esq/m/";
  String baseUrl = defaultBaseUrl;

  // Optional custom backend server URL (e.g. self-hosted FlixDirect Flask server)
  String? customBackendUrl;

  String? get effectiveBackend {
    if (customBackendUrl != null && customBackendUrl!.isNotEmpty) {
      return customBackendUrl;
    }
    if (kIsWeb) {
      return Uri.base.origin;
    }
    return null;
  }

  final Map<String, String> defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
  };

  // Cache for resolved download links
  final Map<String, MirrorLinks> _resolveCache = {};

  // Fetch Latest Movies Feed
  Future<Map<String, dynamic>> fetchLatestMovies({int page = 1}) async {
    final backend = effectiveBackend;
    if (backend != null && backend.isNotEmpty) {
      try {
        final uri = Uri.parse('$backend/api/latest?page=$page');
        final resp = await http.get(uri).timeout(const Duration(seconds: 12));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          final list = (data['movies'] as List?)
                  ?.map((e) => Movie.fromJson(e))
                  .toList() ??
              [];
          return {
            'movies': list,
            'page': page,
            'has_next': data['has_next'] ?? false,
          };
        }
      } catch (_) {
        if (kIsWeb) {
          return {'movies': <Movie>[], 'page': page, 'has_next': false, 'error': 'Connection error to API'};
        }
      }
    }

    final targetUrl = page == 1 ? baseUrl : '${baseUrl}page/$page/';
    try {
      final resp = await http
          .get(Uri.parse(targetUrl), headers: defaultHeaders)
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) {
        return {'movies': <Movie>[], 'page': page, 'has_next': false, 'error': 'HTTP ${resp.statusCode}'};
      }

      final doc = html_parser.parse(resp.body);
      final movies = _parseMovieCards(doc);
      final hasNext = doc.querySelector('a.next, .nav-previous, a[href*="/page/"]') != null;

      return {
        'movies': movies,
        'page': page,
        'has_next': hasNext,
      };
    } catch (e) {
      return {'movies': <Movie>[], 'page': page, 'has_next': false, 'error': e.toString()};
    }
  }

  // Search Movies with Query
  Future<Map<String, dynamic>> searchMovies(String query, {int page = 1}) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) {
      return {'movies': <Movie>[], 'page': page, 'has_next': false};
    }

    final backend = effectiveBackend;
    if (backend != null && backend.isNotEmpty) {
      try {
        final uri = Uri.parse('$backend/api/search?q=${Uri.encodeQueryComponent(cleanQ)}&page=$page');
        final resp = await http.get(uri).timeout(const Duration(seconds: 12));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          final list = (data['movies'] as List?)
                  ?.map((e) => Movie.fromJson(e))
                  .toList() ??
              [];
          return {
            'movies': list,
            'query': cleanQ,
            'suggested_query': data['suggested_query'],
            'page': page,
            'has_next': data['has_next'] ?? false,
          };
        }
      } catch (_) {
        if (kIsWeb) {
          return {'movies': <Movie>[], 'query': cleanQ, 'page': page, 'has_next': false, 'error': 'Search connection error'};
        }
      }
    }

    final encodedQ = Uri.encodeQueryComponent(cleanQ);
    final targetUrl = page == 1 ? '$baseUrl?s=$encodedQ' : '${baseUrl}page/$page/?s=$encodedQ';

    try {
      final resp = await http
          .get(Uri.parse(targetUrl), headers: defaultHeaders)
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) {
        return {'movies': <Movie>[], 'page': page, 'has_next': false, 'error': 'HTTP ${resp.statusCode}'};
      }

      final doc = html_parser.parse(resp.body);
      var movies = _parseMovieCards(doc);

      // Smart fallback: If 0 results on page 1, try main keyword
      String? suggestedQuery;
      if (movies.isEmpty && page == 1 && cleanQ.contains(' ')) {
        final stopWords = {'the', 'movie', 'full', 'hindi', 'film', 'dual', 'audio', 'season', 'episodes'};
        final words = cleanQ
            .split(' ')
            .where((w) => w.length > 3 && !stopWords.contains(w.toLowerCase()))
            .toList();

        if (words.isNotEmpty) {
          words.sort((a, b) => b.length.compareTo(a.length));
          final altQ = words.first;
          final altUrl = '$baseUrl?s=${Uri.encodeQueryComponent(altQ)}';
          final altResp = await http.get(Uri.parse(altUrl), headers: defaultHeaders).timeout(const Duration(seconds: 8));
          if (altResp.statusCode == 200) {
            final altDoc = html_parser.parse(altResp.body);
            final altMovies = _parseMovieCards(altDoc);
            if (altMovies.isNotEmpty) {
              movies = altMovies;
              suggestedQuery = altQ;
            }
          }
        }
      }

      final hasNext = doc.querySelector('a.next') != null;

      return {
        'movies': movies,
        'query': cleanQ,
        'suggested_query': suggestedQuery,
        'page': page,
        'has_next': hasNext,
      };
    } catch (e) {
      return {'movies': <Movie>[], 'query': cleanQ, 'page': page, 'has_next': false, 'error': e.toString()};
    }
  }

  // Fetch Full Movie Details & Screenshots & Downloads
  Future<MovieDetails> fetchMovieDetails(String slugOrUrl) async {
    final backend = effectiveBackend;
    if (backend != null && backend.isNotEmpty) {
      try {
        final uri = Uri.parse('$backend/api/detail?slug=${Uri.encodeQueryComponent(slugOrUrl)}');
        final resp = await http.get(uri).timeout(const Duration(seconds: 14));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          return MovieDetails.fromJson(data);
        }
      } catch (_) {
        if (kIsWeb) {
          return MovieDetails(
            title: 'Error',
            cleanTitle: 'Failed to load details',
            cleanYear: '',
            poster: '',
            metadata: {},
            plot: '',
            screenshots: [],
            downloads: [],
            error: 'Failed to connect to API',
          );
        }
      }
    }

    final targetUrl = slugOrUrl.startsWith('http') ? slugOrUrl : '$baseUrl$slugOrUrl/';

    try {
      final resp = await http
          .get(Uri.parse(targetUrl), headers: defaultHeaders)
          .timeout(const Duration(seconds: 14));

      if (resp.statusCode != 200) {
        return MovieDetails(
          title: '',
          cleanTitle: '',
          cleanYear: '',
          poster: '',
          metadata: {},
          plot: '',
          screenshots: [],
          downloads: [],
          error: 'HTTP ${resp.statusCode}',
        );
      }

      final doc = html_parser.parse(resp.body);
      final entry = doc.querySelector('.entry');
      if (entry == null) {
        return MovieDetails(
          title: '',
          cleanTitle: '',
          cleanYear: '',
          poster: '',
          metadata: {},
          plot: '',
          screenshots: [],
          downloads: [],
          error: 'Could not parse movie entry',
        );
      }

      final titleEl = doc.querySelector('.entry-title');
      final rawTitle = titleEl?.text.trim() ?? '';

      // Poster image
      final posterImg = entry.querySelector('img');
      final posterUrl = posterImg?.attributes['src'] ?? posterImg?.attributes['data-src'] ?? '';

      // Parse metadata & plot
      final metadata = <String, String>{};
      String plot = '';
      final fullText = entry.text;

      for (final line in fullText.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed.contains(':')) {
          final parts = trimmed.split(':');
          final k = parts[0].replaceAll('*', '').trim().toLowerCase();
          final v = parts.sublist(1).join(':').trim();

          if (k.contains('title') && !metadata.containsKey('title')) {
            metadata['title'] = v;
          } else if (k.contains('imdb')) {
            metadata['imdb'] = v;
          } else if (k.contains('released') || k.contains('date')) {
            metadata['release_date'] = v;
          } else if (k.contains('genre')) {
            metadata['genres'] = v;
          } else if (k.contains('language')) {
            metadata['languages'] = v;
          } else if (k.contains('director')) {
            metadata['director'] = v;
          } else if (k.contains('star')) {
            metadata['stars'] = v;
          } else if (k.contains('plot') || k.contains('story')) {
            plot = v.replaceAll('Please use VLC Player if Audio not audiable.', '').trim();
          }
        }
      }

      if (plot.isEmpty) {
        final plotMatch = RegExp(r'Movie Plot:\s*(.*?)(?:Please use VLC Player|$)', dotAll: true, caseSensitive: false)
            .firstMatch(fullText);
        if (plotMatch != null) {
          plot = plotMatch.group(1)?.trim() ?? '';
        }
      }

      // Screenshots
      final screenshots = <String>[];
      final seenImg = <String>{posterUrl};

      for (final img in entry.querySelectorAll('img')) {
        final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
        if (src.isEmpty || seenImg.contains(src)) continue;
        if (src.toLowerCase().contains('telegram.png') ||
            src.toLowerCase().contains('9xflix-main.png') ||
            src.toLowerCase().contains('how-to-download')) {
          continue;
        }
        seenImg.add(src);
        screenshots.add(src);
      }

      // External screenshot links (e.g. indiworlds.com, imgshare)
      for (final a in entry.querySelectorAll('a')) {
        final href = a.attributes['href'] ?? '';
        if (href.isEmpty) continue;

        final indiMatch = RegExp(r'indiworlds\.com/([a-zA-Z0-9]+)').firstMatch(href);
        if (indiMatch != null) {
          final code = indiMatch.group(1)!;
          final directImg = 'https://storage.indiworlds.com/images/$code.webp';
          if (!seenImg.contains(directImg)) {
            seenImg.add(directImg);
            screenshots.add(directImg);
          }
        } else if (href.contains('imgshare.info') &&
            (href.endsWith('.jpg') || href.endsWith('.png') || href.endsWith('.webp'))) {
          if (!seenImg.contains(href)) {
            seenImg.add(href);
            screenshots.add(href);
          }
        }
      }

      // Downloads
      final downloads = <DownloadOption>[];
      for (final h3 in entry.querySelectorAll('h3 a, p a.download-btn')) {
        final href = h3.attributes['href'] ?? '';
        final btnText = h3.text.trim();
        if (href.isEmpty || href.startsWith('#')) continue;

        final lowerText = btnText.toLowerCase();
        if (['1080p', '720p', '480p', '2160p', 'download', 'gb', 'mb', 'ep'].any((q) => lowerText.contains(q))) {
          final qMatch = RegExp(r'(\d+p)', caseSensitive: false).firstMatch(btnText);
          final quality = qMatch != null ? qMatch.group(1)! : 'HD';

          final sizeMatch = RegExp(r'\[([\d\.]+\s*(?:GB|MB))\]', caseSensitive: false).firstMatch(btnText);
          final size = sizeMatch != null ? sizeMatch.group(1)! : '';

          downloads.add(DownloadOption(
            title: btnText,
            quality: quality,
            size: size,
            intermediateUrl: href,
            host: href.contains('indishare') ? 'Indishare' : 'DriveHub',
          ));
        }
      }

      // Title & Year cleanup
      String cleanTitle = rawTitle;
      String cleanYear = '';
      final yearMatch = RegExp(r'^(.*?)\s+((?:19|20)\d{2})\b').firstMatch(rawTitle);
      if (yearMatch != null) {
        cleanTitle = yearMatch.group(1)!.trim().replaceAll(RegExp(r'[\s\-–]+$'), '');
        cleanYear = yearMatch.group(2)!;
      } else if (metadata.containsKey('title')) {
        cleanTitle = metadata['title']!;
      }

      final isHdtc = RegExp(r'\b(hdtc|hd-tc|cam|hdcam|camrip|predvd|pre-hd)\b', caseSensitive: false)
          .hasMatch('$rawTitle ${metadata['title']}');
      var ripType = isHdtc ? 'HDTC' : '';
      if (ripType.isEmpty) {
        for (final r in ['BluRay', 'BRRip', 'WEB-DL', 'WebRip', 'HDRip']) {
          if (rawTitle.toLowerCase().contains(r.toLowerCase())) {
            ripType = r;
            break;
          }
        }
      }

      return MovieDetails(
        title: rawTitle,
        cleanTitle: cleanTitle,
        cleanYear: cleanYear,
        poster: posterUrl,
        metadata: metadata,
        plot: plot,
        screenshots: screenshots,
        downloads: downloads,
        isHdtc: isHdtc,
        ripType: ripType,
      );
    } catch (e) {
      return MovieDetails(
        title: '',
        cleanTitle: '',
        cleanYear: '',
        poster: '',
        metadata: {},
        plot: '',
        screenshots: [],
        downloads: [],
        error: e.toString(),
      );
    }
  }

  // Automated Direct Download Resolver
  Future<MirrorLinks> resolveDownloadLink(String intermediateUrl) async {
    if (_resolveCache.containsKey(intermediateUrl)) {
      return _resolveCache[intermediateUrl]!;
    }

    final backend = effectiveBackend;
    if (backend != null && backend.isNotEmpty) {
      try {
        final uri = Uri.parse('$backend/api/resolve?url=${Uri.encodeQueryComponent(intermediateUrl)}');
        final resp = await http.get(uri).timeout(const Duration(seconds: 14));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          final result = MirrorLinks.fromJson(data);
          _resolveCache[intermediateUrl] = result;
          return result;
        }
      } catch (_) {
        if (kIsWeb) {
          return MirrorLinks(status: 'error', error: 'Could not connect to resolver API');
        }
      }
    }

    // Desilinks Aggregator Unpacker
    if (intermediateUrl.contains('desilinks')) {
      try {
        final resp = await http.get(Uri.parse(intermediateUrl), headers: defaultHeaders).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final doc = html_parser.parse(resp.body);
          for (final a in doc.querySelectorAll('a')) {
            final href = a.attributes['href'] ?? '';
            if (href.contains('indishare') || href.contains('indi-share') || href.contains('hubcloud')) {
              return await resolveDownloadLink(href);
            }
          }
        }
      } catch (_) {}
    }

    try {
      final code = intermediateUrl.trim().replaceAll(RegExp(r'/+$'), '').split('/').last;
      final baseIndishare = 'https://files.indi-share.com/$code';

      // Indishare Token & R2 Worker
      try {
        final tokenResp = await http.post(
          Uri.parse('$baseIndishare/token'),
          headers: {
            ...defaultHeaders,
            'Referer': baseIndishare,
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ).timeout(const Duration(seconds: 8));

        if (tokenResp.statusCode == 200) {
          final tData = json.decode(tokenResp.body);
          if (tData['status'] == 'success' && tData['url'] != null) {
            final dlPageUrl = tData['url'] as String;
            final dlResp = await http.get(
              Uri.parse(dlPageUrl),
              headers: {...defaultHeaders, 'Referer': baseIndishare},
            ).timeout(const Duration(seconds: 8));

            if (dlResp.statusCode == 200) {
              final body = dlResp.body;
              final mTok = RegExp(r'const\s+_r2Token\s*=\s*"([^"]+)"').firstMatch(body);
              final mCod = RegExp(r'const\s+_r2Code\s*=\s*"([^"]+)"').firstMatch(body);
              if (mTok != null && mCod != null) {
                final r2Resp = await http.post(
                  Uri.parse('https://files.indi-share.com/api/r2link'),
                  headers: {
                    ...defaultHeaders,
                    'Referer': dlPageUrl,
                    'Content-Type': 'application/json',
                  },
                  body: json.encode({'code': mCod.group(1), 'token': mTok.group(1)}),
                ).timeout(const Duration(seconds: 8));

                if (r2Resp.statusCode == 200) {
                  final r2Data = json.decode(r2Resp.body);
                  if (r2Data['status'] == 'success' && r2Data['url'] != null) {
                    final res = MirrorLinks(
                      status: 'success',
                      directLink: r2Data['url'],
                      linkType: 'Cloudflare R2 Direct Worker',
                      r2: r2Data['url'],
                      r2Status: 'active',
                    );
                    _resolveCache[intermediateUrl] = res;
                    return res;
                  }
                }
              }

              for (final m in RegExp(r'''openDownload\(\s*['"]([^'"]+)['"]''').allMatches(body)) {
                final mUrl = m.group(1);
                if (mUrl != null && (mUrl.contains('indi-files') || mUrl.contains('gofile') || mUrl.contains('vikingfile'))) {
                  final res = MirrorLinks(
                    status: 'success',
                    directLink: mUrl,
                    linkType: mUrl.contains('indi-files') ? 'IndiFiles Direct CDN' : 'Fast Mirror',
                  );
                  _resolveCache[intermediateUrl] = res;
                  return res;
                }
              }
            }
          }
        }
      } catch (_) {}

      // Fallback: DriveHub mirror-link API
      try {
        final mirrorApi = 'https://files.indi-share.com/api/mirror-link?code=$code&service=drivehub';
        final headers = Map<String, String>.from(defaultHeaders)..['Referer'] = intermediateUrl;

        final resp1 = await http.get(Uri.parse(mirrorApi), headers: headers).timeout(const Duration(seconds: 10));
        if (resp1.statusCode == 200) {
          final data1 = json.decode(resp1.body);
          if (data1['status'] == 'success' && data1['url'] != null) {
            final drivehubUrl = data1['url'] as String;
            final fileId = drivehubUrl.trim().replaceAll(RegExp(r'/+$'), '').split('/').last;

            final statusApi = 'https://new1.drivehub.dad/system/ajax/mirror-status.php?id=$fileId';
            final headers2 = Map<String, String>.from(defaultHeaders)..['Referer'] = drivehubUrl;

            final resp2 = await http.get(Uri.parse(statusApi), headers: headers2).timeout(const Duration(seconds: 10));
            if (resp2.statusCode == 200) {
              final mirrorsData = json.decode(resp2.body) as Map<String, dynamic>;

              String? bestDirect;
              String? linkType;

              if (mirrorsData['r2'] != null && mirrorsData['r2_status'] == 'active') {
                bestDirect = mirrorsData['r2'];
                linkType = 'Cloudflare R2 Direct High-Speed';
              } else if (mirrorsData['gofile'] != null) {
                bestDirect = mirrorsData['gofile'];
                linkType = 'Gofile Direct Fast Mirror';
              } else if (mirrorsData['vikingfile'] != null) {
                bestDirect = mirrorsData['vikingfile'];
                linkType = 'VikingFile Fast Mirror';
              } else if (mirrorsData['filepress'] != null) {
                bestDirect = mirrorsData['filepress'];
                linkType = 'FilePress';
              } else {
                bestDirect = drivehubUrl;
                linkType = 'DriveHub Web Link';
              }

              final result = MirrorLinks(
                status: 'success',
                directLink: bestDirect,
                linkType: linkType,
                r2: mirrorsData['r2'],
                r2Status: mirrorsData['r2_status'],
                gofile: mirrorsData['gofile'],
                vikingfile: mirrorsData['vikingfile'],
                uploadhub: mirrorsData['uploadhub'],
                filepress: mirrorsData['filepress'],
                drivehubUrl: drivehubUrl,
              );

              _resolveCache[intermediateUrl] = result;
              return result;
            }
          }
        }
      } catch (_) {}

      return MirrorLinks(
        status: 'error',
        error: 'Could not automatically bypass mirror. File might be currently syncing.',
      );
    } catch (e) {
      return MirrorLinks(status: 'error', error: e.toString());
    }
  }

  // Resolve Gofile direct streaming link
  Future<String?> resolveGofileDirect(String gofileUrl, {String? fileName}) async {
    final backend = effectiveBackend;
    if (backend != null && backend.isNotEmpty) {
      try {
        final query = 'url=${Uri.encodeQueryComponent(gofileUrl)}${fileName != null ? '&name=${Uri.encodeQueryComponent(fileName)}' : ''}';
        final uri = Uri.parse('$backend/api/resolve-gofile?$query');
        final resp = await http.get(uri).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          if (data['status'] == 'success' && data['direct_url'] != null) {
            return data['direct_url'] as String;
          }
        }
      } catch (_) {}
    }

    // Direct client-side Gofile resolution fallback
    try {
      final cid = gofileUrl.trim().replaceAll(RegExp(r'/+$'), '').split('/').last;
      const ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

      // 1. Get or create guest token
      String token = 'Z9cln5MQGZUjMS70ryJvLsJ8bik3JLUF';
      try {
        final accResp = await http.post(
          Uri.parse('https://api.gofile.io/accounts'),
          headers: {'User-Agent': ua},
        ).timeout(const Duration(seconds: 5));
        if (accResp.statusCode == 200) {
          final accData = json.decode(accResp.body);
          final t = accData['data']?['token'];
          if (t != null && t.toString().isNotEmpty) {
            token = t.toString();
          }
        }
      } catch (_) {}

      // 2. Generate Website Token
      final timeSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final w = timeSec ~/ 14400;
      final raw = '$ua::en-US::$token::$w::12af056dacea0b';
      final wt = sha256.convert(utf8.encode(raw)).toString();

      // 3. Fetch content
      final contentResp = await http.get(
        Uri.parse('https://api.gofile.io/contents/$cid?page=1&pageSize=100&sortField=name&sortDirection=1'),
        headers: {
          'Authorization': 'Bearer $token',
          'X-Website-Token': wt,
          'X-BL': 'en-US',
          'User-Agent': ua,
          'Accept': '*/*',
          'Origin': 'https://gofile.io',
          'Referer': 'https://gofile.io/',
        },
      ).timeout(const Duration(seconds: 8));

      if (contentResp.statusCode == 200) {
        final cData = json.decode(contentResp.body);
        if (cData['status'] == 'ok' && cData['data']?['children'] != null) {
          for (final child in (cData['data']['children'] as Map).values) {
            if (child is Map && child['link'] != null) {
              return child['link'] as String;
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  // Parse movie cards helper
  List<Movie> _parseMovieCards(dom.Document doc) {
    final movies = <Movie>[];
    for (final li in doc.querySelectorAll('ul.small-block-grid-1 li')) {
      final titleTag = li.querySelector('h5.entry-title a') ?? li.querySelector('h2.entry-title a');
      final imgTag = li.querySelector('.thumbnail img') ?? li.querySelector('img');
      final badgeTag = li.querySelector('.new-badge, .sticky-badge, .hot-badge');

      if (titleTag != null) {
        final movieUrl = titleTag.attributes['href'] ?? '';
        final titleText = titleTag.text.trim();
        final slug = movieUrl.trim().replaceAll(RegExp(r'/+$'), '').split('/').last;

        final posterUrl = imgTag?.attributes['src'] ?? imgTag?.attributes['data-src'] ?? '';
        final badge = badgeTag?.text.trim() ?? '';

        final isHdtc = RegExp(r'\b(hdtc|hd-tc|cam|hdcam|camrip|predvd|pre-hd)\b', caseSensitive: false)
            .hasMatch(titleText);
        var ripType = isHdtc ? 'HDTC' : '';
        if (ripType.isEmpty) {
          for (final r in ['BluRay', 'BRRip', 'WEB-DL', 'WebRip', 'HDRip']) {
            if (titleText.toLowerCase().contains(r.toLowerCase())) {
              ripType = r;
              break;
            }
          }
        }

        var quality = 'HD';
        for (final q in ['2160p', '4K', '1080p', '720p', '480p']) {
          if (titleText.toLowerCase().contains(q.toLowerCase())) {
            quality = q;
            break;
          }
        }

        movies.add(Movie(
          title: titleText,
          slug: slug,
          url: movieUrl,
          poster: posterUrl,
          badge: badge,
          quality: quality,
          isHdtc: isHdtc,
          ripType: ripType,
        ));
      }
    }
    return movies;
  }
}
