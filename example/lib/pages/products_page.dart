import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smart_query/smart_query.dart';

/// Products Page — Classic Pagination:
/// - Products with page 1/2/3 navigation
/// - keepPreviousData: true so old data shows while new page loads
/// - Page buttons disabled while loading
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  int _currentPage = 1;
  static const int _pageSize = 10;
  static const int _totalItems = 100; // JSONPlaceholder has 100 posts
  static final int _totalPages = (_totalItems / _pageSize).ceil();

  static Future<List<Map<String, dynamic>>> _fetchProducts(dynamic page) async {
    final pageNum = page as int;
    final start = (pageNum - 1) * _pageSize;
    final response = await http.get(
      Uri.parse(
        'https://jsonplaceholder.typicode.com/posts?_start=$start&_limit=$_pageSize',
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load products page $pageNum');
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Page content
          Expanded(
            child: PaginatedQueryBuilder<List<Map<String, dynamic>>>(
              queryKey: const ['products'],
              page: _currentPage,
              fetcher: _fetchProducts,
              keepPreviousData: true,
              staleTime: const Duration(minutes: 5),
              builder: (context, result) {
                if (result.isLoading && result.data == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (result.isError && result.data == null) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
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

                final items = result.data!;

                return AnimatedOpacity(
                  opacity: result.isPreviousData ? 0.6 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Stack(
                    children: [
                      ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final itemNum =
                              (_currentPage - 1) * _pageSize + index + 1;
                          return _ProductCard(
                            title: item['title'] as String,
                            body: item['body'] as String,
                            productNumber: itemNum,
                          );
                        },
                      ),
                      if (result.isFetching && !result.isLoading)
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Pagination controls
          _buildPaginationControls(context),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton.filled(
            onPressed:
                _currentPage > 1 ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 8),

          // Page number buttons
          for (int i = 1; i <= _totalPages && i <= 5; i++) ...[
            _PageButton(
              page: i,
              isSelected: _currentPage == i,
              onPressed: () => setState(() => _currentPage = i),
            ),
            if (i < _totalPages && i < 5) const SizedBox(width: 4),
          ],

          if (_totalPages > 5) ...[
            const SizedBox(width: 4),
            Text('...', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(width: 4),
            _PageButton(
              page: _totalPages,
              isSelected: _currentPage == _totalPages,
              onPressed: () => setState(() => _currentPage = _totalPages),
            ),
          ],

          const SizedBox(width: 8),

          // Next button
          IconButton.filled(
            onPressed: _currentPage < _totalPages
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.page,
    required this.isSelected,
    required this.onPressed,
  });

  final int page;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: isSelected
          ? FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
              ),
              child: Text('$page'),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
              ),
              child: Text('$page'),
            ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.title,
    required this.body,
    required this.productNumber,
  });

  final String title;
  final String body;
  final int productNumber;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product #$productNumber',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
