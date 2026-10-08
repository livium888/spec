# Starter outlines

Eleven ready-to-import outlines (136 topics, about 1270 cards at the target counts). Each `.json` file is one subject in the app's outline format: copy the file's contents, open the app, **Import -> Paste from clipboard**, review the preview, **Add topics**.

## What this list is, and is not

- It is **one person's (Claude's) curated map**, not a ranking and not data. Nobody has measured "what the most successful people know"; lists that claim to are survivorship-biased (you only see the winners' habits, not the many who shared them and failed).
- Its design leans on well-known ideas, named from memory and not re-verified here: Charlie Munger's "latticework of mental models", Richard Hamming's *You and Your Research*, the liberal-arts tradition, and Kahneman/Tversky-style decision research.
- The one piece of evidence consulted: Nobel laureates are significantly more likely than other scientists to be polymaths with wide non-specialist interests (Root-Bernstein et al., *Creativity Research Journal*, 2020 and 2022). That is correlational and about Nobel laureates, not about wealth or power.
- Order inside each subject follows prerequisites. Topics marked level 1 are foundations. Country-specific topics (tax wrappers, legal forms) should be learned for where you live.
- Edit freely: drop subjects you do not care about, or ask the app's outline prompt for a subject that is missing (art, music, languages, a craft; the research above suggests those matter too).

## Topics

### 1. Thinking and Decisions (14 topics) - `01-thinking-and-decisions.json`

- **Mental models and the map is not the territory** (L1) - Why every model simplifies, and how to hold several at once.
- **Cognitive biases** (L1) - Confirmation, anchoring, availability, hindsight and overconfidence.
- **Incentives** (L1) - How behaviour follows rewards, and how to read a situation by its incentives.
- **Opportunity cost and trade-offs** (L1) - The real cost of a choice is the best alternative given up.
- **Circle of competence** (L1) - Knowing what you know, what you do not, and acting accordingly.
- **Fermi estimation** (L1) - Getting a usable answer from rough numbers and order-of-magnitude reasoning.
- **Second-order effects** (L2) - Consequences of consequences, and unintended outcomes. *After: Mental models and the map is not the territory*
- **Inversion and pre-mortems** (L2) - Solve problems backwards: what would guarantee failure? *After: Mental models and the map is not the territory*
- **Sunk costs and when to quit** (L2) - Ignoring past spend; deciding on future costs and benefits only. *After: Cognitive biases; Opportunity cost and trade-offs*
- **Base rates and reference classes** (L2) - Starting from how often things happen before adding the specifics. *After: Cognitive biases*
- **Systems thinking** (L2) - Feedback loops, delays, bottlenecks and leverage points. *After: Mental models and the map is not the territory*
- **Probabilistic thinking and calibration** (L2) - Expressing beliefs as probabilities and checking how often you are right. *After: Base rates and reference classes*
- **Expected value and risk of ruin** (L2) - Why a positive-expectation bet can still be a bad bet. *After: Probabilistic thinking and calibration*
- **Decision journals and reversible decisions** (L2) - Recording reasoning, separating luck from skill, and sizing effort to reversibility. *After: Expected value and risk of ruin*

### 2. Maths and Statistics (12 topics) - `02-maths-and-statistics.json`

- **Exponentials, logarithms and compounding** (L1) - Growth that multiplies, and why intuition fails at it.
- **Percentages, ratios and orders of magnitude** (L1) - Fluent everyday quantitative reasoning.
- **Probability basics** (L1) - Events, independence, complements, and the sum and product rules.
- **Combinatorics and counting** (L2) - Permutations, combinations and counting outcomes. *After: Probability basics*
- **Conditional probability and Bayes' theorem** (L2) - Updating beliefs with evidence; the base-rate trap. *After: Probability basics*
- **Expected value and variance** (L2) - Average outcome and spread of outcomes. *After: Probability basics*
- **Distributions: normal, power law and fat tails** (L2) - Which shapes describe heights, wealth, wars and failures. *After: Probability basics*
- **Sampling, confidence intervals and significance** (L2) - What a sample can and cannot tell you; what p-values mean. *After: Distributions: normal, power law and fat tails*
- **Correlation, causation and confounding** (L2) - Why two things moving together proves little. *After: Sampling, confidence intervals and significance*
- **Regression to the mean and survivorship bias** (L2) - Two traps that make noise look like skill. *After: Correlation, causation and confounding*
- **Experiments and A/B tests** (L3) - Randomisation, controls and designing a test that can answer the question. *After: Correlation, causation and confounding*
- **Linear regression intuition** (L3) - Fitting a line, reading coefficients, and overfitting. *After: Correlation, causation and confounding*

### 3. Money and Investing (15 topics) - `03-money-and-investing.json`

- **Budgeting, cash flow and savings rate** (L1) - Where money goes, and why the savings rate beats the return early on.
- **Compound interest and the time value of money** (L1) - Why a sum now is worth more than later, and how time does the work.
- **Inflation and real returns** (L1) - Purchasing power and returns after inflation.
- **Emergency funds and insurance basics** (L1) - Insuring against ruin, not against small losses.
- **Debt, interest rates and credit** (L1) - Good versus bad debt, APR, credit scores and amortisation.
- **Stocks, bonds and funds** (L2) - What each asset is, who pays you, and how they differ in risk.
- **Risk, return and diversification** (L2) - Why spreading bets lowers risk without lowering expected return. *After: Compound interest and the time value of money*
- **Index funds and fees** (L2) - Low-cost passive investing and why fees compound against you. *After: Stocks, bonds and funds; Risk, return and diversification*
- **Retirement and tax-advantaged accounts** (L2) - Country-specific wrappers that shelter growth; learn the ones for where you live. *After: Compound interest and the time value of money*
- **Property as an investment** (L2) - Leverage, rent versus buy, yields and illiquidity. *After: Debt, interest rates and credit*
- **Reading financial statements** (L2) - Income statement, balance sheet and cash flow, and how they connect.
- **Valuation: price versus value** (L3) - Discounted cash flow, multiples and margin of safety. *After: Reading financial statements; Compound interest and the time value of money*
- **Market cycles, bubbles and crashes** (L3) - How booms and busts form, and why timing them fails. *After: Stocks, bonds and funds*
- **Leverage and risk of ruin** (L3) - Why borrowed money turns survivable losses into fatal ones. *After: Debt, interest rates and credit; Risk, return and diversification*
- **Options and derivatives basics** (L3) - Calls, puts, hedging versus speculation, and what can go wrong. *After: Stocks, bonds and funds*

### 4. Economics (14 topics) - `04-economics.json`

- **Supply and demand** (L1) - How prices coordinate buyers and sellers, and what shifts the curves.
- **Scarcity, trade-offs and incentives** (L1) - The core economic frame applied to everyday choices.
- **Comparative advantage and trade** (L1) - Why both sides gain from specialising and trading.
- **GDP, inflation and unemployment** (L1) - What the headline numbers measure and what they miss.
- **Elasticity and pricing** (L2) - How sensitive demand is to price, and what that means for revenue. *After: Supply and demand*
- **Market structures: competition, monopoly and oligopoly** (L2) - How the number of firms changes prices and behaviour. *After: Supply and demand*
- **Network effects and winner-take-all markets** (L2) - Why some products get more valuable as more people use them. *After: Market structures: competition, monopoly and oligopoly*
- **Externalities and public goods** (L2) - Costs and benefits that markets ignore, and common remedies. *After: Supply and demand*
- **Money, banks and central banks** (L2) - How money is created, what banks do, and what a central bank controls. *After: GDP, inflation and unemployment*
- **Interest rates and the business cycle** (L2) - Why rates move, and how they ripple through the economy. *After: Money, banks and central banks*
- **Fiscal policy, debt and deficits** (L2) - Government spending, taxes and what debt sustainability means. *After: GDP, inflation and unemployment*
- **Behavioural economics** (L2) - Where real people depart from rational-agent models.
- **Growth, productivity and inequality** (L3) - What drives long-run prosperity and how gains are shared. *After: GDP, inflation and unemployment*
- **Financial crises** (L3) - Common anatomy of crises: leverage, runs, contagion and policy response. *After: Money, banks and central banks; Interest rates and the business cycle*

### 5. Business and Strategy (15 topics) - `05-business-and-strategy.json`

- **Business models and unit economics** (L1) - How a business makes money per customer, and when it scales.
- **Customer problems and product-market fit** (L1) - Finding a painful problem and proving people will pay for the fix.
- **Competitive advantage and moats** (L2) - What protects profits from competitors: scale, brand, switching costs, network effects. *After: Business models and unit economics*
- **Strategy and positioning** (L2) - Choosing where to play and what to leave out. *After: Competitive advantage and moats*
- **Pricing and margins** (L2) - Cost-plus versus value pricing, gross margin and discounting traps. *After: Business models and unit economics*
- **Marketing, distribution and channels** (L2) - Reaching customers cheaply and repeatably. *After: Customer problems and product-market fit*
- **Sales and customer acquisition cost** (L2) - Funnels, CAC versus lifetime value, and sales process basics. *After: Business models and unit economics; Marketing, distribution and channels*
- **Operations, bottlenecks and the Theory of Constraints** (L2) - Throughput is set by the slowest step; improve that first.
- **Hiring and building a team** (L2) - Defining the role, structured interviews and hiring slowly.
- **Management, delegation and feedback** (L2) - Clear expectations, regular one-to-ones and useful feedback. *After: Hiring and building a team*
- **Organisational culture and incentives** (L3) - Culture is what gets rewarded and tolerated. *After: Management, delegation and feedback*
- **Negotiation** (L2) - Interests versus positions, BATNA, anchoring and listening.
- **Contracts, IP and company structure basics** (L2) - What a contract binds, how IP is protected, and common company forms.
- **Startup funding, equity and dilution** (L3) - Cap tables, term-sheet basics and the trade-offs of raising money. *After: Business models and unit economics*
- **Innovation and disruption** (L3) - How incumbents get displaced and how new entrants win. *After: Competitive advantage and moats*

### 6. Psychology and Influence (12 topics) - `06-psychology-and-influence.json`

- **How memory and attention work** (L1) - Encoding, forgetting, working memory and why focus is limited.
- **Motivation and habits** (L1) - Cues, routines and rewards; what sustains effort.
- **Emotional intelligence and self-awareness** (L1) - Noticing, naming and managing emotions, yours and others'.
- **Active listening and asking good questions** (L1) - Understanding before replying.
- **Clear writing** (L1) - Short sentences, concrete words, one idea at a time.
- **Stress, resilience and burnout** (L2) - What stress does, recovery, and early warning signs. *After: Emotional intelligence and self-awareness*
- **Persuasion principles** (L2) - Reciprocity, commitment, social proof, authority, liking and scarcity.
- **Storytelling and public speaking** (L2) - Structure, clarity and delivery under pressure. *After: Clear writing*
- **Conflict and difficult conversations** (L2) - Staying curious, separating facts from stories, and repairing. *After: Active listening and asking good questions*
- **Group dynamics, status and social proof** (L2) - Conformity, hierarchy, and how groups decide.
- **Personality and individual differences** (L3) - What trait models do and do not predict.
- **Cognitive behavioural principles** (L3) - Thoughts, feelings and behaviour as a loop you can intervene on. *After: Emotional intelligence and self-awareness*

### 7. Technology and AI (12 topics) - `07-technology-and-ai.json`

- **How computers and the internet work** (L1) - Hardware, operating systems, networks, protocols and the web.
- **Programming fundamentals** (L1) - Variables, control flow, functions and data structures.
- **Data, databases and spreadsheets** (L1) - Tables, queries, and reasoning about data.
- **Cybersecurity and privacy basics** (L1) - Passwords, phishing, encryption in daily life and threat models. *After: How computers and the internet work*
- **Algorithms and complexity** (L2) - Sorting, searching, Big-O and why scale changes everything. *After: Programming fundamentals*
- **Software engineering practice** (L2) - Version control, testing, review and maintaining code over time. *After: Programming fundamentals*
- **Cloud, platforms and APIs** (L2) - How modern products are built on rented infrastructure and interfaces. *After: How computers and the internet work*
- **Cryptography and blockchains** (L2) - Hashes, keys, signatures, and what blockchains do and do not guarantee. *After: Cybersecurity and privacy basics*
- **Machine learning basics** (L2) - Training, generalisation, overfitting and evaluation. *After: Data, databases and spreadsheets*
- **Exponential technologies: chips, energy and biotech** (L2) - Cost curves that drop predictably and what they unlock.
- **Large language models and their limits** (L3) - How they work in outline, where they fail, and how to use them safely. *After: Machine learning basics*
- **Automation and the future of work** (L3) - Which tasks automate first and how people and firms adapt. *After: Large language models and their limits*

### 8. History and Power (12 topics) - `08-history-and-power.json`

- **How to read history: sources, bias and narrative** (L1) - Primary versus secondary sources and who wrote the record.
- **The agricultural and industrial revolutions** (L1) - The two shifts that reshaped population, wealth and power.
- **Political systems: democracy, autocracy and federalism** (L1) - How power is acquired, shared and constrained.
- **Law and the rule of law** (L1) - What legal systems do and why predictable rules matter.
- **The rise and fall of empires** (L2) - Recurring patterns of expansion, overreach and decline.
- **Origins and consequences of the World Wars** (L2) - Causes, turning points and the settlements that followed.
- **History of money and finance** (L2) - From commodity money to central banking and modern credit.
- **Media, propaganda and information warfare** (L2) - How narratives are shaped and how to spot manipulation.
- **The Cold War and the post-war order** (L2) - Alliances, institutions and rivalry after 1945. *After: Origins and consequences of the World Wars*
- **Modern China** (L2) - Revolution, reform and the rise of a manufacturing and technology power. *After: The Cold War and the post-war order*
- **Geopolitics: geography, energy and chokepoints** (L2) - How geography and resources shape strategy. *After: The Cold War and the post-war order*
- **Power, institutions and bureaucracy** (L3) - How organisations hold and exercise power over time. *After: Political systems: democracy, autocracy and federalism*

### 9. Science and Health (12 topics) - `09-science-and-health.json`

- **The scientific method and falsifiability** (L1) - Hypotheses that can be wrong, and why that matters.
- **Evolution and natural selection** (L1) - Variation, inheritance and selection as a general explanation.
- **Cells, DNA and genetics** (L1) - The machinery of life and how traits are inherited.
- **Sleep** (L1) - What sleep does, how much you need and how to protect it.
- **Nutrition and metabolism** (L1) - Energy balance, macronutrients and what the evidence supports.
- **Exercise and ageing** (L1) - Strength, cardio and mobility, and their effect on healthspan.
- **Reading a scientific study critically** (L2) - Design, sample, effect size, and conflicts of interest. *After: The scientific method and falsifiability*
- **Energy, entropy and thermodynamics** (L2) - Conservation, efficiency and why some processes only run one way.
- **The brain and nervous system** (L2) - Neurons, circuits and the main brain regions in plain terms. *After: Cells, DNA and genetics*
- **Infectious disease, vaccines and immunity** (L2) - How pathogens spread, how immunity works and how vaccines train it. *After: Cells, DNA and genetics*
- **Climate and energy systems** (L2) - Greenhouse effect, emissions sources and the energy transition. *After: Energy, entropy and thermodynamics*
- **Chemistry and materials basics** (L2) - Atoms, bonds, reactions and why materials behave as they do.

### 10. Philosophy and Ethics (8 topics) - `10-philosophy-and-ethics.json`

- **Logic and common fallacies** (L1) - Valid arguments and the usual ways reasoning goes wrong.
- **Stoicism** (L1) - Focusing on what you control; Marcus Aurelius, Epictetus, Seneca.
- **Ethical frameworks: consequences, duties and virtues** (L2) - Three lenses for judging right action.
- **Epistemology: how we know what we know** (L2) - Evidence, justification, certainty and the limits of knowledge. *After: Logic and common fallacies*
- **Wisdom traditions and meditation** (L2) - What contemplative practices claim and what research suggests.
- **Free will, meaning and existentialism** (L3) - Choice, responsibility and making meaning without guarantees.
- **Moral psychology** (L3) - How people actually form moral judgements. *After: Ethical frameworks: consequences, duties and virtues*
- **Justice, rights and the social contract** (L3) - Competing accounts of fairness and legitimate authority. *After: Ethical frameworks: consequences, duties and virtues*

### 11. Learning and Effectiveness (10 topics) - `11-learning-and-effectiveness.json`

- **How to learn: retrieval, spacing and interleaving** (L1) - The techniques with the best evidence, and why they feel hard.
- **Deep work and managing attention** (L1) - Protecting long, focused blocks and reducing context switching.
- **Time, priorities and the 80/20 rule** (L1) - Choosing the few things that matter most.
- **Reading effectively and note-taking** (L1) - Reading for purpose and capturing what you will reuse.
- **Goal setting and OKRs** (L2) - Outcomes versus activities, and reviewing regularly. *After: Time, priorities and the 80/20 rule*
- **Writing to think** (L2) - Using writing to find out what you believe.
- **Building a network and asking for help** (L2) - Giving first, staying in touch, and making clear asks.
- **Career capital and compounding skills** (L2) - Rare and valuable skills that grow with use. *After: Time, priorities and the 80/20 rule*
- **Health habits as a performance system** (L2) - Sleep, movement and food as inputs to everything else.
- **Leadership** (L3) - Setting direction, earning trust, and developing others. *After: Career capital and compounding skills*
