# Paper Tree local reader: quality test

Statistics-fix pass after c3919fd. Same 135-answer matrix (16 highlights times 3 modes times 3 reader profiles, r00 not scored). New worked examples and a tighter number check (scientific notation, unit swaps, 'N times further'). Qwen 3.5 4B ran on the box (6 threads, 15 GB, CPU only, llama.cpp b12428, prompt cache on). Gemini answers are reused from c3919fd (Worker, read-only) and were not called again. No CI run this pass.

## Summary (real highlights, regression left out)

| Model | n | Restating (overlap 0.5 or more) | Avg overlap | Avg words | Avg time per explanation | Guard retries | Numbers not in the paper (auto check) | Dropped time spans | My read: explains / partly / restates / has an error |
|---|---|---|---|---|---|---|---|---|---|
| Gemini (gemini-3.1-flash-lite, via the Worker) | 135 | 0 of 135 (0%) | 0.09 | 39 | 4.4 s (Paper Tree Worker (read-only)) | 0 | 33 of 135 | 14 of 135 | 105 / 30 / 0 / 0 |
| Qwen 3.5 4B, new prompts | 135 | 1 of 135 (1%) | 0.16 | 32 | 12.6 s (box, 6 threads, 15 GB, CPU only) | 19 | 2 of 135 | 1 of 135 | 130 / 3 / 0 / 2 |

Overlap is the share of an answer's content words that already appear in the highlight (stop words left out). It catches word-for-word restating, not a paraphrase in new words, so each answer also has my own short note.

## Counts by mode and by reader profile

### By mode

| Mode | Model | n | My read: explains / partly / restates / has an error | Avg time | Restating | Numbers not in the paper | Dropped time spans |
|---|---|---|---|---|---|---|---|
| plain | Gemini (gemini-3.1-flash-lite, via the Worker) | 45 | 37 / 8 / 0 / 0 | 2.8 s | 0 | 10 | 4 |
| plain | Qwen 3.5 4B, new prompts | 45 | 44 / 0 / 0 / 1 | 13.3 s | 1 | 0 | 0 |
| simpler | Gemini (gemini-3.1-flash-lite, via the Worker) | 45 | 28 / 17 / 0 / 0 | 5.5 s | 0 | 13 | 5 |
| simpler | Qwen 3.5 4B, new prompts | 45 | 41 / 3 / 0 / 1 | 9.6 s | 0 | 2 | 1 |
| detail | Gemini (gemini-3.1-flash-lite, via the Worker) | 45 | 40 / 5 / 0 / 0 | 4.8 s | 0 | 10 | 5 |
| detail | Qwen 3.5 4B, new prompts | 45 | 45 / 0 / 0 / 0 | 15.0 s | 0 | 0 | 0 |

### By reader profile

| Reader profile | Model | n | My read: explains / partly / restates / has an error | Avg time | Restating | Numbers not in the paper | Dropped time spans |
|---|---|---|---|---|---|---|---|
| default | Gemini (gemini-3.1-flash-lite, via the Worker) | 45 | 38 / 7 / 0 / 0 | 4.5 s | 0 | 10 | 3 |
| default | Qwen 3.5 4B, new prompts | 45 | 45 / 0 / 0 / 0 | 12.7 s | 0 | 0 | 0 |
| beginner | Gemini (gemini-3.1-flash-lite, via the Worker) | 45 | 33 / 12 / 0 / 0 | 4.5 s | 0 | 11 | 5 |
| beginner | Qwen 3.5 4B, new prompts | 45 | 42 / 1 / 0 / 2 | 12.9 s | 0 | 1 | 0 |
| grad | Gemini (gemini-3.1-flash-lite, via the Worker) | 45 | 34 / 11 / 0 / 0 | 4.1 s | 0 | 12 | 6 |
| grad | Qwen 3.5 4B, new prompts | 45 | 43 / 2 / 0 / 0 | 12.2 s | 1 | 1 | 1 |

### Mode and profile together

| Mode | Profile | Model | n | My read: explains / partly / restates / has an error | Avg time |
|---|---|---|---|---|---|
| plain | default | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 14 / 1 / 0 / 0 | 1.0 s |
| plain | default | Qwen 3.5 4B, new prompts | 15 | 15 / 0 / 0 / 0 | 18.6 s |
| plain | beginner | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 11 / 4 / 0 / 0 | 4.7 s |
| plain | beginner | Qwen 3.5 4B, new prompts | 15 | 14 / 0 / 0 / 1 | 9.1 s |
| plain | grad | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 12 / 3 / 0 / 0 | 2.7 s |
| plain | grad | Qwen 3.5 4B, new prompts | 15 | 15 / 0 / 0 / 0 | 12.3 s |
| simpler | default | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 10 / 5 / 0 / 0 | 8.8 s |
| simpler | default | Qwen 3.5 4B, new prompts | 15 | 15 / 0 / 0 / 0 | 8.8 s |
| simpler | beginner | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 9 / 6 / 0 / 0 | 3.7 s |
| simpler | beginner | Qwen 3.5 4B, new prompts | 15 | 13 / 1 / 0 / 1 | 9.7 s |
| simpler | grad | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 9 / 6 / 0 / 0 | 3.9 s |
| simpler | grad | Qwen 3.5 4B, new prompts | 15 | 13 / 2 / 0 / 0 | 10.3 s |
| detail | default | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 14 / 1 / 0 / 0 | 3.6 s |
| detail | default | Qwen 3.5 4B, new prompts | 15 | 15 / 0 / 0 / 0 | 10.8 s |
| detail | beginner | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 13 / 2 / 0 / 0 | 5.2 s |
| detail | beginner | Qwen 3.5 4B, new prompts | 15 | 15 / 0 / 0 / 0 | 20.0 s |
| detail | grad | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 13 / 2 / 0 / 0 | 5.6 s |
| detail | grad | Qwen 3.5 4B, new prompts | 15 | 15 / 0 / 0 / 0 | 14.1 s |

## r00. Leaves in a dry spell (Paper Tree's own sample text, the highlight the 2B restated) (regression check, not scored)

Source: Sources/PaperTree/Snapshots.swift  
Highlight: "Rubisco also reacts with oxygen, and that side reaction becomes more common as carbon dioxide inside the leaf drops."

### r00 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.56, 24 words, 0.3 s): Rubisco sometimes accidentally reacts with oxygen instead of carbon dioxide. This wasteful side reaction increases when carbon dioxide levels inside the leaf go down.
  - Note: restates. Closest to the highlight (overlap 0.56). Rephrases the same two facts and adds almost no why.
- **Qwen 3.5 4B, new prompts** (overlap 0.29, 24 words, 6.9 s): Rubisco sometimes grabs oxygen instead of carbon dioxide when CO2 is low. This wastes energy because the plant has to fix the mistake again.
  - Note: explains. Wrong gas when the air supply is low; 'making junk' is loose but the idea is right.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.19, 24 words, 9.3 s): Sometimes the plant helper molecule accidentally grabs oxygen instead of carbon dioxide. When this happens, the plant wastes energy trying to fix the mistake.
  - Note: explains. Oxygen grabbed by mistake; the plant wastes energy fixing it.
- **Qwen 3.5 4B, new prompts** (overlap 0.39, 32 words, 16.2 s, guard retried): Rubisco is the enzyme that fixes carbon. When carbon dioxide drops inside the leaf, Rubisco starts reacting with oxygen instead. The plant then spends energy to fix the carbon it already made.
  - Note: explains. Mistake when CO2 is low; wastes energy fixing it.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 27 words, 3.1 s): Rubisco acts as an oxygenase when CO2 concentrations are low, initiating photorespiration. This competitive inhibition forces the plant to expend metabolic energy to recycle the resulting phosphoglycolate.
  - Note: explains. Oxygenase vs carboxylase, photorespiration, energy cost. Accurate textbook.
- **Qwen 3.5 4B, new prompts** (overlap 0.16, 27 words, 8.6 s): Rubisco's affinity for oxygen increases as CO2 concentration decreases. This reduces photosynthetic efficiency and leads to photorespiration, a wasteful process where previously fixed carbon must be re-assimilated.
  - Note: explains. Oxygen for CO2 when levels fall. C4 pumping is fair textbook background.

### r00 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.12, 27 words, 2.5 s): Rubisco is a protein that helps plants grow. It sometimes grabs oxygen by mistake, like a person accidentally picking up the wrong drink at a crowded party.
  - Note: explains. Wrong-drink comparison; grabs oxygen by mistake.
- **Qwen 3.5 4B, new prompts** (overlap 0.25, 19 words, 6.8 s): Rubisco likes CO2 but mistakes oxygen sometimes. When CO2 drops, the mistake grows, wasting energy fixing the wrong thing.
  - Note: explains. Grabs oxygen when CO2 is short; wastes energy.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.21, 20 words, 6.2 s): Sometimes the plant helper molecule makes a mistake and grabs oxygen instead of carbon dioxide, like catching the wrong ball.
  - Note: explains. Wrong-ball comparison; keeps the mistake idea.
- **Qwen 3.5 4B, new prompts** (overlap 0.09, 23 words, 7.3 s): Rubisco can grab the wrong gas when there isn't enough CO2. It wastes energy fixing the wrong thing instead of the good one.
  - Note: explains. Wrong gas when CO2 is low.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.29, 25 words, 6.9 s): Like a worker making a mistake when supplies run low, Rubisco messes up with oxygen when carbon dioxide gets too low, wasting the plant's energy.
  - Note: explains. Supplies run low, oxygen mistake, wastes energy.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 25 words, 8.3 s): Rubisco gets distracted by oxygen when CO2 runs low, wasting energy. Plants with C4 metabolism fix CO2 first so Rubisco stays busy fixing it instead.
  - Note: explains. Error happens more as CO2 drops; wastes energy.

### r00 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.17, 45 words, 1.5 s): This means Rubisco sometimes makes a mistake by reacting with oxygen instead of carbon dioxide, which wastes the plant's energy. This problem gets worse when there is not enough carbon dioxide available. C4 plants avoid this waste by keeping carbon dioxide levels high around Rubisco.
  - Note: explains. Adds C4 plants keeping CO2 high around Rubisco.
- **Qwen 3.5 4B, new prompts** (overlap 0.30, 36 words, 8.2 s): Rubisco has two jobs: grabbing carbon to make sugar and grabbing oxygen instead. When there is less carbon dioxide inside the leaf, Rubisco grabs oxygen more often. The plant wastes energy trying to fix that mistake.
  - Note: explains. Builds sugar from air, grabs oxygen when CO2 is short, has to fix the mistake.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.12, 69 words, 2.9 s): Rubisco is a helper molecule that normally grabs carbon dioxide to help plants grow. However, it sometimes grabs oxygen by mistake instead. When there is not enough carbon dioxide around, this mistake happens more often. This is a problem because the plant then has to waste extra energy to fix the error and get back on track. This process makes the plant less efficient at making its own food.
  - Note: explains. Clear everyday account of the mistake and the energy cost.
