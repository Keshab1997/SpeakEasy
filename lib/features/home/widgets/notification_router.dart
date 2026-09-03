import 'package:flutter/material.dart';
import '../../../models/notification_history_model.dart';
import '../../../routes/route_names.dart';
import '../../homework/screens/homework_screen.dart';
import '../../game/screens/game_home_screen.dart';

/// Routes notification action types to the appropriate screen navigation.
///
/// Grammar and vocabulary detail screens require model objects (GrammarChapter
/// / VocabularyChapter) which cannot be reconstructed from the notification's
/// actionPayload (a plain chapter number). Instead, we navigate to the generic
/// list screens where the user can choose the specific chapter.
class NotificationRouter {
  static void navigate(BuildContext context, NotificationHistoryItem item) {
    switch (item.actionType) {
      case 'grammar':
        _openGrammar(context);
        break;
      case 'vocabulary':
        _openVocabulary(context);
        break;
      case 'settings':
        Navigator.pushNamed(context, RouteNames.settings);
        break;
      case 'homework':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HomeworkScreen()),
        );
        break;
      case 'game':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GameHomeScreen()),
        );
        break;
      case 'battle_challenge':
        // Open the battle lobby — the GlobalBattleChallengeGate will show
        // the pending challenge sheet automatically.
        Navigator.pushNamed(context, RouteNames.battleLobby);
        break;
      case 'daily_quiz':
        Navigator.pushNamed(context, RouteNames.quiz);
        break;
      default:
        // Just mark as read, no navigation needed
        break;
    }
  }

  static void _openGrammar(BuildContext context) {
    // Navigate to the grammar list screen so the user can pick the chapter.
    // GrammarDetailScreen requires a full GrammarChapter object which we
    // cannot reconstruct from a plain chapter number in the payload.
    Navigator.pushNamed(context, RouteNames.grammarList);
  }

  static void _openVocabulary(BuildContext context) {
    // Navigate to the vocabulary list screen so the user can pick the chapter.
    // ChapterWordsScreen requires a full VocabularyChapter object which we
    // cannot reconstruct from a plain chapter number in the payload.
    Navigator.pushNamed(context, RouteNames.vocabulary);
  }
}
