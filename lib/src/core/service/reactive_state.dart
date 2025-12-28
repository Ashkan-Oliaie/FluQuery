import 'package:flutter/foundation.dart';

/// A reactive state container for services.
///
/// Use this for non-query state in services like:
/// - UI state (selected items, filters, sorting)
/// - Computed values
/// - Form state
/// - Any custom reactive data
///
/// Example:
/// ```dart
/// class CartService extends Service {
///   final items = ReactiveState<List<CartItem>>([]);
///   final selectedCoupon = ReactiveState<String?>(null);
///
///   // Computed property
///   double get total => items.value.fold(0, (sum, item) => sum + item.price);
///
///   void addItem(CartItem item) {
///     items.value = [...items.value, item];
///   }
///
///   void applyCoupon(String code) {
///     selectedCoupon.value = code;
///   }
/// }
///
/// // In widget:
/// class CartWidget extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final cartItems = useServiceValue<CartService, List<CartItem>>(
///       (cart) => cart.items,
///     );
///     return ListView(children: cartItems.map(ItemTile.new).toList());
///   }
/// }
/// ```
class ReactiveState<T> extends ValueNotifier<T> {
  ReactiveState(super.value);

  /// Update the value using a transformer function.
  ///
  /// Useful for immutable updates:
  /// ```dart
  /// items.update((list) => [...list, newItem]);
  /// ```
  void update(T Function(T current) transformer) {
    value = transformer(value);
  }

  /// Reset to initial value.
  void reset(T initialValue) {
    value = initialValue;
  }
}

/// A reactive list state with convenient mutation methods.
///
/// Example:
/// ```dart
/// class TodoService extends Service {
///   final todos = ReactiveList<Todo>([]);
///
///   void addTodo(Todo todo) => todos.add(todo);
///   void removeTodo(String id) => todos.removeWhere((t) => t.id == id);
///   void toggleDone(String id) {
///     todos.updateWhere(
///       (t) => t.id == id,
///       (t) => t.copyWith(done: !t.done),
///     );
///   }
/// }
/// ```
class ReactiveList<T> extends ReactiveState<List<T>> {
  ReactiveList([List<T>? initial]) : super(initial ?? []);

  /// Add an item to the list.
  void add(T item) {
    value = [...value, item];
  }

  /// Add multiple items to the list.
  void addAll(Iterable<T> items) {
    value = [...value, ...items];
  }

  /// Remove an item from the list.
  void remove(T item) {
    value = value.where((e) => e != item).toList();
  }

  /// Remove items matching a predicate.
  void removeWhere(bool Function(T item) test) {
    value = value.where((e) => !test(e)).toList();
  }

  /// Update items matching a predicate.
  void updateWhere(bool Function(T item) test, T Function(T item) update) {
    value = value.map((e) => test(e) ? update(e) : e).toList();
  }

  /// Clear all items.
  void clear() {
    value = [];
  }

  /// Get item at index.
  T operator [](int index) => value[index];

  /// List length.
  int get length => value.length;

  /// Whether the list is empty.
  bool get isEmpty => value.isEmpty;

  /// Whether the list is not empty.
  bool get isNotEmpty => value.isNotEmpty;
}

/// A reactive map state with convenient mutation methods.
///
/// Example:
/// ```dart
/// class SettingsService extends Service {
///   final preferences = ReactiveMap<String, dynamic>({});
///
///   void setSetting(String key, dynamic value) {
///     preferences[key] = value;
///   }
/// }
/// ```
class ReactiveMap<K, V> extends ReactiveState<Map<K, V>> {
  ReactiveMap([Map<K, V>? initial]) : super(initial ?? {});

  /// Set a key-value pair.
  void operator []=(K key, V val) {
    value = {...value, key: val};
  }

  /// Get a value by key.
  V? operator [](K key) => value[key];

  /// Remove a key.
  void remove(K key) {
    value = Map.from(value)..remove(key);
  }

  /// Clear all entries.
  void clear() {
    value = {};
  }

  /// Check if key exists.
  bool containsKey(K key) => value.containsKey(key);

  /// Get all keys.
  Iterable<K> get keys => value.keys;

  /// Get all values.
  Iterable<V> get values => value.values;

  /// Map length.
  int get length => value.length;

  /// Whether the map is empty.
  bool get isEmpty => value.isEmpty;

  /// Whether the map is not empty.
  bool get isNotEmpty => value.isNotEmpty;
}
