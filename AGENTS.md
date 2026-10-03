# ⚡ জিরো ওয়েস্ট — টোকেন সেভিং ওয়ার্কফ্লো

<!-- flutter-builder:agent-pack:start v1.13.1 -->
## Rule #1 — CI is manual; preflight is your check

This repository runs CI **only when the human dispatches it** (Actions → *Flutter
CI* → Run workflow). Nothing runs on a push. So:

- Work lands on `main` **directly** — no feature branch, no pull request.
- Do **not** wait for a run after pushing. Nothing started; waiting only wastes
  time.
- `tool/preflight.py` is your only automatic check. Run it before every push —
  it is seconds, not minutes, and catches the mistakes that would otherwise
  surface in the next manual CI run.
- **Dart edits are checked on purpose, not by reflex.** Most changes have a
  matching test file: run the one that covers your edit
  (`flutter test test/<name>_test.dart`), not the whole suite. `flutter analyze`
  and the full `flutter test` are for diffs that touch a shared surface, for
  work that feels risky, or for when the human asks — repeating the full pair
  after every small edit is the fastest way to make the loop feel like a chore.
  Everything else (Markdown, YAML, scripts, docs) still ships on preflight
  alone. See *Checking Dart for real* below.
- **When CI does run, it is the source of truth** — read its result before
  calling a batch done. But it runs when the human says so, not on your push.

```bash
python3 tool/preflight.py     # before every push: dead code / unused params / unused imports
python3 tool/agent_loop.py -m "fix(scope): what changed"   # preflight + commit + push, one call
```

### What a check costs

| Check | Cost | When it is the right check |
|---|---|---|
| `python3 tool/preflight.py` | ~1 s | every change, before every push |
| `flutter test test/<file>_test.dart` (via flutter-bootstrap) | 40 s once per session, then seconds | the Dart change that file covers |
| `flutter analyze` or the full `flutter test` | ~20 s / 1–3 min | shared surfaces, risky diffs, or when the human asks |
| `python3 tool/see_screen.py` | one CI run | before and after a UI change |
| The human's CI run | the human's attention + a runner | once per finished batch — never per edit |

Pick the cheapest check that actually covers the change. Building the whole app
to answer a question `flutter analyze` can answer is the most common way to turn
a two-minute task into a twenty-minute one.

### Checking Dart for real (flutter-bootstrap)

