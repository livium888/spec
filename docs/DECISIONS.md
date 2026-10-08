# Decision records

## D1 — FSRS implementation: Dart `fsrs` port behind `Scheduler`, not fsrs-rs via FRB
- **Chosen:** `fsrs` 2.0.1 (MIT, open-spaced-repetition/dart-fsrs), 21 params (FSRS-6), wrapped by `DartFsrsScheduler`.
- **Rejected:** fsrs-rs + flutter_rust_bridge. Needs NDK cross-compile, Rust toolchain in CI, and cannot be verified without an Android device/emulator. Gains the optimizer, which v1 does not use.
- **Finding (verified against fsrs-rs `inference_v6.rs`):** the Dart package's default weights are py-fsrs defaults with decay `w[20]=0.2`, NOT the spec's 0.1542. We inject fsrs-rs `FSRS6_DEFAULT_PARAMETERS` (decay 0.1542) explicitly.
- **Known divergences from fsrs-rs** (verify against current docs): the Dart port floors elapsed time to whole days for retrievability and treats `<1 day` as same-day; fsrs-rs uses fractional days. Intervals can differ slightly from Anki's. fsrs-rs main now also ships a v7 model; v1 targets v6.
- **Measured divergence vs fsrs-rs 6.6.2** (12-review sequence incl. two lapses, same weights; reference vectors are in `test/fsrs_scheduler_test.dart`): max stability error 0.99%, max difficulty error 0.037. Cause: the Dart port clamps D0(4) inside the difficulty mean-reversion step; fsrs-rs uses it unclamped (about -4.79 with default weights). Effect on intervals is within ~3%. Accepted for v1; it matters if/when parameters are optimised with fsrs-rs, because they would be fitted to slightly different dynamics.
- **Revisit if:** the optimizer is needed (engine phase) -> add an `FsrsRsScheduler`, or replace the port with a ~100-line own implementation of the published FSRS-6 formulas validated against the same vectors; the interface already allows both.

## D2 — Deterministic fuzz
Library fuzz uses `Random()`, which breaks "replay == live". Library fuzz is disabled; the adapter applies fuzz seeded by `(cardId, reps_before)`.

## D3 — Replay inputs
Replay needs only `review_log` + `fsrs_params`. Learning steps, max interval and weights live in `fsrs_params.params_json`; changing any creates a new params row. `suspended`/`buried_until` are NOT scheduling fields (not derivable from log) and are left untouched by rebuild; leech suspension is applied live only.

## D4 — Schema additions beyond the spec
`card.step` (learning step index; required by FSRS), `setting(key,value)` (so settings travel in backups). Nothing removed.

## D5 — Undo
Undo sets `revoked_at` on the last log row, then rebuilds that one card by replaying its remaining non-revoked logs. One code path for undo and full rebuild.

## D6 — Backup format
Single SQLite file via `VACUUM INTO` (consistent snapshot, no WAL leftovers), named `learning-backup-YYYYMMDD.db`. Zipped DB+JSON rejected: the DB already contains everything; JSON adds a second source of truth.

## D7 — Threat model notes
- JSON import: untrusted text (LLM output). Strict schema validation, length caps, no HTML rendering (plain `Text`), no code execution. Clipboard read only on explicit tap.
- Restore: untrusted file. Open read-only, check `PRAGMA user_version`, `PRAGMA integrity_check`, required tables present, before replacing the live DB; keep the previous DB as `.pre-restore` until success.
- SAF: only the user-picked tree URI with persisted permission; no broad storage permissions.
- Backups are unencrypted (offline, user-owned folder). Revisit if the folder is cloud-synced.

## D8 — Where use cases live
Pure logic (scheduler interface, `applyRating`, queue ordering math, import validation, prompt rendering, engine contracts) is in `lib/domain` with no Flutter/Drift imports. Use cases that must run SQL (`ReviewService`, `QueueService`, `ImportService`, `BackupService`, `EngineFeaturesService`) live in `lib/data` rather than behind repository interfaces: a second abstraction layer over Drift would double the code for no swap-ability we need in v1. Revisit if a second storage backend appears.

