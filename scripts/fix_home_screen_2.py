import re

with open('lib/features/home/screens/home_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = """      // Sync the streak to the main progress provider (Firestore 'progress' collection)
      await ref.read(progressProvider.notifier).syncStreak(newStreak);

      // 3. Record today as active (updates lastActiveDate, totalActiveDays)
      await streakNotifier.recordActiveDay();

      // 4. Handle streak freeze — if streak was reset to 1 and we have a freeze, restore it
      if (newStreak == 1) {
        final progress = ref.read(progressProvider).asData?.value;
        final oldStreak = progress?.streakDays ?? 0;
        if (oldStreak > 1) {
          final hadFreeze = await HiveService.useStreakFreeze();
          if (hadFreeze) {
            // Restore the streak from before the reset
            for (int i = 1; i < oldStreak; i++) {
              await streakNotifier.incrementStreak();
            }
          }
        }
      }"""

replacement = """      // 3. Record today as active (updates lastActiveDate, totalActiveDays)
      await streakNotifier.recordActiveDay();

      // 4. Handle streak freeze — if streak was reset to 1 and we have a freeze, restore it
      if (newStreak == 1) {
        final progress = ref.read(progressProvider).asData?.value;
        final oldStreak = progress?.streakDays ?? 0;
        if (oldStreak > 1) {
          final hadFreeze = await HiveService.useStreakFreeze();
          if (hadFreeze) {
            // Restore the streak from before the reset
            for (int i = 1; i < oldStreak; i++) {
              await streakNotifier.incrementStreak();
            }
          }
        }
      }
      
      // 4.5 Sync the final streak back to the main progress provider (Firestore 'progress' collection)
      final finalStreak = ref.read(streakProvider.notifier).state.currentStreak;
      // if it wasn't refreshed yet use the one from service directly or 
      await ref.read(progressProvider.notifier).syncStreak(ref.read(streakServiceProvider).getCurrentStreak());"""

if target in content:
    content = content.replace(target, replacement)
    with open('lib/features/home/screens/home_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Success")
else:
    print("Target not found")
