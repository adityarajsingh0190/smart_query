/// Holds the accumulated pages for an infinite query.
///
/// Each element in [pages] represents one page of data.
/// [pageParams] contains the corresponding page parameters used to fetch
/// each page.
class InfiniteQueryData<TPage> {
  /// Creates an infinite query data container.
  const InfiniteQueryData({
    required this.pages,
    required this.pageParams,
  });

  /// Creates an empty infinite query data container.
  const InfiniteQueryData.empty()
      : pages = const [],
        pageParams = const [];

  /// All loaded pages in order.
  final List<TPage> pages;

  /// The page parameters used to fetch each page, in the same order as [pages].
  final List<dynamic> pageParams;

  /// Whether any pages have been loaded.
  bool get isEmpty => pages.isEmpty;

  /// Whether at least one page has been loaded.
  bool get isNotEmpty => pages.isNotEmpty;

  /// The number of loaded pages.
  int get length => pages.length;

  /// Returns a new [InfiniteQueryData] with an appended page.
  InfiniteQueryData<TPage> appendPage(TPage page, dynamic pageParam) {
    return InfiniteQueryData<TPage>(
      pages: [...pages, page],
      pageParams: [...pageParams, pageParam],
    );
  }

  /// Returns a new [InfiniteQueryData] with a prepended page.
  InfiniteQueryData<TPage> prependPage(TPage page, dynamic pageParam) {
    return InfiniteQueryData<TPage>(
      pages: [page, ...pages],
      pageParams: [pageParam, ...pageParams],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! InfiniteQueryData<TPage>) return false;
    if (pages.length != other.pages.length) return false;
    for (var i = 0; i < pages.length; i++) {
      if (pages[i] != other.pages[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(pages);

  @override
  String toString() => 'InfiniteQueryData<$TPage>(pages: ${pages.length}, '
      'pageParams: $pageParams)';
}