## D9 — Spec ambiguities resolved (change if you meant otherwise)
- "Every session start: write an interest_log prompt": implemented as a one-tap, skippable dialog at the END of a session, per domain touched; a row is written only when you tap.
- `cards_surviving_30d`: cards first answered >30 days ago that are now in `review` and not suspended.
- `retention_30d`: share of review/relearning-state answers rated Hard/Good/Easy.
- Import rule "no card without a quote or URL" applies to `quote`/`url` source types; `model_memory` cards are allowed without one but are tagged `unverified`.
- Manual "Add card" reuses the import pipeline (source "manual entry").
- A new card's `due` equals its note's `created_at`; replay depends on this.
- Android Auto Backup is disabled (`allowBackup=false`) so no data leaves the phone except your SAF folder.

## D10 — Not verified in this environment (verify on device)
Android SDK downloads are blocked in the build container, so the APK build, SAF folder picker/writer, WorkManager weekly job and release signing are untested here. Host-side tests cover the logic: replay==live, undo, queue, import, backup/restore acceptance (export, wipe, restore, identical counts/dues/review count).

## D11 — "Learn something new": rule-based planner, not a learned model
- **Chosen:** `LearnPlanner` (pure, `lib/domain/learn_planner.dart`). Candidate actions per syllabus topic: *new topic*, *deepen*, *remediate*. Hand-set scores: new = 1.0 + 0.3·interest + up to 0.2·staleness; deepen = 0.2 + 0.8·(share of target still missing); remediate = 0.9 + severity (leeches/5 + lapse rate). Ties are broken by a hash of (day, topic), so equal options rotate from day to day but never change within a day.
- **Gates:** a topic opens only when every prerequisite is done or has >= 70% of its target cards; at most 2 topics in progress per domain (WIP limit); only the first eligible topic in outline order per domain is offered, so the curriculum order is respected.
- **Two options:** best candidate, plus the runner-up on a different topic. With probability 0.15 (seeded by day) the second slot is a random other candidate, flagged "A change of pace". This produces unbiased comparison data for a later learned policy and keeps the app from locking onto one domain.
- **Capacity:** `cardsRoom = floor((budget_minutes*60 - due_reviews*avg_sec) / (3*avg_sec))`; 3 = assumed reviews a new card costs in its first week (heuristic, not measured). `avg_sec` is the 30-day mean of logged review durations (12 s default until 20 reviews exist). If room < 3 the screen warns but still allows a small prompt.
- **Same day, same plan:** seed = logical day index. An issued-but-unimported prompt (< 24 h) is shown first with "Show it again / Discard".
- **Logging:** every choice writes `engine_decision` (`planner-1`, seed, capacity, all candidates with features, all scores, shown keys, explore flags and eps, whether the user chose manually, prompt id). Enough to fit weights or do off-policy evaluation later.
- **Rejected:** reinforcement learning / knowledge tracing now. Published methods rely on many learners or on simulated ones to get past the cold start (see the literature summary in the chat); with a single learner there is nothing to fit for months. Revisit once there are a few hundred logged decisions.
- **Revisit if:** the user keeps overriding the top option (the `manual` flag), or WIP limit / 70% gate feels too strict.

## D12 — Outline first
Topics come from an LLM-written outline (`outline-v1` prompt, imported as JSON `{domain, items[{title, level, description, target_cards, prerequisites[]}]}`). Costs one extra paste per subject; gives the app a definition of "covered / not covered". Validation: 1-60 topics, unique titles, levels 1-3, target 3-30, prerequisites must be titles, no self references and no cycles (also checked against existing topics before writing). Unknown prerequisite titles are dropped and reported. A wrong outline is the biggest risk, so the preview shows every topic and its prerequisites before anything is saved, and topics can be marked done/reopened later.

