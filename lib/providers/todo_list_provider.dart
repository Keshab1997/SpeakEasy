import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo_item.dart';
import '../models/grammar_chapter_model.dart';
import '../models/vocabulary_chapter_model.dart';
import '../services/hive_service.dart';
import 'auth_provider.dart';
import 'grammar_provider.dart';
import 'chapter_vocabulary_provider.dart';

class StudyPlanState {
  final List<TodoItem> items;
  final int completedCount;
  final int totalCount;
  final String? nextSuggestedId;
  final String? nextVocabId;
  final String? nextGrammarId;
  final List<String> skippedIds;

  const StudyPlanState({
    this.items = const [],
    this.completedCount = 0,
    this.totalCount = 0,
    this.nextSuggestedId,
    this.nextVocabId,
    this.nextGrammarId,
    this.skippedIds = const [],
  });
}

class TodoListNotifier extends StateNotifier<StudyPlanState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  TodoListNotifier() : super(const StudyPlanState());

  void init(String? userId, List<GrammarChapter> grammarChapters,
      List<VocabularyChapter> vocabChapters) {
    // Re-init if userId changed (login/logout) or first time
    if (_userId == userId && state.items.isNotEmpty) return;
    _userId = userId;
    _loadFromFirestore(grammarChapters, vocabChapters);
  }

  Future<void> _loadFromFirestore(List<GrammarChapter> grammar,
      List<VocabularyChapter> vocab) async {
    final defaultList = _buildDefaultList(grammar, vocab);

    // Always read local Hive first; it contains full status objects.
    final saved = HiveService.getTodoItems();
    final hiveMap = <String, Map<String, dynamic>>{};
    for (final s in saved) {
      hiveMap[s['id'] as String] = s;
    }

    // Firestore only stores completed timestamps, and may be partial.
    final Map<String, String> firestoreCompleted = {};
    bool firestoreDocExists = false;

    if (_userId != null) {
      try {
        final doc =
            await _firestore.collection('study_plan').doc(_userId!).get();
        if (doc.exists && doc.data() != null) {
          firestoreDocExists = true;
          final data = doc.data()!;
          final completed =
              data['completedItems'] as Map<String, dynamic>? ?? {};
          for (final entry in completed.entries) {
            firestoreCompleted[entry.key] = entry.value as String;
          }
        }
      } catch (_) {}
    }

    // Merge rules:
    // - If Firestore has a timestamp for an item => use Firestore (completed).
    // - Else if Hive has status=completed for that item => keep Hive completion.
    // - Else => keep default pending.
    final items = defaultList.map((item) {
      final fireTs = firestoreCompleted[item.id];
      if (fireTs != null) {
        return item.copyWith(
          status: TodoStatus.completed,
          completedAt: DateTime.parse(fireTs),
        );
      }

      final h = hiveMap[item.id];
      if (h != null && h['status'] == 'completed') {
        return TodoItem.fromJson(h);
      }

      return item;
    }).toList();

    // Build a merged completed map (for self-heal to Firestore).
    // This ensures permanent correctness even if Firestore was partial.
    final mergedCompletedMap = <String, String>{};
    for (final item in items) {
      if (item.status == TodoStatus.completed && item.completedAt != null) {
        mergedCompletedMap[item.id] = item.completedAt!.toIso8601String();
      }
    }

    // Cache merged state to Hive (prevents overwrite-to-pending bugs).
    await HiveService.saveTodoItems(items.map((i) => i.toJson()).toList());

    // If logged in and Firestore doc is missing/partial, sync merged completion to cloud.
    if (_userId != null) {
      if (!firestoreDocExists) {
        _syncHiveToFirestore(items);
      } else if (mergedCompletedMap.isNotEmpty) {
        try {
          await _firestore.collection('study_plan').doc(_userId!).set(
            {'completedItems': mergedCompletedMap},
            SetOptions(merge: true),
          );
        } catch (_) {}
      }
    }

    _emit(items);
  }

  Future<void> _syncHiveToFirestore(List<TodoItem> items) async {
    if (_userId == null) return;
    final completedMap = <String, String>{};
    for (final item in items) {
      if (item.status == TodoStatus.completed && item.completedAt != null) {
        completedMap[item.id] = item.completedAt!.toIso8601String();
      }
    }
    if (completedMap.isEmpty) return;
    try {
      await _firestore.collection('study_plan').doc(_userId!).set(
        {'completedItems': completedMap},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  List<TodoItem> _buildDefaultList(
      List<GrammarChapter> grammar, List<VocabularyChapter> vocab) {
    final list = <TodoItem>[];
    final levels = ['Beginner', 'Intermediate', 'Advanced'];
    for (final level in levels) {
      for (final ch in grammar.where((g) => g.level == level)) {
        list.add(TodoItem(
          id: 'grammar_${ch.chapter}',
          type: 'grammar',
          chapterNumber: ch.chapter,
          title: ch.title,
          level: ch.level,
        ));
      }
    }
    for (final level in levels) {
      for (final ch in vocab.where((v) => v.level == level)) {
        list.add(TodoItem(
          id: 'vocab_${ch.chapter}',
          type: 'vocabulary',
          chapterNumber: ch.chapter,
          title: ch.title,
          level: ch.level,
        ));
      }
    }
    return list;
  }

  void _emit(List<TodoItem> items) {
    final completed =
        items.where((i) => i.status == TodoStatus.completed).length;
    final skipped = _findSkipped(items);
    final next = _findNext(items);
    final nextVocab = _findNextByType(items, 'vocabulary');
    final nextGrammar = _findNextByType(items, 'grammar');

    state = StudyPlanState(
      items: items,
      completedCount: completed,
      totalCount: items.length,
      nextSuggestedId: next,
      nextVocabId: nextVocab,
      nextGrammarId: nextGrammar,
      skippedIds: skipped,
    );
  }

  String? _findNextByType(List<TodoItem> itms, String type) {
    for (final item in itms) {
      if (item.type == type && item.status == TodoStatus.pending) return item.id;
    }
    return null;
  }

  List<String> _findSkipped(List<TodoItem> itms) {
    final skipped = <String>{};
    final types = ['grammar', 'vocabulary'];
    for (final type in types) {
      final typed = itms.where((i) => i.type == type).toList();
      for (int i = 0; i < typed.length; i++) {
        if (typed[i].status == TodoStatus.pending &&
            typed.skip(i + 1).any((later) => later.status == TodoStatus.completed)) {
          skipped.add(typed[i].id);
        }
      }
    }
    return skipped.toList();
  }

  String? _findNext(List<TodoItem> itms) {
    for (final item in itms) {
      if (item.status == TodoStatus.pending) return item.id;
    }
    return null;
  }

  Future<void> toggleComplete(String id) async {
    final idx = state.items.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    final item = state.items[idx];
    final now = DateTime.now();
    final isCompleting = item.status != TodoStatus.completed;
    final updated = isCompleting
        ? item.copyWith(status: TodoStatus.completed, completedAt: now)
        : item.copyWith(status: TodoStatus.pending, completedAt: null);
    final newItems = [...state.items];
    newItems[idx] = updated;

    // Save to Hive
    await HiveService.updateTodoItem(updated.toJson());

    // Save to Firestore
    if (_userId != null) {
      try {
        final docRef = _firestore.collection('study_plan').doc(_userId);
        if (isCompleting) {
          await docRef.set({
            'completedItems': {id: now.toIso8601String()}
          }, SetOptions(merge: true));
        } else {
          // Remove from completed
          await _firestore.runTransaction((tx) async {
            final snap = await tx.get(docRef);
            if (snap.exists) {
              final data = Map<String, dynamic>.from(snap.data()!);
              final completed =
                  Map<String, dynamic>.from(data['completedItems'] as Map? ?? {});
              completed.remove(id);
              data['completedItems'] = completed;
              tx.set(docRef, data);
            }
          });
        }
      } catch (_) {
        // Offline — Hive already saved as fallback
      }
    }

    _emit(newItems);
  }

  String? pickRandomForWeeklyTest() {
    final completed =
        state.items.where((i) => i.status == TodoStatus.completed).toList();
    if (completed.isEmpty) return null;
    completed.shuffle();
    return completed.first.id;
  }
}

final todoListProvider =
    StateNotifierProvider<TodoListNotifier, StudyPlanState>((ref) {
  final notifier = TodoListNotifier();

  void loadData() {
    final authAsync = ref.read(authProvider);
    final userId = authAsync.asData?.value?.id;
    final grammarAsync = ref.read(allGrammarChaptersProvider);
    final vocabAsync = ref.read(allChaptersProvider);
    final grammarData = grammarAsync.asData?.value ?? [];
    final vocabData = vocabAsync.asData?.value ?? [];
    if (grammarData.isNotEmpty || vocabData.isNotEmpty) {
      notifier.init(userId, grammarData, vocabData);
    }
  }

  Future.microtask(loadData);

  // Re-try when auth, grammar, or vocab data loads/changes
  ref.listen(authProvider, (_, __) => Future.microtask(loadData));
  ref.listen(allGrammarChaptersProvider, (_, __) => Future.microtask(loadData));
  ref.listen(allChaptersProvider, (_, __) => Future.microtask(loadData));

  return notifier;
});
