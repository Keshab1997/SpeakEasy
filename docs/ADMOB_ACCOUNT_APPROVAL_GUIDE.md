# AdMob Account Approval Guide — SpeakEasy

> **Your AdMob account was not approved. This guide tells you exactly what to fix.**

---

## ❓ Why AdMob Rejects Accounts

1. **App not live on Google Play** (most common reason)
2. **Privacy Policy missing AdMob/advertising disclosure**
3. **Incomplete payment/tax details** in AdMob
4. **Policy violations** in app content or ad placement
5. **Suspected invalid clicks/activity**

---

## ✅ Fix Checklist (Step-by-Step)

### Step 1: App LIVE on Google Play (MUST)
- Go to play.google.com/console → SpeakEasy
- App must be **Production/Published**, NOT draft
- Complete **Data Safety form** (declare ads/analytics)
- Complete **App Content** (Ads = Yes)
- If not published yet: upload `.aab` and complete all listing fields

### Step 2: Privacy Policy with Advertising Section
- Your Play Store privacy URL: `https://keshab1997.github.io/SpeakEasy/privacy_policy.html`
- ✅ I updated `assets/privacy_policy.html` with full **Advertising/AdMob** section
- ✅ `docs/privacy_policy.html` already has AdMob section
- Make sure the URL opens on a phone — if not, re-push GitHub Pages (`docs/` folder)

### Step 3: Complete AdMob Account & Payment Details
- apps.admob.com → gear icon → Account:
  - [ ] Legal name
  - [ ] Country: **India**
  - [ ] Address (street/city/state/postal)
  - [ ] Phone + Email verified (OTP)
- Payment → complete:
  - [ ] Bank details
  - [ ] Tax info / PAN / W-8BEN (India)

### Step 4: Confirm Program Policies
- On the "Account wasn't approved" screen:
- ☑️ Check **"I confirm I've read and am meeting AdMob Program Policies"**
- Click the confirm button → triggers automatic re-review (24–72 hrs)

### Step 5: App Quality Checks
- ✓ App has real educational content (70+ lessons) — good
- Ads NOT near buttons that cause accidental taps
- No fake/self clicks
- For "all ages" apps, mark **child-directed** in AdMob → disables personalized ads
- No ads on login/registration screens

### Step 6: If Still Rejected → Appeal
1. apps.admob.com → **Help** → **Contact Support**
2. Choose: "Account not approved → request review"
3. Send this message:

```
Title: AdMob Account Reactivation Request

My AdMob account (keshabsarkar2018@gmail.com) was not approved,
but I have resolved all requirements:

1. App "SpeakEasy - Learn English" (com.speakeasy.english.learn)
   is live on Google Play Store.
2. App has original educational content: 70+ grammar lessons,
   vocabulary, speaking practice, mock tests, games.
3. Privacy Policy (https://keshab1997.github.io/SpeakEasy/privacy_policy.html)
   now has a complete Advertising section disclosing AdMob usage,
   personalized ads, opt-out options, and children's privacy.
4. I read and comply with AdSense Program Policies and Google
   Publisher Policies. No invalid activity.

Please re-review my account. Thank you.
Keshab Sarkar
```

### Step 7: Wait 2–7 Days
- Don't create multiple accounts
- Check spam email folder
- Check AdMob dashboard status

---

## 📌 Your Action Summary

| # | Action |
|---|--------|
| 1 | Ensure Play Store app is **Published** (Production) |
| 2 | Fill AdMob Payment + Tax (PAN/W-8BEN) |
| 3 | Verify Phone + Email (OTP) |
| 4 | Check "I confirm..." box on AdMob |
| 5 | If rejected again → Appeal with message above |

---

## 🔄 After Approval
- Link AdMob app ↔ Firebase (User Metrics → Enable)
- Update real Ad Unit IDs if needed
- Rebuild & test with real ads
- Keep Privacy Policy updated

> ✅ **Your app code is already AdMob-ready. Only the account side needs fixing.**