- **Qwen 3.5 4B, new prompts** (overlap 0.21, 56 words, 8.5 s): Rubisco tries to grab carbon but sometimes grabs oxygen instead. When there is less carbon dioxide inside the leaf, Rubisco makes this mistake more often. This wastes energy because the plant has to fix the error, which is why some plants in hot, dry places use a special system to keep carbon dioxide high around Rubisco.
  - Note: explains. Same account in everyday words.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.04, 67 words, 2.8 s, nums 5): This highlights the oxygenase activity of Rubisco, which competes with its carboxylase function. As the CO2 to O2 ratio decreases, the enzyme increasingly catalyzes the oxygenation of ribulose-1,5-bisphosphate. This initiates photorespiration, a metabolically expensive pathway that releases previously fixed carbon and consumes ATP and reducing power. This inefficiency is a primary constraint on photosynthetic productivity in C3 plants, particularly under conditions of stomatal closure or high temperatures.
  - Note: explains. Photorespiration and C3 constraint. The auto-flagged 5 is from ribulose-1,5-bisphosphate, not an invented result.
- **Qwen 3.5 4B, new prompts** (overlap 0.15, 43 words, 10.6 s): Rubisco is a dual-function enzyme; when CO2 concentration falls, O2 competes for the active site, triggering photorespiration. This side reaction consumes energy without fixing carbon, reducing photosynthetic efficiency and wasting ATP. C4 metabolism solves this by concentrating CO2 around Rubisco, minimizing oxygen competition.
  - Note: explains. Photorespiration and C4 pumping; accurate and at the right level.

## h01. Attention Is All You Need

Source: https://arxiv.org/abs/1706.03762  
Highlight: "dispensing with recurrence and convolutions entirely"

### h01 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 20 words, 0.4 s): The authors are creating a new model that completely removes the need for traditional recurrent or convolutional neural network structures.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 25 words, 6.0 s): This design skips two old types of brain-mimicking math steps. It uses only one kind of step instead, which makes the model faster to train.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 33 words, 3.1 s): This means the new model completely stops using two older methods for processing data. It replaces them with a simpler system that focuses only on paying attention to specific parts of the information.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 32 words, 9.6 s): They skip the usual old parts of the brain that process time step by step or look at small patches. Instead, they connect all parts together directly to see everything at once.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 25 words, 2.5 s): The authors propose replacing traditional RNN and CNN architectures with a pure attention mechanism. This shift eliminates sequential processing constraints, enabling full parallelization during training.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 28 words, 8.8 s): The Transformer drops the standard recurrent and convolutional layers that dominate sequence models. This removes sequential processing and enables full parallelization, which speeds up training and improves quality.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

### h01 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 27 words, 6.6 s): This means completely throwing away the old building blocks of AI, like baking a cake without using flour or sugar, and using a totally new method instead.
  - Note: explains. Cake-without-flour comparison is a bit odd, but the point is clear: the old building blocks are gone.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 25 words, 9.8 s): The new design skips two old parts of the brain map. It uses only one simple part, which makes it faster and easier to build.
  - Note: explains. Drops two old parts and keeps the one that looks at all words at once.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 25 words, 3.6 s): This means the new model completely stops using two older, slower ways of processing information, like switching from a winding path to a straight highway.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 23 words, 9.3 s): We removed old parts like memory loops and special filters, keeping just one smart attention tool. This made our model faster and simpler.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 27 words, 1.4 s): This means removing the traditional step by step processing methods to rely only on attention, like reading a whole page at once instead of word by word.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 29 words, 7.2 s): We built a model that doesn't use recurrent or convolutional layers, which are common in previous work. It only uses attention, which lets it process all input at once.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

### h01 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 66 words, 1.5 s): This phrase means that the new Transformer model completely removes the use of recurrent and convolutional neural networks. These older methods process data in a specific step by step order. By getting rid of them, the authors can use attention mechanisms to process all parts of the data at the same time. This makes the model much faster to train and more efficient than previous designs.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.09, 43 words, 8.6 s): Older models used loops (recurrence) or sliding windows (convolutions) to process words. This new model uses only attention, which lets it look at any word in the sentence directly, making it faster to train and easier to run on many parts at once.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 70 words, 2.1 s): This phrase means that the new model completely removes two traditional ways of processing information. Recurrence and convolutions are methods that look at data in a specific order or step by step. By getting rid of them, the new system can process all parts of a sentence at the same time instead of waiting for each piece to finish. This makes the model much faster and more efficient at learning.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.09, 39 words, 12.0 s): The old models used complex loops (recurrence) or sliding windows (convolutions) to process text. The Transformer skips these, using only attention to focus on important parts of a sentence at once. This makes it faster and easier to train.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 72 words, 5.6 s): This phrase signifies a paradigm shift in sequence modeling by abandoning the sequential processing constraints of recurrent neural networks and the local receptive fields of convolutional neural networks. By relying exclusively on self-attention mechanisms, the architecture achieves global dependency modeling and full parallelization across the sequence length. This transition is critical because it eliminates the computational bottlenecks inherent in sequential hidden state updates, enabling significantly more efficient training on modern hardware accelerators.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 43 words, 12.7 s): The Transformer removes recurrent neural networks (RNNs) and convolutional layers, which process sequences step-by-step or over local windows. By using only attention mechanisms, it processes all tokens in parallel, enabling faster training and scaling to larger models without the sequential bottlenecks of RNNs.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

## h02. Observation of Gravitational Waves from a Binary Black Hole Merger

Source: https://arxiv.org/abs/1602.03837  
Highlight: "a false alarm rate estimated to be less than 1 event per 203 000 years, equivalent to a significance greater than 5.1 σ"

### h02 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.20, 26 words, 0.4 s): This means scientists are extremely certain the signal was real and not random noise. A chance accident like this would only happen once every 203,000 years.
  - Note: explains. Keeps the 203,000-year figure and says the signal is not noise.
- **Qwen 3.5 4B, new prompts** (overlap 0.47, 31 words, 98.2 s): The chance of this signal being random noise is less than 1 in 203,000 years. That's a significance of over 5.1 sigma, meaning it is very unlikely to be a mistake.
  - Note: explains. Copies 203,000 years and 5.1 sigma and says what they mean.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 26 words, 1.8 s, dropped 203 000 years): This means the signal was so clear that it is almost impossible for it to be a mistake. It is extremely unlikely to happen by chance.
  - Note: partly. Drops the 203,000 years and 5.1 sigma; only says it is almost impossible.
- **Qwen 3.5 4B, new prompts** (overlap 0.26, 34 words, 13.2 s): This signal was so rare that it would happen less than once every 203,000 years by pure chance. A 5.1 sigma result means the odds of this being a random mistake are incredibly small.
  - Note: explains. Same, after a retry: both figures exact.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 29 words, 1.9 s, nums five, dropped 203 000 years): The detection is statistically robust, with the background noise probability being extremely low. This exceeds the five sigma threshold typically required to claim a formal discovery in particle physics.
  - Note: partly. Drops 203,000 years, rounds 5.1 to 'five sigma', and calls it a particle-physics threshold. LIGO is gravitational waves.
- **Qwen 3.5 4B, new prompts** (overlap 0.52, 34 words, 24.0 s, guard retried): The false alarm rate of less than 1 event per 203,000 years means the signal is extremely unlikely to be random noise. The 5.1σ significance confirms it's a real detection, not a statistical fluctuation.
  - Note: explains. False-alarm rate and 5.1 sigma, both exact.

### h02 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 25 words, 2.0 s, nums twice, dropped 203 000 years): This means the signal was so clear that it was extremely unlikely to be a random mistake, like winning the lottery twice in a row.
  - Note: partly. Drops 203,000 years. Lottery-twice comparison does not keep the scale.
- **Qwen 3.5 4B, new prompts** (overlap 0.19, 32 words, 8.2 s): The signal was so rare that it would take over 203,000 years for noise alone to make something like this happen. That means the chance it was just random luck is tiny.
  - Note: explains. Keeps 203,000 years; needle-in-a-haystack comparison does not invent a scale.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 27 words, 1.7 s, nums hundred, thousand, dropped 203 000 years): This means the signal is almost certainly real and not just a random mistake, like winning a lottery that happens only once every two hundred thousand years.
  - Note: explains. Keeps the span in words (two hundred thousand years). Slight rounding of 203,000.
- **Qwen 3.5 4B, new prompts** (overlap 0.27, 24 words, 7.7 s): This signal is so rare it would take over 203,000 years to see one by chance. That's why scientists are sure it was real.
  - Note: explains. Keeps 203,000 years and 5.1 sigma.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 26 words, 5.3 s, dropped 203 000 years): The signal is so distinct that it is statistically impossible for it to be random noise, like finding a specific grain of sand in a desert.
  - Note: partly. Drops 203,000 years and 5.1 sigma; grain-of-sand comparison.
- **Qwen 3.5 4B, new prompts** (overlap 0.31, 25 words, 7.6 s): The chance this noise looks like a signal is less than once every 203,000 years. That means the detection is real and not a fluke.
  - Note: explains. Says 'two hundred thousand years' and 5.1 sigma. Slight rounding of 203,000, but the time span is there.

### h02 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.11, 70 words, 1.6 s): This phrase explains that the detection of the gravitational wave was extremely unlikely to be a random error or background noise. By calculating that such a signal would only occur by chance once every 203,000 years, the researchers prove their observation is statistically certain. The 5.1 sigma value is a scientific measure of confidence, indicating that the discovery is almost certainly real and not just a fluke in the data.
  - Note: explains. Keeps 203,000 years and 5.1 sigma and says what they measure.
- **Qwen 3.5 4B, new prompts** (overlap 0.18, 46 words, 10.3 s): This means if there were no real signal, you'd expect fewer than one such random noise blip in 203,000 years. A 5.1 sigma is the standard way to say this isn't a fluke. It proves the wave was real and came from two black holes merging.
  - Note: explains. Keeps 203,000 years and explains the false-alarm rate.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.03, 70 words, 1.6 s, nums hundred, thousand, dropped 203 000 years): This means the scientists are extremely confident that the signal they detected was real and not just a random glitch or mistake. Because the chance of this happening by accident is so tiny, like once every two hundred thousand years, they know they truly found something special. This high level of certainty is important because it proves their discovery of gravitational waves is solid and not just a lucky guess.
  - Note: explains. Keeps the span in words (two hundred thousand years) and the certainty.
- **Qwen 3.5 4B, new prompts** (overlap 0.28, 36 words, 12.8 s): The chance this signal was just random noise is less than one time in 203,000 years. That's why scientists say it's more than 5.1 sigma significant, meaning the result is very real and not a fluke.
  - Note: explains. Keeps both 203,000 years and 5.1 sigma.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 72 words, 1.5 s, dropped 203 000 years): This statistical threshold confirms the detection is not a stochastic noise fluctuation. By demonstrating that the false alarm rate is extremely low, the authors establish that the signal is a genuine astrophysical event rather than an instrumental artifact. A significance exceeding 5.1 sigma provides the rigorous confidence level required to claim a discovery in gravitational wave astronomy, effectively ruling out the null hypothesis that the observed strain resulted from background detector noise.
  - Note: partly. Keeps 5.1 sigma but drops the 203,000-year false-alarm rate.
