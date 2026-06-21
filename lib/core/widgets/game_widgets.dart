import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/game/timer_provider.dart';
import '../../providers/game/score_provider.dart';
import '../../providers/game/xp_provider.dart';
import '../../providers/game/coin_provider.dart';
import '../../providers/game/streak_provider.dart';
import '../../providers/game/achievement_provider.dart';
import '../../services/sound_service.dart';

// ── Question Card ──

class QuestionCard extends StatelessWidget {
  final String question;
  final String? tenseType;
  final String? difficulty;
  final Color? gradientStart;
  final Color? gradientEnd;

  const QuestionCard({
    super.key,
    required this.question,
    this.tenseType,
    this.difficulty,
    this.gradientStart,
    this.gradientEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart ?? AppColors.primary, gradientEnd ?? AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (gradientStart ?? AppColors.primary).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tenseType != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tenseType!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (difficulty != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _getDifficultyIcon(difficulty!),
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  difficulty!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getDifficultyIcon(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
      case 'beginner':
        return Icons.sentiment_satisfied;
      case 'medium':
      case 'intermediate':
        return Icons.sentiment_neutral;
      case 'hard':
      case 'advanced':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.help_outline;
    }
  }
}

// ── Option Button ──

class OptionButton extends StatelessWidget {
  final String option;
  final int index;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final VoidCallback onTap;
  final Color? color;

  const OptionButton({
    super.key,
    required this.option,
    required this.index,
    this.isSelected = false,
    this.isCorrect = false,
    this.isWrong = false,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = color ?? AppColors.primary;

    Color backgroundColor;
    Color borderColor;
    Color textColor;

    if (isCorrect) {
      backgroundColor = AppColors.success;
      borderColor = AppColors.success;
      textColor = Colors.white;
    } else if (isWrong) {
      backgroundColor = AppColors.error;
      borderColor = AppColors.error;
      textColor = Colors.white;
    } else if (isSelected) {
      backgroundColor = buttonColor.withOpacity(0.1);
      borderColor = buttonColor;
      textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    } else {
      backgroundColor = theme.cardColor;
      borderColor = AppColors.borderLight;
      textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    }

    return InkWell(
      onTap: isCorrect || isWrong ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected || isCorrect || isWrong ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCorrect || isWrong || isSelected ? buttonColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? buttonColor : (theme.brightness == Brightness.dark ? Colors.grey : Colors.grey),
                ),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    color: isCorrect || isWrong || isSelected ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: textColor,
                  fontSize: 15,
                ),
              ),
            ),
            if (isCorrect) ...[
              const Icon(Icons.check_circle, color: Colors.white, size: 24),
            ] else if (isWrong) ...[
              const Icon(Icons.cancel, color: Colors.white, size: 24),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Progress Bar ──

class ProgressBar extends StatelessWidget {
  final double progress;
  final Color? color;
  final Color? backgroundColor;
  final double height;

  const ProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.backgroundColor,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        backgroundColor: backgroundColor ?? (theme.brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]),
        color: color ?? AppColors.primary,
        minHeight: height,
      ),
    );
  }
}

// ── Timer Widget ──

class TimerWidget extends ConsumerWidget {
  final int remainingSeconds;
  final int totalSeconds;
  final bool showMilliseconds;
  final Color? normalColor;
  final Color? warningColor;