## D13 — Linking imported cards to topics
LLMs rephrase titles. Resolution order: normalised title match -> the topic of the latest unimported prompt in that domain -> a new topic (only if the JSON names one). This prevents phantom topics. Status is derived from card counts (`todo -> active` on first card, `-> done` at target); a manual "done" is never overridden.

## D14 — Restore accepts older backups
Restore refuses only backups from a NEWER schema; older files are migrated by Drift on reopen and then replay-checked. (The first version of restore rejected any version mismatch, which would have made every backup unusable after the first schema change.)

## Threat-model additions
- Outline JSON is untrusted: size caps (60 topics, 120-char titles, 300-char descriptions), strict types, no markup rendering, cycle detection before any write, all writes in one transaction.
- Prompts embed user-controlled text (source text, goal, existing titles, problem cards) into a template with single-pass substitution, so a value containing `{n}` or similar is never re-expanded. The LLM's answer is the real untrusted input and is validated on import.

## D15 — Topics are never "used up": rest, then return deeper
- **Lifecycle:** `todo -> active -> done -> (rest) -> active (round n+1) -> done ...`. A finished topic becomes eligible for a **revisit** after a rest of `base_months x 2^(round-1)` (default base 3 months: 3, 6, 12, 24 ... months), capped at **12 years**. The learner can force "Go deeper now" from the Topics screen at any time.
- **A revisit asks for NEW cards**, not repeats: the prompt says "round N, go deeper (mechanisms, applications, edge cases, misconceptions)", lists the topic's existing cards as do-not-repeat (up to 60), and import still dedupes by normalised front. Prompt version is logged as `v1+deeper`.
- **Mechanics:** choosing a revisit raises the topic's target by the round size (5-10 cards) and sets `rounds+1`, status `active`, so an unimported revisit shows as unfinished work ("deepen") instead of vanishing. The rest clock restarts when cards are imported (`MAX(note.created_at)` for the topic).
- **Scoring:** revisit = (0.5 + up to 0.4 for being overdue + up to 0.1 interest) x subject weight, so it competes below a brand-new topic (1.0) but wins when there is nothing new, or when a subject has been neglected.
- **Learner controls (Settings -> Subjects and topics):** per subject *Off / Low / Normal / High* (score x 0 / 0.6 / 1.0 / 1.4; Off pauses prompts, reviews of existing cards continue), a *Bring finished topics back later* switch, a per-topic *Skip* (never offered, does not block later topics), and a global first-rest length (1-24 months). Topics show "Comes back in about N months".
- **Schema v3:** `domain.learn_weight`, `domain.revisit`, `syllabus_item.rounds`; tested v1->v3 and v2->v3 migrations; restore of older backups still upgrades.
- **Rejected:** fixed "every N days" repetition of the same prompt (would produce duplicate cards); randomly resurfacing finished topics (unpredictable, ignores how long it has been). The doubling rest mirrors how spaced repetition itself treats cards.
- **Revisit if:** the rest feels too long or short (change the base months), or reviews pile up (lower retention or pause subjects; cards never disappear on their own).
- **Lifelong load, honestly:** the app has no card limit, but reviews do not shrink on their own. Mature cards have long intervals, so the daily load grows slowly with the collection; "Learn something new" already limits new cards to the study-time budget left after due reviews.

## D16 — Study advisor: when to add more, when to stop, and why
- **Verdicts:** *Good time* (go), *Go gently* (small batch, max 5), *Hold off* (wait), *Done for today* (stop). Each carries plain-language reasons, shown on Home (compact, "Why?" expands), on the prompt screen, after a review session, and as the gate when you press "Learn something new" while it advises against.
- **Inputs:** reviews due today and their time; minutes already studied today (logged durations) against the daily budget; new cards already added vs today's limit (which shrinks with backlog); reviews already scheduled for the next 7 days; retention over 30 days vs target (only with >= 50 answers); leech count; days since the last session.
- **Rules (hand-set heuristics, not fitted):**
  - stop: today's new-card limit is reached (or 0); or the budget is used up with nothing due; or too little time is left for even a few cards.
  - hold off: due reviews alone are > 90% of the budget; or retention is more than 7 points below target; or the next 7 days already hold >= 80% of the budget in reviews.
  - go gently: retention 3-7 points below target; >= 8 leeches; away more than 10 days.
  - otherwise go: up to `min(time left / (3 reviews x avg seconds), what next week can absorb / 3, new-card limit left, 10)` new cards, and the reason names the constraint that binds.