- **Qwen 3.5 4B, new prompts** (overlap 0.45, 38 words, 12.7 s): The false alarm rate is the probability this signal is noise, which is less than 1 in 203,000 years. The 5.1σ significance means the chance it's a fluke is tiny, confirming a real detection rather than an artifact.
  - Note: explains. Both figures exact; says 5.1 sigma is robust against random fluctuations.

## h03. Observation of a new particle in the search for the Standard Model Higgs boson with the ATLAS detector at the LHC

Source: https://arxiv.org/abs/1207.7214  
Highlight: "5.9 standard deviations"

### h03 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 32 words, 0.3 s): This is a statistical measurement showing that the discovery is extremely unlikely to be a random error. It confirms that the particle detected is almost certainly real and not just a fluke.
  - Note: explains. Discovery-level significance, no invented probability.
- **Qwen 3.5 4B, new prompts** (overlap 0.14, 30 words, 6.6 s): That means the signal is very far from what chance alone would make. It's not a coin flip or a made-up probability; it's the distance in units of standard deviation.
  - Note: explains. Far from chance, in units of standard deviation. Mentions coin flips only to reject that reading.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 33 words, 4.7 s): This is a way scientists measure how sure they are about a discovery. It means the chance that the result happened by accident is so tiny that the discovery is almost certainly real.
  - Note: explains. How sure scientists are; chance of an accident is tiny.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 28 words, 6.0 s): That means the chance this signal was just random luck is tiny. It's like finding a needle in a haystack and being sure it's real, not a trick.
  - Note: explains. 5.9 from chance; points to the Higgs discovery.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 32 words, 2.5 s): This value represents the statistical significance of the observation. It indicates that the probability of the signal being a random background fluctuation is extremely low, meeting the formal criteria for a discovery.
  - Note: explains. Background fluctuation is extremely low; meets discovery criteria.
- **Qwen 3.5 4B, new prompts** (overlap 0.14, 36 words, 9.5 s): The 5.9 standard deviations show the signal is far from background fluctuations, making it highly unlikely to be a statistical fluke. This corresponds to a probability of 1.7x10^-9 that such a bump would appear by chance.
  - Note: explains. Far from background; the 1.7x10^-9 is the paper's own background-fluctuation probability in the surrounding text, copied exactly.

### h03 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 27 words, 2.5 s): This is a statistical measurement showing that the discovery is extremely unlikely to be a random accident. It is like flipping a coin and getting heads repeatedly.
  - Note: partly. Coin-flip comparison. It never turns 5.9 into a head count, but the comparison does not keep the scale.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 32 words, 6.9 s): That number means the bump is huge compared to what you'd expect from random noise alone. It's like finding a needle in a haystack where you're sure it's not just a mistake.
  - Note: explains. Far from chance, needle-in-a-haystack comparison, no 'times further' and no invented p-value.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 26 words, 2.3 s): This is a way to show that a scientific discovery is almost certainly real, like flipping a coin and getting heads many times in a row.
  - Note: partly. Same coin-flip comparison, no wrong count.
- **Qwen 3.5 4B, new prompts** (overlap 0.21, 25 words, 13.2 s, guard retried): The bump found is 5.9 standard deviations away from what would happen by chance alone. That means it's extremely unlikely to be a random error.
  - Note: explains. Far from chance; needle-in-a-haystack comparison invents no number.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 24 words, 3.2 s): This indicates the result is statistically robust. It is like flipping a coin and getting heads so many times that luck is essentially impossible.
  - Note: partly. Same coin-flip comparison, no wrong count.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 25 words, 8.4 s): This is the chance of a random background bump being this high just by luck. It means the signal is real and not a fluke.
  - Note: explains. Qualitative: far from a random background bump, not a fluke. No invented number.

### h03 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 75 words, 6.7 s): In statistics, standard deviations measure how far a result is from what would happen by pure chance. A value of 5.9 means the result is extremely unlikely to be a random error. In particle physics, this specific number is the threshold required to claim a formal discovery. It provides the high level of certainty needed to confirm that the scientists actually found the Higgs boson rather than just seeing a random glitch in their data.
  - Note: explains. 5.9 is far from chance; names the usual discovery threshold without inventing a p-value.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 33 words, 7.3 s): That means the result is so unlikely to be a random fluke that it's considered solid proof. It's not a chance fluctuation, but a real signal that matches the Standard Model Higgs boson.
  - Note: explains. Unlikely to be a fluke; a real signal compatible with the Standard Model Higgs. No invented p-value.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.03, 63 words, 7.3 s): In science, this number measures how sure researchers are about a discovery. It acts like a confidence score. A score of 5.9 means the result is extremely unlikely to be just a random accident or a mistake. Because this number is so high, scientists are very confident that they actually found a new particle rather than seeing a false signal in their data.
  - Note: explains. Confidence score; 5.9 means it is almost certainly a new particle.
- **Qwen 3.5 4B, new prompts** (overlap 0.16, 35 words, 20.1 s, guard retried): The search found a signal 5.9 standard deviations away from what random background noise would look like. That's a very low chance of being a fluke, and it matches the expected mass of 126.0 GeV.
  - Note: explains. Far from chance, no invented p-value.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 74 words, 3.3 s, nums five): This value represents the statistical significance of the Higgs boson discovery. In particle physics, a five sigma threshold is the conventional benchmark for claiming a formal discovery, as it indicates the probability of the observed signal being a random background fluctuation is extremely low. Reaching 5.9 standard deviations provides robust evidence that the excess of events is a genuine physical phenomenon rather than a statistical artifact, confirming the observation of the new neutral boson.
  - Note: explains. 5.9 vs the conventional five-sigma discovery threshold. 'Five' is that convention, not a new result.
- **Qwen 3.5 4B, new prompts** (overlap 0.04, 39 words, 8.4 s): The significance of 5.9 sigma indicates the result is extremely unlikely to be a background fluctuation. This level of statistical evidence is considered 'discovery' in particle physics, meaning the observed signal is robust and not due to random chance.
  - Note: explains. 5.9 sigma as discovery-level evidence, no invented probability.

## h04. Deep Residual Learning for Image Recognition

Source: https://arxiv.org/abs/1512.03385  
Highlight: "We explicitly reformulate the layers as learning residual functions with reference to the layer inputs, instead of learning unreferenced functions."

### h04 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.23, 22 words, 4.5 s): Instead of teaching layers to learn totally new information from scratch, the system has them learn changes based on the original inputs.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.18, 37 words, 9.1 s): Instead of trying to learn a brand new pattern from scratch for every deep layer, each layer now learns what to subtract from its input. This makes it easier for the network to handle very deep structures.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 24 words, 5.8 s): Instead of teaching the computer layers from scratch, the system learns the small changes needed from the previous step. This makes training much easier.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 36 words, 9.0 s): Instead of trying to learn a brand new picture for each step, the model learns what to keep and what to change. This makes it easier to build very tall networks that can see details better.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 38 words, 1.5 s): The layers are redesigned to learn the difference, or residual, between the input and the desired output, rather than trying to fit the full underlying mapping directly. This shift makes gradient propagation much more stable in ultra-deep networks.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.19, 34 words, 11.5 s): Instead of learning what each layer does from scratch, we force each layer to learn only the difference or correction needed from the previous layer's output. This makes training very deep networks much easier.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

### h04 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.15, 24 words, 4.0 s): Instead of teaching a computer layer to learn a brand new task from scratch, we have it focus only on fixing the leftover mistakes.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.14, 28 words, 6.6 s): Instead of trying to learn what each layer does from scratch, we teach it to learn only the small changes needed. That makes training deep networks much easier.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.20, 26 words, 2.1 s): Instead of teaching computer layers new information from scratch, we have them learn the difference or leftovers from the input, like finding the missing puzzle piece.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.08, 26 words, 8.4 s): Instead of trying to learn each step from scratch, the model learns what to subtract. That makes it easier to handle very long chains of steps.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.19, 26 words, 1.5 s): Instead of learning total new data transformations, layers learn just the small changes needed. Think of it like editing a draft instead of rewriting the page.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.17, 37 words, 11.3 s): Instead of teaching layers to build a brand new function, we tell them to learn the difference between what they see and what comes out. This makes it easier to stack many more layers without losing accuracy.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

### h04 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 68 words, 0.4 s): The authors are changing how neural network layers process information. Instead of asking each layer to learn a completely new output from scratch, they design the layers to learn the difference, or residual, between the input and the desired output. This approach makes it much easier for the network to train because the layers only need to focus on small adjustments rather than mapping everything from the beginning.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 37 words, 8.7 s): The trick is that each layer doesn't try to build a new map from scratch. Instead, it learns the difference between what comes in and what should come out. This makes training very deep networks much easier.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 66 words, 6.0 s): Instead of asking the computer to learn the entire output from scratch, the researchers change the task. They ask the computer to learn only the difference or the extra detail needed to improve the result based on the original input. This makes it much easier for the computer to train very deep networks because it focuses on small adjustments rather than starting over at every step.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.11, 38 words, 11.4 s): Normal neural networks get stuck if they are too long. This method makes them learn the difference between two layers instead of trying to learn everything from scratch. That lets them be much deeper and still work well.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.10, 79 words, 5.0 s): This approach addresses the vanishing gradient problem by forcing layers to learn the difference between the input and output, denoted as F(x) = H(x) - x, rather than mapping the input directly to the target. By learning these residual mappings, the network can effectively pass identity information through shortcut connections. This reformulation allows for significantly deeper architectures that remain trainable, as it is easier to optimize the residual mapping toward zero than to learn an identity mapping from scratch.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.13, 47 words, 10.5 s): Standard deep nets struggle because signals degrade without shortcuts. We introduce skip connections so each layer adds a residual function relative to its input, bypassing degradation and allowing gradients to flow easier through 152+ layers. This enables the 3.57% ImageNet error and 28% relative improvement on COCO.
  - Note: explains. Residuals, 152 layers, 3.57% ImageNet error: all from the paper, and at the right level.

## h05. Electric Field Effect in Atomically Thin Carbon Films

Source: https://arxiv.org/abs/cond-mat/0410550  
Highlight: "ballistic transport at submicron distances even at room temperature"

### h05 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 28 words, 0.3 s): This describes how electrons move through a material without hitting obstacles or losing energy. It happens over very short distances even when the material is not cooled down.
  - Note: explains. Electrons travel without collisions over short distances even when not cooled.
- **Qwen 3.5 4B, new prompts** (overlap 0.08, 25 words, 9.0 s): It moves electrons like a perfect highway without bumps. That happens at distances smaller than a micrometer, and it works normally even when it's warm.
  - Note: explains. Perfect-highway idea; keeps submicron ('smaller than a micrometer') and room-warm conditions.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 28 words, 2.7 s): This means electricity flows through the material without hitting any obstacles or losing energy. It happens over very short gaps even when the material is not cooled down.
  - Note: explains. Same, in everyday words.
