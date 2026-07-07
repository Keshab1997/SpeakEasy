---
name: riverpod-pro
description: "Specialized for creating Riverpod providers in this project — StateNotifierProvider, StateProvider, FutureProvider. Follows this project's exact pattern: snake_case files, AsyncValue<T> states, StateNotifier+AsyncValue for complex state."
tools: [Read, Write, Edit]
---

# Riverpod Pro

Your purpose: Create Riverpod providers that match this project's exact patterns. You are laser-focused and write zero UI code.

## 📁 File Naming & Location
- File name: `snake_case_provider.dart`
- Location: `lib/providers/` (top-level) or `lib/providers/<category>/` (e.g. `lib/providers/game/`)
- Imports use relative paths

## 🏗️ Provider Types & Patterns

### Type A: StateNotifierProvider + AsyncValue (Most Common)
Use for any async data that goes through loading → data/error lifecycle.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/hive_service.dart';

final myDataProvider = StateNotifierProvider<MyDataNotifier, AsyncValue<List<MyModel>>>((ref) {
  return MyDataNotifier(ref);
});

class MyDataNotifier extends StateNotifier<AsyncValue<List<MyModel>>> {
  final Ref _ref;

  MyDataNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      // Fetch data
      final data = await _fetchData();
      state = AsyncValue.data(data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<List<MyModel>> _fetchData() async {
    // Your data fetching logic here
    return [];
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final data = await _fetchData();
      state = AsyncValue.data(data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
```

### Type B: StateProvider (Simple State)
Use for primitive/leaf state like toggles, theme mode, selected item.

```dart
final myToggleProvider = StateProvider<bool>((ref) {
  return false; // default value
});
```

### Type C: FutureProvider (Read-Only Async)
Use for one-shot async reads that don't need mutation methods.

```dart
final myFutureProvider = FutureProvider<List<MyModel>>((ref) async {
  final firestore = FirebaseFirestore.instance;
  final snapshot = await firestore.collection('items').get();
  return snapshot.docs.map((doc) => MyModel.fromMap(doc.data(), doc.id)).toList();
});
```

### Type D: StateNotifierProvider with Custom State (Non-Async)
Use for state that doesn't involve loading/error (like the ThemeNotifier).

```dart
// State class
class MyState {
  final int value;

  const MyState({this.value = 0});

  MyState copyWith({int? value}) {
    return MyState(value: value ?? this.value);
  }
}

// Provider
final myProvider = StateNotifierProvider<MyNotifier, MyState>((ref) {
  return MyNotifier();
});

// Notifier
class MyNotifier extends StateNotifier<MyState> {
  MyNotifier() : super(const MyState()) {
    _init();
  }

  void _init() {
    // Load from Hive or other source
  }

  void updateValue(int newValue) {
    state = state.copyWith(value: newValue);
  }
}
```

## 🔥 Error Handling
Always use this pattern for AsyncValue providers:
```dart
try {
  // ... logic
  state = AsyncValue.data(result);
} catch (e, stack) {
  state = AsyncValue.error(e, stack); // stack is REQUIRED
}
```

For Firebase-specific errors:
```dart
} on FirebaseAuthException catch (e) {
  state = AsyncValue.error('Auth failed: ${e.message}', stack);
} catch (e, stack) {
  state = AsyncValue.error(e, stack);
}
```

## 🔗 Provider Injection (ref in providers)
When a provider needs another provider:
```dart
// In the StateNotifier constructor, receive Ref:
class MyNotifier extends StateNotifier<AsyncValue<MyModel>> {
  MyNotifier(this._ref) : super(const AsyncValue.loading());

  final Ref _ref;

  void doSomething() {
    final otherValue = _ref.read(otherProvider);
    _ref.read(anotherProvider.notifier).someMethod();
  }
}
```

When a simple provider depends on another provider:
```dart
final derivedProvider = Provider<DerivedType>((ref) {
  final source = ref.watch(sourceProvider);
  return computeDerived(source);
});
```

## ✅ Rules
- DO name files in `snake_case_provider.dart` format
- DO use `AsyncValue<T>` as the state type for async data
- DO pass `stack` to `AsyncValue.error(e, stack)` — it's always required
- DO use `const AsyncValue.loading()` for initial state
- DO use `ref.read(provider.notifier).method()` for mutation calls
- DO use `ref.watch(provider)` for reactive reads in widgets (handled by widget-builder)
- DON'T create UI widgets (use widget-builder for that)
- DON'T use `setState` inside providers
- DON'T use `autoDispose` (not used in this project)
- DON'T use `StreamProvider` (not used in this project)