- **Why a 7-day look-ahead:** new cards cost most of their reviews in the first week, so judging only today's time says "yes" right up to the point where next week becomes impossible. 3 reviews per new card in week one is an assumption; the logged data can replace it.
- **Autonomy:** the app never refuses. When the advice is hold off or stop, pressing the button shows the reasons and offers "Add just 3 cards anyway". Fixing hard cards (remediation) is still offered when the advice is "hold off", because it reduces load; it is not offered when the advice is "stop".
- **Revisit if:** the thresholds feel wrong in daily use. They are constants in `StudyAdvisor`.

## D17 — One press, no choosing
"Learn something new" picks the top-ranked topic and shows its prompt immediately (count capped by the advisor), with the reasons. Choice stays optional: "Try something else" (runner-up), "See all options", and a manual topic picker. The first press on a fresh install adds all bundled subjects (15; the name-it-yourself language template is excluded) so there is always something to pick; each can be turned off in Settings -> Subjects and topics. An unimported prompt from the last 24 h is shown again instead of generating a new one. This replaces the earlier "show two options" screen, at the user's request.

## D18 — Release pipeline
New pushes cancel older builds (`concurrency`), and the rolling `latest-apk` release is updated in place (`gh release upload --clobber`) instead of deleted and recreated, so a cancelled run cannot leave the release empty.

## D19 — Card prompt v2: engaging cards, richer answer side, personal examples
- **Problem:** v1 produced bare Q&A pairs ("soulless"). Chosen: a teacher/storyteller prompt with 7 ranked principles, four dull-vs-great worked examples from different fields, a variety rule, a self-check, and an accuracy rule (vividness never outranks accuracy).
- **Answer side:** new optional fields `why_it_matters`, `example`, `memory_hook` (<= 600 chars each; stored in `fields_json`; shown after reveal under labelled headings). No DB migration: the importer ignores unknown keys, so older prompts and hand-written JSON keep working.
- **Personal relevance:** optional "About you" text (<= 300 chars, Settings) is added to card prompts so examples and analogies fit the learner. It is sent to whichever LLM the user pastes prompts into; the setting says so.
- **Guard rails:** a test extracts the JSON example embedded in the prompt and runs it through the real importer; it checks the example's `back` obeys the prompt's own length rule; the repair prompt (`remediate-v2`) follows the same principles.
- **Rejected:** forcing a "why" on every card (mixed evidence, slower reviews); long answers with the story inside `back` (hurts retrieval and grading); fixed per-subject tone presets (more settings, little evidence).
- **Risks:** longer prompts are followed less closely by some models; vivid stories raise hallucination risk (mitigated by the accuracy rule and the Unverified tag); examples can be copied (mitigated by "never reuse" and the variety rule).
- **Revisit if:** a model keeps ignoring the extras, cards feel formulaic after a few weeks (rotate examples), or `why_it_matters` becomes filler. Template versions are logged per prompt (`prompt_log.template_version`), so batches can be compared.