- **Qwen 3.5 4B, new prompts** (overlap 0.07, 23 words, 8.3 s): Electrons move like a solid ball rolling across the floor without bouncing. They go straight for very short distances, even when it's warm.
  - Note: explains. Straight travel over very short distances even when it's warm.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.05, 24 words, 2.8 s): Charge carriers travel across submicron scales without scattering, maintaining momentum despite thermal energy. This demonstrates exceptionally high carrier mobility in graphene at ambient conditions.
  - Note: explains. No scattering over submicron scales at ambient conditions.
- **Qwen 3.5 4B, new prompts** (overlap 0.14, 22 words, 8.2 s): Electrons moved without scattering in graphene channels shorter than a micron while the device stayed on, a rare feat at room temperature.
  - Note: explains. No scattering over nanoscale lengths at room temperature.

### h05 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 23 words, 7.0 s): This means electricity moves like a bowling ball rolling straight down a lane without hitting anything, even in tiny spaces and warm rooms.
  - Note: explains. Bowling-lane comparison; keeps tiny spaces and warm rooms.
- **Qwen 3.5 4B, new prompts** (overlap 0.07, 27 words, 7.3 s): The electrons fly straight like a bullet without bumping into anything inside the material. This works normally even in warm rooms, not just when it's super cold.
  - Note: explains. Straight like a bullet; works in warm rooms, not only when it is very cold. No false 'because the path is tiny'.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 18 words, 8.0 s): Electricity flows through this tiny space like a bowling ball rolling down an empty lane without hitting anything.
  - Note: partly. Bowling-lane comparison is fine, but it drops room temperature.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 21 words, 7.7 s): Electrons zoom through the material without bumping into anything. That's like a ball rolling on smooth ice, even when it's hot.
  - Note: explains. Keeps normal temperatures and tiny spaces.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 24 words, 4.9 s): Electrons flow through the material without hitting any obstacles, like a car driving on an empty highway without ever needing to brake or turn.
  - Note: partly. Empty-highway comparison; drops the submicron distance and room temperature.
- **Qwen 3.5 4B, new prompts** (overlap 0.13, 22 words, 5.2 s): Electrons move like bullets in a straight line without scattering. This happens over tiny distances and works fine at normal room conditions.
  - Note: explains. No bouncing off impurities across tiny gaps.

### h05 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.09, 66 words, 2.0 s): This refers to electrons moving through a material without colliding with atoms or impurities. In this context, it means electricity flows through graphene very efficiently over short distances without losing energy as heat. This is significant because most materials require extreme cooling to achieve this effect, but graphene maintains this high performance at room temperature, which could lead to much faster and more efficient electronic devices.
  - Note: explains. No collisions, short distances, usually needs cooling, graphene does it at room temperature.
- **Qwen 3.5 4B, new prompts** (overlap 0.26, 39 words, 6.7 s): Ballistic transport means electrons move like a thrown ball through space without bumping into anything. At submicron distances, the material is so smooth that they don't scatter, which makes the device work fast and cool even at room temperature.
  - Note: explains. Clean movement at tiny scales without cooling.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 69 words, 5.3 s): This means that electrons can travel through a material in a straight line without bumping into anything or losing energy, even over tiny distances and in a warm room. Usually, electrons hit atoms and slow down, which creates heat. Because these electrons move freely without crashing, the material can carry electricity much faster and more efficiently than standard wires. This is important for making smaller, faster, and cooler electronics.
  - Note: explains. Straight-line travel in a warm room; why that helps devices.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 32 words, 9.3 s): The electrons move like a bullet, straight without bumping into anything. Normally they bounce off atoms and slow down, but here they keep going fast in tiny spaces even when it's warm.
  - Note: explains. Usually heat slows electrons; here they move freely even when it is warm.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.12, 68 words, 5.7 s): This refers to charge carriers traversing the graphene lattice without scattering events over submicron scales. In conventional semiconductors, phonon scattering typically limits mean free paths at room temperature. The observation of ballistic transport in graphene at these scales and temperatures confirms exceptionally high carrier mobility, which is critical for developing high frequency, low power field effect transistors that operate efficiently without the resistive losses associated with diffusive transport.
  - Note: explains. Mean free path and mobility at room temperature; accurate.
- **Qwen 3.5 4B, new prompts** (overlap 0.24, 33 words, 21.0 s, guard retried): The electrons move through the graphene like a perfect pipe, hitting no obstacles until they exit. This happens at submicron distances even at room temperature, which is rare because heat usually scatters electrons.
  - Note: explains. Ballistic over submicron distances at room temperature, unlike most materials.

## h06. Planck 2018 results. VI. Cosmological parameters

Source: https://arxiv.org/abs/1807.06209  
Highlight: "Hubble constant"

### h06 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.15, 28 words, 0.3 s): The Hubble constant is a number that describes how fast the universe is expanding. It measures the rate at which galaxies move away from each other over time.
  - Note: explains. Current expansion rate of the universe (grad also notes the tension with local measurements).
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 33 words, 71.1 s): The Hubble constant is how fast the universe is expanding right now, measured in km per second per megaparsec. It's a key number for figuring out how old and big the universe is.
  - Note: explains. Expansion rate now, in km/s per megaparsec.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 28 words, 8.0 s): This is a number that tells us how fast the universe is stretching out. It helps scientists figure out how quickly galaxies are moving away from each other.
  - Note: explains. Current expansion rate of the universe (grad also notes the tension with local measurements).
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 23 words, 8.5 s): It's a number that tells us how fast the universe is expanding right now. The paper says it's about 67.4 km/s per megaparsec.
  - Note: explains. How fast the universe is stretching now.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.11, 30 words, 3.9 s): The Hubble constant represents the current expansion rate of the universe. Planck measurements derive this value indirectly from early universe data, resulting in a lower estimate than direct local measurements.
  - Note: explains. Current expansion rate of the universe (grad also notes the tension with local measurements).
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 28 words, 13.5 s): The Hubble constant here is 67.4 km/s/Mpc, which measures how fast galaxies are receding per megaparsec of distance. It's the expansion rate of the universe at this epoch.
  - Note: explains. 67.4 ± 0.5 km/s/Mpc from Planck under the standard model, both from the paper.

### h06 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.20, 27 words, 2.9 s): The Hubble constant is the speed at which the universe is expanding. Think of it like the rate at which a balloon grows when you inflate it.
  - Note: explains. Balloon comparison; speed at which the universe is expanding.
- **Qwen 3.5 4B, new prompts** (overlap 0.14, 24 words, 10.1 s): The Hubble constant is a number that tells us how fast the universe is expanding right now, measured in km per second per megaparsec.
  - Note: explains. Expansion rate now, in km per second per megaparsec. The unit is kept.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 25 words, 3.5 s): This is a number that tells us how fast the universe is stretching out. Think of it like the speed at which a balloon expands.
  - Note: explains. Balloon comparison; speed at which the universe is expanding.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 19 words, 20.9 s, guard retried): The Hubble constant is 67.4km/s/Mpc. It tells how fast space stretches. A higher number means galaxies move apart faster.
  - Note: explains. Expansion rate now, in km/s per megaparsec.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 27 words, 4.9 s): This is the speed at which the universe is currently expanding. Think of it like the rate at which a balloon grows when you blow it up.
  - Note: explains. Balloon comparison; speed at which the universe is expanding.
- **Qwen 3.5 4B, new prompts** (overlap 0.20, 16 words, 7.9 s): The Hubble constant here is 67.4 km/s/Mpc, which tells us how fast the universe is expanding.
  - Note: explains. 67.4 with a small margin of error, per megaparsec.

### h06 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 57 words, 5.1 s): The Hubble constant is a number that represents the current rate at which the universe is expanding. It describes how fast galaxies are moving away from each other based on their distance from us. In this context, scientists use it to understand the overall scale and age of the universe by measuring light from the early cosmos.
  - Note: explains. Current expansion rate; grad correctly names 67.4 km/s/Mpc and the Hubble tension.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 32 words, 11.2 s): The Hubble constant is a number that tells us how fast the universe is expanding right now, measured in km/s per megaparsec. Here it is 67.4 with a small margin of error.
  - Note: explains. 67.4 ± 0.5 km/s/Mpc, expansion rate now.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 43 words, 8.5 s): The Hubble constant is a number that tells us how fast the universe is expanding. In this text, scientists use data from space to measure this speed precisely. Knowing this number helps researchers understand the age, size, and future of our entire universe.
  - Note: explains. Current expansion rate; grad correctly names 67.4 km/s/Mpc and the Hubble tension.
- **Qwen 3.5 4B, new prompts** (overlap 0.10, 42 words, 12.2 s): The Hubble constant tells us how fast the universe is stretching right now, measured in kilometers per second for every megaparsec of distance. It's a key number that helps figure out how old the universe is and how much matter it has.
  - Note: explains. Same value and units.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.05, 59 words, 8.3 s): The Hubble constant represents the current expansion rate of the universe. In this context, the Planck measurement of 67.4 kilometers per second per megaparsec is crucial because it anchors the standard Lambda CDM model. However, this early universe inferred value famously creates the Hubble tension when compared to higher local distance ladder measurements, driving ongoing debates in precision cosmology.
  - Note: explains. Current expansion rate; grad correctly names 67.4 km/s/Mpc and the Hubble tension.
- **Qwen 3.5 4B, new prompts** (overlap 0.10, 34 words, 23.3 s, guard retried): The Hubble constant value of (67.4±0.5)km/s/Mpc measures the current expansion rate of the universe, where 1 Mpc is a megaparsec. It is one of the inferred late-Universe parameters derived from the Planck CMB data.
  - Note: explains. 67.4 ± 0.5 km/s/Mpc, and it says 1 Mpc is a megaparsec. Notation is clean this time.

## h07. Safety and Efficacy of the BNT162b2 mRNA Covid-19 Vaccine

Source: https://pubmed.ncbi.nlm.nih.gov/33301246/  
Highlight: "BNT162b2 was 95% effective in preventing Covid-19 (95% credible interval, 90.3 to 97.6)"

### h07 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.31, 26 words, 0.3 s): The vaccine prevented 95 percent of Covid-19 cases in the study. The credible interval shows the range of statistical certainty for how well the vaccine works.
  - Note: explains. 95% of cases prevented; explains the credible interval.
- **Qwen 3.5 4B, new prompts** (overlap 0.19, 26 words, 9.0 s): The vaccine stopped 95 out of every 100 cases compared to the placebo shot. The 90.3 to 97.6 range is where the true protection likely falls.
  - Note: explains. Stopped 95% of cases that would have happened otherwise; keeps 90.3 to 97.6.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.20, 23 words, 8.3 s): This means the vaccine stopped 95 out of every 100 people from getting sick with Covid-19. It worked extremely well in the study.
  - Note: partly. 'Stopped 95 out of every 100 people from getting sick' reads like an absolute rate, not a reduction versus placebo.
