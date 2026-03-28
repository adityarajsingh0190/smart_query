import 'package:flutter/material.dart';
import 'package:smart_query/smart_query.dart';

import 'pages/home_page.dart';
import 'pages/posts_page.dart';
import 'pages/products_page.dart';
import 'pages/profile_page.dart';

void main() {
  runApp(const SmartQueryExampleApp());
}

class SmartQueryExampleApp extends StatefulWidget {
  const SmartQueryExampleApp({super.key});

  @override
  State<SmartQueryExampleApp> createState() => _SmartQueryExampleAppState();
}

class _SmartQueryExampleAppState extends State<SmartQueryExampleApp> {
  late final QueryClient _queryClient;

  @override
  void initState() {
    super.initState();
    _queryClient = QueryClient(
      defaultOptions: const QueryDefaults(
        staleTime: Duration(minutes: 1),
        cacheTime: Duration(minutes: 5),
      ),
    );
  }

  @override
  void dispose() {
    _queryClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QueryClientProvider(
      client: _queryClient,
      child: MaterialApp(
        title: 'SmartQuery Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF6750A4),
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF6750A4),
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: const MainNavigation(),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  static const _pages = <Widget>[
    HomePage(),
    ProfilePage(),
    PostsPage(),
    ProductsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: 'Posts',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Products',
          ),
        ],
      ),
    );
  }
}
