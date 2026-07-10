## Implementation Plan: Daily Quiz Ads

### Overview
Add 3 types of ads to the existing Daily Quiz section using the existing `AdService` and `BannerAdWidget`.

### Files to Modify

**1. `lib/features/daily_quiz/screens/daily_quiz_screen.dart` — Banner Ad**
- Add import: `import '../../../core/widgets/banner_ad_widget.dart';`
- In `_buildBody()`, add `const SizedBox(height: 16)`, `const BannerAdWidget()` at the end of the Column's children (after `_buildTipSection`)

**2. `lib/features/daily_quiz/screens/daily_quiz_result_screen.dart` — Interstitial + Rewarded**
- Add import: `import '../../../services/ad_service.dart';`
- **Interstitial**: Modify "Review & Learn" button's `onPressed` to:
  ```dart
  onPressed: () async {
    await AdService().showInterstitialAd();
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyQuizReviewScreen()));
    }
  },
  ```
- **Rewarded**: Add a new "🎥 +5 Bonus Points" button between score stats and Review button:
  ```dart
  // "Watch ad for bonus" button
  SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () async {
        await AdService().showRewardedAd(
          onRewardEarned: () {
            ref.read(dailyQuizProvider.notifier).addBonusPoints(5);
          },
        );
        if (context.mounted) setState(() {});
      },
      icon: const Icon(Icons.play_circle_fill, color: Colors.amber),
      label: const Text('🎥 +5 Bonus Points'),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white54)),
    ),
  ),
  ```
- Note: Result screen is currently `ConsumerWidget` — it needs to be converted to `ConsumerStatefulWidget` for the Rewarded button (state management). Or we can use a different approach.

Actually, looking more carefully at the result screen, it's a `ConsumerWidget`. The Rewarded ad button needs to show loading state. Let me reconsider:

For the result screen, since it's a `ConsumerWidget`, we can either:
- Convert to `ConsumerStatefulWidget` (more changes)
- Use a simple approach with `StatefulBuilder` or just keep it simple without loading state

Given the user wants to start coding quickly, let me propose keeping the result screen as `ConsumerWidget` and using a simple approach:
- The interstitial on review button can be done directly in `onPressed` with an async callback
- The rewarded button can use `StatefulBuilder` or we can convert to `ConsumerStatefulWidget`

**Simpler approach:** Convert the result screen to `ConsumerStatefulWidget` to handle the loading/button state properly. Or we could keep it simple with just a boolean flag using `ValueNotifier`/`StatefulBuilder`.

Let me keep it simple - I'll propose converting to ConsumerStatefulWidget.

### Execution Order
1. Edit `daily_quiz_screen.dart` — add BannerAdWidget (4 lines change)
2. Edit `daily_quiz_result_screen.dart` — convert to ConsumerStatefulWidget, add interstitial + rewarded ad
3. Run `flutter analyze` to verify no errors