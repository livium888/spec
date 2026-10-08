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
