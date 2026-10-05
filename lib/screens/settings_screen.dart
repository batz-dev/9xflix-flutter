import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../providers/movies_provider.dart';
import '../constants/app_theme.dart';
import '../models/movie.dart';
import '../widgets/movie_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _backendController = TextEditingController();
  final TextEditingController _mirrorController = TextEditingController();

  List<Movie> _watchlist = [];
  bool _isLoadingWatchlist = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadWatchlist();
  }

  Future<void> _loadSettings() async {
    final customBackend = await StorageService.getCustomBackend();
    final baseUrl = await StorageService.getBaseUrl();
    setState(() {
      _backendController.text = customBackend ?? '';
      _mirrorController.text = baseUrl;
    });
  }

  Future<void> _loadWatchlist() async {
    final list = await StorageService.getWatchlist();
    if (mounted) {
      setState(() {
        _watchlist = list;
        _isLoadingWatchlist = false;
      });
    }
  }

  void _saveSettings() async {
    await StorageService.setCustomBackend(_backendController.text);
    await StorageService.setBaseUrl(_mirrorController.text);
    if (mounted) {
      final provider = Provider.of<MoviesProvider>(context, listen: false);
      provider.scraper.customBackendUrl = _backendController.text.isNotEmpty ? _backendController.text : null;
      provider.scraper.baseUrl = _mirrorController.text.isNotEmpty ? _mirrorController.text : 'https://9xflix.esq/m/';
      provider.fetchLatest(isRefresh: true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.surfaceElevated,
          content: Text('Settings saved & movies reloaded!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _backendController.dispose();
    _mirrorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Watchlist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Watchlist Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bookmark_rounded, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text('My Watchlist', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              Text('${_watchlist.length} saved', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoadingWatchlist)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppTheme.primary)))
          else if (_watchlist.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder, width: 0.8),
              ),
              child: const Center(
                child: Text('No bookmarked movies yet. Tap bookmark icon on details page.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _watchlist.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 120,
                    child: MovieCard(movie: _watchlist[index]),
                  );
                },
              ),
            ),

          const SizedBox(height: 28),

          // Source Configuration
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('Network & Scraper Source', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('9xflix Mirror Domain', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Change base mirror URL if the current domain is blocked by ISP', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 8),
                TextField(
                  controller: _mirrorController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.surfaceElevated,
                    hintText: 'https://9xflix.esq/m/',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Optional Backend API Endpoint', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Leave empty for pure In-App direct client scraping (recommended)', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 8),
                TextField(
                  controller: _backendController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.surfaceElevated,
                    hintText: 'e.g. http://192.168.1.100:5000',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Save & Apply Settings', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size(double.infinity, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // About App
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder, width: 0.8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FlixDirect Mobile v1.0.0', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Bypasses 9xflix ads & intermediate redirects to provide direct Cloudflare R2 high-speed downloads directly to your device storage.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
