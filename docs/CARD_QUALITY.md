# What makes a card worth reviewing for years

The card prompt (template `v2`) is built on these principles. Evidence marked **(retrieved)** was checked
in this project; **(from memory)** is well-known work not re-verified here.

## Principles and why
1. **Make the learner want the answer (curiosity).** High-curiosity states improve memory for the answer; a 2026
   meta-analysis of 47 studies found a moderate effect (g = 0.44) **(retrieved: Radhakrishna et al.; Gruber et al., Neuron 2014)**.
   Guessing before seeing the answer helps that specific answer **(retrieved: Hollins et al. 2022, "pre-testing effect")**.
   -> Fronts are puzzles, surprises and "what would happen if", not labels.
2. **Explain, but do not turn every card into "why".** Self-explanation prompts help (g = 0.55; Bisra et al. 2018)
   **(retrieved)**, yet plain "why does this make sense" questioning was no better than repetition in one study
   (O'Reilly et al. 1998) **(retrieved)**, and effects depend on how the prompt is designed (Rittle-Johnson et al. 2017) **(retrieved)**.
   -> The reason/story lives in `why_it_matters` on the answer side; the question stays quick to retrieve.
3. **Practice testing and spacing do the heavy lifting.** They had the largest effects across ten techniques
   (Donoghue & Hattie 2021) **(retrieved)**, with the caveat that most studies measured factual recall.
   -> Spacing is FSRS's job; the prompt's job is cards worth testing.
4. **One idea per card, short answer, no lists, cloze for sentences, concrete examples, mnemonics, personal
   relevance, sources.** Wozniak's "20 rules of formulating knowledge" **(from memory)**; the self-reference effect
   (Symons & Johnson 1997) **(from memory)** is why the optional "About you" text exists.
5. **Cards must stand alone for years.** Shuffled order, no "previous card", name the field when a term is ambiguous.
6. **Accuracy beats vividness.** Vivid detail is where LLMs invent; the prompt says to drop any detail it is not
   certain of, and the app marks unsourced cards "Unverified".

## Card anatomy in the app
`front` -> (reveal) -> `back` (short, exact) + **Why it matters** + **Example** + **Memory hook** (all optional, each a sentence or two, capped at 600 characters).

## How to judge a batch (30 seconds)
- Read three fronts. Do you want to know the answers? If they read like a glossary, the prompt is not working.
- Is every `back` under about 15 words? Is the story in `why_it_matters`?
- Any vivid detail you do not believe? Check it; the app's "Unverified" tag exists for this.
- Are there at most two cards of the same shape in a row?

## Honest limits
- Not tested against other LLMs (Gemini, ChatGPT, DeepSeek) in this project. Models differ in how closely they follow long prompts; if one ignores the extras, tell the app's developer which one and how.
- The effect sizes above come from lab and classroom studies of other learners; they justify the design but do not guarantee you will find the cards enjoyable. The real test is whether you still want to open them in month three.
