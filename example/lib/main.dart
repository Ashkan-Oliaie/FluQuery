import 'package:flutter/material.dart';
import 'package:fluquery/fluquery.dart';
import 'package:google_fonts/google_fonts.dart';

import 'api/api_client.dart';
import 'examples/basic_query_example.dart';
import 'examples/mutation_example.dart';
import 'examples/infinite_query_example.dart';
import 'examples/dependent_queries_example.dart';
import 'examples/polling_example.dart';
import 'examples/optimistic_update_example.dart';
import 'examples/race_condition_example.dart';
import 'examples/advanced_features_example.dart';
import 'examples/nested_queries/screens/todo_list_screen.dart';

void main() {
  runApp(const FluQueryExampleApp());
}

class FluQueryExampleApp extends StatefulWidget {
  const FluQueryExampleApp({super.key});

  @override
  State<FluQueryExampleApp> createState() => _FluQueryExampleAppState();
}

class _FluQueryExampleAppState extends State<FluQueryExampleApp> {
  late final QueryClient _queryClient;

  @override
  void initState() {
    super.initState();
    _queryClient = QueryClient(
      config: const QueryClientConfig(
        defaultOptions: DefaultQueryOptions(
          staleTime: StaleTime(Duration(minutes: 5)),
          retry: 3,
        ),
        logLevel: LogLevel.debug,
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
        title: 'FluQuery Examples',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0F0F1A),
          textTheme: GoogleFonts.spaceGroteskTextTheme(
            ThemeData.dark().textTheme,
          ).copyWith(
            headlineLarge: GoogleFonts.orbitron(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            headlineMedium: GoogleFonts.orbitron(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF1A1A2E),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0x1AFFFFFF)),
            ),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            titleTextStyle: GoogleFonts.orbitron(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        home: const ExamplesHomePage(),
      ),
    );
  }
}

class ExamplesHomePage extends StatefulWidget {
  const ExamplesHomePage({super.key});

  @override
  State<ExamplesHomePage> createState() => _ExamplesHomePageState();
}

class _ExamplesHomePageState extends State<ExamplesHomePage> {
  final _backendUrlController = TextEditingController(text: 'http://localhost:8080');

  @override
  void dispose() {
    _backendUrlController.dispose();
    super.dispose();
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withAlpha(40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.settings, color: Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Backend Settings',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backend URL',
              style: TextStyle(
                color: Colors.white.withAlpha(153),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _backendUrlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'http://localhost:8080',
                hintStyle: TextStyle(color: Colors.white.withAlpha(77)),
                filled: true,
                fillColor: Colors.white.withAlpha(13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.link, color: Color(0xFF6366F1)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withAlpha(77)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Start backend first:',
                        style: TextStyle(
                          color: Colors.orange.shade200,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'cd backend && dart run bin/server.dart',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withAlpha(153)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ApiConfig.setBaseUrl(_backendUrlController.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Backend URL updated to ${_backendUrlController.text}'),
                  backgroundColor: const Color(0xFF6366F1),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F1A),
              Color(0xFF1A1A2E),
              Color(0xFF0F0F1A),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.bolt,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'FluQuery',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _showSettingsDialog,
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(26),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.settings,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Powerful async state management for Flutter',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withAlpha(153),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'EXAMPLES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _ExampleCard(
                      icon: Icons.search,
                      title: 'Basic Query',
                      description: 'Fetch and cache data with automatic refetching',
                      color: const Color(0xFF22C55E),
                      onTap: () => _navigate(context, const BasicQueryExample()),
                    ),
                    _ExampleCard(
                      icon: Icons.edit,
                      title: 'Mutations',
                      description: 'Create, update, and delete with cache invalidation',
                      color: const Color(0xFFF59E0B),
                      onTap: () => _navigate(context, const MutationExample()),
                    ),
                    _ExampleCard(
                      icon: Icons.list,
                      title: 'Infinite Query',
                      description: 'Paginated/infinite scroll with load more',
                      color: const Color(0xFF3B82F6),
                      onTap: () => _navigate(context, const InfiniteQueryExample()),
                    ),
                    _ExampleCard(
                      icon: Icons.account_tree,
                      title: 'Dependent Queries',
                      description: 'Sequential queries that depend on each other',
                      color: const Color(0xFFEC4899),
                      onTap: () => _navigate(context, const DependentQueriesExample()),
                    ),
                    _ExampleCard(
                      icon: Icons.refresh,
                      title: 'Polling',
                      description: 'Auto-refresh data at regular intervals',
                      color: const Color(0xFF14B8A6),
                      onTap: () => _navigate(context, const PollingExample()),
                    ),
                    _ExampleCard(
                      icon: Icons.flash_on,
                      title: 'Optimistic Updates',
                      description: 'Instant UI updates with rollback on error',
                      color: const Color(0xFF8B5CF6),
                      onTap: () => _navigate(context, const OptimisticUpdateExample()),
                    ),
                    const SizedBox(height: 12),
                    _ExampleCard(
                      icon: Icons.sync_problem,
                      title: 'Race Conditions',
                      description: 'Automatic handling of concurrent requests',
                      color: const Color(0xFFEC4899),
                      onTap: () => _navigate(context, const RaceConditionExample()),
                    ),
                    const SizedBox(height: 12),
                    _ExampleCard(
                      icon: Icons.auto_awesome,
                      title: 'Advanced Features',
                      description: 'Select, keepPreviousData, and more',
                      color: const Color(0xFF14B8A6),
                      onTap: () => _navigate(context, const AdvancedFeaturesExample()),
                    ),
                    const SizedBox(height: 12),
                    _ExampleCard(
                      icon: Icons.account_tree,
                      title: 'Nested Queries',
                      description: 'Complex list → detail with subtasks & activities',
                      color: const Color(0xFFA855F7),
                      onTap: () => _navigate(context, const NestedQueriesScreen()),
                    ),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ExampleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withAlpha(38),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withAlpha(128),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.white.withAlpha(77),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
