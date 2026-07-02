import re

with open('lib/features/home/screens/home_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = """      // 2. Check if streak should increment (new day) or reset (missed >48h)
      final newStreak = await streakNotifier.checkAndUpdateStreak();

      // 3. Record today as active (updates lastActiveDate, totalActiveDays)
      await streakNotifier.recordActiveDay();"""

replacement = """      // 2. Check if streak should increment (new day) or reset (missed >48h)
      final newStreak = await streakNotifier.checkAndUpdateStreak();
      
      // Sync the streak to the main progress provider (Firestore 'progress' collection)
      await ref.read(progressProvider.notifier).syncStreak(newStreak);

      // 3. Record today as active (updates lastActiveDate, totalActiveDays)
      await streakNotifier.recordActiveDay();"""

if target in content:
    content = content.replace(target, replacement)
    with open('lib/features/home/screens/home_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Success")
else:
    print("Target not found")
