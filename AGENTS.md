# ⚡ জিরো ওয়েস্ট — টোকেন সেভিং ওয়ার্কফ্লো

<!-- flutter-builder:agent-pack:start v1.10.0 -->
## Rule #1 — CI verifies, you never push a guess

This sandbox usually has **no Flutter SDK**, and even when it does, the local
result would not match CI (SDK pin, Android SDK, Firebase secrets). So:

- Do **not** run `flutter test`, `flutter analyze`, `flutter build`,
  `dart analyze` or `gradlew` locally to "check quickly".
- Use the two zero-dependency tools in `tool/` instead — they are seconds, not
  minutes, and they catch the mistakes that actually turn pushes red.
- **CI is the single source of truth.** Read its result before calling a change
  done; a local impression is never verification.

```bash
python3 tool/preflight.py     # before pushing: dead code / unused params / unused imports
python3 tool/ci_watch.py      # after pushing: waits for CI, prints the failing lines
python3 tool/agent_loop.py -m "fix(scope): what changed"   # all five steps, one call
```

## The fast loop — one change, one push, one CI round

1. **Edit** the smallest diff that does one thing.
2. **`python3 tool/preflight.py`** — 1 second, no SDK. Fix what it reports.
3. **Commit.** While the branch is still yours, `git commit --amend` instead of
   piling "fix ci" commits on top.
4. **Push once.** Never push WIP "to see what happens". If you have several
   things to try, open the PR as a **draft** — drafts do not run CI, so iterate
   freely; mark *Ready for review* when you want the run.
5. **`python3 tool/ci_watch.py`** — it polls for you (no turn-by-turn waiting)
   and prints the conclusion of every workflow plus the interesting lines of
   the failed ones.
6. **Red?** Fix → `git commit --amend` → `git push --force-with-lease` →
   watch again. One more round, not five.

Rules of thumb: ten 30-second pushes waste more time than one 3-minute CI run.
Read the CI log before editing; guessing at a red build doubles the rounds.

### The same loop as one command

`tool/agent_loop.py` performs steps 2-5 in a single call, and stops before the
first thing that would waste a run:

```bash
python3 tool/agent_loop.py -m "fix(profile): guard a null avatar"
python3 tool/agent_loop.py -m "fix(profile): drop the unused import" --amend
python3 tool/agent_loop.py -m "feat(cv): add PDF export" --draft-pr
python3 tool/agent_loop.py -m "..." --ready          # drafts run no CI: this starts it
python3 tool/agent_loop.py -m "..." --no-watch       # push and return immediately
```

It refuses, before touching the repository, when

- HEAD is the default branch (`main`/`master`) — use a branch, or `--allow-main`
  when the project really works that way;
- a staged file looks like a credential (`.env`, `*.jks`, `*.keystore`, `*.pem`,
  `key.properties`, `google-services.json`, `secrets/**`, …) — a refusal costs
  one edit, a leaked keystore costs a rotation;
- `preflight.py` reports anything — use `--no-preflight` only when the findings
  are deliberate.

Exit codes: `0` pushed (and green when watched), `1` CI red or push failed,
`2` refused before changing anything. An `--amend` push uses
`--force-with-lease`, never a bare `--force`.

## What a push costs here (and why it is already cheap)

| Situation | What runs |
|---|---|
| Push to a feature branch **with an open PR** | the PR event only — the push trigger is main-only, so no duplicate |
| Push to `main` | CI (+ Web Preview) once |
| **Draft** PR | nothing, until you press *Ready for review* |
| Docs-only change (`**.md`, `docs/**`, `distribution/**`) | nothing (excluded by `paths-ignore`) |
| Merge | CI on `main` + Web Preview deploy |

If a run is cancelled or skipped, do **not** retrigger it with an empty commit —
use *Actions → Run workflow* or the re-run API call.

## CI map

| Workflow | Runs when | What it does |
|---|---|---|
| `ci.yml` → shared `flutter-build.yml` | push to main, PRs | `dart format` check → `flutter analyze --fatal-infos` → `flutter test` + coverage |
| `web-preview.yml` | push to main, PRs | builds the web app, deploys `preview/<branch>/` to GitHub Pages (a branch delete removes its preview) |
| `manual-build.yml` | manual dispatch | APK / AAB artifact |
| `publish-release.yml` | manual dispatch | signed build → tag → GitHub Release (+ Play internal if configured) |
| `release.yml` | `v*` tag push | signed AAB artifact for the tag |

The reusable workflows are pinned by tag; bump the pin in one place
(`.github/workflows/*.yml`) and every project picks the change up.

## Reading CI without wasting a turn

```bash
python3 tool/ci_watch.py                       # HEAD commit, waits, prints failures
python3 tool/ci_watch.py --branch main         # newest runs of a branch
python3 tool/ci_watch.py --once                # no waiting: current state only
python3 tool/ci_watch.py --sha <sha>           # a specific commit
python3 tool/ci_watch.py --token-file secrets/gh_token.txt
```

Token order: `--token-file`, then `$GITHUB_TOKEN` / `$GH_TOKEN`, then `gh auth
token`. Never print a token, and never paste one into a log or a commit.

Raw API equivalents, if you need them:

```bash
GET /repos/{owner}/{repo}/actions/runs?head_sha=<sha>     # run list + conclusions
GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs      # failing job and step
GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs      # plain-text log
```

The log endpoint answers with a **302 to blob storage**; the pre-signed URL
rejects a request that still carries the `Authorization` header
(`InvalidAuthenticationInfo`), so strip it on redirect — `ci_watch.py` does.

## Working rules

- **Small, focused diffs.** One concern per commit; conventional commit
  messages (`fix(profile): …`, `feat(cv): …`, `chore(ci): …`).
- **Branch + PR** for anything non-trivial; keep the branch name descriptive.
  Docs-only fixes may go straight to `main` when the project allows it.
- **Merge only when green.** Delete the branch after merging — the preview
  cleanup runs automatically.
- **Secrets never enter git:** `google-services.json`, `android/key.properties`,
  `*.jks` / `*.keystore`, `.pem`, tokens. CI receives them from repository
  secrets. Do not add them to the repo to "make CI pass".
- **Respect existing structure:** edit existing files over adding new ones, and
  read the file you are about to change (comments explain *why* the code is the
  way it is — keep that voice).

## Ask the human before

- merging to `main` (when the project wants review), **tagging a release**, or
  touching workflows / secrets / repository settings;
- force-pushing a branch you do not own, rewriting published history, or
  deleting branches, tags, or repository content;
- anything that publishes publicly, spends money, or is irreversible.

<!-- flutter-builder:agent-pack:end -->

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
