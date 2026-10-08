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

## Learn something new (Home -> button)
Zones: capacity line, warning banner (if reviews use up the budget), pending-prompt card, 1-2 option cards, secondary actions.
Primary action per option card: "Use this". Each card shows kind (New topic / Go deeper / Fix hard cards), card count, headline, and the reasons in words.
| State | Behaviour |
|---|---|
| loading | progress indicator |
| error | message + Retry |
| no subjects | "Start with a subject" + button to the outline flow |
| subjects without topics | "No topics yet" + same button |
| everything covered | "Everything in your outlines is covered" + add topics |
| one option | heading "Suggested for today" |
| two options | heading "Pick one"; the second may carry "A change of pace" |
| budget used up | warning banner; options still offered with a small card count |
| unimported prompt (< 24 h) | card with "Show it again" / "Discard it" |
Keyboard/screen reader: option buttons are full-width, >= 52dp, labelled by their card.

## Prompt result
Steps 1-4 in words, "Copy prompt" (primary), "Paste the answer" (opens Import), collapsible full prompt. Errors: none (pure display).

## New subject or more topics
Subject (chips for existing ones), optional goal. Validation messages inline. Success opens Prompt result for `outline-v1`.

## Topics
Per domain list of topics with status in words (Covered / In progress / Not started), "x of y cards", and "After: prerequisites". Tap: make cards for this topic, mark done, reopen. In pick mode (from "Choose a topic myself") a tap goes straight to a prompt and is logged as a manual choice.

## Import (outline mode)
Pasting JSON with `items` shows the outline preview: new vs existing subject banner, each topic with level, target cards, prerequisites, errors and warnings; "Add N topics". Fatal errors (loop, duplicates, bad shape) list reasons and block import.

## Starter library
List of bundled subjects (name, topics, about N cards) with **Add**. A "Language course" template asks you to name it first. Added subjects show "Added". States: loading, error with message, list. Works offline.

## Settings -> Subjects and topics
Per subject: name, "x of y topics covered", *Off / Low / Normal / High* (paused text when Off), switch *Bring finished topics back later*, button *Topics*. Button to add subjects from the starter library.
Topics screen additions: statuses in words (Covered / In progress / Skipped by you / Not started), "round n", "Comes back in about N months" / "Due for a deeper pass now"; tap menu: make cards / go deeper now, skip or include again, mark done / reopen.
Learn screen additions: option kind "Revisit" with the reason "You last added cards to X 4 months ago (round 1)"; empty state "Everything is covered for now" with when the next revisit is due; "All your subjects are paused".

## Advice card (Home, prompt screen, end of review session, Learn gate)
Icon + label + headline + reasons; label is one of "Good time", "Go gently", "Hold off", "Done for today" (words and icon, never colour alone). Compact form shows one reason and a "Why?" expander.

## Learn something new (current behaviour)
| State | Behaviour |
|---|---|
| first ever press | "Setting up your starter subjects..." then straight to the prompt |
| advice go / gently | spinner "Picking something for you..." then prompt screen with "Why this one", the advice, copy/paste steps, "Try something else", "See all options" |
| unimported prompt < 24 h | that prompt, flagged "You asked for this earlier...", with "Discard and pick again" |
| advice hold off / done | advice card with reasons; "OK, reviews first" / "OK, I will stop here"; "Add just 3 cards anyway" |
| nothing to offer | explanation (all covered with when the next revisit is due, all subjects paused, no topics) and buttons to the library / new subject |
| error | message + Retry |

## Review: answer side
After "Show answer": the short answer, then labelled sections **Why it matters**, **Example**, **Memory hook** when the card has them (plain selectable text, never rendered as markup).

## Settings: About you
Optional multi-line field (300 characters) with a note that it is added to card prompts and so goes to the LLM you paste into.

## Navigation (current)
Bottom bar: **Today**, **Progress**, **Library**. Settings is the gear in the Today header.

## Today
Greeting + date; hero card (progress ring with cards left, headline, streak with a 7-day strip, one primary button: "Start review" / "Keep going" / "Get started"); "Learn something new" tile; advice card; horizontal subject tiles (icon, name, due count, long-term-memory bar); backup status.
| State | Behaviour |
|---|---|
| no cards yet | ring empty, "Let's plant your first cards", button "Get started" |
| cards waiting | "N cards waiting", about M min, "Start review" (or "Keep going" if some answered) |
| all done | check in the ring, "All done for today", how many tomorrow |
| caught up | "You're all caught up", how many tomorrow |
| streak at risk | "N-day streak · rest day used" when yesterday was forgiven |
| error | message + Retry |

## Progress
Streak card (current, best); 17-week activity heatmap with a text summary; long-term memory count and 30-day recall; stacked bar New / Learning / Growing / Long-term; 7-day forecast bars; milestones (earned or n/goal).

## Library
Subject tiles (2 columns) and the ways to add: starter library, paste an answer, new subject, custom prompt, add a card; Browse cards; Subjects and topics settings.

## Review (current)
Close, thin progress bar, undo, edit/delete, suspend. Large card: subject tag, state tag, "Unverified" tag, question in serif. Tap anywhere (or "Show answer") to reveal: short answer, then Why it matters / Example / Memory hook. Four colour-coded rating buttons with next interval. End: ring, summary (cards, time, % remembered), streak, advice, "Back to home".

## Browse cards (Library -> Browse, edit or delete cards)
Search box (literal match on question/answer text, 300 ms debounce), newest first, 50 per page with "Show more"; tap a row to edit.

| State | Shows |
|---|---|
| Loading | spinner |
| Empty, no search | "No cards yet." |
| Empty, search | "No card matches that." |
| Error | "Could not load: ..." |
| Success | rows: question (2 lines), subject, kind |

## Edit card
Fields by kind (basic: Question, Answer; cloze: Text with gaps, Answer extra) plus optional Why it matters, Example, Memory hook. Save validates with the same limits as import; errors appear in a live region under the fields and nothing is saved. Delete (app bar) asks for confirmation naming how many cards and reviews go.

| State | Shows |
|---|---|
| Loading | spinner |
| Not found (deleted elsewhere) | "This card no longer exists." |
| Invalid | red messages, fields kept |
| Saved / Deleted | pops with a result; the caller reloads |

## Learn something new: growth states (added)
| Situation | What the one press does |
|---|---|
| Topics available | prompt for the best topic (unchanged) |
| Everything covered or resting | outline prompt: "More topics for X", or "A new subject: Y" every third time; reasons shown |
| A subject has no outline yet | the outline prompt is shown again |
| Advice says wait / stop and nothing to teach | advice card plus a "Grow your library" card with a "Get this prompt" button |
| Nothing can grow (no subjects usable and catalog exhausted) | the old empty state with Starter library / New subject |
