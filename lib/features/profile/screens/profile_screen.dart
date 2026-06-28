import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/progress_provider.dart';
import '../../../providers/todo_list_provider.dart';
import '../../../providers/game/statistics_provider.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../providers/game/streak_provider.dart';
import '../../../services/hive_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../feedback/screens/feedback_screen.dart';
import '../../feedback/screens/my_feedback_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(progressProvider.notifier).fetchProgress();
      ref.read(statisticsProvider.notifier).refresh();
      ref.read(xpProvider.notifier).refresh();
      ref.read(coinProvider.notifier).refresh();
    });
  }

  void _handleSignOut() async {
    try {
      await ref.read(authProvider.notifier).signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    if (_isUploadingPhoto) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
              title: const Text('Take Photo'),
              subtitle: const Text('Use camera to capture a new profile photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select an existing image from your device'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    await _pickAndUploadPhoto(source);
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final pickedImage = await ImagePicker().pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1000,
        maxHeight: 1000,
      );

      if (pickedImage == null) return;

      setState(() => _isUploadingPhoto = true);
      final bytes = await pickedImage.readAsBytes();
      await ref.read(authProvider.notifier).updateProfilePhoto(
            bytes: bytes,
            fileName: pickedImage.name,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile photo: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final progressAsync = ref.watch(progressProvider);
    final studyState = ref.watch(todoListProvider);
    final statisticsState = ref.watch(statisticsProvider);
    final xpState = ref.watch(xpProvider);
    final coinState = ref.watch(coinProvider);
    final streakState = ref.watch(streakProvider);

    final user = authState.asData?.value;
    final progress = progressAsync.asData?.value;

    final name = user?.name ?? 'User';
    final email = user?.email ?? 'user@email.com';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    // ── Real streak: prefer game streak (live), fall back to Firebase progress ──
    final int currentStreak = streakState.currentStreak > 0
        ? streakState.currentStreak
        : (progress?.streakDays ?? 0);

    // ── Lessons completed from Study Plan (todo list) ──
    final int lessonsCompleted = studyState.completedCount;

    // ── Vocabulary learned: count of unique read chapters from Hive ──
    final int vocabLearned = HiveService.getReadChapters().length;

    // ── XP: live from XpNotifier (reads ProgressRepository / Hive) ──
    final int currentXP = xpState.currentXP;

    // ── Coins: live from CoinNotifier (reads ProgressRepository / Hive) ──
    final int currentCoins = coinState.currentCoins;

    // ── Game stats from StatisticsProvider ──
    final int totalGames = statisticsState.totalGamesPlayed;
    final double accuracy = statisticsState.overallAccuracy;
    final int bestStreak = statisticsState.bestStreak;

    final String streakValue = '$currentStreak';
    final String lessonsDoneValue = '$lessonsCompleted';
    final String vocabCountValue = '$vocabLearned';
    final String xpValue = '$currentXP';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit profile clicked'), behavior: SnackBarBehavior.floating),
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      InkWell(
                        onTap: _showPhotoSourceSheet,
                        customBorder: const CircleBorder(),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 4),
                          ),
                          child: _buildProfileAvatar(
                            photoUrl: user?.photoUrl ?? '',
                            initial: initial,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Material(
                          color: AppColors.secondary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _showPhotoSourceSheet,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(7),
                              child: _isUploadingPhoto
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: theme.textTheme.headlineLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(email, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Learning Journey Stats', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.8,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildMetricTile(theme, '$streakValue Days', 'Current Streak', '🔥', Colors.deepOrange),
                      _buildMetricTile(theme, '$lessonsDoneValue Lessons', 'Completed', '📚', Colors.blue),
                      _buildMetricTile(theme, '$vocabCountValue Chapters', 'Vocab Read', '📖', Colors.teal),
                      _buildMetricTile(theme, '$xpValue XP', 'Total XP', '✨', Colors.amber),
                      _buildMetricTile(theme, '$currentCoins', 'Total Coins', '🪙', Colors.orange),
                      _buildMetricTile(theme, '$totalGames Games', 'Games Played', '🎮', Colors.indigo),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Accuracy bar
                  Row(
                    children: [
                      const Text('🎯 ', style: TextStyle(fontSize: 14)),
                      Text(
                        'Accuracy: ${(accuracy * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      if (bestStreak > 0)
                        Row(
                          children: [
                            const Text('🏆 ', style: TextStyle(fontSize: 12)),
                            Text(
                              'Best Streak: $bestStreak',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                    title: const Text('Clear All Cache'),
                    subtitle: const Text('Reset local stored data'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear cache?'),
                          content: const Text(
                            'This will clear all locally stored learning/settings/cache data. Your Firestore data will reload again.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'Clear',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirmed != true) return;

                      try {
                        await HiveService.clearAllCaches();
                        await ref.read(progressProvider.notifier).fetchProgress();

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cache cleared successfully'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to clear cache'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_rounded, color: Colors.purple),
                    title: const Text('Settings'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history_rounded, color: Colors.teal),
                    title: const Text('My Feedback'),
                    subtitle: const Text('View your submitted feedback and replies'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyFeedbackScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.feedback_rounded, color: Colors.amber),
                    title: const Text('Send Feedback'),
                    subtitle: const Text('Help us improve the app'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    title: const Text('Sign Out'),
                    onTap: _handleSignOut,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar({required String photoUrl, required String initial}) {
    if (photoUrl.trim().isEmpty) {
      return _buildInitialAvatar(initial);
    }

    return CachedNetworkImage(
      imageUrl: photoUrl,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: 50,
        backgroundColor: AppColors.primary,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => const CircleAvatar(
        radius: 50,
        backgroundColor: AppColors.primary,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
      errorWidget: (context, url, error) => _buildInitialAvatar(initial),
    );
  }

  Widget _buildInitialAvatar(String initial) {
    return CircleAvatar(
      radius: 50,
      backgroundColor: AppColors.primary,
      child: Text(
        initial,
        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildMetricTile(ThemeData theme, String value, String label, String iconEmoji, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(iconEmoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}


