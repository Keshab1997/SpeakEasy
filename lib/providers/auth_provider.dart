import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../models/game/game_progress_model.dart';
import '../services/hive_service.dart';
import '../services/game_data_sync_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    // Synchronous check first (handles edge case where authStateChanges never fires)
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      state = const AsyncValue.data(null);
    } else {
      fetchUserData(currentUser.uid);
    }

    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        state = const AsyncValue.data(null);
      } else {
        await fetchUserData(firebaseUser.uid);
      }
    });
  }

  Future<void> fetchUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        var userModel = UserModel.fromMap(doc.data()!, uid);
        final authPhotoUrl = _auth.currentUser?.photoURL ?? '';

        if (userModel.photoUrl.isEmpty && authPhotoUrl.isNotEmpty) {
          userModel = userModel.copyWith(photoUrl: authPhotoUrl);
          await _firestore.collection('users').doc(uid).set(
            {'photoUrl': authPhotoUrl},
            SetOptions(merge: true),
          );
        }

        state = AsyncValue.data(userModel);
        
        // Load user's game data from Firebase after successful auth
        final syncService = GameDataSyncService();
        await syncService.loadUserDataFromFirebase();
        
        debugPrint('✅ User data loaded from Firebase: ${userModel.name}');
      } else {
        // Fallback or if document doesn't exist yet
        state = AsyncValue.data(UserModel(
          id: uid,
          name: _auth.currentUser?.displayName ?? 'User',
          email: _auth.currentUser?.email ?? '',
          photoUrl: _auth.currentUser?.photoURL ?? '',
          joinedAt: DateTime.now(),
        ));
        
        // Load game data for new user too
        final syncService = GameDataSyncService();
        await syncService.loadUserDataFromFirebase();
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final firebaseUser = credential.user;
      if (firebaseUser != null) {
        // Update Firebase display name
        await firebaseUser.updateDisplayName(name);

        final newUser = UserModel(
          id: firebaseUser.uid,
          name: name,
          email: email,
          photoUrl: '',
          joinedAt: DateTime.now(),
          streak: 1, // Start with 1 day streak
          currentLevel: 'Beginner',
        );

        // Store user in Firestore
        await _firestore.collection('users').doc(firebaseUser.uid).set(newUser.toMap());
        
        // 🔥 Create initial game progress for new user
        final initialProgress = GameProgressModel(
          userId: firebaseUser.uid,
          currentLevel: 1,
          currentXP: 0,
          totalCoins: 0,
          streak: 1, // Start with 1-day streak!
          unlockedModes: const [],
          weeklyStreak: 1,
          longestStreak: 1,
          missedDays: 0,
          totalActiveDays: 1,
          lastActiveDate: DateTime.now(),
        );
        
        // Upload to Firebase
        await _firestore
            .collection('game_progress')
            .doc(firebaseUser.uid)
            .set(initialProgress.toFirestoreMap());
        
        debugPrint('✅ Initial game progress created for new user: $name');
        
        state = AsyncValue.data(newUser);
      } else {
        throw Exception("User registration failed.");
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        await fetchUserData(credential.user!.uid);
      } else {
        throw Exception("User login failed.");
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // Check if user document already exists in Firestore
        final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
        UserModel userModel;
        
        if (!doc.exists) {
          // Create new user profile if first time Google login
          userModel = UserModel(
            id: firebaseUser.uid,
            name: firebaseUser.displayName ?? 'Google User',
            email: firebaseUser.email ?? '',
            photoUrl: firebaseUser.photoURL ?? '',
            joinedAt: DateTime.now(),
            streak: 1,
            currentLevel: 'Beginner',
          );
          await _firestore.collection('users').doc(firebaseUser.uid).set(userModel.toMap());
          
          // 🔥 Create initial game progress for new Google user
          final initialProgress = GameProgressModel(
            userId: firebaseUser.uid,
            currentLevel: 1,
            currentXP: 0,
            totalCoins: 0,
            streak: 1, // Start with 1-day streak!
            unlockedModes: const [],
            weeklyStreak: 1,
            longestStreak: 1,
            missedDays: 0,
            totalActiveDays: 1,
            lastActiveDate: DateTime.now(),
          );
          
          // Upload to Firebase
          await _firestore
              .collection('game_progress')
              .doc(firebaseUser.uid)
              .set(initialProgress.toFirestoreMap());
          
          debugPrint('✅ Initial game progress created for new Google user: ${userModel.name}');
        } else {
          userModel = UserModel.fromMap(doc.data()!, firebaseUser.uid);
        }

        state = AsyncValue.data(userModel);
      } else {
        throw Exception("Google Sign-in failed.");
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> updateProfilePhoto({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw Exception('No signed-in user found.');
    }

    try {
      final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage
          .ref()
          .child('profile_photos')
          .child(firebaseUser.uid)
          .child('${timestamp}_$safeFileName');

      final metadata = SettableMetadata(contentType: _contentTypeForFile(safeFileName));
      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      await firebaseUser.updatePhotoURL(downloadUrl);
      await _firestore.collection('users').doc(firebaseUser.uid).set(
        {'photoUrl': downloadUrl},
        SetOptions(merge: true),
      );

      final currentUser = state.asData?.value;
      if (currentUser != null) {
        state = AsyncValue.data(currentUser.copyWith(photoUrl: downloadUrl));
      } else {
        await fetchUserData(firebaseUser.uid);
      }

      return downloadUrl;
    } catch (e, stack) {
      final currentUser = state.asData?.value;
      if (currentUser != null) {
        state = AsyncValue.data(currentUser);
      } else {
        state = AsyncValue.error(e, stack);
      }
      rethrow;
    }
  }

  String _contentTypeForFile(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      // Clear all local Hive data before signing out
      await HiveService.clearAllCaches();
      
      // Sign out from Firebase and Google
      await _auth.signOut();
      await _googleSignIn.signOut();
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Permanently delete the user's account and all associated data.
  /// Returns a descriptive error string on failure, or null on success.
  Future<String?> deleteAccount() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return 'No signed-in user found.';

    final uid = firebaseUser.uid;

    try {
      state = const AsyncValue.loading();

      // 1. Delete Firestore documents
      try {
        await _firestore.collection('users').doc(uid).delete();
      } catch (_) {
        // ignore if doc doesn't exist
      }
      try {
        await _firestore.collection('game_progress').doc(uid).delete();
      } catch (_) {}
      try {
        await _firestore.collection('game_statistics').doc(uid).delete();
      } catch (_) {}
      try {
        await _firestore.collection('progress').doc(uid).delete();
      } catch (_) {}
      try {
        await _firestore.collection('study_plan').doc(uid).delete();
      } catch (_) {}

      // 2. Delete profile photo from Storage
      try {
        await _storage.ref().child('profile_photos').child(uid).listAll().then(
          (result) => Future.wait(result.items.map((ref) => ref.delete())),
        );
      } catch (_) {}

      // 3. Delete Firebase Auth account
      await firebaseUser.delete();

      // 4. Clear all local Hive data
      await HiveService.clearAllCaches();

      state = const AsyncValue.data(null);
      return null; // success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        state = AsyncValue.data(UserModel(
          id: uid,
          name: firebaseUser.displayName ?? 'User',
          email: firebaseUser.email ?? '',
          joinedAt: DateTime.now(),
        ));
        return 'requires-recent-login';
      }
      state = AsyncValue.data(UserModel(
        id: uid,
        name: firebaseUser.displayName ?? 'User',
        email: firebaseUser.email ?? '',
        joinedAt: DateTime.now(),
      ));
      return 'Failed to delete account: ${e.message}';
    } catch (e) {
      state = AsyncValue.data(UserModel(
        id: uid,
        name: firebaseUser.displayName ?? 'User',
        email: firebaseUser.email ?? '',
        joinedAt: DateTime.now(),
      ));
      return 'Failed to delete account: $e';
    }
  }
}
