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
After "Show answer": the short answer, then labelled sections **Why it matters**, **Example**, **Memory hook** when the card has them (selectable text; a small safe Markdown subset and LaTeX formulas are drawn, see D42).

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
Close, thin progress bar, undo, edit/delete, suspend; under the bar a caption "N left - about M min" (10 s a card until 3 are answered, then the learner's own pace). Card: picture-first when the card has a front picture (edge to edge, up to 320 px high, tap for full screen), then subject, state and "Unverified" tags, the question in serif. Cloze: the blank is a styled gap in the sentence (width never reveals the answer length; the hint shows inside it); on reveal the answer fills that gap in place with a highlight. Tap anywhere (or "Show answer") to reveal (D34: question size follows its length and the Card text size setting; after the reveal a question over 90 characters folds to 3 small lines with "Show the whole question", tap to unfold): the answer panel eases in (short fade, slide and accent bar; instant under reduce-motion). Extras (Why it matters / Example / Memory hook): all shown one under the other, each under its own label (a heading for screen readers); nothing is hidden behind a tap or swipe (D35). The card scrolls if they run past the rating buttons. Four colour-coded rating buttons with next interval. End: ring, summary (cards, time studied, % remembered, time per card), a Again/Hard/Good/Easy bar with counts (screen readers get one sentence), streak, advice, "Back to home".

| State | Shows |
|---|---|
| Front | tags, question or cloze with blank, hint "Think of your answer, then tap to reveal" |
| Revealed | answer panel, extras chips, rating buttons |
| No picture / no extras | those parts are simply absent (no empty boxes) |
| Reduce-motion | no animation; same content |
| Picture missing from the database | the card shows without it |

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

## How it works (guide)
Scrolling page, section headings (semantic headers): The idea; Every day; Learn something new step by step (numbered); Three kinds of prompt (cards, topics, new subjects) with what the answer starts with; How the library grows; Fixing and removing cards; Making cards fit you; Backups; If pasting fails; Privacy. Opened from the ? in the Today header, Settings, the prompt screen, and the one-time "New here?" card (Show me / Not now; either marks it seen, stored in `setting` so it travels in backups).

## Import: several subjects (plan)
Preview lists each proposed subject with a tick-box, its "why", topic count, whether it is new or extends one you have, and the first topics. Invalid subjects show their errors and cannot be ticked. Button: "Add N subjects" (disabled at 0). States: parse error (list of fatal problems), preview, saved message ("Added N subjects with M topics").

## Memory model (Settings > Memory model: fit to my reviews)
Intro; status card (built-in or personal settings, usable reviews, expected vs actual recall); advice card ("Ready now", "In 20 days", "In about 900 more reviews (about 18 days at your pace)" with reasons); Fit button; result card after a fit; go-back link when personal.

| State | Shows |
|---|---|
| Loading | spinner |
| Error | "Could not load: ..." |
| Too early (< 1000 usable reviews) | advice with the missing count and days; button disabled with "Available from 1000 usable reviews." |
| Fitting | indeterminate progress, "can take a minute or two; keep the app open" |
| Better fit | result card: reason, held-out check, "Use the new weights" / "Keep my current settings" |
| No better fit | "Nothing to change" + reason, "OK" (records the check) |
| Applied / kept / reset | confirmation line (live region) |

Today also shows a dismissible card ("Your memory model can be personalised" + the reason, See details / Later) only when a fit is due.

## Diagnostics and phone check (Settings)
Build card (label, built time, OS, counts, DB size, recent backups); 15 check rows, each with Works / Broken toggles (tap again to clear); Notes; Copy report; Errors section with the log tail (monospace, selectable), Clear. States: loading spinner; no errors ("No errors recorded."); error entries listed newest last.

## Daily reminder (Settings)
Switch "Remind me every day"; when on, a button "Around HH:MM" opens the time picker. States: off; on; permission refused (message in a live region, switch stays off).

## Share in / out
Prompt screen: "Send to my AI app" (share sheet). Anything shared to the app opens Import with the preview already showing; not-JSON text shows the normal "can't be imported" explanation; oversized text shows "too large" and does not open Import.

## Looking ahead (Library, Progress)
Explanation; verdict card (green: sustainable; amber: "You will outgrow your time budget in about N months" with the 5-year minutes and the pace that fits); slider "New cards a day" (0-80, debounced re-run); table (6 months, 1, 2, 5, 10 years: reviews and minutes a day, minutes red when over budget; a screen-reader label per row); notes on budget and seconds per review; "Ways to bring it down" (fewer cards, Retire mastered cards, Target recall per subject). States: working (spinner and text), error ("Could not work it out: ..."), result (the table dims with a spinner while a slider run is in progress).

## Retire mastered cards (Library)
Years selector (1, 2, 3), qualifying count with the honest saving, "Retire N cards" with a confirmation dialog, a live-region message, the retired list (newest 50, title, subject, years until next review, "Bring back"), "Bring back all retired cards". States: loading; none qualify ("No cards qualify yet"); some qualify; nothing retired.

## Subjects and topics (addition)
Per subject "Target recall": same as everything else, 80, 85, 90 or 95%, with the hint "Lower means fewer reviews, but you forget a little more."

## Pictures (Edit card, Review)
Edit card: "Picture (optional)" section: an "Image keywords" field first (the AI's `image_query`, editable, kept even with no picture; a web address is refused), then thumbnail (max 180 px high, tap for full screen), "Shows on the question / answer", a description field (300 characters, for screen readers), "Add a picture" or "Change the picture", "Remove the picture". Errors (too large, not a picture) appear in the live region above Save. A picture picked and then abandoned is deleted when the screen closes. Review: the picture sits at the top of the card (question side) or above the answer (answer side); missing picture shows "The picture is missing". A picture found online shows its credit line ("Author · Licence · Wikimedia Commons") under it, but only after the answer is revealed (a credit can name the artist, which would answer "who painted this?").

## Find a picture (Edit card > "Find a picture online")
The one screen that uses the internet (D32). Edit card first asks once ("Look for a picture online?": what is sent, Allow / Not now; also the Settings switch "Find pictures online"). Then: search box prefilled from the card's AI-written `image_query` (empty otherwise); source chips (Wikimedia Commons, Openverse, The Met, Art Institute; at least one stays on; D33); results interleaved from every chosen source as a 2-column grid of thumbnails with names and the source under each; a note names any source that did not answer; tap one to get a larger preview with its credit, description and licence, "Use this picture" or "Back to results". Nothing is saved until "Use this picture"; the description field is never prefilled (a file name usually names the work).

| State | Shows |
|---|---|
| Start, no usable query | search box, hint "Type what the picture should show, then search." |
| Searching / getting the picture | spinner and "Searching Wikimedia Commons…" (live region) |
| Results | grid of up to 8 |
| No results | "No pictures found. Try fewer or more general words, or the name of the work or place." |
| Error (offline, slow, rate limited, too large, not a picture) | the reason in plain words and "Try again" |
| Web address typed as the search | refused without going online ("Type a few words ... not a web address") |
| Preview | picture, name, credit, description, "Is this the right picture for your card?" |
| Not allowed (consent declined or switch off) | the screen does not open; nothing is sent |

Accessibility: tiles are 48 dp or larger and named "Picture: <name>"; busy and error states are live regions; the search field is labelled and submits from the keyboard.

## Read aloud (Subjects and topics, Review)
Per subject: language menu (Off + 19 languages) and, when on, "Which side is written in that language?" (Question / Answer). Top of the screen: "Read aloud automatically". Review: a speaker icon next to the tags (greyed and inert while the language side is the hidden answer); tapping speaks that side with the phone's voice; failures show a snackbar with the reason and how to fix it.

## Settings: Card text size
Small / Medium / Large (default Medium) with a sample line in the chosen size; saves at once. The phone's own font size still applies on top.

## Library > Image keywords for older cards
Count of cards with no keywords and no picture; batch size (20 / 40 / 80); "Send to my AI app", "Copy prompt", "Paste the answer". An answer shared into the app opens this screen's preview directly.

| State | Shows |
|---|---|
| Loading | spinner |
| Nothing missing | "Every card already has image keywords or a picture. Nothing to do here." |
| Cards missing | the count, batch size, the three buttons, steps |
| Prompt copied / shared | "Prompt for N cards copied..." (live region) or the share sheet; share failure suggests Copy |
| Clipboard empty | "The clipboard is empty. Copy the AI's JSON answer first." |
| Answer not usable | "This can't be used:" with the reasons (not JSON, wrong shape, empty, too many entries) |
| Preview | one row per entry: ticked rows with the card's question, keywords and picture side; other rows say why skipped (no such card, already has keywords, already has a picture, not usable, repeated) |
| Applied | "Added keywords to N cards. M still have none: send the next batch." / "Every card now has keywords." |

## Library > Go deeper: reading list (D37)
Header note (AI suggestions; "found" means listed, not good), "Check all that have not been checked", then entries grouped by subject. Each entry: kind and topic, title, author, why, a status line with icon AND words, and actions: Check it exists / Check again, Look it up (opens the catalogue page in an in-app browser tab), Mark as read / Not read yet, Remove (asks first). First check asks once for consent (names Open Library and Crossref, says what is sent).

| State | Shows |
|---|---|
| Loading | spinner |
| Error loading | "Could not load: ..." |
| Empty | "No reading suggestions yet." and where they come from |
| Entry not checked | "Not checked yet" and Check it exists |
| Checking | spinner in place of the buttons; "Checking..." on Check all |
| Found | "Listed in Open Library" or "Listed in Crossref", the catalogue's title and year, Look it up |
| Not found | "Not found in the catalogue: the title or author may be wrong" and Check again |
| Cannot be checked (course, other) | "Cannot be checked automatically" at once |
| Check failed (offline, rate limit) | message naming the entry and the reason (live region); the entry stays unchecked; Check all stops at the first failure |
| Consent declined | nothing is sent; asked again next time |

## After adding a subject or topics (Import)
Under the "Added N topics" / "Imported N notes" message a button "See the topics and choose what to learn" opens that subject's Topics screen (after a several-subjects paste: "Back to the Library to see them"). Topics screen: a one-line hint, then each topic with its status; tap one for "Make cards for this topic", "Skip this topic (never offer it)" or "Mark as done". Library: "Tap a subject to see its topics and choose what to learn." Reported on the phone: a new subject's topics could not be found; they were always under the subject's tile in Library, but nothing said so.

## Settings > Subjects and topics: the topics themselves (reported: new topics could not be found here)
Each subject card now shows its topics straight under the subject name: "Topics: N of M offered", a tick-box per topic (ticked = offered for new cards; unticked = skipped, shown as "Not offered"), each with its status ("Not started", "In progress", "Covered") and card count, plus "Offer all" and "Offer none" (done topics are left alone by "Offer none"). The list is open for a new subject (no cards yet) or one with 10 topics or fewer, collapsed for a large one. Below it the existing controls (how often, bring finished topics back, target recall, read aloud) and "More about each topic" (the full Topics screen: make cards now, mark done). No topics yet: "Learn something new will ask your AI for an outline."

## Simplify pass (D38)
- **Library:** zones in reading order: title and hint; Subjects grid; Add to your library; Manage; Advanced (collapsed ExpansionTile: Looking ahead, Retire mastered cards). Collapsed by default; the tile is keyboard- and screen-reader operable (native ExpansionTile, expanded state announced).
- **Settings and backup:** "How the app works" first; Advanced (collapsed) at the bottom above Save: Memory model, Diagnostics and phone check.
- **Review:** the tag row shows subject and state only (New / Learning / Review / Forgotten); no Unverified tag.
- States are unchanged for the screens opened from these entries.

## Review: undo bar, learn-ahead, about this card (D40)
- **Undo bar:** zone above the answer buttons; text "Rated <rating>" and an Undo button (48 dp); live region; 6 s; hidden by Undo, by the next answer replacing it, or on leaving. On the finished screen it sits near the bottom.
- **Learn-ahead:** the queue appends not-yet-due learning cards (within the setting) only when it is otherwise empty. "Next card in about N min" appears only when no card is within the window.
- **About this card (bottom sheet from the state tag, 48 dp target, label "<State>. About this card's memory"):** reading order: state title + plain explanation; Memory statistics; How this memory fades (chart with a text equivalent); Your last answers; footnote about estimates.
- **States:** loading (spinner); error ("Could not load the card details"); new card (explanation + times answered/forgotten; "Nothing to show yet" for the model numbers); partial (a learning card with a stability but no history: numbers without the list); success (all sections).

## About this card: Build the foundations (D41)
- **Zone:** under the state explanation. Text "Hard, but you like the idea? Get 2 to 4 short cards on the ideas it rests on, from your own AI." and a full-width button (52 dp) "Build the foundations".
- **Result:** the sheet closes and "Your prompt" opens (Copy / Send to my AI app / Paste the answer), with two reasons. The same prompt is shown again if it was never imported.
- **States:** none yet (button); already done ("Foundations added: N cards that prepare you for this one", check icon); the card is itself a foundation (a sentence saying so, no button); error (snackbar "Could not build the prompt"). After import the cards appear first among new cards.

## Card text: Markdown and formulas (D42)
- **Where:** review (question, folded question, answer, Why it matters / Example / Memory hook, cloze sentence and its revealed gap); Edit card shows a live preview under any field that has formatting or formulas; Browse and read-aloud use the plain text.
- **Drawn:** **bold**, *italic*, `code`, "- " bullets, "1. " numbers, paragraphs, inline $formula$ and standalone $$formula$$. **Never drawn:** HTML, links, images, headings, tables (shown as the text they are).
- **States:** plain text (unchanged); formatted; formula cannot be drawn (its LaTeX source is shown in monospace); formula too long (> 500 characters) or more than 40 in one text (shown as text); display formula wider than the screen (scrolls sideways). Each formula has a screen-reader label "formula: <LaTeX>".
