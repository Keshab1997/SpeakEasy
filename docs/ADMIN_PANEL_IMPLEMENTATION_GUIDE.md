# Admin Panel Implementation Guide

## AI দিয়ে কিভাবে এই features বানাবেন

প্রতিটি feature এর জন্য **Cline (AI)** কে একটা নির্দিষ্ট prompt দিয়ে শুরু করতে হবে। নিচে প্রতিটা feature এর জন্য step-by-step instruction দেওয়া আছে।

---

## Feature 1: Dashboard Analytics

### Overview
Admin panel এ charts সহ real-time statistics দেখাবে:
- Today's Active Users
- New Signups (This Week)
- Total Lessons Completed Today
- User Growth chart (line chart)
- Module Popularity chart (pie chart)
- Streak Distribution chart (bar chart)

### AI Prompts (Sequentially)

**Prompt 1: Add fl_chart dependency**
```
flutter pub add fl_chart
```

**Prompt 2: Make analytics service**
```
Create a new file lib/services/analytics_service.dart:

class AnalyticsService {
  static final _firestore = FirebaseFirestore.instance;

  // 1. Total users count
  static Future<int> getTotalUsers() async { ... }

  // 2. New users this week
  static Future<int> getNewUsersThisWeek() async { ... }

  // 3. Today's active users (users who practiced today)
  static Future<int> getTodayActiveUsers() async { ... }

  // 4. Lessons completed today (from progress collection)
  static Future<int> getTodayLessons() async { ... }

  // 5. Daily signups for last 7 days (for chart)
  static Future<List<AnalyticsDataPoint>> getDailySignups() async { ... }

  // 6. Module completion stats
  static Future<List<ModuleStat>> getModuleStats() async { ... }

  // 7. Streak distribution
  static Future<StreakDistribution> getStreakDistribution() async { ... }
}

Data models needed:
- AnalyticsDataPoint(date: DateTime, count: int)
- ModuleStat(name: String, completedCount: int, icon: String)
- StreakDistribution(activeUsers: int, atRiskUsers: int, inactiveUsers: int)
```

**Prompt 3: Create admin analytics screen**
```
Create lib/features/admin/screens/admin_analytics_screen.dart:

- Title: "Analytics Dashboard"
- Loading skeleton while data loads  
- Refresh button
- Cards for: Today Active, New This Week, Total Lessons, Total Users
- LineChart for daily signups (7 days)
- PieChart for module distribution
- BarChart for streak distribution
- Pull-to-refresh support
- Use fl_chart package
- Dark mode support
- Color scheme using AppColors
```

**Prompt 4: Add navigation in admin panel**
```
In lib/features/admin/screens/admin_dashboard_screen.dart, 
add a new IconButton in the AppBar actions:
- Icon: Icons.analytics_rounded
- Tooltip: 'Analytics'
- onPressed: Navigate to AdminAnalyticsScreen
```

---

## Feature 2: Content Management

### Overview
Admin panel থেকে directly vocabulary chapters, grammar chapters, daily word ইত্যাদি manage করা যাবে (JSON file edit না করেই)।

### AI Prompts

**Prompt 1: Create Firestore collections for content**
```
Create these Firestore collections programmatically:

1. content_vocabulary_chapters
   - docId: auto
   - fields: chapterNumber (int), title (String), level (String: Beginner/Intermediate/Advanced)
   
2. content_vocabulary_words
   - docId: auto  
   - fields: chapterId (String ref), word (String), meaning (String), banglaMeaning (String), pronunciation (String), exampleSentence (String)

3. content_grammar_chapters
   - docId: auto
   - fields: chapterNumber (int), title (String), content (String - markdown)

4. app_config (single document)
   - docId: "daily_word_config"
   - fields: activeChapterId (String)
```

**Prompt 2: Create AdminContentScreen**
```
Create lib/features/admin/screens/admin_content_screen.dart:

Three tabs:
1. "Vocabulary" tab:
   - List of vocabulary chapters with edit/delete buttons
   - FAB to add new chapter
   - Tap chapter -> see word list, add/edit/delete words
  
2. "Grammar" tab:
   - List of grammar chapters
   - Tap to edit content (markdown editor)
   
3. "Daily Word" tab:
   - Pick which chapter daily words come from
   - Preview today's words

Each tab has forms with TextFields, Save/Cancel buttons.
Use Firestore CRUD operations directly.
```

**Prompt 3: Update providers to read from Firestore instead of JSON**
```
Modify lib/providers/vocabulary_provider.dart and grammar_provider.dart:
- First check if Firestore has content (content_vocabulary_chapters collection)
- If yes, load from Firestore
- If empty, fallback to JSON files (existing behavior)
- Add refresh method to reload from Firestore
```

---

## Feature 3: Remote App Config + Force Update

