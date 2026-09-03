import 'package:flutter/material.dart';

/// ⚡ Ready-made notification templates for the admin panel.
///
/// Why: the AI writer can occasionally return garbled / wrong wording.
/// Templates guarantee a correct, on-brand message in ONE tap — no AI needed.
/// The AI is still available for free-form ideas; if it fails, the app falls
/// back to the best-matching template here (never a broken message).
class NotificationTemplate {
  final String id;
  final String label;
  final IconData icon;
  final String title;
  final String body;
  final String aiHint;

  const NotificationTemplate({
    required this.id,
    required this.label,
    required this.icon,
    required this.title,
    required this.body,
    required this.aiHint,
  });

  String fillTitle(Map<String, String> vars) => _fill(title, vars);
  String fillBody(Map<String, String> vars) => _fill(body, vars);

  static String _fill(String text, Map<String, String> vars) {
    var out = text;
    vars.forEach((k, v) => out = out.replaceAll('{$k}', v));
    return out;
  }
}

/// All templates. `winner` is excluded from the quick-pick chip row (the
/// dashboard has a dedicated "Ajker Quiz Winner" button that fills in the
/// REAL leaderboard data), but it is used for AI matching & fallback.
const kNotificationTemplates = <NotificationTemplate>[
  NotificationTemplate(
    id: 'quiz',
    label: 'Daily Quiz',
    icon: Icons.quiz_rounded,
    title: '🧠 Ajker Quiz Ready? 😎',
    body: '10 ta fun question tomar jonno! 5 minute e complete koro, points komao 🔥',
    aiHint: 'daily quiz er announcement koro',
  ),
  NotificationTemplate(
    id: 'winner',
    label: 'Quiz Champion 🏆',
    icon: Icons.emoji_events_rounded,
    title: '🏆 {winner} — Ajker Champion! 🎉',
    body: '{winner} {score} points score koreche! Kal tomar turn — quiz khelo, naam likho! 💪🔥',
    aiHint: 'daily quiz winner er name + score announce koro',
  ),
  NotificationTemplate(
    id: 'streak',
    label: 'Streak',
    icon: Icons.local_fire_department_rounded,
    title: '🔥 Streak Bache, Moja Ache!',
    body: 'Mone rakho — 2 min ekta lesson korlei streak hero thakbe! Cholo, koro! 😍',
    aiHint: 'streak bachano r reminder',
  ),
  NotificationTemplate(
    id: 'lesson',
    label: 'New Lesson',
    icon: Icons.auto_stories_rounded,
    title: '✨ Notun Lesson Eseche!',
    body: 'Ekdom fresh content ready — boring lagbe na, promise! Test kore dekho 🎯',
    aiHint: 'notun lesson add hoyeche',
  ),
  NotificationTemplate(
    id: 'vocabulary',
    label: 'Vocabulary',
    icon: Icons.menu_book_rounded,
    title: '📖 Notun Word Shikho!',
    body: 'Din e 5 ta word — English er rasta soja hoye jabe! Aaj theke shuru koro ⚡',
    aiHint: 'vocabulary / word of the day',
  ),
  NotificationTemplate(
    id: 'battle',
    label: 'Battle Arena',
    icon: Icons.sports_kabaddi_rounded,
    title: '⚔️ 1v1 Duel Dake!',
    body: 'Bandhu ke challenge koro, trophies jeeto — Battle Arena te jao! 🏆',
    aiHint: 'battle arena 1v1 challenge',
  ),
  NotificationTemplate(
    id: 'mock',
    label: 'Mock Test',
    icon: Icons.assignment_rounded,
    title: '📝 Mock Test Practice Time!',
    body: 'Real exam er moto sobuj — mock test kore confidence barao 💯',
    aiHint: 'mock test practice',
  ),
  NotificationTemplate(
    id: 'practice',
    label: 'Practice Alert',
    icon: Icons.timer_rounded,
    title: '⏰ Practice Reminder!',
    body: '5 min practice koro — daily hero hoye jao! Streak ta miss koro na 🔥',
    aiHint: 'daily practice reminder',
  ),
  NotificationTemplate(
    id: 'streak_saver',
    label: 'Night Streak Saver',
    icon: Icons.bedtime_rounded,
    title: '🌙 Rate Bache Streak!',
    body: 'Ghumayar age 1 minute — streak er jonno ekta jhap! Cholo 😴🔥',
    aiHint: 'raat e streak bachano',
  ),
  NotificationTemplate(
    id: 'festive',
    label: 'Festive',
    icon: Icons.celebration_rounded,
    title: '🎉 Shubho Utshob!',
    body: 'Utshob er anande English practice miss koro na — choto ekta lesson! 🎊',
    aiHint: 'eid / puja / new year / festive wishing',
  ),
  NotificationTemplate(
    id: 'update',
    label: 'App Update',
    icon: Icons.campaign_rounded,
    title: '📢 Notun Update Eseche!',
    body: 'App e notun kichu ache! Quickly dekhe felo — surprise pawa jabe 🎁',
    aiHint: 'app update news',
  ),
  NotificationTemplate(
    id: 'thanks',
    label: 'Thank You',
    icon: Icons.favorite_rounded,
    title: '💖 Thank You!',
    body: 'Tomader valobasha-i amader cholay — practice continue rakho! 🙏',
    aiHint: 'users ke thanks',
  ),
];