  const TimerWidget({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.showMilliseconds = false,
    this.normalColor,
    this.warningColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;
    final isWarning = remainingSeconds < 10;

    return Row(
      children: [
        Icon(
          Icons.timer,
          color: isWarning ? (warningColor ?? Colors.red) : (normalColor ?? AppColors.primary),
          size: 20,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isWarning ? Colors.red.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _formatTime(remainingSeconds),
            style: TextStyle(
              color: isWarning ? (warningColor ?? Colors.red) : (normalColor ?? AppColors.primary),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (showMilliseconds) {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

// ── Score Card ──

class ScoreCard extends StatelessWidget {
  final int score;
  final int? correctCount;
  final int? wrongCount;
  final bool showDetails;

  const ScoreCard({
    super.key,
    required this.score,
    this.correctCount,
    this.wrongCount,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (showDetails && correctCount != null && wrongCount != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 16),
                const SizedBox(width: 4),
                Text('$correctCount', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 16),
                Icon(Icons.cancel, color: AppColors.error, size: 16),
                const SizedBox(width: 4),
                Text('$wrongCount', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Life Indicator ──

class LifeIndicator extends StatelessWidget {
  final int lives;
  final int maxLives;
  final Color? activeColor;
  final Color? inactiveColor;

  const LifeIndicator({
    super.key,
    required this.lives,
    this.maxLives = 3,
    this.activeColor = Colors.red,
    this.inactiveColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLives, (index) {
        final isActive = index < lives;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            Icons.favorite,
            color: isActive ? activeColor : inactiveColor,
            size: 24,
          ),
        );
      }),
    );
  }
}

// ── Hint Button ──

class HintButton extends ConsumerWidget {
  final int hintsRemaining;
  final VoidCallback onTap;
  final Color? color;

  const HintButton({
    super.key,
    required this.hintsRemaining,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final buttonColor = color ?? Colors.amber;

    return InkWell(
      onTap: hintsRemaining > 0 ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: hintsRemaining > 0
              ? LinearGradient(colors: [buttonColor, buttonColor.withOpacity(0.8)])
              : null,
          color: hintsRemaining > 0 ? null : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb,
              color: hintsRemaining > 0 ? Colors.white : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '$hintsRemaining',
              style: TextStyle(
                color: hintsRemaining > 0 ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Result Card ──

class ResultCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const ResultCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Achievement Card ──

class AchievementCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isUnlocked;
  final DateTime? unlockDate;
  final int? stars;

  const AchievementCard({
    super.key,
    required this.title,
    required this.description,
    required this.isUnlocked,
    this.unlockDate,
    this.stars,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked ? AppColors.success.withOpacity(0.1) : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked ? AppColors.success : AppColors.borderLight,
          width: isUnlocked ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: isUnlocked
                  ? LinearGradient(colors: [Colors.amber, Colors.orange])
                  : null,
              color: isUnlocked ? null : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUnlocked ? Icons.emoji_events : Icons.lock,
              color: isUnlocked ? Colors.white : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isUnlocked ? null : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isUnlocked ? null : Colors.grey,
                  ),
                ),
                if (isUnlocked && unlockDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Unlocked: ${_formatDate(unlockDate!)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
                if (stars != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(3, (index) {
                      return Icon(
                        index < stars! ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 14,
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
          if (isUnlocked)
            const Icon(Icons.check_circle, color: AppColors.success, size: 28),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ── XP Bar ──

class XPBar extends StatelessWidget {
  final int currentXP;
  final int xpForNextLevel;
  final double progress;
  final bool showText;

  const XPBar({
    super.key,
    required this.currentXP,
    required this.xpForNextLevel,
    required this.progress,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showText) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level Progress',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                '$currentXP / $xpForNextLevel XP',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppColors.primary.withOpacity(0.1),
            color: AppColors.primary,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

// ── Coin Card ──

class CoinCard extends StatelessWidget {
  final int coins;
  final int? earned;
  final int? spent;
  final bool showChange;

  const CoinCard({
    super.key,
    required this.coins,
    this.earned,
    this.spent,
    this.showChange = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monetization_on, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Text(
                '$coins',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (showChange) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (earned != null && earned! > 0) ...[
                  Icon(Icons.arrow_upward, color: AppColors.success, size: 16),
                  const SizedBox(width: 4),
                  Text('+$earned', style: const TextStyle(color: AppColors.success, fontSize: 12)),
                ],
                if (spent != null && spent! > 0) ...[
                  Icon(Icons.arrow_downward, color: AppColors.error, size: 16),
                  const SizedBox(width: 4),
                  Text('-$spent', style: const TextStyle(color: AppColors.error, fontSize: 12)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Level Card ──

class LevelCard extends StatelessWidget {
  final int level;
  final String title;
  final int totalStars;
  final bool isUnlocked;
  final bool isCompleted;
  final VoidCallback? onTap;

  const LevelCard({
    super.key,
    required this.level,
    required this.title,
    required this.totalStars,
    this.isUnlocked = true,
    this.isCompleted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: isUnlocked ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isUnlocked
              ? LinearGradient(colors: _getLevelColors())
              : null,
          color: isUnlocked ? null : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: isUnlocked ? LinearGradient(colors: _getLevelColors()) : null,
                color: isUnlocked ? null : Colors.grey[400],
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getLevelIcon(),
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Level $level',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? null : Colors.grey[600],
                        ),
                      ),
                      if (isCompleted) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isUnlocked ? null : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(3, (index) {
                      return Icon(
                        index < (totalStars / 2).round() ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 16,
                      );
                    }),
                  ),
                ],
              ),
            ),
            if (isUnlocked)
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  List<Color> _getLevelColors() {
    return [AppColors.primary, AppColors.primary.withOpacity(0.8)];
  }

  IconData _getLevelIcon() {
    return Icons.quiz;
  }
}

// ── Mode Card ──

class ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final int? timeLimit;
  final int? lives;
  final int? hints;
  final VoidCallback? onTap;

  const ModeCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    this.timeLimit,
    this.lives,
    this.hints,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            if (timeLimit != null || lives != null || hints != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (timeLimit != null) ...[
                    const Icon(Icons.timer, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text('${timeLimit}s', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                  if (lives != null) ...[
                    if (timeLimit != null) const SizedBox(width: 12),
                    const Icon(Icons.favorite, color: Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Text('$lives', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                  if (hints != null) ...[
                    if (timeLimit != null || lives != null) const SizedBox(width: 12),
                    const Icon(Icons.lightbulb, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text('$hints', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Stat Card ──

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Streak Card ──

class StreakCard extends StatelessWidget {
  final int streak;
  final String emoji;
  final int flameCount;

  const StreakCard({
    super.key,
    required this.streak,
    required this.emoji,
    required this.flameCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                emoji * flameCount,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                '$streak days',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Current Streak',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 60,
            color: Colors.white30,
          ),
          Column(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Text(
                '$flameCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Flame Level',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Daily Challenge Card ──

class DailyChallengeCard extends StatelessWidget {
  final int questions;
  final String difficulty;
  final String? timeRemaining;
  final VoidCallback? onTap;

  const DailyChallengeCard({
    super.key,
    required this.questions,
    required this.difficulty,
    this.timeRemaining,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.today, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s Challenge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$questions questions • $difficulty',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  if (timeRemaining != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ends in $timeRemaining',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '+50% XP',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Boss Battle Card ──

class BossBattleCard extends StatelessWidget {
  final String bossName;
  final int questions;
  final String difficulty;
  final int? bestScore;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const BossBattleCard({
    super.key,
    required this.bossName,
    required this.questions,
    required this.difficulty,
    this.bestScore,
    this.isUnlocked = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isUnlocked ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: isUnlocked
              ? LinearGradient(colors: [Colors.red, Colors.deepOrange])
              : null,
          color: isUnlocked ? null : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: isUnlocked
                    ? LinearGradient(colors: [Colors.red, Colors.deepOrange])
                    : null,
                color: isUnlocked ? null : Colors.grey[400],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bossName,
                    style: TextStyle(
                      color: isUnlocked ? Colors.white : Colors.grey[600],
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$questions questions • $difficulty',
                    style: TextStyle(
                      color: isUnlocked ? Colors.white70 : Colors.grey[500],
                      fontSize: 13,
                    ),
                  ),
                  if (bestScore != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Best: $bestScore',
                          style: TextStyle(
                            color: isUnlocked ? Colors.white : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isUnlocked)
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}