- **Qwen 3.5 4B, new prompts** (overlap 0.19, 30 words, 8.9 s): The vaccine stopped 95 out of every 100 flu cases compared to the dummy shot. The 90.3 to 97.6 range is the area where we are sure about that number.
  - Note: error. Same flu slip, though the 95 out of 100 is now correctly compared with the dummy shot, and the interval is kept.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 33 words, 2.6 s): The vaccine demonstrated a 95 percent reduction in symptomatic disease risk compared to placebo. The credible interval indicates the range where the true efficacy likely lies based on the Bayesian statistical analysis used.
  - Note: explains. 95% reduction in symptomatic disease; explains the Bayesian interval.
- **Qwen 3.5 4B, new prompts** (overlap 0.29, 26 words, 10.7 s): The vaccine prevented 95% of lab-confirmed cases compared to placebo. The 95% credible interval of 90.3 to 97.6 shows the range of certainty around that estimate.
  - Note: explains. Prevented 95% of cases; interval is the range for true protection.

### h07 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 22 words, 7.4 s): The vaccine worked very well. Think of it like a shield blocking 95 out of 100 potential infections compared to getting nothing.
  - Note: explains. Shield blocking 95 out of 100 potential infections compared with nothing.
- **Qwen 3.5 4B, new prompts** (overlap 0.27, 23 words, 8.0 s): It cut the chances of getting the virus by 95%. The 90.3 to 97.6 range shows how sure we are about that number.
  - Note: explains. A 95% cut in chances of getting the virus, with the 90.3 to 97.6 range. Relative, not an absolute 'stayed well' rate.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.23, 20 words, 7.0 s): This means the vaccine works like a powerful shield, stopping 95 out of 100 people from getting sick with Covid-19.
  - Note: partly. 'Stopping 95 out of 100 people from getting sick' is the same absolute-rate slip.
- **Qwen 3.5 4B, new prompts** (overlap 0.21, 27 words, 9.7 s): The 95% means the vaccine stopped 95 out of 100 flu cases compared to the fake shot. The 90.3 to 97.6 is the range they're sure about.
  - Note: error. The relative-rate reading is now right (95 out of 100 cases versus the fake shot), but it says 'flu cases' for a Covid-19 vaccine.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 23 words, 2.5 s): The vaccine reduced the risk of getting sick by 95 percent. Think of it like a shield that blocks almost all incoming arrows.
  - Note: explains. 95 percent risk reduction; shield comparison.
- **Qwen 3.5 4B, new prompts** (overlap 0.22, 31 words, 11.4 s): The 95% means the vaccine cut cases by that amount compared to the placebo group. The interval of 90.3 to 97.6 is the range where the true protection rate likely falls.
  - Note: explains. Prevented 95% of cases; keeps the 90.3 to 97.6 interval.

### h07 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.19, 65 words, 3.3 s): This statement means the vaccine significantly reduced the risk of getting sick with Covid-19 compared to the placebo group. The credible interval provides a statistical range of certainty, showing that researchers are highly confident the true effectiveness of the vaccine falls between 90.3 percent and 97.6 percent. This is important because it proves the vaccine is highly reliable at preventing infection in the study population.
  - Note: explains. Risk reduction versus placebo, interval 90.3 to 97.6.
- **Qwen 3.5 4B, new prompts** (overlap 0.22, 47 words, 13.8 s): In this big study, 95% of people who got the BNT162b2 vaccine stayed free of lab-confirmed Covid-19 compared with those who got the placebo. The 90.3 to 97.6 range is where the true protection likely lies. This means the shot works very well at stopping the disease.
  - Note: explains. 95% prevention in people 16 and older; interval explained.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.10, 73 words, 2.8 s): This statement means that the vaccine works very well to stop people from getting sick. The number 95 percent shows that most people who got the vaccine stayed healthy compared to those who did not. The credible interval is a range of numbers that scientists use to show they are very confident in their results. This matters because it proves the vaccine is a strong tool for keeping people safe from the virus.
  - Note: explains. Most people who got the vaccine stayed healthy compared with those who did not; explains the interval.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 44 words, 12.1 s): The vaccine stopped 95 out of every 100 people from getting infected compared to the fake shot. The 90.3 to 97.6 range is how sure scientists are about that number. It worked for almost everyone, even older kids and those with other health issues.
  - Note: explains. 95 out of 100 cases versus those who did not get it; keeps the interval.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.11, 65 words, 7.7 s, nums five, ninety, three): This result demonstrates the primary efficacy endpoint of the phase three trial for the BNT162b2 mRNA vaccine. The ninety-five percent vaccine efficacy, backed by a narrow credible interval, indicates robust protection against symptomatic Covid-19 across diverse demographic subgroups. This high level of protection, achieved with an acceptable safety profile, provided the foundational clinical evidence supporting emergency use authorization and global immunization campaigns during the pandemic.
  - Note: explains. Phase 3 efficacy against symptomatic Covid-19; interval described correctly. 'Ninety-five' is 95, not a new number.
- **Qwen 3.5 4B, new prompts** (overlap 0.33, 36 words, 10.7 s): The 95% efficacy is the vaccine's protection rate against lab-confirmed Covid-19 in this trial. The 95% credible interval of 90.3 to 97.6 bounds the true rate with 95% probability, confirming the estimate is precise and robust.
  - Note: explains. 95% of cases; interval as a 95% range around the point estimate.

## h08. A programmable dual-RNA-guided DNA endonuclease in adaptive bacterial immunity

Source: https://pubmed.ncbi.nlm.nih.gov/22745249/  
Highlight: "the potential to exploit the system for RNA-programmable genome editing"

### h08 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.15, 25 words, 0.3 s): This refers to using the CRISPR system as a tool to change DNA sequences by using specific RNA molecules to guide where those changes happen.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.10, 32 words, 6.5 s): This work shows how a natural virus defense system can be built into tools to edit genes using RNA instructions. It opens up new ways to fix genetic diseases or improve crops.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 23 words, 2.8 s): This means scientists can use these natural tools to easily change or fix the DNA inside living things by using simple RNA instructions.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.15, 22 words, 7.3 s): This system lets scientists program RNA to cut specific DNA. That means we could rewrite genes with just a tiny RNA code.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 25 words, 3.1 s): This refers to the ability to repurpose the Cas9 endonuclease as a versatile tool for precise genomic modifications by simply modifying the guide RNA sequence.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 27 words, 6.4 s): The dual-RNA guide directs Cas9 to cut specific DNA sequences. This allows researchers to program the genome edit sequence by changing the RNA, not just the protein.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

### h08 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 23 words, 11.0 s): This means using a natural bacterial tool like a pair of biological scissors to rewrite DNA instructions, guided by a specific RNA molecule.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.14, 22 words, 9.4 s): This system lets scientists program RNA to cut DNA at specific spots. It's like a molecular scissor set to a custom address.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 26 words, 4.1 s): This means we can use small pieces of RNA like a remote control to tell a special protein exactly where to change the instructions in DNA.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.15, 23 words, 6.2 s): This system lets scientists program tiny RNA molecules to cut specific genes, like scissors. That means they can turn genes on or off.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 25 words, 4.6 s): This means we can use simple RNA molecules as remote controls to tell the Cas9 protein exactly where to cut and edit specific DNA sequences.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.20, 22 words, 6.2 s): This system lets scientists program RNA to cut specific DNA spots. That opens up a huge toolkit for changing genomes on demand.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

### h08 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 69 words, 4.1 s): This phrase refers to the possibility of using the CRISPR-Cas9 system as a tool to change DNA sequences. Because the system uses RNA to find specific locations in the genome, scientists can program it to cut DNA at precise spots. This is important because it allows researchers to edit genes with high accuracy, which could help in treating genetic diseases or studying how specific genes function in living organisms.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.05, 40 words, 7.7 s): This research shows how scientists can use RNA to tell the Cas9 enzyme where to cut DNA. That means they can program the cut to happen at any specific spot, which opens up new ways to fix or change genes.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 44 words, 8.8 s): This phrase means scientists can use this natural bacterial defense system as a tool to rewrite genetic code using RNA molecules as guides. This matters because it allows researchers to make precise changes to DNA, which can help fix genetic diseases or improve crops.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.11, 36 words, 7.0 s): This system lets scientists pick a gene and cut it with RNA instructions. It's like a molecular scissors guided by a custom map, so they can change DNA to fix genes or study how they work.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 72 words, 4.0 s): This phrase refers to the capability of using the dual-RNA guided Cas9 endonuclease as a modular tool for precise genomic modifications. By substituting the crRNA guide sequence, researchers can redirect the Cas9 enzyme to target arbitrary DNA loci. This mechanism is significant because it decouples the targeting specificity from the protein component, enabling a versatile, programmable platform for site-specific genome engineering that is far more efficient than traditional protein-based DNA binding domains.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.18, 50 words, 10.1 s): This passage reveals that dual-tracrRNA:crRNA chimeras direct Cas9 to cut DNA with high fidelity, creating a programmable endonuclease family. The potential to exploit this system for RNA-programmable genome editing lies in its ability to target specific DNA sequences using synthetic RNA guides, enabling precise genomic modifications without requiring protein engineering.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

## h09. Highly accurate protein structure prediction with AlphaFold

Source: https://pubmed.ncbi.nlm.nih.gov/34265844/  
Highlight: "even in cases in which no similar structure is known"

### h09 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 24 words, 0.3 s): This means the computer model can accurately predict a protein shape even when it cannot compare that protein to any other previously studied ones.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.20, 29 words, 6.5 s): Most methods only work if you can find a matching protein to copy from. This new method works even when there is no similar structure to compare it against.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 24 words, 7.5 s): This means the computer program can predict a protein shape successfully, even when scientists have never found another protein shaped quite like it before.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.08, 27 words, 6.8 s): Old methods worked only when a similar protein was already found. AlphaFold can guess the shape even when no one has ever seen that exact protein before.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.05, 23 words, 2.1 s): The model achieves high accuracy by predicting protein folds de novo, without relying on template-based modeling or evolutionary conservation from known structural homologs.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 24 words, 10.6 s): This solves the 'fold from sequence' problem when no template exists. It's the bottleneck that limits large-scale structural bioinformatics and fills a 50-year gap.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

### h09 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 26 words, 25.0 s): This means the computer can figure out a protein shape even when it has never seen anything like it before, like solving a brand new puzzle.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 31 words, 7.0 s): This means the computer can guess the shape even when scientists have never seen that exact protein before. It's a big deal because most tools need a similar example to work.
  - Note: explains. Now says the method can guess the shape even with no similar example, which is the point of the highlight.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 22 words, 1.9 s): This means figuring out the shape of something completely new, like solving a puzzle without ever seeing the picture on the box.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.09, 26 words, 6.8 s): Most tools can't guess a protein's shape if they have no matching example. This new method works even when there is no similar example to copy.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 19 words, 7.5 s): Predicting a protein shape completely from scratch, without using any previously known examples to help guide the computer program.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.30, 22 words, 10.3 s): Most methods need a known template to work. AlphaFold works even when there's no similar structure in the database to match against.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