/// Picks the template whose topic best matches [idea] (keyword based).
/// Guarantees a sensible fallback when the AI writer fails.
NotificationTemplate bestTemplateForIdea(String idea) {
  final q = idea.toLowerCase();
  bool has(List<String> keys) => keys.any(q.contains);

  if (has(const ['winner', 'champion', 'top score', 'topper', 'leaderboard'])) {
    return _byId('winner');
  }
  if (has(const ['quiz', 'wkj', 'daily quiz'])) return _byId('quiz');
  if (has(const ['streak', 'fire', 'series', 'roj niye', 'daily practice'])) {
    return _byId('streak');
  }
  if (has(const ['lesson', 'new chapter', 'notun chapter'])) return _byId('lesson');
  if (has(const ['vocab', 'word', 'word of the day'])) return _byId('vocabulary');
  if (has(const ['battle', 'duel', 'challenge', 'arena'])) return _byId('battle');
  if (has(const ['mock', 'exam', 'test'])) return _byId('mock');
  if (has(const ['practice', 'reminder', 'remind'])) return _byId('practice');
  if (has(const ['eid', 'puja', 'diwali', 'new year', 'festive', 'utsav'])) {
    return _byId('festive');
  }
  if (has(const ['night', 'rat', 'ghum'])) return _byId('streak_saver');
  if (has(const ['thank', 'thanks', 'love'])) return _byId('thanks');
  return _byId('update');
}

NotificationTemplate _byId(String id) =>
    kNotificationTemplates.firstWhere((t) => t.id == id, orElse: () => kNotificationTemplates.last);

/// YYYY-MM-DD date key used by `daily_quiz_leaderboard/{date}/...` and by the
/// quiz provider — must match exactly.
String todayQuizDateKey() {
  final now = DateTime.now();
  return '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

/// Builds the "Quiz Champion" announcement from REAL leaderboard data.
/// Returns (title, body) — both length-safe (≤55 / ≤180 chars).
({String title, String body}) buildQuizWinnerMessage({
  required String dateKey,
  required String winnerName,
  required int score,
  int? correctCount,
  String? secondName,
  int? secondScore,
}) {
  final name = winnerName.trim();
  final shortName = name.length > 20 ? '${name.substring(0, 20)}...' : name;

  var title = '🏆 $shortName — Ajker Champion! 🎉';
  if (title.length > 55) title = '${title.substring(0, 52)}...';

  var body = '$shortName $score points score koreche!';
  if (correctCount != null && correctCount > 0) {
    body += ' ($correctCount ta correct)';
  }
  final second = secondName?.trim();
  if (second != null && second.isNotEmpty) {
    body += ' $second ${secondScore ?? 0} points — ektu holei pichhe!';
  }
  body += ' Kal tomar turn — quiz khelo, naam likho! 💪🔥';
  if (body.length > 180) body = '${body.substring(0, 177)}...';
  return (title: title, body: body);
}

/// "2026-09-03" → "3 Sep" (used inside the winner message).
String prettyDateKey(String dateKey) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final parts = dateKey.split('-');
  if (parts.length != 3) return dateKey;
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (m == null || d == null || m < 1 || m > 12) return dateKey;
  return '$d ${months[m - 1]}';
}
