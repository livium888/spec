/// The longest a single card counts as "time spent". A card left open while the phone is put down
/// would otherwise add hours to the session summary, the time estimate and the study-time stats.
/// (Anki caps answer time the same way, at 60 seconds.) The raw time is not kept: it was junk.
const kMaxCardMs = 60000;

int cappedCardMs(int elapsedMs) => elapsedMs < 0 ? 0 : (elapsedMs > kMaxCardMs ? kMaxCardMs : elapsedMs);

/// Problem cards (D43) are worked out on paper, so a longer pause is real work, not an idle phone.
const kMaxProblemCardMs = 600000;

int cappedProblemMs(int elapsedMs) => elapsedMs < 0 ? 0 : (elapsedMs > kMaxProblemCardMs ? kMaxProblemCardMs : elapsedMs);