### h09 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.12, 52 words, 7.4 s): This phrase means that the new method works successfully even when scientists have no previous examples of similar protein structures to use as a guide. This matters because most known proteins lack a known structure, so a tool that does not rely on prior examples can solve unknowns that older methods cannot.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 31 words, 7.0 s): Before this, computers could only guess well if a close match existed. This tool can now predict shapes accurately even when no similar protein exists in nature, filling a huge gap.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.04, 69 words, 2.9 s): This phrase means that the new computer program can figure out the shape of a protein even when scientists have never seen anything like it before. Usually, researchers look for similar proteins to guess the shape of a new one. Being able to do this without any clues is a huge deal because it allows scientists to understand the shapes of many proteins that were previously a complete mystery.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 34 words, 7.6 s): Scientists usually compare a new protein to an old one they already know. But sometimes there’s no old one to match it against. AlphaFold can still guess the shape right, even without that comparison.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 58 words, 8.4 s): This phrase highlights the key breakthrough of the new AlphaFold model. Traditional computational methods relied heavily on evolutionary templates, failing when a query protein lacked a known homologue. Achieving atomic accuracy without similar reference structures means the algorithm learns fundamental biophysical principles rather than merely memorizing or aligning existing templates, effectively solving the core bottleneck in structural bioinformatics.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.09, 36 words, 11.8 s): Existing methods fail when no homologous structure exists because they rely on alignment to known templates. AlphaFold's novelty is its ability to predict atomic accuracy without a homologous template by leveraging multi-sequence alignments and physical knowledge.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

## h10. A Randomized Trial of Intensive versus Standard Blood-Pressure Control

Source: https://pubmed.ncbi.nlm.nih.gov/26551272/  
Highlight: "hazard ratio with intensive treatment, 0.75; 95% confidence interval [CI], 0.64 to 0.89"

### h10 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.33, 35 words, 0.3 s, nums 11, 25, 36): The hazard ratio shows that intensive treatment reduced the risk of heart events by 25 percent. The confidence interval means researchers are 95 percent sure the true risk reduction is between 11 and 36 percent.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.30, 41 words, 13.7 s): The hazard ratio of 0.75 means the risk of heart problems was lower in the group aiming for lower blood pressure, not higher. The 95% CI from 0.64 to 0.89 shows that range where we are sure the real effect lies.
  - Note: explains. Keeps 0.75 and 0.64 to 0.89; no percent conversion.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.12, 30 words, 2.4 s, nums 25): This means the intensive treatment group had a 25 percent lower risk of heart problems compared to the standard group. The range shows how certain researchers are about this result.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.25, 39 words, 13.9 s): The hazard ratio of 0.75 means the group with stricter blood pressure control had a lower risk of bad heart events than the other group. The range from 0.64 to 0.89 shows how sure we are about that difference.
  - Note: explains. Same, exact figures, lower chance of heart attacks or strokes.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.19, 27 words, 2.4 s, nums 25): Intensive blood pressure control reduced the primary cardiovascular event rate by 25 percent compared to standard treatment. The narrow confidence interval confirms this finding is statistically robust.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.36, 39 words, 25.9 s, guard retried): The hazard ratio of 0.75 means the intensive treatment group had a lower rate of fatal or nonfatal major cardiovascular events than standard treatment. The 95% CI of 0.64 to 0.89 excludes 1, showing this difference is statistically significant.
  - Note: explains. 0.75 vs 1 as no difference; interval excludes 1.

### h10 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 27 words, 3.3 s, nums 25): The intensive treatment reduced the risk of heart problems by 25 percent. The range shows how certain researchers are that this benefit is real and not luck.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.41, 40 words, 22.9 s, guard retried): The hazard ratio of 0.75 means the intensive treatment group had a lower rate of bad heart events than the standard group. The 95% CI from 0.64 to 0.89 shows the range where we are sure this difference is real.
  - Note: explains. Exact figures, no conversion.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 25 words, 3.4 s, nums 25): This means the intensive treatment lowered the risk of heart problems by 25 percent compared to standard care, like a discount on a price tag.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.29, 25 words, 18.5 s, nums 25, guard retried): The 0.75 means the risky events were 25% less likely in the strong treatment group. The 0.64 to 0.89 range is what we're sure about.
  - Note: partly. Correct 25% reading of 0.75, but that percent is computed, not written in the paper.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 26 words, 3.3 s, nums 25, quarter): Intensive blood pressure control reduced the risk of major heart events by 25 percent compared to standard care, like getting a quarter off a price tag.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.40, 33 words, 26.2 s, nums 25, guard retried): The hazard ratio of 0.75 means the intensive group had a 25% lower rate of major heart events over time. The 95% CI from 0.64 to 0.89 shows this isn't due to chance.
  - Note: partly. Same correct 25% conversion of the hazard ratio, still a number the paper does not write.

### h10 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.22, 53 words, 7.9 s, nums five, twenty): This statistical result shows that the intensive treatment group experienced twenty five percent fewer major cardiovascular events compared to the standard group. The hazard ratio of 0.75 means the risk went down. The confidence interval proves this finding is reliable and not just due to random chance, because the range stays below one.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.33, 46 words, 28.1 s, guard retried): The hazard ratio of 0.75 means people in the intensive group had a lower risk of major heart or stroke events than those in the standard group. The 95% CI from 0.64 to 0.89 shows we are sure this difference is real, not just random chance.
  - Note: explains. Exact figures; whole interval below 1.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.18, 72 words, 2.5 s, nums 11, 25, 36): The hazard ratio of 0.75 means that people who received the intensive treatment were 25 percent less likely to have a heart problem or die compared to those in the standard group. The confidence interval shows the range of numbers that researchers are very sure about, meaning the real benefit is likely between 11 and 36 percent. This matters because it proves that lowering blood pressure more aggressively helps people stay healthier.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.30, 45 words, 14.7 s): The hazard ratio of 0.75 means the risky events happened less often in the low-blood-pressure group than the other group. The 95% CI of 0.64 to 0.89 is a range showing how sure we are that this difference is real and not just a fluke.
  - Note: explains. Exact figures, sure it is not luck.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.20, 74 words, 3.3 s, nums 1.0, 25): The hazard ratio of 0.75 indicates a 25 percent relative risk reduction for the primary composite cardiovascular outcome in the intensive treatment group compared to the standard group. The 95 percent confidence interval, ranging from 0.64 to 0.89, excludes the null value of 1.0, confirming that the observed benefit is statistically significant. This precision suggests a robust clinical effect, supporting the efficacy of lower systolic targets despite the associated increase in specific adverse events.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.33, 43 words, 29.5 s, guard retried): The hazard ratio of 0.75 means intensive treatment reduced the rate of major cardiovascular events compared to standard treatment over the median follow-up of 3.26 years. The 95% CI of 0.64 to 0.89 is entirely below 1, showing the reduction is statistically significant.
  - Note: explains. Keeps 0.75 and 0.64 to 0.89, interval below 1, and the 3.26-year follow-up. No 25% conversion.

## h11. Once-Weekly Semaglutide in Adults with Overweight or Obesity

Source: https://pubmed.ncbi.nlm.nih.gov/33567185/  
Highlight: "-14.9% in the semaglutide group as compared with -2.4% with placebo"

### h11 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.19, 33 words, 3.8 s): People taking semaglutide lost 14.9 percent of their body weight, while those taking a fake pill only lost 2.4 percent. This shows the drug was much more effective at helping people lose weight.
  - Note: explains. 14.9% vs 2.4%, exact.
- **Qwen 3.5 4B, new prompts** (overlap 0.15, 30 words, 8.3 s): People on the drug lost 14.9% of their weight, while those on the dummy shot lost only 2.4%. That means the drug caused a much bigger drop in body weight.
  - Note: explains. 14.9% vs 2.4%, exact.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 23 words, 7.3 s, nums fifteen): People taking the special medicine lost about fifteen percent of their body weight. People taking the fake medicine lost only about two percent.
  - Note: partly. Rounds 14.9% to 'about fifteen' and 2.4% to 'about two'.
- **Qwen 3.5 4B, new prompts** (overlap 0.20, 28 words, 8.1 s): The drug group lost 14.9% of their starting weight, while the fake shot group lost only 2.4%. That means the real medicine helped people lose much more weight.
  - Note: explains. Both figures exact.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.21, 24 words, 2.0 s, nums fifteen): This highlights a striking efficacy difference, showing that semaglutide drove a nearly fifteen percent weight loss compared to just over two percent for placebo.
  - Note: partly. 'Nearly fifteen' and 'just over two' instead of 14.9 and 2.4.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 42 words, 16.3 s): Semaglutide drove a mean weight loss of -14.9% versus -2.4% on placebo at week 68, an estimated treatment difference of -12.4 percentage points (95% CI, -13.4 to -11.5; P<0.001). This reflects the primary estimand, capturing effects regardless of discontinuation or rescue interventions.
  - Note: explains. 14.9% vs 2.4%, and the 12.4 point difference and 68 weeks from the paper.

### h11 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 27 words, 0.3 s, nums fifteen, hundred): People taking the medicine lost about fifteen percent of their body weight, like losing fifteen pounds out of one hundred, while the control group lost very little.
  - Note: partly. 'About fifteen percent' and 'fifteen pounds out of one hundred'; the control group 'lost very little' drops 2.4%.
- **Qwen 3.5 4B, new prompts** (overlap 0.14, 31 words, 8.7 s): People on the drug lost 14.9% of their body weight, while those on the dummy shot lost only 2.4%. That means the drug helped them lose much more over 68 weeks.
  - Note: explains. Both figures exact, and it keeps the 68 weeks.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 23 words, 5.7 s): People taking the medicine lost about 15 percent of their body weight, while those taking a fake pill only lost about 2 percent.
  - Note: partly. About 15 percent vs about 2 percent; both rounded.
- **Qwen 3.5 4B, new prompts** (overlap 0.17, 32 words, 8.8 s): The weight went down 14.9% for people on the drug, but only 2.4% for those on the sugar pill. The difference is that the drug made them lose a lot more weight.
  - Note: explains. Both figures exact.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 28 words, 5.1 s, nums fifteen): People taking the drug lost about fifteen percent of their body weight, while those taking a dummy pill lost only two percent. It is like shedding a backpack.
  - Note: partly. About fifteen vs only two; 2.4% is rounded off.
- **Qwen 3.5 4B, new prompts** (overlap 0.26, 30 words, 19.7 s, guard retried): The mean change in body weight was -14.9% with semaglutide versus -2.4% with placebo over 68 weeks. The difference is -12.4 percentage points, meaning the drug group lost more weight.
  - Note: explains. Both figures exact over 68 weeks.