## D20 — Visual design and the "healthy habit" question
- **Reframing:** the goal is a daily habit people keep because it feels good and works, not compulsion. Engagement tricks (guilt streaks, variable rewards, leaderboards, spend-able currency) are rejected.
- **Evidence (retrieved):** gamification has small-to-moderate effects on learning (g about 0.25-0.5), the weakest on motivation and behaviour (Sailer & Homner 2019); one meta-analysis found better results with four or fewer game elements (Yu et al. 2023). Hence a deliberately small set: (1) a forgiving streak, (2) a daily progress ring, (3) a few real milestones, (4) a session summary. Nothing else.
- **Forgiving streak:** one missed day is bridged once the run before it is >= 3 days, at most once per 7 active days; the forgiven day is not counted. Copy never scolds. The advisor's "Done for today" is a feature: stopping is celebrated, not discouraged.
- **Visual identity:** warm paper neutrals + one vermilion accent (amber in dark mode); Fraunces (soft serif) for headlines and card text, Inter for controls; bundled fonts (SIL OFL), so still offline. Each subject has its own colour family and icon (colour by subject id so neighbours differ). Rating buttons are colour-coded AND labelled with the next interval.
- **Structure:** bottom navigation (Today / Progress / Library); Settings from the Today header. Today = one hero (ring, count, streak, one button), a Learn tile, the advice card, subject tiles. Progress = streak, 17-week activity heatmap, memory strength (long-term = stability >= 21 days), 7-day forecast, milestones. Review = large serif card, tap anywhere to reveal, haptics, session summary with a short confetti (skipped when the system asks for reduced motion).
- **Checks that run in CI:** every text/background colour pair and every subject colour family meets WCAG AA contrast (tests); tap-target size and labelled targets (Flutter guidelines) on Today and Review; no overflow at 160% system text size; reduced-motion behaviour.
- **I can see what I build:** `SCREENSHOT_DIR=... flutter test test/screenshots/screens_test.dart` renders the real screens with the real fonts to PNG (skipped in CI). Viewing them found real defects (identical rating buttons with unreadable labels, an invisible chart bar, a card that ignored taps on its own text). Whether it is *beautiful* still needs your eyes on a phone.
- **Rejected:** heavy animation libraries (Rive/Lottie: size, offline assets, little benefit), leaderboards (single user), points or currency, guilt notifications, per-subject mascot characters.
- **Not built yet:** a daily reminder notification at a chosen time (the single strongest habit cue; needs a notification plugin and an Android 13 permission prompt), sounds, widgets, custom app icon and splash.
- **Revisit if:** the streak or ring starts to feel like pressure (make them optional in Settings), or the user wants more variety (more subject colours/themes).

## D21 — Learn-view speed, and editing / deleting cards
- **Speed:** "Learn something new" ran four correlated subqueries per syllabus topic, each rescanning note / card / review_log (no index on note.syllabus_item_id). Measured 34 s at 25,000 cards, 200 topics, 800,000 log rows. Now one grouped pass per fact (cards and leeches per topic, last-covered per topic, 30-day reviews from review_log_time_idx): 1.0 s on the same data. Remaining cost is queue build plus stats (about 0.3 s each). Host numbers; a phone is slower.
- **Edit:** text only (question, answer or cloze text, and the three optional extras). Scheduling columns are never touched, so history and replay stay valid. Same length limits and the same cloze rule as import. A cloze edit may add a gap (a new card is created with `due` = note.created_at, which rebuild relies on) but may not remove one that already has a card.
- **Delete:** permanent, whole note (all cloze cards), with its review_log rows, in one transaction; review_log has a foreign key to card, so history cannot outlive its card. The dialog names what goes and points to Suspend for a temporary break. Older backups still hold the data.
- **Rejected:** soft delete with a `deleted_at` flag (every query in the app would need the filter, a schema migration, and the user asked for deletion); deleting a single cloze card out of a note (leaves a note whose text still hides a gap with no card).
- **Not built:** undo for delete (the confirm dialog is the guard), bulk delete, editing which topic a card belongs to.
- **Revisit if:** users delete by mistake (add an undo snackbar backed by a 10-second tombstone), or bulk clean-up is needed.