### Overview
Firestore এ একটা config document রাখলে app remotely configure করা যাবে — without app update।

### AI Prompts

**Prompt 1: Create Firestore config document**
```
Create a Firestore document at: config/app_settings

Fields:
{
  "featureToggles": {
    "aiTeacher": true,
    "games": true,
    "homework": true,
    "sentenceAnalyzer": true,
    "speaking": true,
    "listening": true
  },
  "forceUpdate": {
    "enabled": false,
    "message": "Please update to the latest version",
    "targetVersion": "2.0.0",
    "playStoreUrl": "https://play.google.com/store/apps/details?id=..."
  },
  "maintenanceMode": {
    "enabled": false,
    "message": "App is under maintenance. Please come back later."
  },
  "gameplay": {
    "streakFreezeCost": 100,
    "dailyGoalXP": 50,
    "maxStreakFreezes": 3
  }
}
```

**Prompt 2: Create RemoteConfigService**
```
Create lib/services/remote_config_service.dart:

class RemoteConfigService {
  static final _firestore = FirebaseFirestore.instance;
  static Map<String, dynamic>? _cachedConfig;
  
  // Fetch config from Firestore (with caching)
  static Future<Map<String, dynamic>> getConfig() async { ... }
  
  // Feature checks
  static Future<bool> isFeatureEnabled(String feature) async { ... }
  static Future<bool> isMaintenanceMode() async { ... }
  static Future<ForceUpdateInfo?> getForceUpdateInfo() async { ... }
  static Future<int> getStreakFreezeCost() async { ... }
  
  // Admin: update config
  static Future<void> updateConfig(Map<String, dynamic> updates) async { ... }
}
```

**Prompt 3: Create admin config screen**
```
Create lib/features/admin/screens/admin_config_screen.dart:

Sections:
1. "Feature Toggles" — Switch list for each feature
2. "Force Update" — Toggle + message + version fields
3. "Maintenance Mode" — Toggle + message
4. "Game Settings" — Streak freeze cost, daily XP goal inputs

All changes save directly to Firestore config/app_settings.
Show success/error snackbar after save.
```

**Prompt 4: Integrate in app startup**
```
In lib/main.dart:
- Call RemoteConfigService.getConfig() on app start
- If maintenance mode enabled, show MaintenanceScreen instead of HomeScreen
- If force update required, show ForceUpdateScreen with Play Store link

In each feature screen:
- Check isFeatureEnabled before showing the feature
- If disabled, show a "Coming Soon" placeholder or hide the entry point
```

---

## Feature 4: User Feedback / Complaint Box

### Overview
Users app থেকে feedback পাঠাতে পারবে, admin panel এ দেখা যাবে, এবং reply করা যাবে।

### AI Prompts

**Prompt 1: Create feedback screen for users**
```
Create lib/features/feedback/screens/feedback_screen.dart:

- TextField for message (max 500 chars)
- Optional category dropdown: "Bug Report", "Feature Request", "Complaint", "Suggestion", "Other"
- Submit button -> saves to Firestore "feedback" collection
- Fields: userId, userName, message, category, timestamp, status: "pending"
- Show success snackbar on submit
- Add entry point in HomeScreen settings or profile section
```

**Prompt 2: Create admin feedback management screen**
```
Create lib/features/admin/screens/admin_feedback_screen.dart:

- Stream from Firestore "feedback" collection ordered by timestamp desc
- Three tabs: "Pending" (default), "Resolved", "All"
- Each feedback card shows:
  - User name + email
  - Category badge
  - Message
  - Timestamp
  - Status
- Tap to expand and see reply section
- Admin can write reply and mark as resolved
- Save reply to Firestore feedback document
```

**Prompt 3: Add navigation**
```
AdminDashboardScreen: Add IconButton for feedback
User side: Add Feedback option in Settings or Profile drawer
```

---

## Feature 5: Achievement & Reward Configuration

### Overview
Admin theke badge thresholds, XP rewards, coin rewards configure করা যাবে।

### AI Prompts

**Prompt 1: Create achievements Firestore collection**
```
Collection: config/achievements

Documents like:
{
  "id": "bronze_learner",
  "title": "Bronze Learner",
  "description": "Complete 5 lessons",
  "icon": "emoji_events",
  "requiredCount": 5,
  "type": "lessons_completed",  // lessons_completed, streak_days, words_favorited, total_xp
  "rewardXp": 50,
  "rewardCoins": 25,
  "enabled": true
}
```

**Prompt 2: Create admin achievements screen**
```
Create lib/features/admin/screens/admin_achievements_screen.dart:

- List all achievement configs
- Add new achievement
- Edit existing: title, description, requiredCount, rewardXp, rewardCoins
- Toggle enabled/disabled
- Preview what badges users will see
```

