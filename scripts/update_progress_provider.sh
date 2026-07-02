cat << 'INNER' > lib/providers/progress_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/progress_model.dart';

final progressProvider = StateNotifierProvider<ProgressNotifier, AsyncValue<ProgressModel?>>((ref) {
  return ProgressNotifier();
});

class ProgressNotifier extends StateNotifier<AsyncValue<ProgressModel?>> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ProgressNotifier() : super(const AsyncValue.data(null));

  Future<void> fetchProgress() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('progress').doc(user.uid).get();
      if (doc.exists) {
        state = AsyncValue.data(ProgressModel.fromMap(doc.data()!, user.uid));
      } else {
        state = AsyncValue.data(ProgressModel(userId: user.uid, lastActiveDate: DateTime.now()));
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> syncStreak(int streak) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final currentProgress = state.asData?.value;
      if (currentProgress?.streakDays == streak) return;

      await _firestore.collection('progress').doc(user.uid).set({
        'streakDays': streak,
        'lastActiveDate': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));

      await fetchProgress();
    } catch (_) {}
  }

  Future<void> updateStreak() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final currentProgress = state.asData?.value;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int newStreak = currentProgress?.streakDays ?? 0;
      if (currentProgress != null) {
        final lastActive = DateTime(
          currentProgress.lastActiveDate.year,
          currentProgress.lastActiveDate.month,
          currentProgress.lastActiveDate.day,
        );
        final diff = today.difference(lastActive).inDays;
        
        // 🐛 FIX: Proper calendar day logic
        if (diff >= 2) {
          newStreak = 1;
        } else if (diff == 1) {
          newStreak = newStreak == 0 ? 1 : newStreak + 1;
        } else if (diff == 0 && newStreak == 0) {
          newStreak = 1;
        }
      } else {
        newStreak = 1;
      }

      await _firestore.collection('progress').doc(user.uid).set({
        'streakDays': newStreak,
        'lastActiveDate': Timestamp.fromDate(now),
        'lessonsCompleted': currentProgress?.lessonsCompleted ?? 0,
        'quizScore': currentProgress?.quizScore ?? 0,
        'speakingScore': currentProgress?.speakingScore ?? 0,
        'studyTime': currentProgress?.studyTime ?? 0,
        'completedLessonIds': currentProgress?.completedLessonIds ?? [],
      }, SetOptions(merge: true)); // Use merge to prevent overwriting missing fields

      await fetchProgress();
    } catch (_) {}
  }

  Future<void> addStudyTime(int minutes) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final current = state.asData?.value;
      final totalTime = (current?.studyTime ?? 0) + minutes;
      await _firestore.collection('progress').doc(user.uid).update({
        'studyTime': totalTime,
      });
      await fetchProgress();
    } catch (_) {}
  }
}
INNER
