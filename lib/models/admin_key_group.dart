import 'admin_api_key.dart';

/// Per-provider group configuration stored in Firestore `admin_key_groups`
/// (docId = provider). Lets the admin enable/disable a whole provider at once
/// and rank providers so the fast group is tried before slower fallbacks.
class AdminKeyGroup {
  /// Provider id this group applies to: `google` | `openrouter` | `custom`.
  final String provider;

  final String name;
  final bool enabled;

  /// Lower = tried first. Keys are ordered by (group priority, key priority).
  final int priority;

  const AdminKeyGroup({
    required this.provider,
    required this.name,
    this.enabled = true,
    this.priority = 100,
  });

  factory AdminKeyGroup.fromMap(Map<String, dynamic> map, String provider) {
    return AdminKeyGroup(
      provider: provider,
      name: map['name'] as String? ?? AdminApiKey.providerName(provider),
      enabled: map['enabled'] as bool? ?? true,
      priority: map['priority'] as int? ?? 100,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'enabled': enabled,
      'priority': priority,
    };
  }

  AdminKeyGroup copyWith({String? name, bool? enabled, int? priority}) {
    return AdminKeyGroup(
      provider: provider,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
    );
  }
}
