import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/movies_provider.dart';
import '../constants/app_theme.dart';
import '../widgets/movie_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _quickSearches = [
    'Deadpool',
    'Avengers',
    'Pushpa',
    'KGF',
    'Mirzapur',
    'Stree',
    'Kalki',
    'Oppenheimer',
    'John Wick',
    'Spider-Man',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      final provider = Provider.of<MoviesProvider>(context, listen: false);
      if (provider.searchHasNext && !provider.isSearching) {
        provider.loadMoreSearch();
      }
    }
  }

  void _submitSearch(String query) {
    if (query.trim().isNotEmpty) {
      FocusScope.of(context).unfocus();
      Provider.of<MoviesProvider>(context, listen: false).search(query.trim());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder, width: 0.8),
            ),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              autofocus: false,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onSubmitted: _submitSearch,
              decoration: InputDecoration(
                hintText: 'Search movies, series, dual audio...',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                          Provider.of<MoviesProvider>(context, listen: false).search('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ),
      body: Consumer<MoviesProvider>(
        builder: (context, provider, child) {
          if (provider.isSearching && provider.searchResults.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }

          if (provider.searchError != null && provider.searchResults.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.textMuted, size: 48),
                  const SizedBox(height: 12),
                  Text('Search error: ${provider.searchError}', style: const TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          if (provider.searchResults.isEmpty) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'POPULAR SEARCHES',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: _quickSearches.map((tag) {
                      return ActionChip(
                        label: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        backgroundColor: AppTheme.surfaceElevated,
                        side: const BorderSide(color: AppTheme.cardBorder, width: 0.8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onPressed: () {
                          _controller.text = tag;
                          _submitSearch(tag);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 40),
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_rounded, color: AppTheme.cardBorder, size: 64),
                        SizedBox(height: 12),
                        Text(
                          'Type a title to search on 9xflix',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final results = provider.searchResults;

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Typo Correction / Did you mean suggestion
              if (provider.suggestedQuery != null && provider.suggestedQuery != provider.currentQuery)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: AppTheme.accentGold, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              children: [
                                const TextSpan(text: 'Showing results for '),
                                TextSpan(
                                  text: provider.suggestedQuery,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentGold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Search Count Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text(
                    'Found ${results.length} results for "${provider.currentQuery}"',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              // Results Grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => MovieCard(movie: results[index]),
                    childCount: results.length,
                  ),
                ),
              ),

              if (provider.searchHasNext)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
            ],
          );
        },
      ),
    );
  }
}
