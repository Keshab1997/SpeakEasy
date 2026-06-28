import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/progress_repository.dart';
import '../repositories/statistics_repository.dart';
import '../repositories/achievement_repository.dart';

/// Service to sync game data between local Hive storage and Firebase Firestore
/// Ensures each user has isolated data based on their Firebase UID
class GameDataSyncService {
  final ProgressRepository _progressRepository;
  final StatisticsRepository _statisticsRepository;
  final AchievementRepository _achievementRepository;
  final FirebaseAuth _auth;

  GameDataSyncService({
    ProgressRepository? progressRepository,
    StatisticsRepository? statisticsRepository,
    AchievementRepository? achievementRepository,
    FirebaseAuth? auth,
  })  : _progressRepository = progressRepository ?? ProgressRepository(),
        _statisticsRepository = statisticsRepository ?? StatisticsRepository(),
        _achievementRepository = achievementRepository ?? AchievementRepository(),
        _auth = auth ?? FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Load user's game data from Firebase to local Hive on login
  Future<void> loadUserDataFromFirebase() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      // Load progress
      await _progressRepository.syncProgressFromFirestoreToHive(userId);

      // Load levels
      await _progressRepository.syncLevelsFromFirestoreToHive(userId);

      // Load statistics
      await _statisticsRepository.syncFromFirestoreToHive(userId);

      // Load achievements
      await _achievementRepository.syncFromFirestoreToHive(userId);

      print('✅ Game data loaded from Firebase for user: $userId');
    } catch (e) {
      print('❌ Error loading game data from Firebase: $e');
      // If no data exists in Firebase, that's okay - new user
    }
  }

  /// Save current game data to Firebase (call after game completion)
  Future<void> saveUserDataToFirebase() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      // Save progress
      final progress = _progressRepository.getProgress();
      if (progress != null) {
        final updatedProgress = progress.copyWith(userId: userId);
        await _progressRepository.uploadProgressToFirestore(updatedProgress);
      }

      // Save statistics meta (boss wins, daily wins, time played)
      await _statisticsRepository.uploadMetaToFirestore(userId);

      // Save achievements
      final achievements = _achievementRepository.getCachedAchievements();
      if (achievements.isNotEmpty) {
        await _achievementRepository.batchUploadToFirestore(userId, achievements);
      }

      // Save levels (was previously missing — levels were only saved to Hive!)
      final levels = _progressRepository.getLevels();
      if (levels.isNotEmpty) {
        await _progressRepository.batchUploadLevelsToFirestore(userId, levels);
      }

      print('✅ Game data saved to Firebase for user: $userId');
    } catch (e) {
      print('❌ Error saving game data to Firebase: $e');
    }
  }

  /// Sync all local data to Firebase after a game (called by ResultScreen).
  Future<void> syncAfterGame() async {
    await saveUserDataToFirebase();
  }

  /// Sync on app startup (if user is logged in)
  Future<void> syncOnAppStartup() async {
    if (currentUserId != null) {
      await loadUserDataFromFirebase();
    }
  }
}
