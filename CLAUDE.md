# Daily Learning App — project rules

## Always apply the `principal-architect` skill
`.claude/skills/principal-architect/SKILL.md` governs ALL work in this repo:
building, answering questions, and reviewing. Load it (Skill tool) at the start of any
session and follow it. Scale the process to the request (a one-line fix gets scope + change +
verification), but never skip: stated assumptions, decision records, state tables for every
screen (empty/loading/error/partial/success), threat-model notes for external input
(JSON import, backup restore, SAF), WCAG 2.2 AA, a "verify against current docs" mark on
version-sensitive facts, and a self-critique before presenting.

Decisions go in `docs/DECISIONS.md` (chosen, rejected, revisit-if). Screen specs and state
tables go in `docs/SCREENS.md`. Update them in the same commit as the code they describe.

## Architecture rules (from the build spec)
- Clean Architecture: `lib/domain` (no Flutter/Drift imports), `lib/data`, `lib/presentation`.
- `review_log` is the source of truth; card scheduling fields are a rebuildable cache.
- Scheduling must be pure + deterministic (replay == live). Fuzz is seeded, never `Random()`.
- All time = UTC epoch ms; day rolls over at 04:00 local (configurable).
- Do NOT copy Anki source (AGPL). Reimplement behaviour only.
- Offline only. No network calls from the app.

## Tooling
Flutter SDK may be at /opt/sdk/flutter (not preinstalled). Tests: `flutter test`.
