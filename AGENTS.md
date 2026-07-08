# ⚡ জিরো ওয়েস্ট — টোকেন সেভিং ওয়ার্কফ্লো

> **মূলনীতি:** ফাইল পড়া শেষ অস্ত্র। গ্রাফ, সার্চ, এবং ইউজারের নির্দেশনা আগে।

---

## 🧭 ১. প্রতিটি সেশনের শুরুতে — বাধ্যতামূলক চেকলিস্ট

প্রথম মেসেজ পাওয়ার পর, **কিছু করার আগে** এই চেকলিস্ট অনুসরণ করতেই হবে:

### ✅ Step 1: গ্রাফ চেক করো

```
যদি graphify-out/ ফোল্ডার থাকে:
  → GRAPH_REPORT.md পড়ো (পুরো প্রজেক্ট না)
  → graph.json থেকে শুধু relevant nodes দেখো
যদি graphify-out/ না থাকে:
  → বলো: "graphify run করবেন? (টোকেন বাঁচাতে)"
  → ইউজার না বললে, Explore agent দিয়ে কাজ চালাও
```

### ✅ Step 2: ইউজারকে নির্দিষ্ট করতে বলো

```
বলো: "কোন ফাইল/লাইনে কাজ করব? নির্দিষ্ট করে দিন — তাহলে টোকেন বাঁচবে।"
```

### ✅ Step 3: টুল সিলেক্ট করো (নিচের টেবিল অনুযায়ী)

| কাজ | কোন Tool/Agent/Skill | কেন |
|------|----------------------|-----|
| 🆕 প্রজেক্ট বোঝা | **graphify** → GRAPH_REPORT.md | পুরো ফাইল না পড়ে আর্কিটেকচার বোঝা |
| 🔍 কিছু খোঁজা | **Explore agent** + `grep` | শুধু ম্যাচিং অংশ পড়ে, পুরো ফাইল নয় |
| 🐛 বাগ ফিক্স | **superpowers:systematic-debugging** | এলোমেলো টোকেন খরচ কমায় |
| ✨ ফিচার ডেভ | **superpowers:test-driven-development** বা **brv-smart-workflow** | গাইডেড, কম রিডান্ডেন্সি |
| 🎨 ক্রিয়েটিভ ওয়ার্ক | **superpowers:brainstorming** → তারপর impl skill | পরিকল্পনা ছাড়া কোডিং নয় |
| 🔄 প্যারালাল টাস্ক | **superpowers:dispatching-parallel-agents** | একসাথে multiple agents |
| 📄 ফাইল পড়া | **Read with offset+limit** | পুরো ফাইল নয়, শুধু нужные লাইন |
| ✏️ এডিট করা | **Edit** (exact string match) | টোকেন সেভ করে, Write-এর চেয়ে ভালো |
| ✅ দাবি করার আগে | **superpowers:verification-before-completion** | মিথ্যা দাবি ঠেকায় |

---

## 🚀 ২. এক্সিকিউশন প্রোটোকল — ধাপে ধাপে

### যখন ইউজার বলে: "এক্স ফিচার বানাও" বা "ওয়াই বাগ ফিক্স করো"

```
① গ্রাফ চেক করো (GRAPH_REPORT.md)
② যদি brainstorming প্রয়োজন → superpowers:brainstorming কল করো
③ TodoWrite দিয়ে tasks ট্র্যাক করো
④ Explore agent দিয়ে relevant code খোঁজো (grep-based)
⑤ শুধু needed line ranges Read করো
⑥ Edit/Write দিয়ে কাজ করো
⑦ superpowers:verification-before-completion চালাও
⑧ graphify --update চালাও (যদি graphify-out/ থাকে)
```

---

## 📖 ৩. ফাইল রিডিং নীতিমালা (Token Optimization)

### ❌ যা করা যাবে না:
```
Read whole file from line 1 to 2000
Read entire directory structure without filter
```

### ✅ যা করতে হবে:
```
# নির্দিষ্ট ফাংশন/ক্লাস খুঁজতে:
→ grep -n "functionName\|className" *.dart
→ তারপর Read with offset+limit

# ডিরেক্টরি দেখতে:
→ ls target_dir/ | head -30
→ অথবা glob pattern: **/*.dart
```

### ফাইল পড়ার নিয়ম:

| ফাইল সাইজ | কীভাবে পড়বে |
|-----------|-------------|
| ≤ ৫০ লাইন | পুরো পড়া যাবে |
| ৫০-২০০ লাইন | offset দিয়ে needed অংশ |
| > ২০০ লাইন | grep → offset → only needed section |
| স্ক্রোল করার দরকার নেই | `limit` প্যারামিটার দিয়ে থামাও |

---

## 🧠 ৪. ম্যান্ডেটরি স্কিল/এজেন্ট রুটিং

> **নিয়ম:** নিচের প্রতিটি情景-এ নির্দিষ্ট skill/agent ব্যবহার করা **বাধ্যতামূলক**। স্কিপ করা যাবে না।

### ৪.১ প্রোজেক্ট এক্সপ্লোরেশন
```
/task: "এই কোডবেস বুঝতে চাই"
→ graphify (Run or Read GRAPH_REPORT.md)
```

### ৪.২ বাগ ফিক্স
```
/task: "এক্স কাজ করছে না"
→ superpowers:systematic-debugging
   (এটা না চালিয়ে সরাসরি ফিক্স করা যাবে না)
```

