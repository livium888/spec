# Decision records

## D1 — FSRS implementation: Dart `fsrs` port behind `Scheduler`, not fsrs-rs via FRB
- **Chosen:** `fsrs` 2.0.1 (MIT, open-spaced-repetition/dart-fsrs), 21 params (FSRS-6), wrapped by `DartFsrsScheduler`.
- **Rejected:** fsrs-rs + flutter_rust_bridge. Needs NDK cross-compile, Rust toolchain in CI, and cannot be verified without an Android device/emulator. Gains the optimizer, which v1 does not use.
- **Finding (verified against fsrs-rs `inference_v6.rs`):** the Dart package's default weights are py-fsrs defaults with decay `w[20]=0.2`, NOT the spec's 0.1542. We inject fsrs-rs `FSRS6_DEFAULT_PARAMETERS` (decay 0.1542) explicitly.
- **Known divergences from fsrs-rs** (verify against current docs): the Dart port floors elapsed time to whole days for retrievability and treats `<1 day` as same-day; fsrs-rs uses fractional days. Intervals can differ slightly from Anki's. fsrs-rs main now also ships a v7 model; v1 targets v6.
- **Revisit if:** the optimizer is needed (engine phase) -> add an `FsrsRsScheduler`; the interface already allows it.

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
