## Plan: Provider Groups + Google AI Studio (Gemini) Key Support

### সমস্যা
OpenRouter free key-গুলো slow answer দেয়। Google AI Studio-র Gemini key দ্রুত। চাও: (১) Google AI Studio key add করা যাবে, (২) provider অনুযায়ী group করে group-level toggle, (৩) fast group (Google) আগে, slow (OpenRouter) fallback হিসেবে।

### ফাইল-ভিত্তিক পরিবর্তন

**১. Data model — `lib/models/admin_api_key.dart`**
- নতুন `provider` field: `openrouter | google | custom`
- `fromMap`-এ field না থাকলে baseUrl থেকে infer: `generativelanguage` → google, `openrouter` → openrouter, বাকি → custom (পুরনো keys-এর জন্য **zero migration**)
- `toMap`/`copyWith`/constructor update

**২. Group config — Firestore `admin_key_groups` collection**
- docId = provider; fields: `{name, enabled, priority}`
- doc না থাকলে default: `enabled=true, priority=100` (এখনো কোনো setup ভাঙবে না)
- `ApiKeyManager` keys-এর সাথে সাথে group config-ও listen করে

**৩. Selection logic — `lib/services/api_key_manager.dart`**
- `getNextKey()`/`peekFirstKey()`: disabled group-এর keys বাদ, তারপর sort করবে **(group priority asc, key priority asc)** দিয়ে, তারপর round-robin
- ফলাফল: Google group priority=1 হলে সব request আগে Google-এ যাবে; Google keys সব cooldown/fail হলেই OpenRouter (priority=2) fallback
- Admin UI-তে group priority বদলানো যায়

**৪. Gemini API support — `lib/services/ai_service.dart`**
- `_callOpenAI` provider-aware হবে:
  - `google` → Gemini REST API: `POST {baseUrl}/models/{model}:generateContent?key={key}`, body `{systemInstruction, contents:[{role:user|model, parts:[{text}]}]}`, parse `candidates[0].content.parts[0].text`
  - বাকি → আগের OpenAI-compatible `/chat/completions` path (অপরিবর্তিত)
- History roles map: user→user, assistant→model, system→systemInstruction
- `testConnectionWithKey`: `provider` param + Gemini ping branch
- Default google baseUrl: `https://generativelanguage.googleapis.com/v1beta`, model: `gemini-2.5-flash`
- OpenRouter-নির্দিষ্ট `fetchFreeOpenRouterModels`/`resolveOpenRouterModel` অপরিবর্তিত

**৫. Admin UI — `lib/features/admin/screens/admin_api_keys_screen.dart`**
- Add/Edit dialog: **Provider dropdown** (OpenRouter / Google AI Studio / Custom) — provider বাছলে baseUrl+model auto-prefill; google-র জন্য OpenRouter models-fetch বাটন লুকানো
- Key list: **provider অনুযায়ী group header card** — প্রতিটায় group name, **enable/disable switch**, **priority field**
- Key card-এ provider badge

**৬. Verification**
- `flutter analyze` (আমার ফাইলে ০ error/warning)
- আপডেট করা ফাইলগুলোর সংক্ষিপ্ত test (যদি থাকে)

### Scope-র বাইরে (পরে দেখা যাবে)
- Per-key latency tracking / fastest-key-প্রথম
- Google AI Studio-র `:listModels` fetch বাটন

আপত্তি থাকলে বলো, নাহলে approve করলে implement শুরু করব।