**Prompt 3: Update achievement service**
```
Modify lib/services/achievement_service.dart:
- Read achievement configs from Firestore (with local fallback)
- Check achievements dynamically based on config
- Award XP/coins based on config values
```

---

## Feature 6: User Progress Explorer

### Overview
Admin যেকোনো user খুঁজে তার complete progress দেখতে পারবে — এবং必要时 adjust করতে পারবে (support purpose)।

### AI Prompts

**Prompt 1: Create admin user search screen**
```
Create lib/features/admin/screens/admin_user_search_screen.dart:

- Search bar with autocomplete (by name/email)
- Search results showing: name, email, role, lastActive
- Tap user -> detailed progress view:

Progress View:
- Basic info card: name, email, photo, joined date, role
- Stats: streak, XP, level, coins, total lessons
- Chapter completion list (Grammar + Vocabulary with checkmarks)
- Last 7 days activity heatmap
- Action buttons:
  - "Reset Streak" (with confirmation)
  - "Add XP" (input amount + reason)
  - "Add Coins" (input amount + reason)
  - "Send Test Notification"
- All actions logged in a "support_logs" collection
```

**Prompt 2: Create support log (audit trail)**
```
Every admin action on user account should be logged:
Collection: support_logs
Fields: adminId, adminName, userId, action, details, timestamp
```

---

## Feature 7: Scheduled Notifications

### Overview
Admin নির্দিষ্ট time এ notification schedule করে রাখতে পারবে — and recurring notifications।

### AI Prompts

**Prompt 1: Update admin notification screen for scheduling**
```
Modify lib/features/admin/screens/admin_dashboard_screen.dart notification composer:

Add fields:
- "Schedule for later" toggle
- Date & Time picker (if scheduled)
- "Repeat" dropdown: None, Daily, Weekly, Monthly
- "Send Now" button vs "Schedule" button

For scheduled notifications:
- Save to "admin_notifications" with: scheduledAt (timestamp), repeat (string)
- A Cloud Function checks every minute and sends when scheduledAt <= now
```

**Prompt 2: Create scheduled notifications list**
```
In AdminNotificationsScreen (history):
- Add tab: "Scheduled" showing future notifications
- Show schedule time + repeat info
- Cancel scheduled notification button
```

---

## Feature 8: Data Export (CSV)

### Overview
Admin users এর data CSV file হিসেবে download করতে পারবে।

### AI Prompts

**Prompt 1: Create admin export screen**
```
Create lib/features/admin/screens/admin_export_screen.dart:

Export options:
1. "Users List" -> name, email, role, joinedAt, streak, level, XP, coins
2. "Progress Report" -> userId, chapterType, chapterNumber, completedAt, score
3. "Wrong Questions" -> userId, question, correctAnswer, userAnswer, timestamp
4. "Feedback" -> userId, message, category, timestamp, status

Each export:
- Date range filter (from/to)
- Export button -> generates CSV
- Saves to device downloads folder
- Shows share sheet
- Uses `csv` package and `path_provider` + `share_plus`
```

**Prompt 2: Add dependencies**
```
flutter pub add csv
flutter pub add share_plus
flutter pub add path_provider
```

---

## Execution Order (Recommended)

| Priority | Feature | Estimated Time | Difficulty |
|----------|---------|---------------|------------|
| ⭐⭐ | 3. Remote App Config | ১-২ hours | Easy |
| ⭐⭐⭐ | 1. Dashboard Analytics | ২-৩ hours | Medium |
| ⭐ | 8. Data Export | ১ hour | Easy |
| ⭐⭐⭐ | 6. User Progress Explorer | ৩-৪ hours | Medium-Hard |
| ⭐⭐ | 4. User Feedback | ২ hours | Medium |
| ⭐⭐⭐ | 2. Content Management | ৪-৫ hours | Hard |
| ⭐⭐ | 5. Achievement Config | ২ hours | Medium |
| ⭐⭐ | 7. Scheduled Notifications | ২-৩ hours | Medium |

---

## How to Start with Any Feature

1. **Copy-paste** the relevant "AI Prompts" থেকে প্রথম prompt টা
2. AI কাজ করবে — file তৈরি করবে
3. **Check** করে দেখুন ঠিকমতো হয়েছে কিনা
4. **Next prompt** দিন
5. শেষে `flutter analyze` দিয়ে check করুন error নেই কিনা

> **Tip:** প্রতিটি feature এর জন্য আলাদা branch তৈরি করে কাজ করুন, যাতে কোনো problem হলে main branch এ effect না পড়ে।

---

## Required Packages Summary

```yaml
dependencies:
  fl_chart: ^0.68.0       # For analytics charts
  csv: ^6.0.0             # For CSV export
  share_plus: ^9.0.0      # For sharing exported files
  path_provider: ^2.1.0   # For file system access