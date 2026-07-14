import 'package:cloud_firestore/cloud_firestore.dart';

class ApiErrorLog {
  final String? id;
  final String keyId;
  final String keyName;
  final String userId;
  final String feature;
  final String errorType;
  final int statusCode;
  final String message;
  final bool retried;
  final bool retrySuccess;
  final DateTime timestamp;

  const ApiErrorLog({
    this.id,
    required this.keyId,
    required this.keyName,
    required this.userId,
    required this.feature,
    required this.errorType,
    required this.statusCode,
    required this.message,
    this.retried = false,
    this.retrySuccess = false,
    required this.timestamp,
  });

  factory ApiErrorLog.fromMap(Map<String, dynamic> map, [String? docId]) {
    return ApiErrorLog(
      id: docId,
      keyId: map['keyId'] as String? ?? '',
      keyName: map['keyName'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      feature: map['feature'] as String? ?? '',
      errorType: map['errorType'] as String? ?? '',
      statusCode: map['statusCode'] as int? ?? 0,
      message: map['message'] as String? ?? '',
      retried: map['retried'] as bool? ?? false,
      retrySuccess: map['retrySuccess'] as bool? ?? false,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'keyId': keyId,
      'keyName': keyName,
      'userId': userId,
      'feature': feature,
      'errorType': errorType,
      'statusCode': statusCode,
      'message': message,
      'retried': retried,
      'retrySuccess': retrySuccess,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  @override
  String toString() => 'ApiErrorLog(id: $id, type: $errorType, key: $keyName)';
}
