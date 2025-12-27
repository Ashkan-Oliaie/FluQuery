import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

/// Example demonstrating factory services with their own QueryStores.
///
/// Watch the devtools as you:
/// 1. Navigate into a product detail → Service appears in Services tab, Stores appear
/// 2. Navigate back → Service and its Stores disappear (disposed)
/// 3. Navigate to different products → Different services with unique names
///
/// This showcases the lifecycle management of named/factory services.
class ServiceLifecycleExample extends StatelessWidget {
  const ServiceLifecycleExample({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Lifecycle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
                )
              : null,
        ),
        child: Column(
          children: [
            // Instructions banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: const Color(0xFF8B5CF6),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Watch the Devtools!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Click a product → Service & Stores appear in devtools\n'
                    '• Go back → Service & Stores disappear (disposed)\n'
                    '• Each product gets its own named service instance',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            // Product list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return _ProductCard(
                    product: product,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ProductDetailPage(product: product),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MOCK DATA
// ============================================================

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final IconData icon;
  final Color color;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.icon,
    required this.color,
  });
}

const _products = [
  Product(
    id: 'laptop-1',
    name: 'MacBook Pro',
    description: 'Powerful laptop for professionals',
    price: 2499.99,
    icon: Icons.laptop_mac,
    color: Color(0xFF8B5CF6),
  ),
  Product(
    id: 'phone-1',
    name: 'iPhone 15',
    description: 'Latest smartphone with amazing camera',
    price: 1199.99,
    icon: Icons.phone_iphone,
    color: Color(0xFF3B82F6),
  ),
  Product(
    id: 'watch-1',
    name: 'Apple Watch',
    description: 'Smart watch for health tracking',
    price: 399.99,
    icon: Icons.watch,
    color: Color(0xFF22C55E),
  ),
  Product(
    id: 'headphones-1',
    name: 'AirPods Max',
    description: 'Premium over-ear headphones',
    price: 549.99,
    icon: Icons.headphones,
    color: Color(0xFFEC4899),
  ),
];

// ============================================================
// PRODUCT DATA TYPES
// ============================================================

class ProductDetails {
  final String id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final double rating;

  ProductDetails({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.rating,
  });
}

class Review {
  final String id;
  final String author;
  final int rating;
  final String comment;

  Review({
    required this.id,
    required this.author,
    required this.rating,
    required this.comment,
  });
}

// ============================================================
// PRODUCT SERVICE (Named service - one per product)
// ============================================================

/// A service that manages data for a single product.
/// Registered as a named service - each product gets its own named instance.
/// When disposed, its QueryStores are also disposed.
class ProductService extends Service {
  final String productId;
  late final QueryStore<ProductDetails, Object> detailsStore;
  late final QueryStore<List<Review>, Object> reviewsStore;

  ProductService(ServiceRef ref, this.productId) {
    // Create stores for this specific product
    // These stores are owned by this service and will be disposed with it
    detailsStore = ref.createStore<ProductDetails, Object>(
      queryKey: ['product', productId, 'details'],
      queryFn: (_) => _fetchProductDetails(productId),
      staleTime: const StaleTime(Duration(seconds: 30)),
    );

    reviewsStore = ref.createStore<List<Review>, Object>(
      queryKey: ['product', productId, 'reviews'],
      queryFn: (_) => _fetchProductReviews(productId),
      staleTime: const StaleTime(Duration(seconds: 30)),
    );

    debugPrint('✅ ProductService($productId) created with 2 stores');
  }

  @override
  Future<void> onInit() async {
    // Fetch data when service is initialized
    await Future.wait([
      detailsStore.fetch(),
      reviewsStore.fetch(),
    ]);
    debugPrint('🚀 ProductService($productId) initialized');
  }

  @override
  Future<void> onDispose() async {
    debugPrint('🗑️ ProductService($productId) disposing...');
  }

  // Simulated API calls
  static Future<ProductDetails> _fetchProductDetails(String id) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final product = _products.firstWhere((p) => p.id == id);
    return ProductDetails(
      id: product.id,
      name: product.name,
      description: product.description,
      price: product.price,
      stock: Random().nextInt(100) + 10,
      rating: 3.5 + Random().nextDouble() * 1.5,
    );
  }

  static Future<List<Review>> _fetchProductReviews(String id) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return List.generate(
      Random().nextInt(5) + 3,
      (i) => Review(
        id: 'review-$i',
        author: ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve'][i % 5],
        rating: Random().nextInt(2) + 4,
        comment: [
          'Great product! Highly recommend.',
          'Good quality, fast shipping.',
          'Exactly as described.',
          'Love it! Will buy again.',
          'Excellent value for money.',
        ][i % 5],
      ),
    );
  }
}

