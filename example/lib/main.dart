import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';
import 'package:google_fonts/google_fonts.dart';

import 'api/api_client.dart';
import 'examples/basic_query/basic_query_example.dart';
import 'examples/mutation/mutation_example.dart';
import 'examples/infinite_query/infinite_query_example.dart';
import 'examples/dependent_queries/dependent_queries_example.dart';
import 'examples/polling/polling_example.dart';
import 'examples/optimistic_update/optimistic_update_example.dart';
import 'examples/race_condition/race_condition_example.dart';
import 'examples/advanced_features/advanced_features_example.dart';
import 'examples/nested_queries/screens/todo_list_screen.dart';
import 'examples/global_store/global_store_example.dart';
import 'examples/persistence/persistence_example.dart';
import 'examples/services/services_example.dart';
import 'examples/viewmodel/viewmodel_example.dart';
import 'services/services.dart';

void main() {
  runApp(const FluQueryExampleApp());
}

class FluQueryExampleApp extends StatefulWidget {
  const FluQueryExampleApp({super.key});

  @override
  State<FluQueryExampleApp> createState() => _FluQueryExampleAppState();
}

class _FluQueryExampleAppState extends State<FluQueryExampleApp> {
  QueryClient? _queryClient;
  HiveCePersister? _persister;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    // Create and initialize the Hive CE persister
    // Data is stored in the app's documents directory
    _persister = HiveCePersister(boxName: 'fluquery_example_cache');
    await _persister!.init();

    _queryClient = QueryClient(
      config: QueryClientConfig(
        defaultOptions: DefaultQueryOptions(
          staleTime: StaleTime(const Duration(minutes: 5)),
          retry: 3,
        ),
        logLevel: LogLevel.debug,
      ),
      persister: _persister,
    );

    // Initialize services
    await _queryClient!.initServices((container) {
      // Config service - global app configuration with polling
      container.register<ConfigService>((ref) => ConfigService());
      // Auth services
      container.register<TokenStorageService>((ref) => TokenStorageService());
      container.register<ActivityTrackingService>(
          (ref) => ActivityTrackingService());
      container.register<SessionService>((ref) => SessionService(ref));
      container.register<AuthService>((ref) => AuthService(ref));
    });

    // Hydrate cache from persistence - restores cached queries
    await _queryClient!.hydrate();

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _queryClient?.dispose();
    _persister?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while initializing
    if (!_isInitialized || _queryClient == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing...'),
              ],
            ),
          ),
        ),
      );
    }

    return QueryClientProvider(
      client: _queryClient!,
      child: const _ConfiguredApp(),
    );
  }
}

/// App wrapper that listens to ConfigService
class _ConfiguredApp extends HookWidget {
  const _ConfiguredApp();

  @override
  Widget build(BuildContext context) {
    // Use selector to get config from ConfigService
    final config = useSelect<ConfigService, ConfigState, AppConfig?>((s) => s.config);
    final isDark = config?.theme != 'light';

    return MaterialApp(
      title: 'FluQuery Examples',
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: _buildTheme(config, false),
      darkTheme: _buildTheme(config, true),
      builder: (context, child) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              // Global persistent header
              const GlobalConfigBar(),
              // Page content
              Expanded(child: child ?? const SizedBox()),
            ],
          ),
        );
      },
      home: const ExamplesHomePage(),
    );
  }
}

ThemeData _buildTheme(AppConfig? config, bool isDark) {
  final accentColor = _getAccentColor(config?.accentColor ?? 'indigo');

  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: isDark ? Brightness.dark : Brightness.light,
    ),
    scaffoldBackgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.grey[100],
    textTheme: GoogleFonts.spaceGroteskTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).copyWith(
      headlineLarge: GoogleFonts.orbitron(
        fontSize: _getFontSize(config?.fontSize, 28),
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
      headlineMedium: GoogleFonts.orbitron(
        fontSize: _getFontSize(config?.fontSize, 20),
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black87,
      ),
    ),
    cardTheme: CardThemeData(
      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0x1AFFFFFF) : Colors.grey.shade200,
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: GoogleFonts.orbitron(
        fontSize: _getFontSize(config?.fontSize, 20),
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
      iconTheme: IconThemeData(
        color: isDark ? Colors.white70 : Colors.black54,
      ),
    ),
  );
}

