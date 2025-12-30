import 'package:flutter/foundation.dart';
import 'service.dart';

/// A service with reactive state and selector support.
///
/// ```dart
/// class CartService extends StatefulService<CartState> {
///   CartService() : super(const CartState());
///
///   void addItem(CartItem item) {
///     state = state.copyWith(items: [...state.items, item]);
///   }
/// }
///
/// // In widget:
/// final items = useSelect<CartService, CartState, List<CartItem>>(
///   (s) => s.items,
/// );
/// ```
abstract class StatefulService<TState> extends Service {
  final _stateNotifier = _StateNotifier<TState>();

  StatefulService(TState initialState) {
    _stateNotifier._value = initialState;
  }

  TState get state => _stateNotifier.value;

  set state(TState newState) {
    if (_stateNotifier._value != newState) {
      _stateNotifier._value = newState;
      _stateNotifier.notifyListeners();
    }
  }

  void updateState(TState Function(TState current) transformer) {
    state = transformer(state);
  }

  ValueListenable<TState> get stateListenable => _stateNotifier;

  /// Select a part of state. Only notifies when selected value changes.
  ValueListenable<R> select<R>(R Function(TState state) selector) {
    return _SelectorNotifier<TState, R>(_stateNotifier, selector);
  }

  @override
  Future<void> onDispose() async {
    _stateNotifier.dispose();
    await super.onDispose();
  }
}

class _StateNotifier<T> extends ChangeNotifier implements ValueListenable<T> {
  late T _value;

  @override
  T get value => _value;

  @override
  void notifyListeners() => super.notifyListeners();
}

/// Selector that only notifies when selected value changes (deep equality).
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
    if (!_deepEquals(newValue, _selectedValue)) {
      _selectedValue = newValue;
      notifyListeners();
    }
  }

  bool _deepEquals(TSelected a, TSelected b) {
    if (identical(a, b)) return true;
    if (a == b) return true;
    if (a is List && b is List) return listEquals(a, b);
    if (a is Map && b is Map) return mapEquals(a, b);
    if (a is Set && b is Set) return setEquals(a, b);
    return false;
  }

  @override
  void dispose() {
    _source.removeListener(_onSourceChange);
    super.dispose();
  }
}
