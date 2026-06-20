import 'package:flutter/material.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/home/screens/main_navigation_screen.dart';
import '../features/grammar/screens/grammar_list_screen.dart';
import '../features/grammar/screens/tense_screen.dart';
import '../features/grammar/screens/article_screen.dart';
import '../features/grammar/screens/preposition_screen.dart';
import '../features/conversation/screens/daily_conversation_screen.dart';
import '../features/conversation/screens/restaurant_conversation_screen.dart';
import '../features/conversation/screens/interview_conversation_screen.dart';
import '../features/listening/screens/listening_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/translator/screens/banglish_translator_screen.dart';
import 'route_names.dart';

class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case RouteNames.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case RouteNames.signup:
        return MaterialPageRoute(builder: (_) => const SignUpScreen());
      case RouteNames.home:
        return MaterialPageRoute(builder: (_) => const MainNavigationScreen());
      case RouteNames.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case RouteNames.grammarList:
        return MaterialPageRoute(builder: (_) => const GrammarListScreen());
      case RouteNames.grammarTense:
        return MaterialPageRoute(builder: (_) => const TenseScreen());
      case RouteNames.grammarArticle:
        return MaterialPageRoute(builder: (_) => const ArticleScreen());
      case RouteNames.grammarPreposition:
        return MaterialPageRoute(builder: (_) => const PrepositionScreen());
      case RouteNames.conversationDaily:
        return MaterialPageRoute(builder: (_) => const DailyConversationScreen());
      case RouteNames.conversationRestaurant:
        return MaterialPageRoute(builder: (_) => const RestaurantConversationScreen());
      case RouteNames.conversationInterview:
        return MaterialPageRoute(builder: (_) => const InterviewConversationScreen());
      case RouteNames.listening:
        return MaterialPageRoute(builder: (_) => const ListeningScreen());
      case RouteNames.banglishTranslator:
        return MaterialPageRoute(builder: (_) => const BanglishTranslatorScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
