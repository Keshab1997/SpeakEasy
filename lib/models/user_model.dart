import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String photoUrl;
  final DateTime joinedAt;
  final int streak;
  final String currentLevel; // 'Beginner', 'Intermediate', 'Advanced'
  final String role; // 'student', 'admin'
  final String referralCode;
  final String? referredBy;
  final int referralCount;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl = '',
    required this.joinedAt,
    this.streak = 0,
    this.currentLevel = 'Beginner',
    this.role = 'student',
    this.referralCode = '',
    this.referredBy,
    this.referralCount = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      id: docId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      streak: map['streak'] ?? 0,
      currentLevel: map['currentLevel'] ?? 'Beginner',
      role: map['role'] ?? 'student',
      referralCode: map['referralCode'] ?? '',
      referredBy: map['referredBy'] as String?,
      referralCount: map['referralCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'streak': streak,
      'currentLevel': currentLevel,
      'role': role,
      'referralCode': referralCode,
      if (referredBy != null) 'referredBy': referredBy,
      'referralCount': referralCount,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
    DateTime? joinedAt,
    int? streak,
    String? currentLevel,
    String? role,
    String? referralCode,
    String? referredBy,
    int? referralCount,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      joinedAt: joinedAt ?? this.joinedAt,
      streak: streak ?? this.streak,
      currentLevel: currentLevel ?? this.currentLevel,
      role: role ?? this.role,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      referralCount: referralCount ?? this.referralCount,
    );
  }
}
