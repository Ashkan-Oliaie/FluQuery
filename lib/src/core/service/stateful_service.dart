import 'package:flutter/foundation.dart';
import 'service.dart';

/// A service that maintains a single immutable state object.
///
/// Use this for services that need reactive state with:
/// - Single source of truth
/// - Atomic updates (multiple changes = one notification)
/// - Selector support for granular widget rebuilds
/// - Built-in equality checking
///
/// ## Basic Usage
/// ```dart
/// // 1. Define your state (immutable)
/// class CartState {
///   final List<CartItem> items;
///   final String? couponCode;
///   final bool isLoading;
///
///   const CartState({
///     this.items = const [],
///     this.couponCode,
///     this.isLoading = false,
///   });
///
///   CartState copyWith({
///     List<CartItem>? items,
///     String? couponCode,
///     bool? isLoading,
///   }) => CartState(
///     items: items ?? this.items,
///     couponCode: couponCode ?? this.couponCode,
///     isLoading: isLoading ?? this.isLoading,
///   );
///
///   @override
///   bool operator ==(Object other) =>
///       identical(this, other) ||
///       other is CartState &&
///           listEquals(items, other.items) &&
///           couponCode == other.couponCode &&
///           isLoading == other.isLoading;
///
///   @override
///   int get hashCode => Object.hash(items, couponCode, isLoading);
/// }
///
/// // 2. Create the service
/// class CartService extends StatefulService<CartState> {
///   CartService() : super(const CartState());
///
///   void addItem(CartItem item) {
///     state = state.copyWith(items: [...state.items, item]);
///   }
///
///   Future<void> applyCoupon(String code) async {
///     state = state.copyWith(isLoading: true);
///     try {
///       await _api.validateCoupon(code);
///       state = state.copyWith(couponCode: code, isLoading: false);
///     } catch (e) {
///       state = state.copyWith(isLoading: false);
///       rethrow;
///     }
///   }
/// }
/// ```
///
/// ## In Widgets (with selectors)
/// ```dart
/// class CartWidget extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final cart = useService<CartService>();
///
///     // Only rebuilds when items change
///     final items = useSelector(cart, (s) => s.items);
///
///     // Only rebuilds when isLoading changes
///     final isLoading = useSelector(cart, (s) => s.isLoading);
///
///     return isLoading
///         ? CircularProgressIndicator()
///         : ListView(children: items.map(ItemTile.new).toList());
///   }
/// }
/// ```
abstract class StatefulService<TState> extends Service {
  final _stateNotifier = _StateNotifier<TState>();

  /// Create a stateful service with initial state.
  StatefulService(TState initialState) {
    _stateNotifier._value = initialState;
  }

  /// Current state.
  TState get state => _stateNotifier.value;

  /// Update state. Only notifies if state changed (via ==).
  set state(TState newState) {
    if (_stateNotifier._value != newState) {
      _stateNotifier._value = newState;
      _stateNotifier.notifyListeners();
    }
  }

  /// Update state using a transformer function.
  ///
  /// ```dart
  /// updateState((s) => s.copyWith(isLoading: true));
  /// ```
  void updateState(TState Function(TState current) transformer) {
    state = transformer(state);
  }

  /// Listenable for the entire state.
  /// Use [select] for granular subscriptions.
  ValueListenable<TState> get stateListenable => _stateNotifier;

  /// Select a part of state for granular subscriptions.
  ///
  /// Returns a [ValueListenable] that only notifies when the
  /// selected value changes.
  ///
  /// ```dart
  /// final itemsListenable = cart.select((s) => s.items);
  /// final isLoadingListenable = cart.select((s) => s.isLoading);
  /// ```
  ValueListenable<R> select<R>(R Function(TState state) selector) {
    return _SelectorNotifier<TState, R>(_stateNotifier, selector);
  }

  @override
  Future<void> onDispose() async {
    _stateNotifier.dispose();
    await super.onDispose();
  }
}

/// Internal state notifier that exposes notifyListeners.
class _StateNotifier<T> extends ChangeNotifier implements ValueListenable<T> {
  late T _value;

  @override
  T get value => _value;

  @override
  void notifyListeners() => super.notifyListeners();
}

/// A listenable that selects part of a parent state.
/// Only notifies when the selected value changes.
class _SelectorNotifier<TState, TSelected> extends ChangeNotifier
    implements ValueListenable<TSelected> {
  final ValueListenable<TState> _source;
  final TSelected Function(TState) _selector;
  late TSelected _selectedValue;

  _SelectorNotifier(this._source, this._selector) {
    _selectedValue = _selector(_source.value);
    _source.addListener(_onSourceChange);
  }

  @override
  TSelected get value => _selectedValue;

  void _onSourceChange() {
    final newValue = _selector(_source.value);
    if (newValue != _selectedValue) {
      _selectedValue = newValue;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _source.removeListener(_onSourceChange);
    super.dispose();
  }
}

/// Extension for using selectors with hooks.
extension StatefulServiceHooks<TState> on StatefulService<TState> {
  /// Create a selector that can be used with useValueListenable.
  ///
  /// Note: For hooks, prefer the useSelector hook which handles
  /// disposal correctly.
  ValueListenable<R> selectListenable<R>(R Function(TState state) selector) {
    return select(selector);
  }
}
