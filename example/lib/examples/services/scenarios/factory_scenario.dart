import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluquery/fluquery.dart';

import '../../shared/shared.dart';

/// Demonstrates Factory Services - one service instance per screen.
///
/// **Factory = Screen-Scoped Pattern:**
/// - Each screen gets its own service instance
/// - Isolated state: form data, selections, loading states
/// - Disposed automatically when screen closes
/// - Perfect for: Product pages, forms, wizards, modals
class FactoryScenario extends HookWidget {
  const FactoryScenario({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedProduct = useState<_ProductInfo?>(null);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),
          Expanded(
            child: selectedProduct.value == null
                ? _ProductGrid(
                    onSelectProduct: (p) => selectedProduct.value = p,
                  )
                : _ProductDetailScreen(
                    product: selectedProduct.value!,
                    onBack: () => selectedProduct.value = null,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Factory Pattern - Screen-Scoped Services',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Each product detail screen gets its own service with isolated state. '
          'Select a product to see a service managing quantity, variants, and cart actions.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SERVICE - Factory service for product detail screen
// ============================================================

/// Product detail service - created per product via factory.
class ProductDetailService extends Service {
  final _ProductInfo product;

  // Reactive state
  final quantity = ReactiveState<int>(1);
  final selectedSize = ReactiveState<String?>(null);
  final selectedColor = ReactiveState<String?>(null);
  final isAddingToCart = ReactiveState<bool>(false);
  final cartMessage = ReactiveState<String?>(null);
  final isFavorite = ReactiveState<bool>(false);

  // Computed values exposed
  int get totalPrice => product.price * quantity.value;
  bool get canAddToCart =>
      selectedSize.value != null && selectedColor.value != null;

  ProductDetailService(this.product);

  void incrementQuantity() {
    if (quantity.value < 10) quantity.value++;
  }

  void decrementQuantity() {
    if (quantity.value > 1) quantity.value--;
  }

  void selectSize(String size) {
    selectedSize.value = size;
    cartMessage.value = null;
  }

  void selectColor(String color) {
    selectedColor.value = color;
    cartMessage.value = null;
  }

  void toggleFavorite() {
    isFavorite.value = !isFavorite.value;
  }

  Future<void> addToCart() async {
    if (!canAddToCart) {
      cartMessage.value = 'Please select size and color';
      return;
    }

    isAddingToCart.value = true;
    cartMessage.value = null;

    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 800));

    cartMessage.value =
        'Added ${quantity.value}x ${product.name} (${selectedSize.value}, ${selectedColor.value}) to cart!';
    isAddingToCart.value = false;

    // Reset after success
    await Future.delayed(const Duration(seconds: 2));
    cartMessage.value = null;
  }

  @override
  Future<void> onDispose() async {
    quantity.dispose();
    selectedSize.dispose();
    selectedColor.dispose();
    isAddingToCart.dispose();
    cartMessage.dispose();
    isFavorite.dispose();
  }
}

// ============================================================
// MOCK DATA
// ============================================================

class _ProductInfo {
  final String id;
  final String name;
  final String image;
  final int price;
  final String description;
  final List<String> sizes;
  final List<String> colors;
  final double rating;
  final int reviews;

  const _ProductInfo({
    required this.id,
    required this.name,
    required this.image,
    required this.price,
    required this.description,
    required this.sizes,
    required this.colors,
    required this.rating,
    required this.reviews,
  });
}

const _products = [
  _ProductInfo(
    id: '1',
    name: 'Classic Sneakers',
    image: '👟',
    price: 129,
    description:
        'Timeless design meets modern comfort. Perfect for everyday wear.',
    sizes: ['US 7', 'US 8', 'US 9', 'US 10', 'US 11'],
    colors: ['White', 'Black', 'Navy'],
    rating: 4.8,
    reviews: 2341,
  ),
  _ProductInfo(
    id: '2',
    name: 'Running Pro',
    image: '🏃',
    price: 179,
    description: 'Engineered for performance. Lightweight and responsive.',
    sizes: ['US 7', 'US 8', 'US 9', 'US 10'],
    colors: ['Red', 'Blue', 'Lime'],
    rating: 4.9,
    reviews: 1823,
  ),
  _ProductInfo(
    id: '3',
    name: 'Hiking Boots',
    image: '🥾',
    price: 219,
    description: 'Waterproof and durable. Conquer any trail.',
    sizes: ['US 8', 'US 9', 'US 10', 'US 11', 'US 12'],
    colors: ['Brown', 'Olive', 'Black'],
    rating: 4.7,
    reviews: 987,
  ),
  _ProductInfo(
    id: '4',
    name: 'Sandals Comfort',
    image: '🩴',
    price: 59,
    description: 'Ultimate comfort for beach and casual outings.',
    sizes: ['US 7', 'US 8', 'US 9', 'US 10'],
    colors: ['Tan', 'Black', 'White'],
    rating: 4.5,
    reviews: 1456,
  ),
];

// ============================================================
// UI COMPONENTS
// ============================================================

class _ProductGrid extends StatelessWidget {
  final void Function(_ProductInfo) onSelectProduct;

  const _ProductGrid({required this.onSelectProduct});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a product to open its detail screen:',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.4,
            ),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              return _ProductCard(
                product: product,
                onTap: () => onSelectProduct(product),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final _ProductInfo product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ThemedCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(product.image, style: const TextStyle(fontSize: 32)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          product.rating.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                product.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${product.price}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Product detail screen with its own service
class _ProductDetailScreen extends HookWidget {
  final _ProductInfo product;
  final VoidCallback onBack;

  const _ProductDetailScreen({
    required this.product,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Create service for this screen instance
    final service =
        useMemoized(() => ProductDetailService(product), [product.id]);

    // Dispose service when screen closes
    useEffect(() => service.dispose, [service]);

    // Subscribe to reactive state
    final quantity = useValueListenable(service.quantity);
    final selectedSize = useValueListenable(service.selectedSize);
    final selectedColor = useValueListenable(service.selectedColor);
    final isAddingToCart = useValueListenable(service.isAddingToCart);
    final cartMessage = useValueListenable(service.cartMessage);
    final isFavorite = useValueListenable(service.isFavorite);

    return ThemedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Service Hash: ${service.hashCode.toRadixString(16)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: service.toggleFavorite,
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : null,
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05)),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(product.image,
                              style: const TextStyle(fontSize: 48)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\$${product.price}',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.star,
                                    size: 16, color: Colors.amber.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  '${product.rating} (${product.reviews} reviews)',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Size selector
                  Text(
                    'Size',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: product.sizes.map((size) {
                      final isSelected = selectedSize == size;
                      return ChoiceChip(
                        label: Text(size),
                        selected: isSelected,
                        onSelected: (_) => service.selectSize(size),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Color selector
                  Text(
                    'Color',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: product.colors.map((color) {
                      final isSelected = selectedColor == color;
                      return ChoiceChip(
                        label: Text(color),
                        selected: isSelected,
                        onSelected: (_) => service.selectColor(color),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Quantity selector
                  Text(
                    'Quantity',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton.filled(
                        onPressed: service.decrementQuantity,
                        icon: const Icon(Icons.remove),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          foregroundColor: theme.colorScheme.primary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          quantity.toString(),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: service.incrementQuantity,
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          foregroundColor: theme.colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Total: \$${service.totalPrice}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Cart message
          if (cartMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: cartMessage.contains('Added')
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              child: Text(
                cartMessage,
                style: TextStyle(
                  color: cartMessage.contains('Added')
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Add to cart button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isAddingToCart ? null : () => service.addToCart(),
                icon: isAddingToCart
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.shopping_cart),
                label: Text(isAddingToCart ? 'Adding...' : 'Add to Cart'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
