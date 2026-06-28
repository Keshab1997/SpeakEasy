import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String message;
  final String category; // 'Bug Report', 'Feature Request', 'Complaint', 'Suggestion', 'Other'
  final String status; // 'pending', 'resolved'
  final String? adminReply;
  final DateTime createdAt;
  final DateTime? updatedAt;

  FeedbackModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.message,
    required this.category,
    this.status = 'pending',
    this.adminReply,
    required this.createdAt,
    this.updatedAt,
  });

  factory FeedbackModel.fromMap(Map<String, dynamic> map, String docId) {
    return FeedbackModel(
      id: docId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      message: map['message'] ?? '',
      category: map['category'] ?? 'Other',
      status: map['status'] ?? 'pending',
      adminReply: map['adminReply'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'message': message,
      'category': category,
      'status': status,
      'adminReply': adminReply,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  FeedbackModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? message,
    String? category,
    String? status,
    String? adminReply,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeedbackModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      message: message ?? this.message,
      category: category ?? this.category,
      status: status ?? this.status,
      adminReply: adminReply ?? this.adminReply,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