The sandbox starts without a Flutter SDK, and one installed now is gone next
session. `flutter-bootstrap` installs a working SDK in ~40 seconds, with no
credentials and a sha256-verified download:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Keshab1997/flutter-bootstrap/main/setup.sh) --quiet --json
cd <app-dir> && flutter pub get && flutter analyze && flutter test
```

- When you run a Dart check at all, `flutter analyze` is the floor: it catches
  exactly what preflight cannot, in ~20 seconds. Worth it for a diff that
  reaches a shared surface, or one you cannot clear by reading it.
- A behaviour change with a matching test gets that **one file** run
  (`flutter test test/<name>_test.dart`). The full suite belongs to the human's
  CI run, unless the human asks for it locally.
- CI pins its own Flutter version: a local pass is *indicative*, not final. When
  the two disagree, CI wins — do not "fix" code to satisfy the local version
  without saying so in the commit message.
- Do **not** `flutter build apk` / `flutter build aab` / `flutter build web`
  locally "just to check". That is minutes per run for an artifact only the CI
  workflow needs to produce, and the signing secrets live in CI anyway.
- Re-running that one-liner later in the same session is safe and instant (~0.2 s
  when the SDK is already there).
- Need a GitHub token in this session (to dispatch a run, read logs, push)? The
  companion repo `agent-bootstrap` pairs one with three browser clicks; pushing
  with `git` over HTTPS may already work, in which case skip it.

## The batch loop — many small changes, one push, one CI run

Small edits are cheap; CI runs are not. So batch them instead of running CI per
change:

1. **Edit** the smallest diff that does one thing.
2. **`python3 tool/preflight.py`** — 1 second, no SDK. Fix what it reports.
3. **Commit and push to `main`.** `python3 tool/agent_loop.py -m "…"` does
   preflight, the secret guard, the commit and the push in one call. Repeat for
   each small change; every commit goes straight to `main`.
4. **Do not wait for CI.** Nothing started. Keep working.
5. **When the batch is ready, tell the human** to run CI once (Actions → *Flutter
   CI* → Run workflow). If a run is already in flight, `python3 tool/ci_watch.py`
   prints the conclusion of every workflow plus the interesting lines of the
   failed ones.

Rules of thumb: a CI run per push wastes the most time; push freely, run CI once
per batch. When a red run does arrive, read the log before editing — guessing at
a red build doubles the rounds.

### The same loop as one command

`tool/agent_loop.py` performs preflight, the secret guard, the commit and the
push in a single call:

```bash
python3 tool/agent_loop.py -m "fix(profile): guard a null avatar"
python3 tool/agent_loop.py -m "fix(profile): drop the unused import" --amend
python3 tool/agent_loop.py -m "chore: wip" --no-push     # commit without pushing
python3 tool/agent_loop.py -m "…" --watch                # wait, only if a run is in flight
```

It refuses, before touching the repository, when

- a staged file looks like a credential (`.env`, `*.jks`, `*.keystore`, `*.pem`,
  `key.properties`, `google-services.json`, `secrets/**`, …) — a refusal costs
  one edit, a leaked keystore costs a rotation;
- `preflight.py` reports anything — use `--no-preflight` only when the findings
  are deliberate.

It commits on the current branch (normally `main`) and pushes there; no branch,
no pull request. Exit codes: `0` committed/pushed, `1` the push failed,
`2` refused before changing anything. An `--amend` push uses
`--force-with-lease`, never a bare `--force`.

## Seeing a screen — look, do not guess

You cannot run the app, but you can *see* it. `tool/see_screen.py` asks CI to
build the app for web and photograph the routes you name, waits for the run,
downloads the images and prints their paths. Then open them — with your image
tool, not your imagination:

```bash
python3 tool/see_screen.py --route /settings           # one screen
python3 tool/see_screen.py --route / --route /profile  # several, one build
python3 tool/see_screen.py --route /settings --wait-ms 12000   # slow first frame
```

* **Use it before and after a UI change.** Before: see what the screen looks
  like now. After: see what your change did. A green CI says the code compiles;
  only the picture says the layout is right.
* This is the one thing that does start a run — it dispatches the UI-screenshots
  workflow itself, so use it deliberately, not on every edit.
* The routes are the app's own (`/settings`, `/profile`) — the same names the
  app navigates to. A screen behind a login or several taps cannot be reached
  this way; ask the human for a screenshot of that one instead.
* It is the **web** build: layout, colours and text are faithful; fonts and
  platform widgets differ, and camera/bluetooth/notification plugins render as a
  blank screen. The script says so when the pixels are flat — believe it rather
  than "fixing" the capture.
* `--out` defaults to `.agent-screens/` (git-ignored). The images are throwaway
  artifacts: never commit them, and never use one as a test fixture.
* No token? `gh auth login` once, or pass `--token-file`.

## Four things that cost an hour here (do not do them)

1. **Waiting for CI after a push.** Nothing was queued — see the manual-only
   table below. Waiting is pure loss.
2. **Running a full build to check a Dart edit.** `flutter build apk|aab|web`
   takes minutes and proves nothing `analyze` + `test` did not already prove.
3. **Asking the human for a CI run before preflight is green and the tests you
   chose to run pass.** A red run spends their attention and a runner, and tells
   you what a local check would have.
4. **Guessing at a red build.** Read the failing step's log first (below). A
   guess that misses doubles the rounds, which is the whole cost this file
   exists to avoid.

## What a push costs here

| Situation | What runs |
|---|---|
| Push to `main` (any change) | nothing — CI is manual |
| Docs-only change (`**.md`, `docs/**`, `distribution/**`) | nothing |
| You ask the human to run CI | CI once, for the whole batch |
| `flutter analyze` / `flutter test` (via flutter-bootstrap) | nothing on GitHub — 40 s to install once per session, then seconds to minutes |
| `see_screen.py` | the UI-screenshots workflow, once per call |

If you want a run right now, do **not** retrigger it with an empty commit — use
*Actions → Run workflow* (or ask the human to).

## CI map

| Workflow | Runs when | What it does |
|---|---|---|
| `ci.yml` → shared `flutter-build.yml` | **manual** (`workflow_dispatch`) | `dart format` check → `flutter analyze --fatal-infos` → `flutter test` + coverage |
| `web-preview.yml` | manual dispatch, branch delete | builds the web app, deploys `preview/<branch>/` to GitHub Pages |
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
- **Push straight to `main`.** No feature branch, no pull request. Batch small
  changes and let the human run CI once at the end.
- **Secrets never enter git:** `google-services.json`, `android/key.properties`,
  `*.jks` / `*.keystore`, `.pem`, tokens. CI receives them from repository
  secrets. Do not add them to the repo to "make CI pass".
- **Respect existing structure:** edit existing files over adding new ones, and
  read the file you are about to change (comments explain *why* the code is the
  way it is — keep that voice).
- **Match the check to the change** — the cost table near the top of this file
  is the map. Cheap checks run every time; CI runs once, at the end.

## Ask the human before

- running CI, when a batch is ready to be checked (they own the run button);
- **tagging a release**, or touching workflows / secrets / repository settings;
- force-pushing over history you do not own, or deleting branches, tags, or
  repository content;
- anything that publishes publicly, spends money, or is irreversible.

## মানুষের জন্য — এই ফাইলটা কী

- **যে যাচাইটা আসলে দরকার, শুধু সেটাই:** ছোট পরিবর্তনে শুধু `preflight.py`
  (~১ সেকেন্ড); Dart বদলালে সংশ্লিষ্ট একটা test ফাইল
  (`flutter test test/<name>_test.dart`) — পুরো `analyze` + `test` শুধু shared
  কিছু বদলালে বা আপনি বললে। প্রতিটা ছোট edit-এর পিছনে পুরো suite চালানো লাগে না।
- **সরাসরি `main`-এ push** — branch নেই, PR নেই। push করলে CI নিজে থেকে চলে না।
- **CI চালানোর বোতাম আপনারই** — একটা batch শেষ হলে একবার চালালেই যথেষ্ট।
- **UI বদলালে ছবি দেখে যাচাই** — `python3 tool/see_screen.py`।
- **agent আগে অনুমতি নেবে** — tag/release, secrets, store metadata, বা যা
  ফিরিয়ে আনা যায় না এমন কিছুর আগে।
- এই ব্লকটা `install-agent-pack.sh` চালালে নিজে থেকেই update হয়; নিচের
  আপনার নিজের notes কখনো মোছা হয় না।

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
