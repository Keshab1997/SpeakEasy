// Central registry that keeps the tense "id" used in code/navigation in sync
// with the `tenseType` value actually stored inside the question JSON files.
//
// Why this exists
// ---------------
// Screens and rules pass around a snake_case id (e.g. `present_indefinite`),
// but the JSON questions store their `tenseType` as the human readable label
// (e.g. `Present Indefinite`). Earlier the two never matched, so filtering by
// tense returned "No questions available". This file is the single source of
// truth that maps between the two representations.

class TenseConstants {
  TenseConstants._();

  /// Ordered list of all 12 tenses as `{id, name}` pairs.
  /// `id`   → stable key used in code (snake_case)
  /// `name` → the `tenseType` string stored inside the question JSON
  static const List<TenseInfo> tenses = [
    // Present
    TenseInfo(id: 'present_indefinite', name: 'Present Indefinite', group: TenseGroup.present),
    TenseInfo(id: 'present_continuous', name: 'Present Continuous', group: TenseGroup.present),
    TenseInfo(id: 'present_perfect', name: 'Present Perfect', group: TenseGroup.present),
    TenseInfo(id: 'present_perfect_continuous', name: 'Present Perfect Continuous', group: TenseGroup.present),
    // Past
    TenseInfo(id: 'past_indefinite', name: 'Past Indefinite', group: TenseGroup.past),
    TenseInfo(id: 'past_continuous', name: 'Past Continuous', group: TenseGroup.past),
    TenseInfo(id: 'past_perfect', name: 'Past Perfect', group: TenseGroup.past),
    TenseInfo(id: 'past_perfect_continuous', name: 'Past Perfect Continuous', group: TenseGroup.past),
    // Future
    TenseInfo(id: 'future_indefinite', name: 'Future Indefinite', group: TenseGroup.future),
    TenseInfo(id: 'future_continuous', name: 'Future Continuous', group: TenseGroup.future),
    TenseInfo(id: 'future_perfect', name: 'Future Perfect', group: TenseGroup.future),
    TenseInfo(id: 'future_perfect_continuous', name: 'Future Perfect Continuous', group: TenseGroup.future),
  ];

  /// Maps a snake_case id → JSON `tenseType` label.
  /// Returns the id unchanged when no mapping is found so unknown keys are
  /// still usable as a raw filter.
  static String nameFromId(String id) {
    final match = tenses.firstWhere(
      (t) => t.id == id,
      orElse: () => TenseInfo(id: id, name: id, group: TenseGroup.present),
    );
    return match.name;
  }

  /// Maps a JSON `tenseType` label → snake_case id.
  static String idFromName(String name) {
    final match = tenses.firstWhere(
      (t) => t.name == name,
      orElse: () => TenseInfo(id: name, name: name, group: TenseGroup.present),
    );
    return match.id;
  }

  /// Per-tense rules JSON asset path.
  static String rulesPathForId(String id) {
    switch (id) {
      case 'present_indefinite':
        return 'assets/json/game/rules/01_present_indefinite_rules.json';
      case 'present_continuous':
        return 'assets/json/game/rules/02_present_continuous_rules.json';
      case 'present_perfect':
        return 'assets/json/game/rules/03_present_perfect_rules.json';
      case 'present_perfect_continuous':
        return 'assets/json/game/rules/04_present_perfect_continuous_rules.json';
      case 'past_indefinite':
        return 'assets/json/game/rules/05_past_indefinite_rules.json';
      case 'past_continuous':
        return 'assets/json/game/rules/06_past_continuous_rules.json';
      case 'past_perfect':
        return 'assets/json/game/rules/07_past_perfect_rules.json';
      case 'past_perfect_continuous':
        return 'assets/json/game/rules/08_past_perfect_continuous_rules.json';
      case 'future_indefinite':
        return 'assets/json/game/rules/09_future_indefinite_rules.json';
      case 'future_continuous':
        return 'assets/json/game/rules/10_future_continuous_rules.json';
      case 'future_perfect':
        return 'assets/json/game/rules/11_future_perfect_rules.json';
      case 'future_perfect_continuous':
        return 'assets/json/game/rules/12_future_perfect_continuous_rules.json';
      case 'comparison':
        return 'assets/json/game/rules/13_comparison_rules.json';
      case 'special_usage':
        return 'assets/json/game/rules/14_special_usage_rules.json';
      default:
        return '';
    }
  }
}

enum TenseGroup { present, past, future }

class TenseInfo {
  final String id;
  final String name;
  final TenseGroup group;

  const TenseInfo({
    required this.id,
    required this.name,
    required this.group,
  });
}
