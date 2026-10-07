# Screens, flows and states (v1)

Target surface: Flutter Material 3, Android phone, one-handed portrait, sideloaded. Offline.
Accessibility baseline (WCAG 2.2 AA): targets >= 48dp, text scales with system font size, nothing
conveyed by colour alone (status always has a text label + icon), every icon button has a tooltip /
semantic label, errors say what happened and what to do. Visual polish and real-user testing need a human.

## Flows
1. Daily: Home -> Review -> (session ends) -> one-tap interest per domain touched -> Home.
2. LLM loop: Home -> Prompt builder (domain, count, optional source) -> copy -> [external LLM] -> Import -> Paste -> Preview -> Import.
3. Backup: Settings -> choose folder (once) -> auto weekly + on open; manual button. Restore: Settings -> pick file -> validate -> report.

## Home
Zones: (1) backup status line, (2) per-domain cards (due / new / leeches), (3) primary action "Review (N)", (4) secondary: Import, Prompt, Add card, Settings.
| State | Behaviour |
|---|---|
| loading | progress indicator |
| empty (no domains) | explains the loop, buttons: Import, Prompt builder |
| nothing due | "All done for today" + next learning due time if any |
| backup never / >14d | text "No backup yet" / "Last backup N days ago - overdue" + warning icon + red; tap opens Settings |
| error | message + Retry |

## Review
Zones: top bar (progress "12 left", undo, menu: suspend), card (domain, unverified marker, front), reveal area, rating row.
Primary action: "Show answer" then four rating buttons with labels `Again 1m / Hard 6m / Good 10m / Easy 4d`.
| State | Behaviour |
|---|---|
| front shown | tap anywhere/button reveals |
| answer shown | 4 buttons with next interval text (also read by screen reader) |
| undo | restores previous card and shows it unrevealed; disabled if nothing to undo |
| learning cards not yet due | "Next card in 4 min" with remaining count |
| queue empty | summary (answered, time) then interest prompt per domain (skippable) |
| leech hit | snackbar "Marked as leech and suspended" |
| error | snackbar + stay on card; answer not lost |

## Import
Paste from clipboard (explicit tap only) -> preview. Per-card rows: status (OK / Invalid + reasons / Duplicate), unverified marker, checkbox. "Import N cards".
| State | Behaviour |
|---|---|
| empty | instructions + paste button |
| fatal error | list of schema errors, nothing importable |
| partial | invalid cards listed with reasons, valid ones selectable |
| new domain | banner "Domain 'X' will be created" |
| success | counts + back to Home |

## Prompt builder
Domain (existing), optional syllabus item, count (1-50), optional source text -> Generate -> shows prompt, Copy. Writes prompt_log (status issued).

## Settings & Backup
New cards/day, backlog divisor, desired retention, learning steps, relearning steps, day rollover hour; backup folder, Backup now, Restore from file / latest.
| State | Behaviour |
|---|---|
| no folder | Backup disabled with explanation |
| backing up | progress, buttons disabled |
| restore | confirm dialog (destructive) -> validate -> report counts + mismatches |
