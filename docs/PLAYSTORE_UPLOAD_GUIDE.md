# Play Store Upload Guide — SpeakEasy

## App Info
- **Package Name:** `com.speakeasy.english.learn`
- **App Name:** SpeakEasy
- **Default Language:** English (United States)
- **Category:** Education
- **Type:** App, Free

> ⚠️ **Important:** Since the package name was changed from the previous one, this will be a **NEW app listing** in Play Console. You cannot update the old app's package name.

---

## Prerequisites
- ✅ Google Play Developer account ($25) — [play.google.com/console](https://play.google.com/console)
- ✅ App Bundle ready (`flutter build appbundle` → `build/app/outputs/bundle/release/app-release.aab`)
- ✅ Privacy Policy hosted: `https://keshab1997.github.io/SpeakEasy/privacy_policy.html`
- ✅ AdMob real App ID configured in `AndroidManifest.xml`
- ✅ **App signing key created** (see Step 0 below)
- ✅ App icon generated

---

## Step 0: Create App Signing Key (First Time Only)

If you haven't created a keystore yet, do this first:

```bash
# Create key.properties
cd android/app

# Generate a keystore (replace alias/passwords with your own)
keytool -genkey -v -keystore release-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias speak-easy-key

# Create key.properties file
cat > key.properties << EOF
storeFile=release-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=speak-easy-key
EOF
```

> ⚠️ **Save these passwords somewhere safe!** You'll need them for future updates.

---

## Step-by-Step

### 1. Create App in Play Console
1. Go to [Google Play Console](https://play.google.com/console)
2. Click **Create app**
3. Fill in:
   - **Name:** SpeakEasy
   - **Default language:** English (United States)
   - **App or game:** App
   - **Free or paid:** Free

### 2. Store Listing
Fill in these fields:

| Field | Content |
|-------|---------|
| **Short description** (80 chars) | Learn English through Bengali with AI — 70+ grammar lessons, vocabulary, quizzes & speaking practice. |
| **Full description** | SpeakEasy is your AI English Speaking Partner. Learn English through Bengali with 70+ grammar lessons, vocabulary builder, AI conversation, speaking practice, and daily quizzes. Features: 70+ Grammar Lessons, Vocabulary (Beginner/Intermediate/Advanced), AI Chat Teacher, Speaking Practice with Speech Recognition, Daily Quizzes, Mock Tests with Timer, Streak Tracking, Interactive Games, Dark Mode, Ad-Free option |
| **Screenshots** | 2-8 phone screenshots (min 2 required) |
| **Feature graphic** | 1024×500 px (required) |
| **Category** | Education |
| **Tags** | Education, Language Learning, English |
| **Email** | krishnasarkar987653@gmail.com |
| **Privacy Policy** | https://keshab1997.github.io/SpeakEasy/privacy_policy.html |

> ℹ️ **Note:** The email above should match the one in your Firebase Console support email.

### 3. App Content
- **Content Rating:** Complete questionnaire (usually rated for Everyone or Everyone 10+)
- **Target Audience:** Select appropriate age groups
- **Ads:** Yes (AdMob)
- **News:** No

### 4. Build & Upload App Bundle

```bash
# Clean build
flutter clean

# Generate the release app bundle
flutter build appbundle --release

# Output file:
# build/app/outputs/bundle/release/app-release.aab
```

1. Go to **Production** → **Create new release**
2. Upload `app-release.aab`
3. Add release notes (What's new?)
4. Review and rollout

### 5. Pricing & Distribution
- Select countries (start with India, Bangladesh, USA, UK, UAE)
- Keep Free

---

## ⚠️ Important: AdMob After Package Name Change

Since the package name changed to `com.speakeasy.english.learn`, you need to:

1. Go to [AdMob Console](https://apps.admob.com)
2. **Add a new app** with the new package name: `com.speakeasy.english.learn`
3. Create **new Ad Unit IDs** (Banner, Interstitial, Rewarded) for this app
4. Update these IDs in `lib/services/ad_service.dart`:
   - `_realBannerAdUnitId`
   - `_realInterstitialAdUnitId`
   - `_realRewardedAdUnitId`
5. Also update the **AdMob App ID** in `android/app/src/main/AndroidManifest.xml` if it changes

> ⚠️ Do NOT use the old package name's ad units with the new package — they won't serve ads.

---

## Screenshot Tips
- Use Android emulator or real device to capture clean screenshots
- Show main screens: Home, Lesson, Quiz, AI Chat, Speaking Practice, Progress
- Dimensions: 1080×1920 px (Android phone screenshots)
- No status bar (use Clean Status Bar app or edit in screenshot tool)

---

## Release Notes Template (What's New)

```
🚀 SpeakEasy — Your AI English Learning Partner is here!

• 70+ Grammar Lessons with Bengali explanations
• AI Chat Teacher for real conversation practice
• Vocabulary Builder (Beginner to Advanced)
• Speaking Practice with Speech Recognition
• Daily Quizzes & Mock Tests
• Interactive Games for fun learning
• Streak Tracking to stay motivated
• Dark Mode support
• Works offline for core features
```

---

## After Release
- Monitor via Play Console
- Check Firebase Crashlytics for crashes
- Respond to user reviews
- Plan next update
