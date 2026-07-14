import 'package:cloud_firestore/cloud_firestore.dart';

class AdminApiKey {
  final String id;
  final String name;
  final String key;
  final String baseUrl;
  final String model;
  final bool isActive;
  final int priority;
  final int usageCount;
  final int errorCount;
  final DateTime? lastErrorAt;
  final DateTime? lastUsedAt;
  final String addedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdminApiKey({
    required this.id,
    required this.name,
    required this.key,
    this.baseUrl = 'https://openrouter.ai/api/v1',
    this.model = 'gpt-4o-mini',
    this.isActive = true,
    this.priority = 1,
    this.usageCount = 0,
    this.errorCount = 0,
    this.lastErrorAt,
    this.lastUsedAt,
    this.addedBy = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminApiKey.fromMap(Map<String, dynamic> map, String docId) {
    return AdminApiKey(
      id: docId,
      name: map['name'] as String? ?? '',
      key: map['key'] as String? ?? '',
      baseUrl: map['baseUrl'] as String? ?? 'https://openrouter.ai/api/v1',
      model: map['model'] as String? ?? 'gpt-4o-mini',
      isActive: map['isActive'] as bool? ?? true,
      priority: map['priority'] as int? ?? 1,
      usageCount: map['usageCount'] as int? ?? 0,
      errorCount: map['errorCount'] as int? ?? 0,
      lastErrorAt: (map['lastErrorAt'] as Timestamp?)?.toDate(),
      lastUsedAt: (map['lastUsedAt'] as Timestamp?)?.toDate(),
      addedBy: map['addedBy'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'key': key,
      'baseUrl': baseUrl,
      'model': model,
      'isActive': isActive,
      'priority': priority,
      'usageCount': usageCount,
      'errorCount': errorCount,
      'lastErrorAt': lastErrorAt != null ? Timestamp.fromDate(lastErrorAt!) : null,
      'lastUsedAt': lastUsedAt != null ? Timestamp.fromDate(lastUsedAt!) : null,
      'addedBy': addedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AdminApiKey copyWith({
    String? id,
    String? name,
    String? key,
    String? baseUrl,
    String? model,
    bool? isActive,
    int? priority,
    int? usageCount,
    int? errorCount,
    DateTime? lastErrorAt,
    DateTime? lastUsedAt,
    String? addedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminApiKey(
      id: id ?? this.id,
      name: name ?? this.name,
      key: key ?? this.key,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      usageCount: usageCount ?? this.usageCount,
      errorCount: errorCount ?? this.errorCount,
      lastErrorAt: lastErrorAt ?? this.lastErrorAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      addedBy: addedBy ?? this.addedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'AdminApiKey(id: $id, name: $name, isActive: $isActive)';
}