## D22 — Stats cache and streamed, compressed backups (scale work)
- **Stats cache:** Home and Progress scanned the whole review_log (distinct active days, total count, heatmap) on every refresh. Now `activity_bucket` (schema v4) holds answers per 15-minute bucket, caught up incrementally from `review_log` by a watermark (highest counted log id) stored in `setting`, updated in the same transaction. Undo uncounts the row; deleting cards invalidates and the next read rebuilds from the log. 15-minute buckets, not hourly: a day rollover at a :30 or :45 UTC offset would otherwise fall inside a bucket. Measured at 25,000 cards / 800,000 reviews: stats 1,041 ms -> 132 ms warm (the first call after upgrade builds the cache once, about 1.1 s here; seconds at tens of millions of rows). `review_log` stays the source of truth; the cache is disposable (`invalidate()`).
- **Still O(cards) per refresh:** the card-state counts, forecast and per-subject table scan the card table. Fine to roughly 100k cards; at 1M they would need their own incremental counters. Not done: no evidence yet that it matters.
- **Backups:** file-to-file through `saf_stream` `pasteLocalFile` / `copyToLocalFile`, so no backup is ever held whole in memory; the snapshot (`VACUUM INTO`) is gzip-compressed while streaming to a temp file that is deleted afterwards. 85 MB -> 12 MB on synthetic data (real cards compress less; expect 3-4x). New files are `learning-backup-YYYYMMDD.db.gz`; restore detects gzip by its magic bytes, so older plain `.db` backups still restore, and a corrupt archive is refused before the live database is touched. Retention (8) counts both kinds.
- **Verify against current docs / on a device:** `saf_stream` 4.0.2 `pasteLocalFile` and `copyToLocalFile` behaviour (overwrite semantics, very large files) is read from its source, not exercised. Tests use a plain directory storage; the SAF path has still never run on a phone.
- **Rejected:** SQL triggers to maintain counters (would also fire during restore/replay and hide bugs), a separate stats isolate (adds complexity before it is needed), zip with several files (no benefit over one gzip).
- **Revisit if:** the card table exceeds ~100k rows (add incremental card-state counters), or backups of a real multi-year database are still too large (move old review_log rows into yearly summaries).

## D23 — A library that never runs out (growth step)
- **Problem:** the starter outlines are finite (about 2,000 cards). When the learner had covered everything, the Learn screen asked them to browse the starter library or type a subject: a dead end, and a chooser they did not want. The starter library also advertised "about N cards", which read as a ceiling.
- **Decision:** when no card-level option exists (everything covered or resting), the one press produces an OUTLINE prompt automatically, chosen by `GrowthPlanner` (pure, seeded, logged to `engine_decisions` as `growth-v1`):
  1. `resume`: a subject that was started but never received its outline is asked for again (an abandoned prompt must not strand an empty subject).
  2. `expand`: more topics for a used-up subject, picked by weight + interest + staleness - size, with seeded jitter; the batch leans towards one of six rotating angles (advanced, applications, people and history, misconceptions, neighbouring areas, practice) so repeated batches differ.
  3. `discover`: every third growth step starts a brand-new subject from a built-in catalog of 197 subjects in 11 areas (not an LLM call), rotating through areas so none is neglected; never a subject that already exists.
  The learner sees why ("Why this one") and chooses nothing. "See all options" shows the growth step as one more card. Under "wait" / "stop" advice the advice is shown and the learner decides (an outline adds no cards but leads to more).
- **Prompt:** `outline-v2` lists at most the newest 100 existing titles (a lifelong subject can hold thousands) and says to cover different ground. Near-duplicates beyond the listed titles are possible; exact duplicates are dropped on import.
- **Copy:** the starter library says "Starts with N topics" and explains that the library keeps growing; the topics list says "N cards so far" instead of "N of target".
- **Honest limit:** this removes the dead end, not the work. At the 1M-in-40-years pace (68 new cards a day) that is roughly one outline round trip every 3-4 days (about 25 topics each) plus a daily card paste, and the review time is still the binding constraint (see the lifetime simulation).
- **Rejected:** asking the LLM to propose subjects (an extra round trip and an unpredictable list; the catalog is offline and testable); auto-importing without the learner pasting (offline-only app, no network calls); expanding while topics remain (adds clutter with no benefit).
- **Revisit if:** the catalog runs out (the planner then returns nothing and the screen says so), expansion batches feel repetitive (add angles or send more title context), or the every-third-step discover ratio feels wrong (it is one constant).
