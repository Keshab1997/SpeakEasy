import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_spoken_english_app/models/admin_key_group.dart';

void main() {
  group('AdminKeyGroup', () {
    test('fromMap parses cooldown fields', () {
      final g = AdminKeyGroup.fromMap({
        'name': 'OpenRouter',
        'enabled': true,
        'priority': 5,
        'rateLimitCooldownSeconds': 120,
        'serverErrorCooldownSeconds': 300,
        'defaultCooldownSeconds': 45,
      }, 'openrouter');
      expect(g.provider, 'openrouter');
      expect(g.name, 'OpenRouter');
      expect(g.enabled, true);
      expect(g.priority, 5);
      expect(g.rateLimitCooldownSeconds, 120);
      expect(g.serverErrorCooldownSeconds, 300);
      expect(g.defaultCooldownSeconds, 45);
    });

    test('fromMap uses defaults when fields missing', () {
      final g = AdminKeyGroup.fromMap({}, 'custom');
      expect(g.name, 'Custom');
      expect(g.enabled, true);
      expect(g.priority, 100);
      expect(g.rateLimitCooldownSeconds, isNull);
      expect(g.serverErrorCooldownSeconds, isNull);
      expect(g.defaultCooldownSeconds, isNull);
    });

    test('toMap round-trips cooldown fields', () {
      const g = AdminKeyGroup(
        provider: 'google',
        name: 'Google',
        enabled: false,
        priority: 10,
        rateLimitCooldownSeconds: 90,
        serverErrorCooldownSeconds: 240,
        defaultCooldownSeconds: 20,
      );
      final restored = AdminKeyGroup.fromMap(g.toMap(), 'google');
      expect(restored.rateLimitCooldownSeconds, 90);
      expect(restored.serverErrorCooldownSeconds, 240);
      expect(restored.defaultCooldownSeconds, 20);
      expect(restored.enabled, false);
      expect(restored.priority, 10);
    });

    test('toMap omits null cooldown fields', () {
      const g = AdminKeyGroup(provider: 'openrouter', name: 'OpenRouter');
      final map = g.toMap();
      expect(map.containsKey('rateLimitCooldownSeconds'), isFalse);
      expect(map.containsKey('serverErrorCooldownSeconds'), isFalse);
      expect(map.containsKey('defaultCooldownSeconds'), isFalse);
    });

    test('copyWith updates cooldown fields only when provided', () {
      const g = AdminKeyGroup(provider: 'openrouter', name: 'OpenRouter');
      final updated = g.copyWith(rateLimitCooldownSeconds: 75);
      expect(updated.rateLimitCooldownSeconds, 75);
      expect(updated.serverErrorCooldownSeconds, isNull);
      expect(updated.defaultCooldownSeconds, isNull);
      expect(updated.priority, 100);
    });
  });
}