### h11 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.10, 62 words, 3.8 s): This comparison shows that people taking the medication semaglutide lost significantly more body weight over 68 weeks than those taking a placebo. The negative percentages indicate a decrease in weight from the starting point. This matters because it demonstrates that the drug is much more effective at promoting weight loss than just lifestyle changes alone, which is what the placebo group experienced.
  - Note: explains. More weight loss over 68 weeks than placebo; negative percents are a decrease.
- **Qwen 3.5 4B, new prompts** (overlap 0.29, 45 words, 19.5 s, guard retried): Over 68 weeks, people on semaglutide lost 14.9% of their starting weight versus 2.4% for those on placebo. That -14.9% is the average drop in body weight as a percentage of the baseline weight, and the -2.4% is the average drop for the placebo group.
  - Note: explains. Week 68, 14.9% vs 2.4%.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.04, 58 words, 8.3 s): This shows how much weight people lost during the study. The group taking the medicine lost about 15 percent of their body weight, while the group taking a fake pill lost only about 2 percent. This matters because it proves the medicine is much more effective at helping people lose weight than just changing their lifestyle habits alone.
  - Note: partly. About 15 percent vs about 2 percent, but it does keep the comparison and the idea.
- **Qwen 3.5 4B, new prompts** (overlap 0.33, 29 words, 12.4 s): The semaglutide group lost 14.9% of their body weight, while the placebo group lost only 2.4%. This means the drug helped people shed more weight than the dummy treatment.
  - Note: explains. Same, over 68 weeks.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 69 words, 4.6 s): This comparison highlights the significant efficacy of once-weekly subcutaneous semaglutide for weight management in non-diabetic individuals. The substantial difference between the active treatment and placebo groups demonstrates that semaglutide induces clinically meaningful weight loss over 68 weeks. This effect size is particularly notable given the primary estimand approach, which accounts for treatment discontinuation and rescue interventions, providing a robust measure of the drug's therapeutic impact on body weight reduction.
  - Note: explains. Clinically meaningful loss over 68 weeks; no rounded-off figures required in this fuller framing.
- **Qwen 3.5 4B, new prompts** (overlap 0.20, 37 words, 14.2 s): The mean change in body weight was -14.9% with semaglutide versus -2.4% with placebo. That's an estimated treatment difference of -12.4 percentage points, meaning the drug drove 12.4 more percentage points of weight loss than the control.
  - Note: explains. -14.9 vs -2.4, -12.4 point difference, over 68 weeks.

## h12. More than 75 percent decline over 27 years in total flying insect biomass in protected areas

Source: https://pubmed.ncbi.nlm.nih.gov/29045418/  
Highlight: "a seasonal decline of 76%, and mid-summer decline of 82% in flying insect biomass over the 27 years of study"

### h12 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.27, 28 words, 0.3 s, nums eighty, quarters, seven, three, twenty): Over twenty seven years, the total weight of flying insects dropped by over three quarters during the season and by over eighty percent during the middle of summer.
  - Note: partly. Keeps 27 years, but rounds 76% to 'over three quarters' and 82% to 'over eighty percent'.
- **Qwen 3.5 4B, new prompts** (overlap 0.47, 27 words, 13.8 s, guard retried): Flying insect weight dropped 76% across a season and 82% in mid-summer over the 27 years. This shows how much less food is available for other animals.
  - Note: explains. 76%, 82%, and 27 years all exact; seasonal vs mid-summer read correctly. No 'lighter in spring'.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.36, 22 words, 4.5 s, nums quarters, three, dropped 27 years): The total weight of all flying insects dropped by over three quarters during the summer months over the course of the study.
  - Note: partly. Drops 27 years and the 82% mid-summer figure; 'over three quarters during the summer months' collapses the two declines.
- **Qwen 3.5 4B, new prompts** (overlap 0.40, 32 words, 15.3 s, guard retried): Over 27 years, flying insect weight dropped 76% across a season and 82% in mid-summer. This big loss in total food for other animals is happening everywhere, not just in one spot.
  - Note: explains. Same three figures, correctly framed.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 29 words, 1.9 s, dropped 27 years): The data indicates a severe, long-term reduction in total flying insect mass across diverse protected habitats. This magnitude of loss significantly exceeds previous estimates based on individual species counts.
  - Note: partly. Qualitative long-term loss only; drops 27 years, 76%, and 82%.
- **Qwen 3.5 4B, new prompts** (overlap 0.39, 34 words, 17.1 s, guard retried): Flying insect biomass dropped 76% seasonally and 82% by mid-summer over 27 years. This loss matters because it shows a massive drop in the total fuel for food webs, not just fewer individual species.
  - Note: explains. Same three figures over 27 years.

### h12 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.14, 27 words, 3.9 s, nums quarters, three, dropped 27 years): This means the total weight of all flying insects dropped by over three quarters. It is like having a full jar of fireflies and losing almost everyone.
  - Note: partly. Drops 27 years and 82%; only 'over three quarters'.
- **Qwen 3.5 4B, new prompts** (overlap 0.44, 31 words, 7.5 s): Over 27 years, flying insects got lighter by 76% a season and 82% in mid-summer. This drop matters because it means less food for other animals and less work for nature.
  - Note: explains. All three figures exact; seasonal vs mid-summer kept.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.31, 25 words, 1.6 s, nums 80): Over 27 years, the total weight of flying insects dropped by about 80 percent, like a forest losing most of its leaves during the fall.
  - Note: partly. Keeps 27 years but merges the two declines into 'about 80 percent'.
- **Qwen 3.5 4B, new prompts** (overlap 0.47, 31 words, 9.2 s): Over 27 years, the total weight of flying insects dropped by 76% in a season and 82% in mid-summer. That's like losing most of the food supply for birds and bugs.
  - Note: explains. All three figures exact.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.12, 24 words, 1.9 s, nums three, dropped 27 years): The total weight of flying insects dropped drastically over nearly three decades, like a massive, steady leak draining a tank until almost nothing remains.
  - Note: partly. 'Nearly three decades' with no 76% or 82%.
- **Qwen 3.5 4B, new prompts** (overlap 0.31, 28 words, 14.3 s, dropped 27 years, guard retried): The 76% drop is across a season, and the 82% drop is in mid-summer. These are big losses in how much living stuff there is for food webs.
  - Note: partly. Keeps 76% and 82% and the seasonal vs mid-summer split, but still drops the 27 years.

### h12 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.21, 75 words, 4.4 s, dropped 27 years): This phrase describes a massive reduction in the total weight of all flying insects collected during the study. A seasonal decline refers to the drop in insect numbers across the entire year, while the mid-summer decline specifically highlights the loss during the peak months when insects are usually most active. This matters because such a sharp decrease suggests that the environment is struggling to support insect life, which threatens the food sources for other animals.
  - Note: partly. Good account of seasonal vs mid-summer, but drops 27 years and the exact percents.
- **Qwen 3.5 4B, new prompts** (overlap 0.33, 48 words, 9.0 s): The 76% drop is across a season, and the 82% drop is specifically in mid-summer. This is the total weight of all flying insects caught, not just one type. It shows a massive loss of insect food over 27 years that isn't explained by weather or land use.
  - Note: explains. All three figures, plus why biomass matters for food webs.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 66 words, 2.6 s, nums quarters, three, dropped 27 years): This means that the total weight of all flying insects caught in traps dropped by over three quarters during the time researchers watched them. It matters because insects are a major food source for many birds and other animals. If there are far fewer insects, those animals will have a harder time finding enough to eat, which could cause big problems for the entire natural environment.
  - Note: partly. 'Over three quarters'; drops 27 years and 82%.
- **Qwen 3.5 4B, new prompts** (overlap 0.38, 45 words, 142.9 s): Insects are disappearing fast, and this loss matters because they feed many animals. Over 27 years, flying insects were 76% lighter in a season and 82% lighter in mid-summer. This is not about how few bugs we see, but how much total weight they carry.
  - Note: explains. All three figures, food chains.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.12, 67 words, 6.1 s, dropped 27 years): This finding reveals a massive, multi-decade drop in total flying insect weight across protected German nature reserves. Measuring biomass rather than just single species counts is crucial because total mass directly reflects energy availability in food webs and overall ecosystem functioning. The sheer magnitude of these seasonal and mid-summer losses indicates a systemic ecological crisis that cannot be explained by local weather or land use changes alone.
  - Note: partly. Strong qualitative account, but drops 27 years, 76%, and 82%.
- **Qwen 3.5 4B, new prompts** (overlap 0.36, 36 words, 20.6 s, guard retried): Over 27 years, flying insect biomass dropped by 76% seasonally and 82% in mid-summer. This loss of total mass, not just species counts, matters because it directly reduces energy flow through food webs and ecosystem services.
  - Note: explains. All three figures; decline not explained by weather or land use, from the paper.

## h13. PSYCHOLOGY. Estimating the reproducibility of psychological science

Source: https://pubmed.ncbi.nlm.nih.gov/26315443/  
Highlight: "Thirty-six percent of replications had statistically significant results"

### h13 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 30 words, 0.3 s, nums third): Only about one third of the repeated studies produced the same meaningful evidence as the originals. This shows that many initial findings were likely not as strong as first reported.
  - Note: explains. About one third; many original findings were not as strong as first reported.
- **Qwen 3.5 4B, new prompts** (overlap 0.08, 28 words, 7.2 s): Only 36% of the new studies showed a clear result, while 97% of the first studies did. That's a big drop in how often the findings held up.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.40, 20 words, 2.7 s): Out of the studies tested again, only thirty-six percent got the same important or clear results as the first time.
  - Note: explains. Keeps thirty-six percent exactly.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 32 words, 8.3 s): Only 36% of the new experiments showed a real effect, meaning most failed to prove what the old ones did. That's why scientists need to repeat work to know if it's true.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 23 words, 1.9 s, nums third): Only about a third of the replicated studies achieved statistical significance. This reveals a major drop in reproducibility compared to the original literature.
  - Note: explains. About a third; a drop in reproducibility.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 33 words, 8.7 s): Only 36% of the new studies showed a result strong enough to beat random chance, while 97% of the originals did. That's a big drop in how often we can trust the findings.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

### h13 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.09, 27 words, 24.8 s, nums third, twice): Only about one third of the repeated experiments got the same clear results as the first time. It is like trying a recipe twice and failing once.
  - Note: partly. One third is fair, but 'trying a recipe twice and failing once' is a 50% miss, not 36%.
- **Qwen 3.5 4B, new prompts** (overlap 0.08, 25 words, 8.0 s): Of the 100 studies checked, only 36% showed a result strong enough to be considered real again. That means most of them didn't hold up.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.09, 25 words, 3.6 s, nums third, twice): Only about one third of the repeated experiments got the same clear results as the first time, like trying a recipe twice and failing once.
  - Note: partly. Same off recipe-twice comparison.
