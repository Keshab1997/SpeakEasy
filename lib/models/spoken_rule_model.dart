class SpokenRule {
  final String point;
  final String bangla;

  SpokenRule({required this.point, required this.bangla});

  factory SpokenRule.fromJson(Map<String, dynamic> json) {
    return SpokenRule(
      point: json['point'] ?? '',
      bangla: json['bangla'] ?? '',
    );
  }
}

class SpokenRuleCategory {
  final String id;
  final String title;
  final String banglaTitle;
  final String icon;
  final String color;
  final String explanation;
  final List<SpokenRule> rules;

  SpokenRuleCategory({
    required this.id,
    required this.title,
    required this.banglaTitle,
    required this.icon,
    required this.color,
    required this.explanation,
    required this.rules,
  });

  factory SpokenRuleCategory.fromJson(Map<String, dynamic> json) {
    return SpokenRuleCategory(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      banglaTitle: json['banglaTitle'] ?? '',
      icon: json['icon'] ?? '',
      color: json['color'] ?? '#2563EB',
      explanation: json['explanation'] ?? '',
      rules: (json['rules'] as List<dynamic>?)
              ?.map((r) => SpokenRule.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SpokenRulesData {
  final String id;
  final String title;
  final String banglaTitle;
  final String color;
  final String icon;
  final String shortDescription;
  final List<SpokenRuleCategory> categories;

  SpokenRulesData({
    required this.id,
    required this.title,
    required this.banglaTitle,
    required this.color,
    required this.icon,
    required this.shortDescription,
    required this.categories,
  });

  factory SpokenRulesData.fromJson(Map<String, dynamic> json) {
    return SpokenRulesData(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      banglaTitle: json['banglaTitle'] ?? '',
      color: json['color'] ?? '#2563EB',
      icon: json['icon'] ?? '',
      shortDescription: json['shortDescription'] ?? '',
      categories: (json['categories'] as List<dynamic>?)
              ?.map((c) => SpokenRuleCategory.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}