Color _getAccentColor(String colorName) {
  switch (colorName) {
    case 'purple':
      return const Color(0xFF8B5CF6);
    case 'teal':
      return const Color(0xFF14B8A6);
    case 'orange':
      return const Color(0xFFF59E0B);
    case 'pink':
      return const Color(0xFFEC4899);
    case 'blue':
      return const Color(0xFF3B82F6);
    case 'indigo':
    default:
      return const Color(0xFF6366F1);
  }
}

double _getFontSize(String? size, double base) {
  switch (size) {
    case 'small':
      return base * 0.85;
    case 'large':
      return base * 1.15;
    case 'medium':
    default:
      return base;
  }
}

/// Global config bar that appears at the top of ALL pages
class GlobalConfigBar extends HookWidget {
  const GlobalConfigBar({super.key});

  @override
  Widget build(BuildContext context) {
    // Use selectors - granular rebuilds
    final config = useSelect<ConfigService, ConfigState, AppConfig?>((s) => s.config);
    final isLoading = useSelect<ConfigService, ConfigState, bool>((s) => s.isLoading);
    final isPaused = useSelect<ConfigService, ConfigState, bool>((s) => s.isPaused);

    // Get service for actions
    final configService = useService<ConfigService>();

    final isDark = config?.theme != 'light';
    final accentColor = _getAccentColor(config?.accentColor ?? 'indigo');

    return Material(
      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,
          left: 12,
          right: 12,
          bottom: 4,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: accentColor.withAlpha(60),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Config indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentColor.withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withAlpha(100),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    config?.accentColor.toUpperCase() ?? 'LOADING',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Theme indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(10)
                    : Colors.black.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    size: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    config?.theme.toUpperCase() ?? '-',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Version badge
            if (config != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha(8)
                      : Colors.black.withAlpha(8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'v${config.version}',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const Spacer(),
            // Loading indicator
            if (isLoading)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accentColor,
                  ),
                ),
              ),
            // Pause/Resume button
            GestureDetector(
              onTap: configService.togglePause,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha(10)
                      : Colors.black.withAlpha(10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPaused ? Icons.play_arrow : Icons.pause,
                  size: 14,
                  color: isPaused
                      ? const Color(0xFF22C55E)
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Randomize button
            GestureDetector(
              onTap: () async {
                try {
                  final newConfig = await ApiClient.randomizeConfig();
                  configService.setConfig(newConfig);
                } catch (_) {}
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.shuffle,
                  size: 14,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
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
  final _backendUrlController =
      TextEditingController(text: 'http://localhost:8080');

  @override
  void dispose() {
    _backendUrlController.dispose();
    super.dispose();
  }

  void _showSettingsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0x1AFFFFFF) : Colors.grey.shade200,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.settings,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Backend Settings',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
              ),
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
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _backendUrlController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'http://localhost:8080',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
                filled: true,
                fillColor:
                    isDark ? Colors.white.withAlpha(13) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(
                  Icons.link,
                  color: Theme.of(context).colorScheme.primary,
                ),
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
                      const Icon(Icons.info_outline,
                          color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Start backend first:',
                        style: TextStyle(
                          color: Colors.orange.shade700,
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
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ApiConfig.setBaseUrl(_backendUrlController.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Backend URL updated to ${_backendUrlController.text}'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F0F1A),
                    Color(0xFF1A1A2E),
                    Color(0xFF0F0F1A),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey.shade50,
                    Colors.white,
                    Colors.grey.shade100,
                  ],
                ),
        ),
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
                            gradient: LinearGradient(
                              colors: [
                                accentColor,
                                accentColor.withAlpha(180),
                              ],
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
                              color: isDark
                                  ? Colors.white.withAlpha(26)
                                  : Colors.black.withAlpha(13),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.settings,
                              color: isDark ? Colors.white70 : Colors.black54,
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
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'EXAMPLES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
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
                    description:
                        'Fetch and cache data with automatic refetching',
                    color: const Color(0xFF22C55E),
                    onTap: () => _navigate(context, const BasicQueryExample()),
                  ),
                  _ExampleCard(
                    icon: Icons.edit,
                    title: 'Mutations',
                    description:
                        'Create, update, and delete with cache invalidation',
                    color: const Color(0xFFF59E0B),
                    onTap: () => _navigate(context, const MutationExample()),
                  ),
                  _ExampleCard(
                    icon: Icons.list,
                    title: 'Infinite Query',
                    description: 'Paginated/infinite scroll with load more',
                    color: const Color(0xFF3B82F6),
                    onTap: () =>
                        _navigate(context, const InfiniteQueryExample()),
                  ),
                  _ExampleCard(
                    icon: Icons.account_tree,
                    title: 'Dependent Queries',
                    description: 'Sequential queries that depend on each other',
                    color: const Color(0xFFEC4899),
                    onTap: () =>
                        _navigate(context, const DependentQueriesExample()),
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
                    onTap: () =>
                        _navigate(context, const OptimisticUpdateExample()),
                  ),
                  _ExampleCard(
                    icon: Icons.sync_problem,
                    title: 'Race Conditions',
                    description: 'Automatic handling of concurrent requests',
                    color: const Color(0xFFEC4899),
                    onTap: () =>
                        _navigate(context, const RaceConditionExample()),
                  ),
                  _ExampleCard(
                    icon: Icons.auto_awesome,
                    title: 'Advanced Features',
                    description: 'Select, keepPreviousData, and more',
                    color: const Color(0xFF14B8A6),
                    onTap: () =>
                        _navigate(context, const AdvancedFeaturesExample()),
                  ),
                  _ExampleCard(
                    icon: Icons.account_tree,
                    title: 'Nested Queries',
                    description:
                        'Complex list → detail with subtasks & activities',
                    color: const Color(0xFFA855F7),
                    onTap: () =>
                        _navigate(context, const NestedQueriesScreen()),
                  ),
                  _ExampleCard(
                    icon: Icons.storage,
                    title: 'Global Store',
                    description:
                        'Persistent store with background polling across pages',
                    color: const Color(0xFFEF4444),
                    onTap: () => _navigate(context, const GlobalStoreExample()),
                  ),
                  _ExampleCard(
                    icon: Icons.save,
                    title: 'Persistence',
                    description:
                        'Save query data to disk and restore on app restart',
                    color: const Color(0xFF0EA5E9),
                    onTap: () => _navigate(context, const PersistenceExample()),
                  ),
                  _ExampleCard(
                    icon: Icons.category_rounded,
                    title: 'Services',
                    description: 'DI, auth flow, multi-tenant configurations',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => _navigate(context, const ServicesExample()),
                  ),
                  _ExampleCard(
                    icon: Icons.view_module_rounded,
                    title: 'ViewModel Pattern',
                    description:
                        'Task manager with filtering, CRUD, and real-time sync',
                    color: const Color(0xFFF59E0B),
                    onTap: () => _navigate(context, const ViewModelExample()),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    // Blend accent with item's own color for a themed look
    final blendedColor = Color.lerp(color, accentColor, 0.3)!;

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
              // Card background gets a subtle tint from global accent
              color: isDark
                  ? Color.lerp(const Color(0xFF1A1A2E), accentColor, 0.05)
                  : Color.lerp(Colors.white, accentColor, 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? accentColor.withAlpha(40)
                    : accentColor.withAlpha(25),
              ),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: accentColor.withAlpha(15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: accentColor.withAlpha(20),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: blendedColor.withAlpha(38),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: blendedColor.withAlpha(60)),
                  ),
                  child: Icon(icon, color: blendedColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: accentColor.withAlpha(isDark ? 100 : 80),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
