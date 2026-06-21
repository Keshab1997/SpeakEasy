import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/game/xp_provider.dart';
import '../../../../providers/game/coin_provider.dart';
import '../../../../providers/game/sound_provider.dart';
import './game_home_screen.dart';

class ResultScreen extends ConsumerWidget {
  final int score;
  final int correctAnswers;
  final int wrongAnswers;
  final int earnedXP;
  final int earnedCoins;

  const ResultScreen({
    super.key,
    required this.score,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.earnedXP,
    required this.earnedCoins,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = correctAnswers + wrongAnswers;
    final accuracy = total > 0 ? correctAnswers / total : 0.0;
    final rating = _getRating(accuracy);
    final isPerfect = accuracy >= 1.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: AppColors.primaryGradient, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  isPerfect ? 'Perfect!' : 'Game Over',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(rating, style: const TextStyle(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 40),

                // Score Circle
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5)],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$score', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const Text('Score', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Stats Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ResultStat(label: 'Correct', value: '$correctAnswers', icon: Icons.check_circle, color: AppColors.success),
                    _ResultStat(label: 'Wrong', value: '$wrongAnswers', icon: Icons.cancel, color: AppColors.error),
                    _ResultStat(label: 'Accuracy', value: '${(accuracy * 100).toStringAsFixed(1)}%', icon: Icons.pie_chart, color: AppColors.primary),
                  ],
                ),

                const SizedBox(height: 30),

                // Rewards
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _RewardItem(icon: Icons.star, label: 'XP', value: '+$earnedXP', color: Colors.amber),
                      _RewardItem(icon: Icons.monetization_on, label: 'Coins', value: '+$earnedCoins', color: Colors.amberAccent),
                    ],
                  ),
                ),

                const Spacer(),

                // Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(xpProvider.notifier).addXP(earnedXP);
                      ref.read(coinProvider.notifier).addCoins(earnedCoins);
                      ref.read(soundServiceProvider).playLevelUp();
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GameHomeScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRating(double accuracy) {
    if (accuracy >= 1.0) return 'Perfect! 🌟';
    if (accuracy >= 0.9) return 'Excellent! 🏆';
    if (accuracy >= 0.8) return 'Great Job! 👏';
    if (accuracy >= 0.7) return 'Good! 👍';
    if (accuracy >= 0.5) return 'Not Bad! 💪';
    return 'Keep Practicing! 📚';
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ResultStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _RewardItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _RewardItem({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}