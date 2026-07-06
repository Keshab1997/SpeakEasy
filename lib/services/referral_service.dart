import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'coin_service.dart';
import '../repositories/progress_repository.dart';
import '../repositories/statistics_repository.dart';

class ReferralService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int _referralRewardCoins = 50;
  static const int _newUserRewardCoins = 25;

  /// Generate a unique 6-character referral code from user UID
  static String generateReferralCode(String uid) {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    // Take first 3 chars of uid + 3 random chars
    final prefix = uid.substring(0, min(3, uid.length)).toUpperCase();
    final suffix = List.generate(3, (_) => chars[random.nextInt(chars.length)]).join();
    return '$prefix$suffix';
  }

  /// Apply a referral code for a new user
  /// Returns true if referral was successfully applied
  Future<bool> applyReferralCode(String code, String newUserId) async {
    if (code.isEmpty) return false;

    final normalizedCode = code.trim().toUpperCase();

    try {
      // Find the user who owns this referral code
      final querySnapshot = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: normalizedCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return false;

      final referrerDoc = querySnapshot.docs.first;
      final referrerId = referrerDoc.id;

      // Cannot refer yourself
      if (referrerId == newUserId) return false;

      // Reward the referrer
      await _rewardUser(referrerId, _referralRewardCoins);

      // Reward the new user
      await _rewardUser(newUserId, _newUserRewardCoins);

      // Update referral count for referrer
      await _firestore.collection('users').doc(referrerId).set(
        {
          'referralCount': FieldValue.increment(1),
          'referredUsers': FieldValue.arrayUnion([newUserId]),
        },
        SetOptions(merge: true),
      );

      return true;
    } catch (e) {
      // Silently fail - referral is optional
      return false;
    }
  }

  /// Get referral count for a user
  Future<int> getReferralCount(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return (doc.data()!['referralCount'] ?? 0) as int;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Get list of referred user IDs
  Future<List<String>> getReferredUsers(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final users = doc.data()!['referredUsers'];
        if (users is List) {
          return users.cast<String>();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Reward a user with coins
  Future<void> _rewardUser(String uid, int coins) async {
    try {
      final progressRepo = ProgressRepository();
      final statsRepo = StatisticsRepository();
      final coinService = CoinService(
        progressRepository: progressRepo,
        statisticsRepository: statsRepo,
      );
      await coinService.addCoins(coins);
    } catch (_) {
      // Silently fail
    }
  }

  /// Validate referral code format
  static bool isValidReferralCode(String code) {
    if (code.isEmpty) return false;
    final normalized = code.trim().toUpperCase();
    // Must be 4-10 alphanumeric characters
    final regex = RegExp(r'^[A-Z0-9]{4,10}$');
    return regex.hasMatch(normalized);
  }
}