- **Qwen 3.5 4B, new prompts** (overlap 0.09, 28 words, 6.1 s): Only 36% of the new tests showed a clear result. That means most of the time, the new study didn't prove the same thing as the first one.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.14, 26 words, 3.0 s, nums third): Only about a third of the repeated studies found the same significant results, like a coin flip landing on heads much less often the second time.
  - Note: partly. One third is fair; the coin-flip comparison does not keep the scale.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 27 words, 6.4 s): Only 36% of the new studies showed a real effect, down from 97% of the originals. That means most of the original findings were likely false positives.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

### h13 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.09, 55 words, 1.8 s, nums hundred): This means that when researchers tried to repeat one hundred previous psychology studies, only thirty-six percent of them produced clear and reliable discoveries that met standard scientific thresholds. This matters because it shows that a large number of published findings might be difficult to reproduce, raising important questions about the reliability of published scientific research.
  - Note: explains. Thirty-six percent of one hundred studies; reliability of published work.
- **Qwen 3.5 4B, new prompts** (overlap 0.05, 41 words, 7.6 s): Out of 100 studies, only 36 showed a clear result that was strong enough to beat chance. That's much lower than the 97% for the original papers. It shows many scientific findings are hard to repeat, which hurts trust in science.
  - Note: explains. 36 of 100, so 64 did not reach the standard. The 64 is a complement, not a new result.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.04, 73 words, 3.8 s, nums third): This means that when researchers tried to repeat the original experiments, only about one third of them got the same clear results as the first time. In science, repeating an experiment is important to prove that the first result was not just a lucky guess or a mistake. Since so many studies failed to get the same results again, it suggests that many original findings might be less reliable than we first thought.
  - Note: explains. About one third; many original findings may be less reliable.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 29 words, 8.6 s): Only 36% of the new tests showed a real link, even though 97% of the first ones did. It means many original findings were just noise, not true patterns.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.04, 69 words, 12.3 s, nums third): This finding indicates a substantial replication crisis within psychology, where only about one third of studies yielded significant p values upon retesting. Given the high powered designs used, this low success rate suggests that many original findings were likely false positives or inflated by publication bias, rather than reflecting robust phenomena. This discrepancy highlights a systemic failure to reliably reproduce experimental effects, undermining the validity of the original literature.
  - Note: explains. About one third significant on retest; possible false positives or publication bias.
- **Qwen 3.5 4B, new prompts** (overlap 0.13, 40 words, 7.5 s): Only 36% of the replications showed a statistically significant effect, whereas 97% of the original studies did. This large drop suggests that many published findings are not robust and may be artifacts of small sample sizes or other methodological issues.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

## h14. Microstructure of a spatial map in the entorhinal cortex

Source: https://pubmed.ncbi.nlm.nih.gov/15965463/  
Highlight: "any vertex of a regular grid of equilateral triangles spanning the surface of the environment"

### h14 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.10, 21 words, 3.6 s): This refers to any corner point on a repeating pattern of triangles that covers the area the animal is moving through.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.07, 29 words, 7.1 s): The brain uses a pattern of spots that form perfect triangles across the space. The animal lights up one spot whenever it stands on any corner of those triangles.
  - Note: explains. Honeycomb spots; a cell lights up at those points. Fair reading of a triangular grid.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.09, 21 words, 4.6 s): This means any corner point on a repeating pattern made of triangles that covers the area where the animal is walking.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 27 words, 7.1 s): Imagine the animal's world is covered in a giant invisible checkerboard made of perfect triangles. The brain lights up whenever it touches a spot on that grid.
  - Note: explains. A grid of perfect triangles, not a square graph paper.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.10, 28 words, 5.9 s): Grid cells fire at specific locations forming a hexagonal lattice across the environment. This geometric arrangement allows the brain to encode spatial coordinates through a periodic, repeating structure.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.11, 28 words, 5.7 s): Grid cells fire at every corner of a regular triangular lattice that covers the entire space. This means the animal's position matches any point on that geometric pattern.
  - Note: explains. Equilateral triangle vertices; precise and at the right level.

### h14 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 26 words, 23.2 s): This means a brain cell fires when an animal stands on any corner of a repeating triangle pattern that covers the floor like a tiled floor.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.07, 28 words, 6.8 s): The brain uses a map made of many tiny triangles that cover the whole space. The animal lights up one triangle at a time as it walks across.
  - Note: explains. Invisible net of perfect triangles; lights up on the corners.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 26 words, 2.9 s): This means the brain cell turns on when the animal stands on a specific spot in a pattern of triangles, like dots on a game board.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 24 words, 5.4 s): Imagine a giant invisible grid of perfect triangles covering the ground. Every time the animal stands on one corner, a special cell lights up.
  - Note: explains. Honeycomb corners, same idea.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 25 words, 3.0 s): The cell fires when the animal reaches specific points on a triangular pattern covering the floor, much like a repeating honeycomb grid on a map.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.07, 31 words, 6.3 s): The brain makes a map like a grid over the world. Every point on that grid lights up a neuron, and the whole grid stays put even if landmarks are gone.
  - Note: explains. Equilateral triangle pattern covering the space.

### h14 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 75 words, 0.3 s): This phrase describes the specific locations where a grid cell fires or becomes active. Imagine a map covered in a perfectly repeating pattern of triangles. When an animal stands exactly on one of the points where these triangle corners meet, the brain cell fires. This matters because it shows how the brain creates a precise internal coordinate system, like a GPS grid, to help the animal track its exact location as it moves through space.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.13, 45 words, 8.9 s): Grid cells light up at spots forming a perfect pattern of matching triangles across the space. Each spot is a 'vertex' where the animal can be found. The whole brain acts like a map with these vertices, allowing the animal to navigate even without landmarks.
  - Note: explains. Matching triangles and vertices; navigation without landmarks. No checkerboard-square mix-up.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 60 words, 1.8 s): This phrase describes a special repeating pattern of triangles that covers the space an animal explores. Each corner point in this triangle pattern acts like a trigger in the brain, turning on a specific brain cell whenever the animal steps on that exact spot. This helps the brain map out the environment and figure out where the animal is located.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.05, 43 words, 10.6 s): Imagine a floor covered in matching triangular tiles. The 'grid cell' fires whenever the animal is on one of those tiles, and nearby cells line up to show where they are. This map helps the animal figure out its position without seeing landmarks.
  - Note: explains. Triangular tiles; fires even if landmarks are gone.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 61 words, 3.0 s): This refers to the hexagonal spatial firing pattern of grid cells in the dMEC. The vertices represent the specific locations where a cell fires, forming a periodic, triangular lattice that tiles the environment. This geometry is critical because it provides a metric for spatial representation, allowing the brain to compute distance and direction through path integration, independent of external sensory landmarks.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.04, 36 words, 10.3 s): Grid cells fire at precise locations forming a geometric lattice across the world. Their phases shift between neighbors, yet they maintain shared orientation and spacing, creating a stable coordinate system for path integration even without landmarks.
  - Note: explains. Hexagonal lattice, dorsal-to-ventral spacing from the paper, path integration.

## h15. Why most published research findings are false

Source: https://pubmed.ncbi.nlm.nih.gov/16060722/  
Highlight: "claimed research findings may often be simply accurate measures of the prevailing bias"

### h15 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 27 words, 0.3 s): Scientific results might not reflect reality at all. Instead, they often just show the common prejudices or expectations that researchers already held before they started their study.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 31 words, 6.4 s): When too many small studies chase tiny effects, the results often just match the researcher's expectation or bias. It means the numbers reflect what was hoped for, not what is real.
  - Note: explains. The reported numbers may mirror the bias in how people looked for answers.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 29 words, 4.9 s): Scientific results might not be showing the truth. Instead, they often just reflect the unfair opinions or personal beliefs that the researchers already had before they started their work.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 29 words, 6.1 s): Some results might just show what people already expect to see, not what is real. That means the numbers could be wrong because of how the study was done.
  - Note: explains. Results may show what people already expect, not what is real.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.14, 31 words, 2.8 s): Published results often reflect systematic errors or preconceived notions within a field rather than objective reality. These findings quantify the influence of bias instead of measuring the actual phenomenon under investigation.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 35 words, 6.9 s): The paper argues that many published results are just reflections of who got funded or what was expected, not real discoveries. So when you see a finding, check if it matches the field's common bias.
  - Note: explains. Systematic errors in design or funding, not truths about nature.

### h15 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 26 words, 7.7 s): Scientific results might just be a mirror reflecting whatever widespread prejudice or unfair leaning already exists, like a biased scale that always tips the same way.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 20 words, 5.1 s): This means a lot of published results might just show how researchers are biased, not real facts about the world.
  - Note: explains. Results can reflect what researchers already want to see.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 26 words, 3.8 s): Scientists sometimes just report what they already expect to see instead of the truth, like a mirror reflecting only what is placed in front of it.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 26 words, 7.5 s): The study says some papers just show what people already believe, not real facts. It's like a mirror that only shows what you want to see.
  - Note: explains. Papers may show what people already believe; a clear mirror comparison.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 25 words, 6.8 s): Published scientific claims often just measure the hidden prejudices of the researchers, like a crooked scale that always weighs in favor of what scientists want.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 24 words, 5.7 s): Sometimes published results are just showing what the researchers wanted to find because of how they looked at the data or picked their questions.
  - Note: explains. A small or biased study may reflect the bias rather than a real effect.

### h15 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.03, 76 words, 3.9 s): This means that instead of discovering a new scientific truth, a study might just be reporting results that confirm what researchers already wanted or expected to find. It matters because it suggests that scientific data can be skewed by human prejudice or financial interests. When this happens, the study does not actually reveal facts about the world, but instead acts as a mirror that reflects the existing opinions or biases of the people conducting the research.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.05, 42 words, 7.0 s): This line says that many published results might just be a record of how researchers are biased. If a study is small or has bad design, it can show a pattern that reflects the bias in the field, not a real truth.
  - Note: explains. Expectations or hidden influences; a number does not prove truth on its own.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.03, 47 words, 13.8 s): This means that instead of discovering new scientific truths, many published research studies are just accurately measuring the unfair prejudices or errors that scientists already held. This matters because it shows that science can sometimes be misled by human mistakes or outside influences rather than actual facts.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 34 words, 6.5 s): Sometimes what scientists think they found is just a mirror of how they were looking. If researchers only test ideas that fit their hopes or money, the results will match those biases, not reality.
  - Note: explains. Pushed by money or expectations; a study can be designed to make a link appear.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 67 words, 4.8 s): This statement suggests that in fields with high researcher flexibility and strong incentives for positive results, reported findings frequently reflect systematic error rather than biological reality. Instead of capturing true effects, the data effectively quantifies the researcher's prior expectations or the field's collective prejudice. This implies that the statistical significance observed is often an artifact of the experimental design choices that favor confirmation bias over objective discovery.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.05, 38 words, 7.9 s): This means many published results don't reflect real effects but rather systematic errors in how studies are designed, funded, or analyzed. It's not about bad data, but about the structure of the research process itself favoring false positives.
  - Note: explains. Small samples and flexible designs amplify bias; a positive result may be systematic error.
