import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:smart_query/smart_query.dart';

/// Posts Page — Infinite Scroll:
/// - Loads posts via InfiniteQueryBuilder
/// - Cursor-based pagination simulated with page numbers
/// - "Load more" button + auto-trigger on scroll
/// - Loading indicator at bottom while fetching
/// - "No more posts" when hasNextPage is false
class PostsPage extends StatelessWidget {
  const PostsPage({super.key});

  static const int _pageSize = 10;
  static const int _totalPosts = 100; // JSONPlaceholder has 100 posts

  static final _dio = Dio(BaseOptions(
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  ));

  static Future<List<Map<String, dynamic>>> _fetchPostsPage(int page) async {
    final start = (page - 1) * _pageSize;
    final response = await _dio.get(
      'https://dummyjson.com/posts',
      queryParameters: {'skip': start, 'limit': _pageSize},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load posts page $page');
    }
    final List<dynamic> data = response.data['posts'];
    return data.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infinite Posts'),
        centerTitle: true,
      ),
      body: InfiniteQueryBuilder<List<Map<String, dynamic>>, int>(
        queryKey: const ['posts', 'infinite'],
        fetcher: _fetchPostsPage,
        initialPageParam: 1,
        getNextPageParam: (lastPage, allPages) {
          // If the last page returned fewer items than page size, no more pages
          if (lastPage.length < _pageSize) return null;
          // If total loaded items >= total, no more pages
          final totalLoaded =
              allPages.fold<int>(0, (sum, page) => sum + page.length);
          if (totalLoaded >= _totalPosts) return null;
          return allPages.length + 1;
        },
        builder: (context, result) {
          if (result.isError && result.pages.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Error: ${result.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: result.refetch,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (result.pages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Flatten all pages into one list
          final allPosts = result.pages.expand((page) => page).toList();

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Auto-load next page when near the bottom
              if (notification is ScrollEndNotification &&
                  notification.metrics.extentAfter < 200 &&
                  result.hasNextPage &&
                  !result.isFetchingNextPage) {
                result.fetchNextPage();
              }
              return false;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allPosts.length + 1, // +1 for the footer
              itemBuilder: (context, index) {
                if (index == allPosts.length) {
                  return _buildFooter(context, result);
                }
                final post = allPosts[index];
                return _InfinitePostCard(
                  title: post['title'] as String,
                  body: post['body'] as String,
                  index: index + 1,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    InfiniteQueryResult<List<Map<String, dynamic>>> result,
  ) {
    if (result.isFetchingNextPage) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!result.hasNextPage) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                'No more posts',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: result.fetchNextPage,
          icon: const Icon(Icons.expand_more),
          label: const Text('Load More'),
        ),
      ),
    );
  }
}

class _InfinitePostCard extends StatelessWidget {
  const _InfinitePostCard({
    required this.title,
    required this.body,
    required this.index,
  });

  final String title;
  final String body;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
          child: Text('$index'),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
