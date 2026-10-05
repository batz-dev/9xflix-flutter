import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/movies_provider.dart';
import '../constants/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/hero_banner.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  final List<String> _categories = [
    'All',
    '1080p',
    '720p',
    'HDTC',
    'Web Series',
    'Dual Audio',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      final provider = Provider.of<MoviesProvider>(context, listen: false);
      if (!provider.isLoadingMore && provider.hasNext) {
        provider.loadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.movie_filter_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                children: [
                  TextSpan(text: 'FLIX', style: TextStyle(color: Colors.white)),
                  TextSpan(text: 'DIRECT', style: TextStyle(color: AppTheme.primary)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<MoviesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.allRawMovies.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text('Fetching latest movies from 9xflix...', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          if (provider.error != null && provider.allRawMovies.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: AppTheme.textMuted, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load movies',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => provider.fetchLatest(isRefresh: true),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final movies = provider.movies;
          final topMovie = provider.allRawMovies.isNotEmpty ? provider.allRawMovies.first : null;

          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surface,
            onRefresh: () => provider.fetchLatest(isRefresh: true),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Top Category Filter Chips
                SliverToBoxAdapter(
                  child: Container(
                    height: 48,
                    margin: const EdgeInsets.only(top: 4, bottom: 4),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = provider.selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: ChoiceChip(
                            label: Text(
                              cat,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppTheme.primary,
                            backgroundColor: AppTheme.surfaceElevated,
                            side: BorderSide(
                              color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
                              width: 0.8,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                provider.setCategory(cat);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Featured Hero Banner
                if (topMovie != null && provider.selectedCategory == 'All')
                  SliverToBoxAdapter(
                    child: HeroBanner(movie: topMovie),
                  ),

                // Section Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 3.5,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          provider.selectedCategory == 'All' ? 'Latest Releases' : '${provider.selectedCategory} Releases',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${movies.length} movies',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),

                // Movies Grid (2 Columns)
                if (movies.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('No movies found in this category', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  )
                else
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
                        (context, index) {
                          return MovieCard(movie: movies[index]);
                        },
                        childCount: movies.length,
                      ),
                    ),
                  ),

                // Bottom Loading Spinner
                if (provider.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
