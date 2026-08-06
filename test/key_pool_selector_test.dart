import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_spoken_english_app/models/admin_api_key.dart';
import 'package:flutter_spoken_english_app/models/admin_key_group.dart';
import 'package:flutter_spoken_english_app/services/key_pool_selector.dart';

AdminApiKey key({
  required String id,
  String provider = 'openrouter',
  int priority = 1,
  bool isActive = true,
}) {
  return AdminApiKey(
    id: id,
    name: id,
    key: 'sk-$id',
    provider: provider,
    priority: priority,
    isActive: isActive,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

AdminKeyGroup keyGroup(String provider,
    {bool enabled = true, int priority = 100}) {
  return AdminKeyGroup(
    provider: provider,
    name: provider,
    enabled: enabled,
    priority: priority,
  );
}

KeyPoolSelector selector({
  List<AdminApiKey> keys = const [],
  Map<String, AdminKeyGroup> groups = const {},
  List<KeyCooldown> cooldowns = const [],
}) {
  return KeyPoolSelector(keys: keys, groups: groups, cooldowns: cooldowns);
}

void main() {
  group('getHealthyKeys', () {
    test('empty pool returns empty list', () {
      expect(selector().getHealthyKeys(), isEmpty);
    });

    test('excludes inactive keys', () {
      final s = selector(keys: [
        key(id: 'a', isActive: true),
        key(id: 'b', isActive: false),
      ]);
      expect(s.getHealthyKeys().map((k) => k.id), ['a']);
    });

    test('excludes keys in a disabled group', () {
      final s = selector(
        keys: [key(id: 'a'), key(id: 'b', provider: 'google')],
        groups: {
          'openrouter': keyGroup('openrouter'),
          'google': keyGroup('google', enabled: false),
        },
      );
      expect(s.getHealthyKeys().map((k) => k.id), ['a']);
    });

    test('excludes keys on active cooldown, keeps expired ones', () {
      final future = DateTime.now().add(const Duration(minutes: 5));
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      final s = selector(
        keys: [key(id: 'a'), key(id: 'b'), key(id: 'c')],
        cooldowns: [
          KeyCooldown(keyId: 'a', until: future),
          KeyCooldown(keyId: 'b', until: past),
        ],
      );
      expect(s.getHealthyKeys().map((k) => k.id), ['b', 'c']);
    });

    test('sorts by group priority then key priority', () {
      final s = selector(
        keys: [
          key(id: 'slow1', provider: 'custom', priority: 1),
          key(id: 'slow2', provider: 'custom', priority: 2),
          key(id: 'fast2', provider: 'google', priority: 2),
          key(id: 'fast1', provider: 'google', priority: 1),
        ],
        groups: {
          'google': keyGroup('google', priority: 10),
          'custom': keyGroup('custom', priority: 100),
        },
      );
      expect(s.getHealthyKeys().map((k) => k.id),
          ['fast1', 'fast2', 'slow1', 'slow2']);
    });

    test('group without a config doc defaults to priority 100', () {
      final s = selector(keys: [
        key(id: 'a', provider: 'google', priority: 5),
        key(id: 'b', provider: 'custom', priority: 1),
      ], groups: {
        'google': keyGroup('google', priority: 10),
      });
      // 'custom' has no group doc → 100, so 'google' (10) comes first.
      expect(s.getHealthyKeys().map((k) => k.id), ['a', 'b']);
    });
  });

  group('getTopPriorityPool', () {
    test('returns only the highest-priority group keys', () {
      final s = selector(
        keys: [
          key(id: 'fast', provider: 'google'),
          key(id: 'slow', provider: 'custom'),
        ],
        groups: {
          'google': keyGroup('google', priority: 10),
          'custom': keyGroup('custom', priority: 100),
        },
      );
      expect(s.getTopPriorityPool().map((k) => k.id), ['fast']);
    });

    test('empty pool returns empty list', () {
      expect(selector().getTopPriorityPool(), isEmpty);
    });
  });

  group('select (round-robin)', () {
    test('empty pool returns null key and index 0', () {
      final (k, next) = selector().select(3);
      expect(k, isNull);
      expect(next, 0);
    });

    test('single key is always returned and index wraps', () {
      final s = selector(keys: [key(id: 'only')]);
      final (k1, i1) = s.select(0);
      final (k2, i2) = s.select(i1);
      expect(k1?.id, 'only');
      expect(k2?.id, 'only');
      expect(i1, 0);
      expect(i2, 0);
    });

    test('rotates across top group keys', () {
      final s = selector(keys: [
        key(id: 'a', priority: 1),
        key(id: 'b', priority: 2),
        key(id: 'c', priority: 3),
      ]);
      final (ka, ia) = s.select(0);
      final (kb, ib) = s.select(ia);
      final (kc, ic) = s.select(ib);
      final (ka2, _) = s.select(ic);
      expect(ka?.id, 'a');
      expect(kb?.id, 'b');
      expect(kc?.id, 'c');
      expect(ka2?.id, 'a');
    });

    test('wraps a stale index back to the top group', () {
      final s = selector(keys: [key(id: 'a'), key(id: 'b')]);
      final (k, _) = s.select(5);
      expect(k?.id, 'a');
    });

    test('falls back to the next group when the top group is on cooldown', () {
      final s = selector(
        keys: [
          key(id: 'fast', provider: 'google'),
          key(id: 'slow', provider: 'custom'),
        ],
        groups: {
          'google': keyGroup('google', priority: 10),
          'custom': keyGroup('custom', priority: 100),
        },
        cooldowns: [
          KeyCooldown(
              keyId: 'fast',
              until: DateTime.now().add(const Duration(minutes: 5))),
        ],
      );
      final (k, _) = s.select(0);
      expect(k?.id, 'slow');
    });

    test('returns null when every key is on cooldown', () {
      final s = selector(
        keys: [key(id: 'a')],
        cooldowns: [
          KeyCooldown(
              keyId: 'a',
              until: DateTime.now().add(const Duration(minutes: 5))),
        ],
      );
      final (k, _) = s.select(0);
      expect(k, isNull);
    });
  });
}
