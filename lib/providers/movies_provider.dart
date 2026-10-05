import 'package:flutter/foundation.dart';
import '../models/movie.dart';
import '../models/movie_details.dart';
import '../models/mirror_links.dart';
import '../services/scraper_service.dart';
import '../services/storage_service.dart';

class MoviesProvider extends ChangeNotifier {
  final ScraperService _scraper = ScraperService();

  List<Movie> _movies = [];
  int _currentPage = 1;
  bool _hasNext = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  String _selectedCategory = 'All';

  // Search state
  List<Movie> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  String? _suggestedQuery;
  int _searchPage = 1;
  bool _searchHasNext = false;
  String _currentQuery = '';

  // Getters
  List<Movie> get movies => _filterMoviesByCategory(_movies);
  List<Movie> get allRawMovies => _movies;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasNext => _hasNext;
  String? get error => _error;
  String get selectedCategory => _selectedCategory;

  List<Movie> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;
  String? get suggestedQuery => _suggestedQuery;
  bool get searchHasNext => _searchHasNext;
  String get currentQuery => _currentQuery;

  ScraperService get scraper => _scraper;

  Future<void> init() async {
    final customBackend = await StorageService.getCustomBackend();
    _scraper.customBackendUrl = customBackend;
    final baseUrl = await StorageService.getBaseUrl();
    _scraper.baseUrl = baseUrl;
    await fetchLatest();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  List<Movie> _filterMoviesByCategory(List<Movie> list) {
    if (_selectedCategory == 'All') return list;
    if (_selectedCategory == '1080p') {
      return list.where((m) => m.quality.contains('1080p')).toList();
    }
    if (_selectedCategory == '720p') {
      return list.where((m) => m.quality.contains('720p')).toList();
    }
    if (_selectedCategory == 'HDTC') {
      return list.where((m) => m.isHdtc).toList();
    }
    if (_selectedCategory == 'Web Series') {
      return list.where((m) => m.title.toLowerCase().contains('season') || m.title.toLowerCase().contains('s0')).toList();
    }
    if (_selectedCategory == 'Dual Audio') {
      return list.where((m) => m.title.toLowerCase().contains('dual') || m.title.toLowerCase().contains('hindi')).toList();
    }
    return list;
  }

  Future<void> fetchLatest({bool isRefresh = false}) async {
    if (_isLoading) return;
    if (isRefresh) {
      _currentPage = 1;
      _hasNext = true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _scraper.fetchLatestMovies(page: 1);
    _isLoading = false;

    if (result['error'] != null && (result['movies'] as List).isEmpty) {
      _error = result['error'];
    } else {
      _movies = List<Movie>.from(result['movies'] ?? []);
      _currentPage = 1;
      _hasNext = result['has_next'] ?? false;
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasNext) return;

    _isLoadingMore = true;
    notifyListeners();

    final nextPage = _currentPage + 1;
    final result = await _scraper.fetchLatestMovies(page: nextPage);
    _isLoadingMore = false;

    if (result['movies'] != null && (result['movies'] as List).isNotEmpty) {
      _movies.addAll(List<Movie>.from(result['movies']));
      _currentPage = nextPage;
      _hasNext = result['has_next'] ?? false;
    } else {
      _hasNext = false;
    }
    notifyListeners();
  }

  // Search
  Future<void> search(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      _searchResults = [];
      _currentQuery = '';
      _isSearching = false;
      notifyListeners();
      return;
    }

    _currentQuery = clean;
    _isSearching = true;
    _searchError = null;
    _suggestedQuery = null;
    _searchPage = 1;
    notifyListeners();

    await StorageService.addSearchQuery(clean);

    final result = await _scraper.searchMovies(clean, page: 1);
    _isSearching = false;

    if (result['error'] != null && (result['movies'] as List).isEmpty) {
      _searchError = result['error'];
    } else {
      _searchResults = List<Movie>.from(result['movies'] ?? []);
      _suggestedQuery = result['suggested_query'];
      _searchHasNext = result['has_next'] ?? false;
    }
    notifyListeners();
  }

  Future<void> loadMoreSearch() async {
    if (!_searchHasNext || _isSearching) return;

    final nextPage = _searchPage + 1;
    final result = await _scraper.searchMovies(_currentQuery, page: nextPage);

    if (result['movies'] != null && (result['movies'] as List).isNotEmpty) {
      _searchResults.addAll(List<Movie>.from(result['movies']));
      _searchPage = nextPage;
      _searchHasNext = result['has_next'] ?? false;
      notifyListeners();
    } else {
      _searchHasNext = false;
      notifyListeners();
    }
  }

  // Details
  Future<MovieDetails> getMovieDetails(String slugOrUrl) async {
    return await _scraper.fetchMovieDetails(slugOrUrl);
  }

  // Link Resolver
  Future<MirrorLinks> resolveDownload(String intermediateUrl) async {
    return await _scraper.resolveDownloadLink(intermediateUrl);
  }

  // Gofile Direct Link Resolver
  Future<String?> resolveGofileDownload(String gofileUrl, {String? fileName}) async {
    return await _scraper.resolveGofileDirect(gofileUrl, fileName: fileName);
  }
}
