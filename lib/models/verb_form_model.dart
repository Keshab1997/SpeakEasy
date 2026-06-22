import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VerbForm {
  final String v1;
  final String v2;
  final String v3;
  final String v4;
  final String v5;
  final String bangla;
  final String meaning;

  const VerbForm({
    required this.v1,
    required this.v2,
    required this.v3,
    required this.v4,
    required this.v5,
    required this.bangla,
    required this.meaning,
  });

  factory VerbForm.fromJson(Map<String, dynamic> j) => VerbForm(
        v1: j['v1'] ?? '',
        v2: j['v2'] ?? '',
        v3: j['v3'] ?? '',
        v4: j['v4'] ?? '',
        v5: j['v5'] ?? '',
        bangla: j['bangla'] ?? '',
        meaning: j['meaning'] ?? '',
      );
}

class VerbFormCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  List<VerbForm> verbs;

  VerbFormCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.verbs = const [],
  });

  factory VerbFormCategory.fromJson(Map<String, dynamic> j) {
    final iconMap = <String, IconData>{
      'star': Icons.star_rounded,
      'bolt': Icons.bolt_rounded,
      'chat': Icons.chat_rounded,
      'directions_run': Icons.directions_run_rounded,
      'schedule': Icons.schedule_rounded,
      'handyman': Icons.handyman_rounded,
      'psychology': Icons.psychology_rounded,
      'favorite': Icons.favorite_rounded,
      'work': Icons.work_rounded,
      'school': Icons.school_rounded,
      'restaurant': Icons.restaurant_rounded,
      'sports': Icons.sports_soccer_rounded,
      'cloud': Icons.cloud_rounded,
      'flight': Icons.flight_rounded,
      'health': Icons.favorite_border_rounded,
      'paid': Icons.paid_rounded,
      'computer': Icons.computer_rounded,
      'cleaning': Icons.cleaning_services_rounded,
    };
    return VerbFormCategory(
      id: j['id'] ?? '',
      title: j['title'] ?? '',
      subtitle: j['subtitle'] ?? '',
      icon: iconMap[j['icon']] ?? Icons.book_rounded,
      color: _parseColor(j['color'] as String? ?? '#2563EB'),
    );
  }

  static Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  static Future<List<VerbFormCategory>> loadAll() async {
    final raw = await rootBundle.loadString('assets/json/verb_forms/categories.json');
    final list = jsonDecode(raw) as List<dynamic>;

    final categories = list
        .map((e) => VerbFormCategory.fromJson(e as Map<String, dynamic>))
        .toList();

    for (final cat in categories) {
      try {
        final verbsRaw =
            await rootBundle.loadString('assets/json/verb_forms/${cat.id}.json');
        final verbsList = jsonDecode(verbsRaw) as List<dynamic>;
        cat.verbs = verbsList
            .map((v) => VerbForm.fromJson(v as Map<String, dynamic>))
            .toList();
      } catch (_) {
        cat.verbs = [];
      }
    }

    return categories;
  }
}