// ============================================================
// PRODUCT CARD
// ============================================================

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: product.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(product.icon, color: product.color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${product.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: product.color,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PRODUCT DETAIL PAGE (Creates named service on mount)
// ============================================================

class _ProductDetailPage extends HookWidget {
  final Product product;

  const _ProductDetailPage({required this.product});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final client = useQueryClient();

    // State for the service
    final serviceState = useState<ProductService?>(null);
    final isLoading = useState(true);
    final error = useState<String?>(null);

    useEffect(() {
      // Register and get a named service for this specific product
      _initService(client, product.id).then((service) {
        serviceState.value = service;
        isLoading.value = false;
      }).catchError((e) {
        error.value = e.toString();
        isLoading.value = false;
      });

      // Cleanup on unmount - unregister the named service
      return () {
        _disposeService(client, product.id);
      };
    }, [product.id]);

    if (isLoading.value) {
      return Scaffold(
        appBar: AppBar(title: Text(product.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error.value != null) {
      return Scaffold(
        appBar: AppBar(title: Text(product.name)),
        body: Center(child: Text('Error: ${error.value}')),
      );
    }

    final service = serviceState.value!;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
                )
              : null,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: product.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: product.color.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(product.icon, color: product.color, size: 64),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: product.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Service indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF22C55E), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ProductService(${product.id}) active - check Services tab!',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Product details
              _SectionTitle(title: 'Details', isDark: isDark),
              const SizedBox(height: 12),
              _DetailsCard(store: service.detailsStore, isDark: isDark),
              const SizedBox(height: 24),

              // Reviews
              _SectionTitle(title: 'Reviews', isDark: isDark),
              const SizedBox(height: 12),
              _ReviewsList(store: service.reviewsStore, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }

  Future<ProductService> _initService(
      QueryClient client, String productId) async {
    final container = client.services!;
    final serviceName = 'product-$productId';

    // Register a named service for this specific product
    // Each product gets its own named instance
    container.registerNamed<ProductService>(
      serviceName,
      (ref) => ProductService(ref, productId),
      lazy: false, // Initialize immediately
    );

    // Get and wait for initialization
    final service = await container.get<ProductService>(name: serviceName);
    return service;
  }

  Future<void> _disposeService(QueryClient client, String productId) async {
    final container = client.services!;
    final serviceName = 'product-$productId';

    // Unregister the named service - this disposes it and its stores
    await container.unregister<ProductService>(name: serviceName);
    debugPrint('🗑️ ProductService($productId) unregistered and disposed');
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionTitle({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }
}

class _DetailsCard extends HookWidget {
  final QueryStore<ProductDetails, Object> store;
  final bool isDark;

  const _DetailsCard({required this.store, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Subscribe to store state
    final state = useState(store.state);

    useEffect(() {
      final unsub = store.subscribe((s) {
        state.value = s;
      });
      return unsub;
    }, [store]);

    if (state.value.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final details = state.value.data;
    if (details == null) {
      return const Text('No details available');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          _DetailRow(
              label: 'Stock', value: '${details.stock} units', isDark: isDark),
          _DetailRow(
            label: 'Rating',
            value: '${details.rating.toStringAsFixed(1)} ⭐',
            isDark: isDark,
          ),
          _DetailRow(
              label: 'Description', value: details.description, isDark: isDark),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsList extends HookWidget {
  final QueryStore<List<Review>, Object> store;
  final bool isDark;

  const _ReviewsList({required this.store, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Subscribe to store state
    final state = useState(store.state);

    useEffect(() {
      final unsub = store.subscribe((s) {
        state.value = s;
      });
      return unsub;
    }, [store]);

    if (state.value.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final reviews = state.value.data;
    if (reviews == null || reviews.isEmpty) {
      return const Text('No reviews yet');
    }

    return Column(
      children: reviews
          .map((review) => _ReviewCard(review: review, isDark: isDark))
          .toList(),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  final bool isDark;

  const _ReviewCard({required this.review, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.purple.withValues(alpha: 0.2),
                child: Text(
                  review.author[0],
                  style: const TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                review.author,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