### ৪.৩ ফিচার ডেভেলপমেন্ট
```
/task: "এক্স ফিচার যোগ করো"
→ (প্রথমে) superpowers:brainstorming → plan → implement
→ brv-smart-workflow (optional, project-based)
```

### ৪.৪ ভারিফিকেশন
```
/claim: "কাজ done"
→ superpowers:verification-before-completion চালাতেই হবে
→ graphify --update চালাতেই হবে (যদি graph থাকে)
```

### ৪.৫ প্যারালাল এক্সিকিউশন
```
/task: "দুই জায়গায় একসাথে কাজ করো"
→ superpowers:dispatching-parallel-agents
   (একটার পর একটা না করে)
```

---

## 📊 ৫. গ্রাফিফাই ইন্টিগ্রেশন (হার্ড রুল)

### যখন প্রোজেক্টে graphify-out/ আছে:
```
✅ BEGINNING: GRAPH_REPORT.md পড়ো (প্রথম ৫০ লাইন)
✅ DURING: graph.json থেকে relevant node queries করো
✅ END: graphify --update চালাও
```

### যখন graphify-out/ নেই:
```
🚫 বলো: "গ্রাফ নেই। graphify চালাবেন? (টোকেন বাঁচবে)"
→ ইউজার না বললে Explore agent দিয়ে কাজ করো
→ কিন্তু বারবার ফাইল পড়ার warning দেখাও
```

---

## 🛠 ৬. টুল ব্যবহারের টেবিল

| পরিস্থিতি | ব্যবহার করবে | ব্যবহার করবে না |
|-----------|-------------|----------------|
| ফাইল খোঁজা | `find`, `glob`, `grep` | Read all files in dir |
| ফাইল পড়া | Read with offset+limit | Read entire 500+ line file |
| বাগ খোঁজা | systematic-debugging skill | Random file reads |
| ফিচার বানানো | TDD skill → plan → implement | Jump to coding directly |
| ডিরেক্টরি দেখা | `ls target/ \| head`, `glob pattern` | `ls -R` full tree |
| কোড রিভিউ | requesting-code-review skill | Manual scanning |
| কাজ ট্র্যাক | TodoWrite | Relying on memory alone |
| মাল্টি-টাস্ক | dispatching-parallel-agents | Sequential processing |

---

## 💬 ৭. ইউজারকে বলার প্যাটার্ন (টোকেন বাঁচানোর জন্য)

### যখন নির্দিষ্ট info দরকার:
```
"ঠিক কোন ফাইল/লাইনে কাজ করব? এক লাইন বললে ৫০% টোকেন বাঁচবে 🙏"
```

### যখন গ্রাফ নেই:
```
"graphify-out/ নেই। chartify চালাতে ২-৩ মিনিট লাগবে, কিন্তু পরবর্তী কাজ ৬০% দ্রুত হবে। করবেন?"
```

### যখন বারবার একই ফাইল পড়তে হচ্ছে:
```
"এই ফাইলটা মেমরিতে রাখব? তাহলে বারবার পড়তে হবে না।"
```

---

## ⚠️ ৮. নিষেধাজ্ঞা (Hard Blocks)

```
🚫 কখনোই Read করবে না → পুরো ১০০০+ লাইনের ফাইল (offset ছাড়া)
🚫 কখনোই Start করবে না → brainstorming ছাড়া creative task
🚫 কখনোই Claim করবে না → verification-before-completion ছাড়া
🚫 কখনোই Skip করবে না → নির্দিষ্ট skill (উপরে উল্লেখিত) ব্যবহার না করে
🚫 কখনোই বলবে না "done" → graphify --update ছাড়া (যদি graph থাকে)
🚫 কখনোই পড়বে না → grep/Explore agent দিয়ে না খুঁজে
```

---

## 📁 ৯. ফাইল স্ট্রাকচার

```
project-root/
├── AGENTS.md              ← এই ফাইল (সব প্রজেক্টে কপি করবেন)
├── graphify-out/          ← graphify আউটপুট (auto-generated)
│   ├── GRAPH_REPORT.md
│   ├── graph.json
│   └── graph.html
└── ... (আপনার কোড)
```

---

## 🔄 ১০. ইউনিভার্সাল ইউসেজ — সব প্রজেক্টে কাজ করবে

এই AGENTS.md **কোনো প্রজেক্ট-নির্দিষ্ট কিছু ধরে না**। এটি universal:
- Flutter/Dart project
- Node.js/TypeScript project
- Python project
- যেকোনো ভাষা/ফ্রেমওয়ার্ক

**ব্যবহার:** প্রতিটি প্রজেক্টের রুট ফোল্ডারে `AGENTS.md` নামে কপি করুন। ZCode/Claude Code স্বয়ংক্রিয়ভাবে লোড করবে।

**Global setup (ঐচ্ছিক):**
```bash
# Mac/Linux: হোম ডিরেক্টরিতেও রাখতে পারেন
cp /Users/keshabsarkar/ZCodeProject/AGENTS.md ~/AGENTS.md
```

---

> 🎯 **লক্ষ্য:** বারবার ফাইল না পড়ে, graphify + smart tools ব্যবহার করে, দ্রুত এবং কম টোকেনে কাজ শেষ করা।
>
> 📢 **রিমাইন্ডার:** ইউজার যদি নির্দিষ্ট ফাইল/লাইন না বলে, তাহলে জিজ্ঞাসা করো — সেটাই সবচেয়ে বড় টোকেন সেভিং।
