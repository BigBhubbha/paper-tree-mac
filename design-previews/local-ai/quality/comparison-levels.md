# Paper Tree local reader: quality test

Reading-levels pass at 1c9721c. Every highlight (h01 to h15, plus r00) was run at Plain, Simpler and More detail for three reader profiles: no profile (curious high schooler), a middle-school beginner, and a grad student. Qwen 3.5 4B ran on the box (6 threads, 15 GB, CPU only, llama.cpp b12428, prompt cache on). Gemini answers came through the Worker at paper-tree-explain.papertree.workers.dev (read-only, gemini-3.1-flash-lite). The 9B was skipped. Quality CI is run 44131169113; those official Linux 4 vCPU times were not in yet when this was written, so the 4B times below are from the box, which is still slower than a real Apple Silicon Mac. r00 is a regression check and is not scored.

## Summary (real highlights, regression left out)

| Model | n | Restating (overlap 0.5 or more) | Avg overlap | Avg words | Avg time per explanation | Guard retries | Numbers not in the paper (auto check) | Dropped time spans | My read: explains / partly / restates / has an error |
|---|---|---|---|---|---|---|---|---|---|
| Gemini (gemini-3.1-flash-lite, via the Worker) | 135 | 0 of 135 (0%) | 0.09 | 39 | 4.4 s (Paper Tree Worker (read-only)) | 0 | 33 of 135 | 14 of 135 | 105 / 30 / 0 / 0 |
| Qwen 3.5 4B, new prompts | 135 | 0 of 135 (0%) | 0.16 | 34 | 15.4 s (box, 6 threads, 15 GB, CPU only) | 23 | 4 of 135 | 2 of 135 | 115 / 13 / 0 / 7 |

Overlap is the share of an answer's content words that already appear in the highlight (stop words left out). It catches word-for-word restating, not a paraphrase in new words, so each answer also has my own short note.

## Counts by mode and by reader profile

### By mode

| Mode | Model | n | My read: explains / partly / restates / has an error | Avg time | Restating | Numbers not in the paper | Dropped time spans |
|---|---|---|---|---|---|---|---|
| plain | Gemini (gemini-3.1-flash-lite, via the Worker) | 45 | 37 / 8 / 0 / 0 | 2.8 s | 0 | 10 | 4 |
| plain | Qwen 3.5 4B, new prompts | 45 | 40 / 5 / 0 / 0 | 15.9 s | 0 | 0 | 0 |
| simpler | Gemini (gemini-3.1-flash-lite, via the Worker) | 45 | 28 / 17 / 0 / 0 | 5.5 s | 0 | 13 | 5 |
| simpler | Qwen 3.5 4B, new prompts | 45 | 35 / 5 / 0 / 5 | 12.2 s | 0 | 2 | 2 |
| detail | Gemini (gemini-3.1-flash-lite, via the Worker) | 45 | 40 / 5 / 0 / 0 | 4.8 s | 0 | 10 | 5 |
| detail | Qwen 3.5 4B, new prompts | 45 | 40 / 3 / 0 / 2 | 18.2 s | 0 | 2 | 0 |

### By reader profile

| Reader profile | Model | n | My read: explains / partly / restates / has an error | Avg time | Restating | Numbers not in the paper | Dropped time spans |
|---|---|---|---|---|---|---|---|
| default | Gemini (gemini-3.1-flash-lite, via the Worker) | 45 | 38 / 7 / 0 / 0 | 4.5 s | 0 | 10 | 3 |
| default | Qwen 3.5 4B, new prompts | 45 | 37 / 4 / 0 / 4 | 12.6 s | 0 | 1 | 0 |
| beginner | Gemini (gemini-3.1-flash-lite, via the Worker) | 45 | 33 / 12 / 0 / 0 | 4.5 s | 0 | 11 | 5 |
| beginner | Qwen 3.5 4B, new prompts | 45 | 39 / 5 / 0 / 1 | 12.8 s | 0 | 0 | 0 |
| grad | Gemini (gemini-3.1-flash-lite, via the Worker) | 45 | 34 / 11 / 0 / 0 | 4.1 s | 0 | 12 | 6 |
| grad | Qwen 3.5 4B, new prompts | 45 | 39 / 4 / 0 / 2 | 20.9 s | 0 | 3 | 2 |

### Mode and profile together

| Mode | Profile | Model | n | My read: explains / partly / restates / has an error | Avg time |
|---|---|---|---|---|---|
| plain | default | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 14 / 1 / 0 / 0 | 1.0 s |
| plain | default | Qwen 3.5 4B, new prompts | 15 | 14 / 1 / 0 / 0 | 10.7 s |
| plain | beginner | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 11 / 4 / 0 / 0 | 4.7 s |
| plain | beginner | Qwen 3.5 4B, new prompts | 15 | 11 / 4 / 0 / 0 | 13.0 s |
| plain | grad | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 12 / 3 / 0 / 0 | 2.7 s |
| plain | grad | Qwen 3.5 4B, new prompts | 15 | 15 / 0 / 0 / 0 | 24.1 s |
| simpler | default | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 10 / 5 / 0 / 0 | 8.8 s |
| simpler | default | Qwen 3.5 4B, new prompts | 15 | 10 / 2 / 0 / 3 | 10.4 s |
| simpler | beginner | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 9 / 6 / 0 / 0 | 3.7 s |
| simpler | beginner | Qwen 3.5 4B, new prompts | 15 | 13 / 1 / 0 / 1 | 10.9 s |
| simpler | grad | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 9 / 6 / 0 / 0 | 3.9 s |
| simpler | grad | Qwen 3.5 4B, new prompts | 15 | 12 / 2 / 0 / 1 | 15.4 s |
| detail | default | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 14 / 1 / 0 / 0 | 3.6 s |
| detail | default | Qwen 3.5 4B, new prompts | 15 | 13 / 1 / 0 / 1 | 16.9 s |
| detail | beginner | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 13 / 2 / 0 / 0 | 5.2 s |
| detail | beginner | Qwen 3.5 4B, new prompts | 15 | 15 / 0 / 0 / 0 | 14.6 s |
| detail | grad | Gemini (gemini-3.1-flash-lite, via the Worker) | 15 | 13 / 2 / 0 / 0 | 5.6 s |
| detail | grad | Qwen 3.5 4B, new prompts | 15 | 12 / 2 / 0 / 1 | 23.2 s |

## r00. Leaves in a dry spell (Paper Tree's own sample text, the highlight the 2B restated) (regression check, not scored)

Source: Sources/PaperTree/Snapshots.swift  
Highlight: "Rubisco also reacts with oxygen, and that side reaction becomes more common as carbon dioxide inside the leaf drops."

### r00 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.56, 24 words, 0.3 s): Rubisco sometimes accidentally reacts with oxygen instead of carbon dioxide. This wasteful side reaction increases when carbon dioxide levels inside the leaf go down.
  - Note: restates. Closest to the highlight (overlap 0.56). Rephrases the same two facts and adds almost no why.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 31 words, 10.3 s): Rubisco is a factory enzyme that makes sugar from air. If the air supply gets low, it mistakes the wrong gas for its job and starts making junk instead of sugar.
  - Note: explains. Wrong gas when the air supply is low; 'making junk' is loose but the idea is right.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.19, 24 words, 9.3 s): Sometimes the plant helper molecule accidentally grabs oxygen instead of carbon dioxide. When this happens, the plant wastes energy trying to fix the mistake.
  - Note: explains. Oxygen grabbed by mistake; the plant wastes energy fixing it.
- **Qwen 3.5 4B, new prompts** (overlap 0.25, 32 words, 10.8 s): Rubisco is a busy worker that sometimes makes mistakes when there is too little carbon dioxide. When it mistakes oxygen for carbon dioxide, the plant wastes energy trying to fix the error.
  - Note: explains. Mistake when CO2 is low; wastes energy fixing it.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 27 words, 3.1 s): Rubisco acts as an oxygenase when CO2 concentrations are low, initiating photorespiration. This competitive inhibition forces the plant to expend metabolic energy to recycle the resulting phosphoglycolate.
  - Note: explains. Oxygenase vs carboxylase, photorespiration, energy cost. Accurate textbook.
- **Qwen 3.5 4B, new prompts** (overlap 0.16, 30 words, 7.9 s): Rubisco mistakes oxygen for CO2 when CO2 levels fall, wasting energy fixing the wrong molecule. Plants like grasses avoid this by pumping CO2 to the enzyme, keeping oxygen reactions low.
  - Note: explains. Oxygen for CO2 when levels fall. C4 pumping is fair textbook background.

### r00 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.12, 27 words, 2.5 s): Rubisco is a protein that helps plants grow. It sometimes grabs oxygen by mistake, like a person accidentally picking up the wrong drink at a crowded party.
  - Note: explains. Wrong-drink comparison; grabs oxygen by mistake.
- **Qwen 3.5 4B, new prompts** (overlap 0.40, 28 words, 20.2 s, guard retried): Rubisco is a busy enzyme that usually grabs carbon dioxide. But when there isn't enough carbon dioxide inside the leaf, it accidentally grabs oxygen instead, which wastes energy.
  - Note: explains. Grabs oxygen when CO2 is short; wastes energy.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.21, 20 words, 6.2 s): Sometimes the plant helper molecule makes a mistake and grabs oxygen instead of carbon dioxide, like catching the wrong ball.
  - Note: explains. Wrong-ball comparison; keeps the mistake idea.
- **Qwen 3.5 4B, new prompts** (overlap 0.36, 27 words, 8.7 s): Rubisco sometimes grabs the wrong gas when there isn't enough carbon dioxide. It should grab carbon dioxide, but if that gas is low, it grabs oxygen instead.
  - Note: explains. Wrong gas when CO2 is low.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.29, 25 words, 6.9 s): Like a worker making a mistake when supplies run low, Rubisco messes up with oxygen when carbon dioxide gets too low, wasting the plant's energy.
  - Note: explains. Supplies run low, oxygen mistake, wastes energy.
- **Qwen 3.5 4B, new prompts** (overlap 0.35, 28 words, 10.3 s): Rubisco can mistakenly grab oxygen instead of carbon dioxide. As CO2 levels drop inside the leaf, this error happens more often, wasting energy fixing what was already fixed.
  - Note: explains. Error happens more as CO2 drops; wastes energy.

### r00 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.17, 45 words, 1.5 s): This means Rubisco sometimes makes a mistake by reacting with oxygen instead of carbon dioxide, which wastes the plant's energy. This problem gets worse when there is not enough carbon dioxide available. C4 plants avoid this waste by keeping carbon dioxide levels high around Rubisco.
  - Note: explains. Adds C4 plants keeping CO2 high around Rubisco.
- **Qwen 3.5 4B, new prompts** (overlap 0.25, 30 words, 10.1 s): Rubisco, the enzyme that builds sugar from air, also grabs oxygen when there isn't enough carbon dioxide. This wastes energy because the plant has to fix the mistake it made.
  - Note: explains. Builds sugar from air, grabs oxygen when CO2 is short, has to fix the mistake.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.12, 69 words, 2.9 s): Rubisco is a helper molecule that normally grabs carbon dioxide to help plants grow. However, it sometimes grabs oxygen by mistake instead. When there is not enough carbon dioxide around, this mistake happens more often. This is a problem because the plant then has to waste extra energy to fix the error and get back on track. This process makes the plant less efficient at making its own food.
  - Note: explains. Clear everyday account of the mistake and the energy cost.
- **Qwen 3.5 4B, new prompts** (overlap 0.30, 43 words, 9.8 s): Rubisco is a busy worker that grabs carbon from the air. But when there's not enough carbon dioxide inside the leaf, it mistakes oxygen for carbon instead. This mistake wastes energy because the plant has to do extra work to fix the error.
  - Note: explains. Same account in everyday words.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.04, 67 words, 2.8 s, nums 5): This highlights the oxygenase activity of Rubisco, which competes with its carboxylase function. As the CO2 to O2 ratio decreases, the enzyme increasingly catalyzes the oxygenation of ribulose-1,5-bisphosphate. This initiates photorespiration, a metabolically expensive pathway that releases previously fixed carbon and consumes ATP and reducing power. This inefficiency is a primary constraint on photosynthetic productivity in C3 plants, particularly under conditions of stomatal closure or high temperatures.
  - Note: explains. Photorespiration and C3 constraint. The auto-flagged 5 is from ribulose-1,5-bisphosphate, not an invented result.
- **Qwen 3.5 4B, new prompts** (overlap 0.10, 45 words, 15.7 s): Rubisco isn't specific; it mistakes oxygen for CO2 when CO2 levels fall. This causes photorespiration, a wasteful process that burns fixed carbon without making sugar. Plants with C4 metabolism actively pump CO2 to Rubisco's site, suppressing this error and saving energy under hot, dry conditions.
  - Note: explains. Photorespiration and C4 pumping; accurate and at the right level.

## h01. Attention Is All You Need

Source: https://arxiv.org/abs/1706.03762  
Highlight: "dispensing with recurrence and convolutions entirely"

### h01 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 20 words, 0.4 s): The authors are creating a new model that completely removes the need for traditional recurrent or convolutional neural network structures.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 35 words, 13.7 s): The Transformer doesn't use old methods like keeping a running list or scanning patterns in tiny windows. It only uses attention, which lets it look at all words at once instead of one by one.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 33 words, 3.1 s): This means the new model completely stops using two older methods for processing data. It replaces them with a simpler system that focuses only on paying attention to specific parts of the information.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 33 words, 12.3 s): We built a network that doesn't use the old repeating or scanning tricks. It just uses one smart attention part to look at everything it needs, making it faster and easier to learn.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 25 words, 2.5 s): The authors propose replacing traditional RNN and CNN architectures with a pure attention mechanism. This shift eliminates sequential processing constraints, enabling full parallelization during training.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 32 words, 11.7 s): The Transformer model skips the recurrent and convolutional layers used in previous dominant sequence transduction models. It relies solely on attention mechanisms, which simplifies the architecture while improving parallelization and training speed.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

### h01 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 27 words, 6.6 s): This means completely throwing away the old building blocks of AI, like baking a cake without using flour or sugar, and using a totally new method instead.
  - Note: explains. Cake-without-flour comparison is a bit odd, but the point is clear: the old building blocks are gone.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 29 words, 11.8 s): The new design drops two old parts of the brain-like system. It keeps only one part that lets the model look at all words at once instead of step-by-step.
  - Note: explains. Drops two old parts and keeps the one that looks at all words at once.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 25 words, 3.6 s): This means the new model completely stops using two older, slower ways of processing information, like switching from a winding path to a straight highway.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 22 words, 11.3 s): They ditched two old parts of the computer brain, making a simpler design that learns faster and needs less time to train.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 27 words, 1.4 s): This means removing the traditional step by step processing methods to rely only on attention, like reading a whole page at once instead of word by word.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 23 words, 12.7 s): We removed the usual back-and-forth loops and sliding window filters, keeping only attention. This lets us train faster and use parallel hardware better.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

### h01 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 66 words, 1.5 s): This phrase means that the new Transformer model completely removes the use of recurrent and convolutional neural networks. These older methods process data in a specific step by step order. By getting rid of them, the authors can use attention mechanisms to process all parts of the data at the same time. This makes the model much faster to train and more efficient than previous designs.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 35 words, 13.2 s): This new design drops two older, heavy parts of the network. It uses only attention to link words across sentences instead of relying on complex loops or sliding windows, which makes it faster to train.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 70 words, 2.1 s): This phrase means that the new model completely removes two traditional ways of processing information. Recurrence and convolutions are methods that look at data in a specific order or step by step. By getting rid of them, the new system can process all parts of a sentence at the same time instead of waiting for each piece to finish. This makes the model much faster and more efficient at learning.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 37 words, 13.7 s): The old methods used repeating loops or sliding windows to look at words one step at a time. The Transformer skips those parts, letting it jump straight to related words in any order, which makes training faster.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 72 words, 5.6 s): This phrase signifies a paradigm shift in sequence modeling by abandoning the sequential processing constraints of recurrent neural networks and the local receptive fields of convolutional neural networks. By relying exclusively on self-attention mechanisms, the architecture achieves global dependency modeling and full parallelization across the sequence length. This transition is critical because it eliminates the computational bottlenecks inherent in sequential hidden state updates, enabling significantly more efficient training on modern hardware accelerators.
  - Note: explains. Drops recurrence and convolutions; attention looks at everything at once / trains faster.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 39 words, 13.8 s): The Transformer replaces the standard recurrent and convolutional layers used in previous sequence transduction models. By relying only on attention mechanisms, it removes the need for sequential processing or local feature extraction, enabling full parallelization and faster training times.
  - Note: explains. Skips the old loops and sliding windows; attention looks at all words at once and trains faster.

## h02. Observation of Gravitational Waves from a Binary Black Hole Merger

Source: https://arxiv.org/abs/1602.03837  
Highlight: "a false alarm rate estimated to be less than 1 event per 203 000 years, equivalent to a significance greater than 5.1 σ"

### h02 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.20, 26 words, 0.4 s): This means scientists are extremely certain the signal was real and not random noise. A chance accident like this would only happen once every 203,000 years.
  - Note: explains. Keeps the 203,000-year figure and says the signal is not noise.
- **Qwen 3.5 4B, new prompts** (overlap 0.31, 34 words, 15.4 s): The chance that this signal was just random noise is less than one in 203,000 years. That's why scientists say it is more than 5.1 standard deviations away from what they'd expect by accident.
  - Note: explains. Copies 203,000 years and 5.1 sigma and says what they mean.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 26 words, 1.8 s, dropped 203 000 years): This means the signal was so clear that it is almost impossible for it to be a mistake. It is extremely unlikely to happen by chance.
  - Note: partly. Drops the 203,000 years and 5.1 sigma; only says it is almost impossible.
- **Qwen 3.5 4B, new prompts** (overlap 0.39, 40 words, 31.5 s, guard retried): This signal was so rare that it would only happen by chance less than once every 203 000 years. That's why scientists say the significance is greater than 5.1 σ, meaning it is very unlikely to be a random mistake.
  - Note: explains. Same, after a retry: both figures exact.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 29 words, 1.9 s, nums five, dropped 203 000 years): The detection is statistically robust, with the background noise probability being extremely low. This exceeds the five sigma threshold typically required to claim a formal discovery in particle physics.
  - Note: partly. Drops 203,000 years, rounds 5.1 to 'five sigma', and calls it a particle-physics threshold. LIGO is gravitational waves.
- **Qwen 3.5 4B, new prompts** (overlap 0.39, 43 words, 27.6 s, guard retried): This false alarm rate means if there were no real signal, we'd expect to see something like this by chance less than once in 203 000 years. The >5.1 σ significance shows the probability of this match occurring by accident is extremely low.
  - Note: explains. False-alarm rate and 5.1 sigma, both exact.

### h02 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 25 words, 2.0 s, nums twice, dropped 203 000 years): This means the signal was so clear that it was extremely unlikely to be a random mistake, like winning the lottery twice in a row.
  - Note: partly. Drops 203,000 years. Lottery-twice comparison does not keep the scale.
- **Qwen 3.5 4B, new prompts** (overlap 0.31, 33 words, 13.2 s): The signal was so rare that it would have happened by chance less than once in 203,000 years. That's like finding a needle in a haystack and being sure the needle is real.
  - Note: explains. Keeps 203,000 years; needle-in-a-haystack comparison does not invent a scale.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 27 words, 1.7 s, nums hundred, thousand, dropped 203 000 years): This means the signal is almost certainly real and not just a random mistake, like winning a lottery that happens only once every two hundred thousand years.
  - Note: explains. Keeps the span in words (two hundred thousand years). Slight rounding of 203,000.
- **Qwen 3.5 4B, new prompts** (overlap 0.29, 34 words, 14.8 s): This signal was so rare that it would happen less than once in 203,000 years by chance alone. The 5.1 sigma means the chance of this being a random noise glitch is extremely tiny.
  - Note: explains. Keeps 203,000 years and 5.1 sigma.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 26 words, 5.3 s, dropped 203 000 years): The signal is so distinct that it is statistically impossible for it to be random noise, like finding a specific grain of sand in a desert.
  - Note: partly. Drops 203,000 years and 5.1 sigma; grain-of-sand comparison.
- **Qwen 3.5 4B, new prompts** (overlap 0.27, 31 words, 30.5 s, nums hundred, thousand, dropped 203 000 years, guard retried): The chance this signal was random noise is less than one in two hundred thousand years. That's a significance of over 5.1 sigma, meaning it's extremely unlikely to be a fluke.
  - Note: explains. Says 'two hundred thousand years' and 5.1 sigma. Slight rounding of 203,000, but the time span is there.

### h02 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.11, 70 words, 1.6 s): This phrase explains that the detection of the gravitational wave was extremely unlikely to be a random error or background noise. By calculating that such a signal would only occur by chance once every 203,000 years, the researchers prove their observation is statistically certain. The 5.1 sigma value is a scientific measure of confidence, indicating that the discovery is almost certainly real and not just a fluke in the data.
  - Note: explains. Keeps 203,000 years and 5.1 sigma and says what they measure.
- **Qwen 3.5 4B, new prompts** (overlap 0.22, 45 words, 30.7 s, guard retried): This number measures how often a fake signal like this would appear by chance if nothing were happening. It says such a random fluke is less likely than once in every 203,000 years, which means the real event is very unlikely to be a mistake.
  - Note: explains. Keeps 203,000 years and explains the false-alarm rate.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.03, 70 words, 1.6 s, nums hundred, thousand, dropped 203 000 years): This means the scientists are extremely confident that the signal they detected was real and not just a random glitch or mistake. Because the chance of this happening by accident is so tiny, like once every two hundred thousand years, they know they truly found something special. This high level of certainty is important because it proves their discovery of gravitational waves is solid and not just a lucky guess.
  - Note: explains. Keeps the span in words (two hundred thousand years) and the certainty.
- **Qwen 3.5 4B, new prompts** (overlap 0.35, 41 words, 29.3 s, guard retried): This rate means you'd expect fewer than one fake signal like this every 203,000 years by pure chance. A significance greater than 5.1 σ shows the signal is far from random noise and is very strong evidence of a real event.
  - Note: explains. Keeps both 203,000 years and 5.1 sigma.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 72 words, 1.5 s, dropped 203 000 years): This statistical threshold confirms the detection is not a stochastic noise fluctuation. By demonstrating that the false alarm rate is extremely low, the authors establish that the signal is a genuine astrophysical event rather than an instrumental artifact. A significance exceeding 5.1 sigma provides the rigorous confidence level required to claim a discovery in gravitational wave astronomy, effectively ruling out the null hypothesis that the observed strain resulted from background detector noise.
  - Note: partly. Keeps 5.1 sigma but drops the 203,000-year false-alarm rate.
- **Qwen 3.5 4B, new prompts** (overlap 0.38, 44 words, 14.9 s): The false alarm rate is the probability of seeing this signal by pure chance if no black hole merger occurred. Less than 1 per 203,000 years means it's extremely unlikely to be noise. The 5.1σ significance confirms the detection is robust against random fluctuations.
  - Note: explains. Both figures exact; says 5.1 sigma is robust against random fluctuations.

## h03. Observation of a new particle in the search for the Standard Model Higgs boson with the ATLAS detector at the LHC

Source: https://arxiv.org/abs/1207.7214  
Highlight: "5.9 standard deviations"

### h03 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 32 words, 0.3 s): This is a statistical measurement showing that the discovery is extremely unlikely to be a random error. It confirms that the particle detected is almost certainly real and not just a fluke.
  - Note: explains. Discovery-level significance, no invented probability.
- **Qwen 3.5 4B, new prompts** (overlap 0.19, 32 words, 7.8 s): 5.9 standard deviations means the signal is extremely unlikely to be a random chance event. It's so far from what we expect by accident that scientists can be very sure it's real.
  - Note: explains. 5.9 means the signal is far from chance; no invented probability.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 33 words, 4.7 s): This is a way scientists measure how sure they are about a discovery. It means the chance that the result happened by accident is so tiny that the discovery is almost certainly real.
  - Note: explains. How sure scientists are; chance of an accident is tiny.
- **Qwen 3.5 4B, new prompts** (overlap 0.16, 38 words, 23.4 s, guard retried): The search found a signal that was 5.9 standard deviations away from what random chance would produce. That means the result is very unlikely to be a fluke and points strongly to the discovery of the Higgs boson.
  - Note: explains. 5.9 from chance; points to the Higgs discovery.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 32 words, 2.5 s): This value represents the statistical significance of the observation. It indicates that the probability of the signal being a random background fluctuation is extremely low, meeting the formal criteria for a discovery.
  - Note: explains. Background fluctuation is extremely low; meets discovery criteria.
- **Qwen 3.5 4B, new prompts** (overlap 0.17, 33 words, 25.1 s, guard retried): The 5.9 standard deviations measure how far the signal is from a random background fluctuation. This level of evidence is extremely unlikely to be a fluke, confirming the discovery of the Higgs boson.
  - Note: explains. Far from a background fluctuation; discovery-level evidence.

### h03 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 27 words, 2.5 s): This is a statistical measurement showing that the discovery is extremely unlikely to be a random accident. It is like flipping a coin and getting heads repeatedly.
  - Note: partly. Coin-flip comparison. It never turns 5.9 into a head count, but the comparison does not keep the scale.
- **Qwen 3.5 4B, new prompts** (overlap 0.07, 28 words, 9.7 s): That's like finding a needle in a haystack that never happened by chance. It's 5.9 times further away from random noise than normal, so it's very likely real.
  - Note: error. Turns 5.9 standard deviations into '5.9 times further away from random noise'.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 26 words, 2.3 s): This is a way to show that a scientific discovery is almost certainly real, like flipping a coin and getting heads many times in a row.
  - Note: partly. Same coin-flip comparison, no wrong count.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 30 words, 9.9 s): That number means the result is far from what would happen by chance. It's like finding a needle in a haystack that you'd never expect to find just by luck.
  - Note: explains. Far from chance; needle-in-a-haystack comparison invents no number.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 24 words, 3.2 s): This indicates the result is statistically robust. It is like flipping a coin and getting heads so many times that luck is essentially impossible.
  - Note: partly. Same coin-flip comparison, no wrong count.
- **Qwen 3.5 4B, new prompts** (overlap 0.14, 35 words, 23.8 s, guard retried): The 5.9 standard deviations means the signal is far from chance. It corresponds to a background fluctuation probability of 1.7x10^-9, indicating very strong evidence for the production and decay of the Standard Model Higgs boson.
  - Note: error. Invented a background probability of 1.7x10^-9, which the paper does not give.

### h03 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 75 words, 6.7 s): In statistics, standard deviations measure how far a result is from what would happen by pure chance. A value of 5.9 means the result is extremely unlikely to be a random error. In particle physics, this specific number is the threshold required to claim a formal discovery. It provides the high level of certainty needed to confirm that the scientists actually found the Higgs boson rather than just seeing a random glitch in their data.
  - Note: explains. 5.9 is far from chance; names the usual discovery threshold without inventing a p-value.
- **Qwen 3.5 4B, new prompts** (overlap 0.15, 40 words, 30.4 s, guard retried): The finding has a significance of 5.9 standard deviations, meaning it is far from what random chance would usually produce. That corresponds to a background fluctuation probability of 1.7x10^-9, which is the chance that the signal is just a fluke.
  - Note: error. Same invented 1.7x10^-9 probability (a computed p-value, not in the paper).

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.03, 63 words, 7.3 s): In science, this number measures how sure researchers are about a discovery. It acts like a confidence score. A score of 5.9 means the result is extremely unlikely to be just a random accident or a mistake. Because this number is so high, scientists are very confident that they actually found a new particle rather than seeing a false signal in their data.
  - Note: explains. Confidence score; 5.9 means it is almost certainly a new particle.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 29 words, 11.5 s): This number shows how sure scientists are that they found something real. A result this far from random chance means it's extremely unlikely to be a mistake or luck.
  - Note: explains. Far from chance, no invented p-value.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 74 words, 3.3 s, nums five): This value represents the statistical significance of the Higgs boson discovery. In particle physics, a five sigma threshold is the conventional benchmark for claiming a formal discovery, as it indicates the probability of the observed signal being a random background fluctuation is extremely low. Reaching 5.9 standard deviations provides robust evidence that the excess of events is a genuine physical phenomenon rather than a statistical artifact, confirming the observation of the new neutral boson.
  - Note: explains. 5.9 vs the conventional five-sigma discovery threshold. 'Five' is that convention, not a new result.
- **Qwen 3.5 4B, new prompts** (overlap 0.04, 48 words, 12.0 s): This 5.9 sigma result means the signal is far beyond random background fluctuations, making it highly unlikely to be a statistical fluke. The probability of this being a background fluctuation is only 1.7x10^-9. It's the strongest evidence yet for the existence of the Higgs boson at that mass.
  - Note: error. Same invented 1.7x10^-9, plus a firm Higgs claim at 'that mass' the highlight never gives.

## h04. Deep Residual Learning for Image Recognition

Source: https://arxiv.org/abs/1512.03385  
Highlight: "We explicitly reformulate the layers as learning residual functions with reference to the layer inputs, instead of learning unreferenced functions."

### h04 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.23, 22 words, 4.5 s): Instead of teaching layers to learn totally new information from scratch, the system has them learn changes based on the original inputs.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.13, 32 words, 9.7 s): Instead of trying to learn a brand new picture from scratch for every layer, this method makes each layer learn only what it needs to fix or improve on what came before.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 24 words, 5.8 s): Instead of teaching the computer layers from scratch, the system learns the small changes needed from the previous step. This makes training much easier.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.18, 33 words, 12.9 s): Instead of trying to learn a brand new function for every single layer, the network learns what to change from the previous layer's output. This makes it easier to train very deep networks.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 38 words, 1.5 s): The layers are redesigned to learn the difference, or residual, between the input and the desired output, rather than trying to fit the full underlying mapping directly. This shift makes gradient propagation much more stable in ultra-deep networks.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.16, 35 words, 164.1 s): Instead of forcing each layer to learn a full transformation from input to output, we let them learn just the difference needed. This makes it easier for very deep networks to train without vanishing gradients.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

### h04 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.15, 24 words, 4.0 s): Instead of teaching a computer layer to learn a brand new task from scratch, we have it focus only on fixing the leftover mistakes.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.20, 28 words, 10.1 s): Instead of trying to learn every single step from scratch, the new method only learns what needs to change. It compares each layer's output to its own input.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.20, 26 words, 2.1 s): Instead of teaching computer layers new information from scratch, we have them learn the difference or leftovers from the input, like finding the missing puzzle piece.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 35 words, 12.6 s): Instead of teaching the network to build a brand new map from scratch, we teach it what to subtract from its previous map. This keeps the signal strong all the way through the deep layers.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.19, 26 words, 1.5 s): Instead of learning total new data transformations, layers learn just the small changes needed. Think of it like editing a draft instead of rewriting the page.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.25, 35 words, 14.2 s): Instead of forcing the network to learn a new function from scratch for each layer, we let it learn the difference between the input and the output. This makes training very deep networks much easier.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

### h04 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 68 words, 0.4 s): The authors are changing how neural network layers process information. Instead of asking each layer to learn a completely new output from scratch, they design the layers to learn the difference, or residual, between the input and the desired output. This approach makes it much easier for the network to train because the layers only need to focus on small adjustments rather than mapping everything from the beginning.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.09, 64 words, 17.1 s): Normally, deep networks try to learn what each layer should do from scratch. This method teaches layers what to change from the input they received, rather than starting fresh. It's like teaching a student to correct a draft instead of writing a whole new essay. The paper shows this makes training much easier and allows for deeper networks that perform better on image tasks.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 66 words, 6.0 s): Instead of asking the computer to learn the entire output from scratch, the researchers change the task. They ask the computer to learn only the difference or the extra detail needed to improve the result based on the original input. This makes it much easier for the computer to train very deep networks because it focuses on small adjustments rather than starting over at every step.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.04, 41 words, 12.9 s): Usually, deep networks forget how to connect back from the end to the start. This trick makes every layer learn a small change on top of what came before. That way, even very long chains stay clear and easy to teach.
  - Note: explains. Each layer learns only the change from what came before, which makes deep nets easier to train.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.10, 79 words, 5.0 s): This approach addresses the vanishing gradient problem by forcing layers to learn the difference between the input and output, denoted as F(x) = H(x) - x, rather than mapping the input directly to the target. By learning these residual mappings, the network can effectively pass identity information through shortcut connections. This reformulation allows for significantly deeper architectures that remain trainable, as it is easier to optimize the residual mapping toward zero than to learn an identity mapping from scratch.
  - Note: explains. Layers learn the residual, or the change from the input, instead of a full mapping from scratch.
- **Qwen 3.5 4B, new prompts** (overlap 0.10, 52 words, 13.2 s): Standard deep nets struggle because they try to learn complex mappings directly from input to output. We reframe layers to learn residuals, which are corrections or updates relative to the previous layer's output. This allows stable training for networks up to 152 layers on ImageNet, achieving 3.57% error and winning ILSVRC 2015.
  - Note: explains. Residuals, 152 layers, 3.57% ImageNet error: all from the paper, and at the right level.

## h05. Electric Field Effect in Atomically Thin Carbon Films

Source: https://arxiv.org/abs/cond-mat/0410550  
Highlight: "ballistic transport at submicron distances even at room temperature"

### h05 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 28 words, 0.3 s): This describes how electrons move through a material without hitting obstacles or losing energy. It happens over very short distances even when the material is not cooled down.
  - Note: explains. Electrons travel without collisions over short distances even when not cooled.
- **Qwen 3.5 4B, new prompts** (overlap 0.07, 30 words, 8.7 s): This material lets electrons fly through without bumping into anything, like a smooth highway. It works this way even when the room is hot, not just when it's super cold.
  - Note: partly. Smooth-highway idea is right, but 'when the room is hot' overstates room temperature, and the submicron distance is missing.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 28 words, 2.7 s): This means electricity flows through the material without hitting any obstacles or losing energy. It happens over very short gaps even when the material is not cooled down.
  - Note: explains. Same, in everyday words.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 26 words, 10.6 s): Electrons move like a smooth train on a track instead of bumping into bumps. They go fast without slowing down, even when the chip is warm.
  - Note: partly. Smooth-train idea is right, but it drops the submicron distance.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.05, 24 words, 2.8 s): Charge carriers travel across submicron scales without scattering, maintaining momentum despite thermal energy. This demonstrates exceptionally high carrier mobility in graphene at ambient conditions.
  - Note: explains. No scattering over submicron scales at ambient conditions.
- **Qwen 3.5 4B, new prompts** (overlap 0.24, 28 words, 11.0 s): Electrons moved through the material without scattering or losing energy. This ballistic transport happens over nanoscale lengths and persists at room temperature, which is rare for such devices.
  - Note: explains. No scattering over nanoscale lengths at room temperature.

### h05 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 23 words, 7.0 s): This means electricity moves like a bowling ball rolling straight down a lane without hitting anything, even in tiny spaces and warm rooms.
  - Note: explains. Bowling-lane comparison; keeps tiny spaces and warm rooms.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 28 words, 11.8 s): The electrons move like a bullet in a straight line without bumping into anything. This works here because the path is so tiny that they don't hit obstacles.
  - Note: partly. Straight-line travel is right, but it says this works 'because the path is so tiny', which mixes up distance with why transport is ballistic.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 18 words, 8.0 s): Electricity flows through this tiny space like a bowling ball rolling down an empty lane without hitting anything.
  - Note: partly. Bowling-lane comparison is fine, but it drops room temperature.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 29 words, 9.0 s): Electrons move like a ball rolling down a smooth track instead of bumping into things. This works at normal temperatures and over very tiny spaces, making it super fast.
  - Note: explains. Keeps normal temperatures and tiny spaces.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 24 words, 4.9 s): Electrons flow through the material without hitting any obstacles, like a car driving on an empty highway without ever needing to brake or turn.
  - Note: partly. Empty-highway comparison; drops the submicron distance and room temperature.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 25 words, 9.9 s): Electrons move through this graphene like a solid beam of light. They don't bounce off impurities, so they zip across tiny gaps without losing energy.
  - Note: explains. No bouncing off impurities across tiny gaps.

### h05 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.09, 66 words, 2.0 s): This refers to electrons moving through a material without colliding with atoms or impurities. In this context, it means electricity flows through graphene very efficiently over short distances without losing energy as heat. This is significant because most materials require extreme cooling to achieve this effect, but graphene maintains this high performance at room temperature, which could lead to much faster and more efficient electronic devices.
  - Note: explains. No collisions, short distances, usually needs cooling, graphene does it at room temperature.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 36 words, 12.2 s): In this material, electrons move like a straight shot with no bumps or heat slowing them down. This happens at tiny scales and without cooling, which is rare because heat usually messes up that clean movement.
  - Note: explains. Clean movement at tiny scales without cooling.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 69 words, 5.3 s): This means that electrons can travel through a material in a straight line without bumping into anything or losing energy, even over tiny distances and in a warm room. Usually, electrons hit atoms and slow down, which creates heat. Because these electrons move freely without crashing, the material can carry electricity much faster and more efficiently than standard wires. This is important for making smaller, faster, and cooler electronics.
  - Note: explains. Straight-line travel in a warm room; why that helps devices.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 34 words, 11.7 s): Usually, electrons bump into atoms and get slowed down by heat. Here they move like a smooth slide without hitting anything, even when it's warm. This lets electricity flow super fast in tiny circuits.
  - Note: explains. Usually heat slows electrons; here they move freely even when it is warm.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.12, 68 words, 5.7 s): This refers to charge carriers traversing the graphene lattice without scattering events over submicron scales. In conventional semiconductors, phonon scattering typically limits mean free paths at room temperature. The observation of ballistic transport in graphene at these scales and temperatures confirms exceptionally high carrier mobility, which is critical for developing high frequency, low power field effect transistors that operate efficiently without the resistive losses associated with diffusive transport.
  - Note: explains. Mean free path and mobility at room temperature; accurate.
- **Qwen 3.5 4B, new prompts** (overlap 0.27, 36 words, 11.1 s): Electrons move like a solid stream rather than bouncing off impurities in the graphene channel. This ballistic transport occurs over submicron distances, which is remarkable because most materials suffer from scattering at room temperature, limiting performance.
  - Note: explains. Ballistic over submicron distances at room temperature, unlike most materials.

## h06. Planck 2018 results. VI. Cosmological parameters

Source: https://arxiv.org/abs/1807.06209  
Highlight: "Hubble constant"

### h06 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.15, 28 words, 0.3 s): The Hubble constant is a number that describes how fast the universe is expanding. It measures the rate at which galaxies move away from each other over time.
  - Note: explains. Current expansion rate of the universe (grad also notes the tension with local measurements).
- **Qwen 3.5 4B, new prompts** (overlap 0.14, 22 words, 12.8 s): The Hubble constant tells how fast the universe is expanding right now, measured in kilometers per second for every megaparsec of distance.
  - Note: explains. Expansion rate now, in km/s per megaparsec.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 28 words, 8.0 s): This is a number that tells us how fast the universe is stretching out. It helps scientists figure out how quickly galaxies are moving away from each other.
  - Note: explains. Current expansion rate of the universe (grad also notes the tension with local measurements).
- **Qwen 3.5 4B, new prompts** (overlap 0.17, 23 words, 10.0 s): The Hubble constant tells us how fast the universe is stretching right now. Think of it as a speed limit for space itself.
  - Note: explains. How fast the universe is stretching now.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.11, 30 words, 3.9 s): The Hubble constant represents the current expansion rate of the universe. Planck measurements derive this value indirectly from early universe data, resulting in a lower estimate than direct local measurements.
  - Note: explains. Current expansion rate of the universe (grad also notes the tension with local measurements).
- **Qwen 3.5 4B, new prompts** (overlap 0.09, 37 words, 13.9 s): The Hubble constant measures the current expansion rate of the universe, here found to be 67.4 km/s/Mpc with a margin of ±0.5. This value is the best estimate from Planck data when assuming the standard cosmological model.
  - Note: explains. 67.4 ± 0.5 km/s/Mpc from Planck under the standard model, both from the paper.

### h06 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.20, 27 words, 2.9 s): The Hubble constant is the speed at which the universe is expanding. Think of it like the rate at which a balloon grows when you inflate it.
  - Note: explains. Balloon comparison; speed at which the universe is expanding.
- **Qwen 3.5 4B, new prompts** (overlap 0.11, 32 words, 12.3 s): The Hubble constant tells us how fast the universe is expanding right now. The number found is 67.4, meaning galaxies move away from us at that speed for every kilometer of distance.
  - Note: error. Gets 67.4 right, then says galaxies move at that speed 'for every kilometer of distance' instead of every megaparsec.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 25 words, 3.5 s): This is a number that tells us how fast the universe is stretching out. Think of it like the speed at which a balloon expands.
  - Note: explains. Balloon comparison; speed at which the universe is expanding.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 28 words, 12.2 s): The Hubble constant is a number that tells us how fast the universe is stretching right now. It's measured in kilometers per second for every megaparsec of distance.
  - Note: explains. Expansion rate now, in km/s per megaparsec.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 27 words, 4.9 s): This is the speed at which the universe is currently expanding. Think of it like the rate at which a balloon grows when you blow it up.
  - Note: explains. Balloon comparison; speed at which the universe is expanding.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 30 words, 12.0 s): The Hubble constant measures how fast the universe is expanding right now, expressed in kilometers per second per megaparsec. Its value here is 67.4 with a small margin of error.
  - Note: explains. 67.4 with a small margin of error, per megaparsec.

### h06 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 57 words, 5.1 s): The Hubble constant is a number that represents the current rate at which the universe is expanding. It describes how fast galaxies are moving away from each other based on their distance from us. In this context, scientists use it to understand the overall scale and age of the universe by measuring light from the early cosmos.
  - Note: explains. Current expansion rate; grad correctly names 67.4 km/s/Mpc and the Hubble tension.
- **Qwen 3.5 4B, new prompts** (overlap 0.11, 28 words, 12.7 s): The Hubble constant tells us how fast the universe is expanding right now, measured in kilometers per second per megaparsec. The value here is 67.4 ± 0.5 km/s/Mpc.
  - Note: explains. 67.4 ± 0.5 km/s/Mpc, expansion rate now.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 43 words, 8.5 s): The Hubble constant is a number that tells us how fast the universe is expanding. In this text, scientists use data from space to measure this speed precisely. Knowing this number helps researchers understand the age, size, and future of our entire universe.
  - Note: explains. Current expansion rate; grad correctly names 67.4 km/s/Mpc and the Hubble tension.
- **Qwen 3.5 4B, new prompts** (overlap 0.11, 32 words, 25.7 s, guard retried): The Hubble constant is a rate of expansion for the universe, measured in kilometers per second per megaparsec. The Planck data gives a value of 67.4 with an uncertainty of 0.5 km/s/Mpc.
  - Note: explains. Same value and units.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.05, 59 words, 8.3 s): The Hubble constant represents the current expansion rate of the universe. In this context, the Planck measurement of 67.4 kilometers per second per megaparsec is crucial because it anchors the standard Lambda CDM model. However, this early universe inferred value famously creates the Hubble tension when compared to higher local distance ladder measurements, driving ongoing debates in precision cosmology.
  - Note: explains. Current expansion rate; grad correctly names 67.4 km/s/Mpc and the Hubble tension.
- **Qwen 3.5 4B, new prompts** (overlap 0.07, 38 words, 20.2 s): The inferred Hubble constant is $H_0 = (67.4\\/0.5)$ km/s/Mpc. This value represents the current expansion rate of the universe. It is derived from the CMB anisotropies and remains stable across many commonly considered extensions to the base-$Λ$CDM cosmology.
  - Note: partly. The 67.4 and 0.5 are right, but the written form is garbled: (67.4/0.5) instead of 67.4 ± 0.5.

## h07. Safety and Efficacy of the BNT162b2 mRNA Covid-19 Vaccine

Source: https://pubmed.ncbi.nlm.nih.gov/33301246/  
Highlight: "BNT162b2 was 95% effective in preventing Covid-19 (95% credible interval, 90.3 to 97.6)"

### h07 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.31, 26 words, 0.3 s): The vaccine prevented 95 percent of Covid-19 cases in the study. The credible interval shows the range of statistical certainty for how well the vaccine works.
  - Note: explains. 95% of cases prevented; explains the credible interval.
- **Qwen 3.5 4B, new prompts** (overlap 0.25, 24 words, 10.6 s): The vaccine stopped 95% of cases that would have happened otherwise. The 90.3 to 97.6 range shows how sure we are about that number.
  - Note: explains. Stopped 95% of cases that would have happened otherwise; keeps 90.3 to 97.6.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.20, 23 words, 8.3 s): This means the vaccine stopped 95 out of every 100 people from getting sick with Covid-19. It worked extremely well in the study.
  - Note: partly. 'Stopped 95 out of every 100 people from getting sick' reads like an absolute rate, not a reduction versus placebo.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 27 words, 10.8 s): The vaccine worked by giving the body a safe copy of a virus piece to practice fighting. It stopped 95 out of every 100 infections from happening.
  - Note: partly. 'Stopped 95 out of every 100 infections' without saying versus placebo, the usual loose reading of efficacy.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 33 words, 2.6 s): The vaccine demonstrated a 95 percent reduction in symptomatic disease risk compared to placebo. The credible interval indicates the range where the true efficacy likely lies based on the Bayesian statistical analysis used.
  - Note: explains. 95% reduction in symptomatic disease; explains the Bayesian interval.
- **Qwen 3.5 4B, new prompts** (overlap 0.47, 27 words, 12.5 s): The vaccine prevented 95% of Covid-19 cases in this trial. The 95% credible interval means we are very confident the true protection is between 90.3 and 97.6.
  - Note: explains. Prevented 95% of cases; interval is the range for true protection.

### h07 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 22 words, 7.4 s): The vaccine worked very well. Think of it like a shield blocking 95 out of 100 potential infections compared to getting nothing.
  - Note: explains. Shield blocking 95 out of 100 potential infections compared with nothing.
- **Qwen 3.5 4B, new prompts** (overlap 0.27, 28 words, 11.9 s): 95% of people who got the shot didn't get sick. The 90.3 to 97.6 number is the range where we are very sure the real protection is there.
  - Note: error. '95% of people who got the shot didn't get sick' treats efficacy as an absolute rate in recipients, not a reduction versus placebo.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.23, 20 words, 7.0 s): This means the vaccine works like a powerful shield, stopping 95 out of 100 people from getting sick with Covid-19.
  - Note: partly. 'Stopping 95 out of 100 people from getting sick' is the same absolute-rate slip.
- **Qwen 3.5 4B, new prompts** (overlap 0.09, 25 words, 10.8 s): The vaccine worked on 95 out of 100 people who got it. That means it stopped the virus from making you sick in 95 cases.
  - Note: error. 'Worked on 95 out of 100 people who got it' is the same absolute-rate misreading.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 23 words, 2.5 s): The vaccine reduced the risk of getting sick by 95 percent. Think of it like a shield that blocks almost all incoming arrows.
  - Note: explains. 95 percent risk reduction; shield comparison.
- **Qwen 3.5 4B, new prompts** (overlap 0.47, 27 words, 11.6 s): The vaccine prevented 95% of Covid-19 cases. The 95% credible interval of 90.3 to 97.6 means we are very sure the true effectiveness is in that range.
  - Note: explains. Prevented 95% of cases; keeps the 90.3 to 97.6 interval.

### h07 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.19, 65 words, 3.3 s): This statement means the vaccine significantly reduced the risk of getting sick with Covid-19 compared to the placebo group. The credible interval provides a statistical range of certainty, showing that researchers are highly confident the true effectiveness of the vaccine falls between 90.3 percent and 97.6 percent. This is important because it proves the vaccine is highly reliable at preventing infection in the study population.
  - Note: explains. Risk reduction versus placebo, interval 90.3 to 97.6.
- **Qwen 3.5 4B, new prompts** (overlap 0.35, 38 words, 29.7 s, guard retried): The study found that BNT162b2 prevented Covid-19 95% of the time among people 16 and older. The 95% credible interval, 90.3 to 97.6, means we are very sure that the true protection level falls between these two numbers.
  - Note: explains. 95% prevention in people 16 and older; interval explained.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.10, 73 words, 2.8 s): This statement means that the vaccine works very well to stop people from getting sick. The number 95 percent shows that most people who got the vaccine stayed healthy compared to those who did not. The credible interval is a range of numbers that scientists use to show they are very confident in their results. This matters because it proves the vaccine is a strong tool for keeping people safe from the virus.
  - Note: explains. Most people who got the vaccine stayed healthy compared with those who did not; explains the interval.
- **Qwen 3.5 4B, new prompts** (overlap 0.17, 44 words, 13.2 s): The vaccine worked really well. It stopped 95 out of every 100 cases of the virus from happening in people who got it, compared to those who didn't. The range from 90.3% to 97.6% shows how sure we are that it is this good.
  - Note: explains. 95 out of 100 cases versus those who did not get it; keeps the interval.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.11, 65 words, 7.7 s, nums five, ninety, three): This result demonstrates the primary efficacy endpoint of the phase three trial for the BNT162b2 mRNA vaccine. The ninety-five percent vaccine efficacy, backed by a narrow credible interval, indicates robust protection against symptomatic Covid-19 across diverse demographic subgroups. This high level of protection, achieved with an acceptable safety profile, provided the foundational clinical evidence supporting emergency use authorization and global immunization campaigns during the pandemic.
  - Note: explains. Phase 3 efficacy against symptomatic Covid-19; interval described correctly. 'Ninety-five' is 95, not a new number.
- **Qwen 3.5 4B, new prompts** (overlap 0.30, 38 words, 13.4 s): The vaccine prevented 95% of Covid-19 cases in this trial. The 95% credible interval from 90.3 to 97.6 means we are 95% confident the true efficacy lies within that range, reflecting a narrow estimate around the point estimate.
  - Note: explains. 95% of cases; interval as a 95% range around the point estimate.

## h08. A programmable dual-RNA-guided DNA endonuclease in adaptive bacterial immunity

Source: https://pubmed.ncbi.nlm.nih.gov/22745249/  
Highlight: "the potential to exploit the system for RNA-programmable genome editing"

### h08 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.15, 25 words, 0.3 s): This refers to using the CRISPR system as a tool to change DNA sequences by using specific RNA molecules to guide where those changes happen.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.11, 33 words, 8.7 s): This research shows how scientists can program bacteria's own immune defense to cut out specific genes in a DNA sequence. That means we could use it to edit genomes using just RNA instructions.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 23 words, 2.8 s): This means scientists can use these natural tools to easily change or fix the DNA inside living things by using simple RNA instructions.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.11, 26 words, 7.7 s): This system lets scientists program tiny scissors with RNA to cut specific genes in DNA. That could help fix genetic diseases by cutting out broken parts.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 25 words, 3.1 s): This refers to the ability to repurpose the Cas9 endonuclease as a versatile tool for precise genomic modifications by simply modifying the guide RNA sequence.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.17, 31 words, 11.1 s): By fusing crRNA and tracrRNA into one strand, we can program Cas9 to cut any specific DNA sequence. This turns a bacterial immune system into a tool for precise genome editing.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

### h08 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 23 words, 11.0 s): This means using a natural bacterial tool like a pair of biological scissors to rewrite DNA instructions, guided by a specific RNA molecule.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 23 words, 5.8 s): This system lets scientists use a custom RNA code to cut specific parts of DNA, like using molecular scissors with a remote control.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 26 words, 4.1 s): This means we can use small pieces of RNA like a remote control to tell a special protein exactly where to change the instructions in DNA.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.19, 24 words, 5.9 s): This system lets scientists program RNA to cut specific genes in a genome. This could help fix genetic diseases by cutting out bad DNA.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 25 words, 4.6 s): This means we can use simple RNA molecules as remote controls to tell the Cas9 protein exactly where to cut and edit specific DNA sequences.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.14, 28 words, 10.2 s): This work shows how CRISPR-Cas9 uses two RNAs to find DNA cuts. By combining them into one, we can program the enzyme with just RNA to edit genomes.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

### h08 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 69 words, 4.1 s): This phrase refers to the possibility of using the CRISPR-Cas9 system as a tool to change DNA sequences. Because the system uses RNA to find specific locations in the genome, scientists can program it to cut DNA at precise spots. This is important because it allows researchers to edit genes with high accuracy, which could help in treating genetic diseases or studying how specific genes function in living organisms.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.04, 50 words, 11.7 s): This paper shows how engineers can use a single RNA strand to tell the Cas9 protein exactly where to cut DNA. That means scientists can change any gene in a cell by just writing a new RNA recipe, making it easier to fix genetic diseases or study how genes work.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 44 words, 8.8 s): This phrase means scientists can use this natural bacterial defense system as a tool to rewrite genetic code using RNA molecules as guides. This matters because it allows researchers to make precise changes to DNA, which can help fix genetic diseases or improve crops.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.08, 37 words, 9.2 s): This system lets scientists tell Cas9 exactly where to cut DNA using a custom RNA code. It's like a GPS for a molecular scissors, allowing precise changes to any gene without needing special machinery at every site.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 72 words, 4.0 s): This phrase refers to the capability of using the dual-RNA guided Cas9 endonuclease as a modular tool for precise genomic modifications. By substituting the crRNA guide sequence, researchers can redirect the Cas9 enzyme to target arbitrary DNA loci. This mechanism is significant because it decouples the targeting specificity from the protein component, enabling a versatile, programmable platform for site-specific genome engineering that is far more efficient than traditional protein-based DNA binding domains.
  - Note: explains. RNA-guided Cas9 as programmable scissors or a remote control for editing DNA.
- **Qwen 3.5 4B, new prompts** (overlap 0.14, 41 words, 11.5 s): This passage shows how CRISPR uses a guide RNA to find specific DNA sequences and cut them. By engineering single RNAs that mimic two separate RNAs, we can program Cas9 to cut any DNA sequence we design, enabling precise genome editing.
  - Note: explains. Custom RNA tells Cas9 where to cut; a programmable genome-editing tool.

## h09. Highly accurate protein structure prediction with AlphaFold

Source: https://pubmed.ncbi.nlm.nih.gov/34265844/  
Highlight: "even in cases in which no similar structure is known"

### h09 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 24 words, 0.3 s): This means the computer model can accurately predict a protein shape even when it cannot compare that protein to any other previously studied ones.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.22, 28 words, 9.2 s): Most methods only work if you can compare a protein to a known one. This new method works even when there is nothing similar to match it against.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 24 words, 7.5 s): This means the computer program can predict a protein shape successfully, even when scientists have never found another protein shaped quite like it before.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.08, 25 words, 10.0 s): Normally scientists need a similar model to copy from. But this tool guesses the shape correctly even when there's nothing else to compare it to.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.05, 23 words, 2.1 s): The model achieves high accuracy by predicting protein folds de novo, without relying on template-based modeling or evolutionary conservation from known structural homologs.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.13, 25 words, 7.7 s): Existing methods usually need a known template to predict a new structure. AlphaFold works even when that template is absent, which solves a key limitation.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

### h09 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 26 words, 25.0 s): This means the computer can figure out a protein shape even when it has never seen anything like it before, like solving a brand new puzzle.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 32 words, 9.5 s): This is hard because scientists usually compare a new protein to an old one they already know. But when there's no match to compare it to, predicting its shape is very difficult.
  - Note: partly. Explains why the case is hard, but never says this method actually succeeds, which is the point of the highlight.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 22 words, 1.9 s): This means figuring out the shape of something completely new, like solving a puzzle without ever seeing the picture on the box.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 23 words, 8.2 s): Before this method, computers couldn't guess a protein's shape if it had no close relatives. Now it can do that for many proteins.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 19 words, 7.5 s): Predicting a protein shape completely from scratch, without using any previously known examples to help guide the computer program.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.14, 17 words, 5.7 s): Most methods fail when there's no related structure to compare against. This new method works even then.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

### h09 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.12, 52 words, 7.4 s): This phrase means that the new method works successfully even when scientists have no previous examples of similar protein structures to use as a guide. This matters because most known proteins lack a known structure, so a tool that does not rely on prior examples can solve unknowns that older methods cannot.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 40 words, 7.5 s): For decades, scientists could only guess a protein's shape if a very similar one was already solved. This new method works even when there are no similar examples to copy from, making it much more useful for studying unknown proteins.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.04, 69 words, 2.9 s): This phrase means that the new computer program can figure out the shape of a protein even when scientists have never seen anything like it before. Usually, researchers look for similar proteins to guess the shape of a new one. Being able to do this without any clues is a huge deal because it allows scientists to understand the shapes of many proteins that were previously a complete mystery.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 41 words, 11.1 s): Scientists usually compare a new protein to one already solved to figure out its shape. This result shows the computer can guess the shape correctly even when there's nothing else to compare it to, which makes the method much more useful.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 58 words, 8.4 s): This phrase highlights the key breakthrough of the new AlphaFold model. Traditional computational methods relied heavily on evolutionary templates, failing when a query protein lacked a known homologue. Achieving atomic accuracy without similar reference structures means the algorithm learns fundamental biophysical principles rather than merely memorizing or aligning existing templates, effectively solving the core bottleneck in structural bioinformatics.
  - Note: explains. Works even without a known similar structure to copy from.
- **Qwen 3.5 4B, new prompts** (overlap 0.09, 44 words, 12.0 s): This is the hard part: when you have no evolutionary relatives to use as a template. Most methods fail here because they rely on homology, but AlphaFold uses deep learning and physical constraints to predict atomic accuracy without any similar structure in the database.
  - Note: explains. Usual methods need a similar solved shape; this one still works without it.

## h10. A Randomized Trial of Intensive versus Standard Blood-Pressure Control

Source: https://pubmed.ncbi.nlm.nih.gov/26551272/  
Highlight: "hazard ratio with intensive treatment, 0.75; 95% confidence interval [CI], 0.64 to 0.89"

### h10 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.33, 35 words, 0.3 s, nums 11, 25, 36): The hazard ratio shows that intensive treatment reduced the risk of heart events by 25 percent. The confidence interval means researchers are 95 percent sure the true risk reduction is between 11 and 36 percent.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.36, 43 words, 10.8 s): The hazard ratio of 0.75 means people in the intensive group were less likely to have a major heart event than those in the standard group. The 95% CI from 0.64 to 0.89 shows this difference is solid and not due to chance.
  - Note: explains. Keeps 0.75 and 0.64 to 0.89; no percent conversion.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.12, 30 words, 2.4 s, nums 25): This means the intensive treatment group had a 25 percent lower risk of heart problems compared to the standard group. The range shows how certain researchers are about this result.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.33, 39 words, 12.5 s): The hazard ratio of 0.75 means people on the stricter blood pressure plan had a lower chance of having heart attacks or strokes. The 95% CI from 0.64 to 0.89 means we are very sure this difference is real.
  - Note: explains. Same, exact figures, lower chance of heart attacks or strokes.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.19, 27 words, 2.4 s, nums 25): Intensive blood pressure control reduced the primary cardiovascular event rate by 25 percent compared to standard treatment. The narrow confidence interval confirms this finding is statistically robust.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.35, 40 words, 26.5 s, guard retried): The hazard ratio of 0.75 means intensive treatment cuts the rate of major cardiovascular events compared to standard treatment, where 1 equals no difference. The 95% CI of 0.64 to 0.89 excludes 1, confirming this lower risk is statistically significant.
  - Note: explains. 0.75 vs 1 as no difference; interval excludes 1.

### h10 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 27 words, 3.3 s, nums 25): The intensive treatment reduced the risk of heart problems by 25 percent. The range shows how certain researchers are that this benefit is real and not luck.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.33, 38 words, 13.0 s): The hazard ratio of 0.75 means people in the lower blood pressure group were less likely to have a heart event. The 95% CI from 0.64 to 0.89 shows how sure we are that the difference is real.
  - Note: explains. Exact figures, no conversion.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 25 words, 3.4 s, nums 25): This means the intensive treatment lowered the risk of heart problems by 25 percent compared to standard care, like a discount on a price tag.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.30, 41 words, 14.5 s): The hazard ratio of 0.75 means people in the low-blood-pressure group were less likely to have a heart event or die from it. The 95% CI from 0.64 to 0.89 shows this difference is pretty sure and not just a fluke.
  - Note: explains. Exact figures, not a fluke.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 26 words, 3.3 s, nums 25, quarter): Intensive blood pressure control reduced the risk of major heart events by 25 percent compared to standard care, like getting a quarter off a price tag.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.32, 41 words, 31.1 s, nums 25, guard retried): The hazard ratio of 0.75 means the intensive group had a 25% lower risk of the first major cardiovascular event compared to standard treatment. The CI of 0.64 to 0.89 confirms this reduction is statistically significant and not due to chance.
  - Note: partly. Correctly converts 0.75 to a 25% lower risk, but that computed percent is a number the paper does not write.

### h10 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.22, 53 words, 7.9 s, nums five, twenty): This statistical result shows that the intensive treatment group experienced twenty five percent fewer major cardiovascular events compared to the standard group. The hazard ratio of 0.75 means the risk went down. The confidence interval proves this finding is reliable and not just due to random chance, because the range stays below one.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.32, 49 words, 16.5 s): The hazard ratio of 0.75 means people in the intensive group were less likely to have heart attacks or strokes than those in the standard group. The 95% CI from 0.64 to 0.89 shows this difference is solid and not just luck, since the whole range is below 1.
  - Note: explains. Exact figures; whole interval below 1.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.18, 72 words, 2.5 s, nums 11, 25, 36): The hazard ratio of 0.75 means that people who received the intensive treatment were 25 percent less likely to have a heart problem or die compared to those in the standard group. The confidence interval shows the range of numbers that researchers are very sure about, meaning the real benefit is likely between 11 and 36 percent. This matters because it proves that lowering blood pressure more aggressively helps people stay healthier.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.32, 44 words, 17.1 s): The hazard ratio of 0.75 means the group with lower blood pressure had a lower chance of having a heart event or stroke. The 95% CI from 0.64 to 0.89 tells us we are very sure this difference is real and not just luck.
  - Note: explains. Exact figures, sure it is not luck.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.20, 74 words, 3.3 s, nums 1.0, 25): The hazard ratio of 0.75 indicates a 25 percent relative risk reduction for the primary composite cardiovascular outcome in the intensive treatment group compared to the standard group. The 95 percent confidence interval, ranging from 0.64 to 0.89, excludes the null value of 1.0, confirming that the observed benefit is statistically significant. This precision suggests a robust clinical effect, supporting the efficacy of lower systolic targets despite the associated increase in specific adverse events.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction. Where it also converts the interval to 11 to 36 percent, that conversion is right too.
- **Qwen 3.5 4B, new prompts** (overlap 0.31, 49 words, 31.7 s, nums 25, guard retried): The hazard ratio of 0.75 means a 25% lower risk of the primary composite outcome in the intensive-treatment group compared to standard treatment. The 95% CI of 0.64 to 0.89 confirms this, as it does not include 1. This significant reduction occurred after a median follow-up of 3.26 years.
  - Note: partly. Same correct 25% conversion, plus the 3.26-year follow-up from the paper. The invented percent is the slip.

## h11. Once-Weekly Semaglutide in Adults with Overweight or Obesity

Source: https://pubmed.ncbi.nlm.nih.gov/33567185/  
Highlight: "-14.9% in the semaglutide group as compared with -2.4% with placebo"

### h11 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.19, 33 words, 3.8 s): People taking semaglutide lost 14.9 percent of their body weight, while those taking a fake pill only lost 2.4 percent. This shows the drug was much more effective at helping people lose weight.
  - Note: explains. 14.9% vs 2.4%, exact.
- **Qwen 3.5 4B, new prompts** (overlap 0.17, 21 words, 8.4 s): The average person lost 14.9 percent of their starting weight on the drug versus only 2.4 percent on the sugar pill.
  - Note: explains. 14.9% vs 2.4%, exact.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 23 words, 7.3 s, nums fifteen): People taking the special medicine lost about fifteen percent of their body weight. People taking the fake medicine lost only about two percent.
  - Note: partly. Rounds 14.9% to 'about fifteen' and 2.4% to 'about two'.
- **Qwen 3.5 4B, new prompts** (overlap 0.21, 31 words, 9.6 s): The drug group lost 14.9 percent of their starting weight, while the sugar pill group only lost 2.4 percent. That is a big difference in how much weight each person shed.
  - Note: explains. Both figures exact.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.21, 24 words, 2.0 s, nums fifteen): This highlights a striking efficacy difference, showing that semaglutide drove a nearly fifteen percent weight loss compared to just over two percent for placebo.
  - Note: partly. 'Nearly fifteen' and 'just over two' instead of 14.9 and 2.4.
- **Qwen 3.5 4B, new prompts** (overlap 0.21, 30 words, 15.3 s): Semaglutide caused an average 14.9% weight loss versus 2.4% with placebo, a difference of 12.4 percentage points. This is the mean change in body weight from baseline to week 68.
  - Note: explains. 14.9% vs 2.4%, and the 12.4 point difference and 68 weeks from the paper.

### h11 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 27 words, 0.3 s, nums fifteen, hundred): People taking the medicine lost about fifteen percent of their body weight, like losing fifteen pounds out of one hundred, while the control group lost very little.
  - Note: partly. 'About fifteen percent' and 'fifteen pounds out of one hundred'; the control group 'lost very little' drops 2.4%.
- **Qwen 3.5 4B, new prompts** (overlap 0.23, 26 words, 12.4 s): On average, people on semaglutide lost 14.9% of their starting weight over 68 weeks. Those on the fake pill only lost 2.4% during the same time.
  - Note: explains. Both figures exact, and it keeps the 68 weeks.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 23 words, 5.7 s): People taking the medicine lost about 15 percent of their body weight, while those taking a fake pill only lost about 2 percent.
  - Note: partly. About 15 percent vs about 2 percent; both rounded.
- **Qwen 3.5 4B, new prompts** (overlap 0.28, 32 words, 11.9 s): The semaglutide group lost 14.9% of their body weight, while the placebo group only lost 2.4%. That big difference means the medicine helped people lose more fat than the sugar pill did.
  - Note: explains. Both figures exact.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 28 words, 5.1 s, nums fifteen): People taking the drug lost about fifteen percent of their body weight, while those taking a dummy pill lost only two percent. It is like shedding a backpack.
  - Note: partly. About fifteen vs only two; 2.4% is rounded off.
- **Qwen 3.5 4B, new prompts** (overlap 0.30, 39 words, 26.6 s, guard retried): The mean change in body weight was -14.9% in the semaglutide group as compared with -2.4% with placebo over 68 weeks. This means participants lost more weight on average, and it matters because it shows a clear treatment effect.
  - Note: explains. Both figures exact over 68 weeks.

### h11 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.10, 62 words, 3.8 s): This comparison shows that people taking the medication semaglutide lost significantly more body weight over 68 weeks than those taking a placebo. The negative percentages indicate a decrease in weight from the starting point. This matters because it demonstrates that the drug is much more effective at promoting weight loss than just lifestyle changes alone, which is what the placebo group experienced.
  - Note: explains. More weight loss over 68 weeks than placebo; negative percents are a decrease.
- **Qwen 3.5 4B, new prompts** (overlap 0.29, 35 words, 22.0 s, guard retried): At week 68, people on semaglutide lost an average of 14.9% of their body weight, while those on placebo lost only 2.4%. This is the percentage change in body weight from baseline to week 68.
  - Note: explains. Week 68, 14.9% vs 2.4%.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.04, 58 words, 8.3 s): This shows how much weight people lost during the study. The group taking the medicine lost about 15 percent of their body weight, while the group taking a fake pill lost only about 2 percent. This matters because it proves the medicine is much more effective at helping people lose weight than just changing their lifestyle habits alone.
  - Note: partly. About 15 percent vs about 2 percent, but it does keep the comparison and the idea.
- **Qwen 3.5 4B, new prompts** (overlap 0.20, 35 words, 24.3 s, guard retried): People on the drug lost 14.9% of their body weight over 68 weeks, while those on the fake medicine lost only 2.4%. This means the drug caused much more weight loss than the placebo did.
  - Note: explains. Same, over 68 weeks.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 69 words, 4.6 s): This comparison highlights the significant efficacy of once-weekly subcutaneous semaglutide for weight management in non-diabetic individuals. The substantial difference between the active treatment and placebo groups demonstrates that semaglutide induces clinically meaningful weight loss over 68 weeks. This effect size is particularly notable given the primary estimand approach, which accounts for treatment discontinuation and rescue interventions, providing a robust measure of the drug's therapeutic impact on body weight reduction.
  - Note: explains. Clinically meaningful loss over 68 weeks; no rounded-off figures required in this fuller framing.
- **Qwen 3.5 4B, new prompts** (overlap 0.17, 38 words, 11.4 s): The mean change in body weight was -14.9% on semaglutide versus -2.4% on placebo. That's an estimated treatment difference of -12.4 percentage points, meaning the drug drove substantially more weight loss than the control arm over 68 weeks.
  - Note: explains. -14.9 vs -2.4, -12.4 point difference, over 68 weeks.

## h12. More than 75 percent decline over 27 years in total flying insect biomass in protected areas

Source: https://pubmed.ncbi.nlm.nih.gov/29045418/  
Highlight: "a seasonal decline of 76%, and mid-summer decline of 82% in flying insect biomass over the 27 years of study"

### h12 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.27, 28 words, 0.3 s, nums eighty, quarters, seven, three, twenty): Over twenty seven years, the total weight of flying insects dropped by over three quarters during the season and by over eighty percent during the middle of summer.
  - Note: partly. Keeps 27 years, but rounds 76% to 'over three quarters' and 82% to 'over eighty percent'.
- **Qwen 3.5 4B, new prompts** (overlap 0.35, 38 words, 21.5 s, guard retried): Over the 27 years, flying insect weight dropped by 76% in a season and 82% in mid-summer. This loss matters because it shrinks the total food available to other animals, even if some individual bug counts look stable.
  - Note: explains. 76%, 82%, and 27 years all exact; seasonal vs mid-summer read correctly. No 'lighter in spring'.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.36, 22 words, 4.5 s, nums quarters, three, dropped 27 years): The total weight of all flying insects dropped by over three quarters during the summer months over the course of the study.
  - Note: partly. Drops 27 years and the 82% mid-summer figure; 'over three quarters during the summer months' collapses the two declines.
- **Qwen 3.5 4B, new prompts** (overlap 0.44, 36 words, 17.5 s, guard retried): The 76% drop is the loss of total flying insect weight across a season, and the 82% drop is the loss in mid-summer. This big loss happened over 27 years and shows fewer insects are flying.
  - Note: explains. Same three figures, correctly framed.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 29 words, 1.9 s, dropped 27 years): The data indicates a severe, long-term reduction in total flying insect mass across diverse protected habitats. This magnitude of loss significantly exceeds previous estimates based on individual species counts.
  - Note: partly. Qualitative long-term loss only; drops 27 years, 76%, and 82%.
- **Qwen 3.5 4B, new prompts** (overlap 0.44, 31 words, 9.8 s): The study shows a massive loss of total insect weight, not just fewer species. The 76% drop is across a season, and the 82% drop is in mid-summer over 27 years.
  - Note: explains. Same three figures over 27 years.

### h12 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.14, 27 words, 3.9 s, nums quarters, three, dropped 27 years): This means the total weight of all flying insects dropped by over three quarters. It is like having a full jar of fireflies and losing almost everyone.
  - Note: partly. Drops 27 years and 82%; only 'over three quarters'.
- **Qwen 3.5 4B, new prompts** (overlap 0.42, 29 words, 9.4 s): Over 27 years, the total weight of flying insects dropped by 76% across a season and 82% in mid-summer. This big loss matters because it changes how nature works.
  - Note: explains. All three figures exact; seasonal vs mid-summer kept.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.31, 25 words, 1.6 s, nums 80): Over 27 years, the total weight of flying insects dropped by about 80 percent, like a forest losing most of its leaves during the fall.
  - Note: partly. Keeps 27 years but merges the two declines into 'about 80 percent'.
- **Qwen 3.5 4B, new prompts** (overlap 0.47, 27 words, 18.7 s, guard retried): Over 27 years, the total weight of flying insects dropped by 76% in a season and 82% in mid-summer. This means far fewer living bugs than before.
  - Note: explains. All three figures exact.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.12, 24 words, 1.9 s, nums three, dropped 27 years): The total weight of flying insects dropped drastically over nearly three decades, like a massive, steady leak draining a tank until almost nothing remains.
  - Note: partly. 'Nearly three decades' with no 76% or 82%.
- **Qwen 3.5 4B, new prompts** (overlap 0.32, 30 words, 19.8 s, dropped 27 years, guard retried): The total weight of insects dropped by 76% across a season and 82% in mid-summer. This massive loss of biomass happens everywhere, and weather or land use don't explain it.
  - Note: partly. Keeps 76% and 82% and the seasonal vs mid-summer split, but drops the 27 years.

### h12 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.21, 75 words, 4.4 s, dropped 27 years): This phrase describes a massive reduction in the total weight of all flying insects collected during the study. A seasonal decline refers to the drop in insect numbers across the entire year, while the mid-summer decline specifically highlights the loss during the peak months when insects are usually most active. This matters because such a sharp decrease suggests that the environment is struggling to support insect life, which threatens the food sources for other animals.
  - Note: partly. Good account of seasonal vs mid-summer, but drops 27 years and the exact percents.
- **Qwen 3.5 4B, new prompts** (overlap 0.40, 52 words, 13.0 s): This study measured the total weight of all flying insects, not just one species. Over 27 years, the total weight dropped by 76% in a season and 82% in mid-summer. This is important because losing insect biomass hurts food webs more than we thought, even if individual species counts stay the same.
  - Note: explains. All three figures, plus why biomass matters for food webs.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 66 words, 2.6 s, nums quarters, three, dropped 27 years): This means that the total weight of all flying insects caught in traps dropped by over three quarters during the time researchers watched them. It matters because insects are a major food source for many birds and other animals. If there are far fewer insects, those animals will have a harder time finding enough to eat, which could cause big problems for the entire natural environment.
  - Note: partly. 'Over three quarters'; drops 27 years and 82%.
- **Qwen 3.5 4B, new prompts** (overlap 0.31, 49 words, 12.9 s): They counted how much total flying insect weight was caught, not just how many different types. Over 27 years, total weight dropped by 76% in a season and 82% in mid-summer. This matters because losing insects hurts food chains and nature's services, even if some specific bugs didn't disappear.
  - Note: explains. All three figures, food chains.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.12, 67 words, 6.1 s, dropped 27 years): This finding reveals a massive, multi-decade drop in total flying insect weight across protected German nature reserves. Measuring biomass rather than just single species counts is crucial because total mass directly reflects energy availability in food webs and overall ecosystem functioning. The sheer magnitude of these seasonal and mid-summer losses indicates a systemic ecological crisis that cannot be explained by local weather or land use changes alone.
  - Note: partly. Strong qualitative account, but drops 27 years, 76%, and 82%.
- **Qwen 3.5 4B, new prompts** (overlap 0.35, 49 words, 27.2 s, guard retried): Over 27 years, flying insect biomass dropped sharply. The 76% seasonal decline and 82% mid-summer decline show a massive loss of total insect mass, not just fewer individuals. This matters because biomass drives energy flow in food webs, and this decline isn't explained by weather or land use changes.
  - Note: explains. All three figures; decline not explained by weather or land use, from the paper.

## h13. PSYCHOLOGY. Estimating the reproducibility of psychological science

Source: https://pubmed.ncbi.nlm.nih.gov/26315443/  
Highlight: "Thirty-six percent of replications had statistically significant results"

### h13 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 30 words, 0.3 s, nums third): Only about one third of the repeated studies produced the same meaningful evidence as the originals. This shows that many initial findings were likely not as strong as first reported.
  - Note: explains. About one third; many original findings were not as strong as first reported.
- **Qwen 3.5 4B, new prompts** (overlap 0.07, 33 words, 7.2 s): Only 36% of the new studies found a result strong enough to call it real. Most of the original 100 studies were considered real, but fewer than half of the new ones were.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.40, 20 words, 2.7 s): Out of the studies tested again, only thirty-six percent got the same important or clear results as the first time.
  - Note: explains. Keeps thirty-six percent exactly.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 31 words, 8.9 s): Out of 100 tries, only 36 showed a real effect that stood up to checking. That means most of the findings from the first studies didn't hold up when tested again.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 23 words, 1.9 s, nums third): Only about a third of the replicated studies achieved statistical significance. This reveals a major drop in reproducibility compared to the original literature.
  - Note: explains. About a third; a drop in reproducibility.
- **Qwen 3.5 4B, new prompts** (overlap 0.19, 35 words, 10.1 s): Only 36% of the replications were statistically significant, meaning most failed to reach the same level of confidence as the originals. This is a substantial decline from the 97% significance rate in the original studies.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

### h13 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.09, 27 words, 24.8 s, nums third, twice): Only about one third of the repeated experiments got the same clear results as the first time. It is like trying a recipe twice and failing once.
  - Note: partly. One third is fair, but 'trying a recipe twice and failing once' is a 50% miss, not 36%.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 30 words, 9.3 s): Of the 100 studies checked, only 36% showed a real effect when tried again. That means most results that looked solid at first disappeared or got much weaker when repeated.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.09, 25 words, 3.6 s, nums third, twice): Only about one third of the repeated experiments got the same clear results as the first time, like trying a recipe twice and failing once.
  - Note: partly. Same off recipe-twice comparison.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 26 words, 8.7 s): Only 36% of the new tests showed a real link. That means most of them didn't find the same clear connection that the original studies did.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.14, 26 words, 3.0 s, nums third): Only about a third of the repeated studies found the same significant results, like a coin flip landing on heads much less often the second time.
  - Note: partly. One third is fair; the coin-flip comparison does not keep the scale.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 31 words, 9.3 s): Only 36% of the new studies showed a result strong enough to pass standard statistical tests, meaning most of them didn't reach the same level of certainty as the original papers.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

### h13 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.09, 55 words, 1.8 s, nums hundred): This means that when researchers tried to repeat one hundred previous psychology studies, only thirty-six percent of them produced clear and reliable discoveries that met standard scientific thresholds. This matters because it shows that a large number of published findings might be difficult to reproduce, raising important questions about the reliability of published scientific research.
  - Note: explains. Thirty-six percent of one hundred studies; reliability of published work.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 35 words, 17.4 s, nums 64, guard retried): Out of 100 studies checked, only 36 showed a clear, repeatable result. The other 64 didn't reach that same standard. This suggests that many scientific findings might not be stable or reliable when tested again.
  - Note: explains. 36 of 100, so 64 did not reach the standard. The 64 is a complement, not a new result.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.04, 73 words, 3.8 s, nums third): This means that when researchers tried to repeat the original experiments, only about one third of them got the same clear results as the first time. In science, repeating an experiment is important to prove that the first result was not just a lucky guess or a mistake. Since so many studies failed to get the same results again, it suggests that many original findings might be less reliable than we first thought.
  - Note: explains. About one third; many original findings may be less reliable.
- **Qwen 3.5 4B, new prompts** (overlap 0.08, 29 words, 8.0 s): Out of many studies checked, only about one in three showed a real result when tested again. That means most findings didn't hold up under the same careful checks.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.04, 69 words, 12.3 s, nums third): This finding indicates a substantial replication crisis within psychology, where only about one third of studies yielded significant p values upon retesting. Given the high powered designs used, this low success rate suggests that many original findings were likely false positives or inflated by publication bias, rather than reflecting robust phenomena. This discrepancy highlights a systemic failure to reliably reproduce experimental effects, undermining the validity of the original literature.
  - Note: explains. About one third significant on retest; possible false positives or publication bias.
- **Qwen 3.5 4B, new prompts** (overlap 0.08, 45 words, 12.5 s): Only 36% of the replications showed a result strong enough to pass standard statistical tests, compared to 97% in the original studies. This suggests that many published findings are not robust enough to be reproduced under rigorous conditions, which challenges the reliability of current research.
  - Note: explains. Keeps 36% (or a fair 'one in three'); often contrasts it with the 97% of originals.

## h14. Microstructure of a spatial map in the entorhinal cortex

Source: https://pubmed.ncbi.nlm.nih.gov/15965463/  
Highlight: "any vertex of a regular grid of equilateral triangles spanning the surface of the environment"

### h14 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.10, 21 words, 3.6 s): This refers to any corner point on a repeating pattern of triangles that covers the area the animal is moving through.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 31 words, 7.8 s): The brain uses a pattern of spots arranged like a honeycomb to track where an animal is. Each spot lights up when the animal lands on one of those specific points.
  - Note: explains. Honeycomb spots; a cell lights up at those points. Fair reading of a triangular grid.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.09, 21 words, 4.6 s): This means any corner point on a repeating pattern made of triangles that covers the area where the animal is walking.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 31 words, 10.0 s): Imagine the animal's brain is a giant graph paper. Every time it steps on a specific spot, a special cell lights up exactly where that spot would be on the paper.
  - Note: partly. 'Giant graph paper' sounds like a square grid, not equilateral triangles.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.10, 28 words, 5.9 s): Grid cells fire at specific locations forming a hexagonal lattice across the environment. This geometric arrangement allows the brain to encode spatial coordinates through a periodic, repeating structure.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.15, 31 words, 8.4 s): Grid cells fire at specific points that form a perfect geometric pattern of equilateral triangles across the space. This means the animal's position aligns with one of these mathematically precise vertices.
  - Note: explains. Equilateral triangle vertices; precise and at the right level.

### h14 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 26 words, 23.2 s): This means a brain cell fires when an animal stands on any corner of a repeating triangle pattern that covers the floor like a tiled floor.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.07, 27 words, 7.4 s): Imagine a giant invisible net made of perfect triangles covering the ground. A cell lights up only when you stand exactly on one of those triangle corners.
  - Note: explains. Invisible net of perfect triangles; lights up on the corners.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 26 words, 2.9 s): This means the brain cell turns on when the animal stands on a specific spot in a pattern of triangles, like dots on a game board.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.08, 24 words, 7.4 s): Imagine a giant invisible honeycomb covering the whole room. The grid cells light up exactly where you stand on the corners of that honeycomb.
  - Note: explains. Honeycomb corners, same idea.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 25 words, 3.0 s): The cell fires when the animal reaches specific points on a triangular pattern covering the floor, much like a repeating honeycomb grid on a map.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.27, 27 words, 7.2 s): Grid cells fire at every point where the animal is on a specific equilateral triangle pattern. These triangles form a regular grid that covers the whole space.
  - Note: explains. Equilateral triangle pattern covering the space.

### h14 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 75 words, 0.3 s): This phrase describes the specific locations where a grid cell fires or becomes active. Imagine a map covered in a perfectly repeating pattern of triangles. When an animal stands exactly on one of the points where these triangle corners meet, the brain cell fires. This matters because it shows how the brain creates a precise internal coordinate system, like a GPS grid, to help the animal track its exact location as it moves through space.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.04, 42 words, 9.1 s): The brain uses a special code made of overlapping hexagons to track location. The animal’s position matches one point on this pattern, like a checkerboard square. This grid changes size depending on where you are, and it stays even if landmarks disappear.
  - Note: partly. Hexagons and landmark-independence are fair, but 'like a checkerboard square' and 'changes size depending on where you are' muddle the grid.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 60 words, 1.8 s): This phrase describes a special repeating pattern of triangles that covers the space an animal explores. Each corner point in this triangle pattern acts like a trigger in the brain, turning on a specific brain cell whenever the animal steps on that exact spot. This helps the brain map out the environment and figure out where the animal is located.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.04, 43 words, 8.7 s): Imagine a floor covered in matching triangular tiles. A 'grid cell' fires whenever you stand on one of those spots, no matter how big the room is or if the landmarks are gone. This helps the animal count steps and stay on track.
  - Note: explains. Triangular tiles; fires even if landmarks are gone.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 61 words, 3.0 s): This refers to the hexagonal spatial firing pattern of grid cells in the dMEC. The vertices represent the specific locations where a cell fires, forming a periodic, triangular lattice that tiles the environment. This geometry is critical because it provides a metric for spatial representation, allowing the brain to compute distance and direction through path integration, independent of external sensory landmarks.
  - Note: explains. Fires at the corners of a repeating triangular or hexagonal grid covering the space.
- **Qwen 3.5 4B, new prompts** (overlap 0.03, 41 words, 133.7 s): Grid cells fire at precise locations forming a hexagonal lattice. The spacing and size of individual fields increase from dorsal to ventral dMEC, creating a continuous topographical map anchored to landmarks yet persisting in their absence, suggesting a path-integration-based spatial representation.
  - Note: explains. Hexagonal lattice, dorsal-to-ventral spacing from the paper, path integration.

## h15. Why most published research findings are false

Source: https://pubmed.ncbi.nlm.nih.gov/16060722/  
Highlight: "claimed research findings may often be simply accurate measures of the prevailing bias"

### h15 · plain

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 27 words, 0.3 s): Scientific results might not reflect reality at all. Instead, they often just show the common prejudices or expectations that researchers already held before they started their study.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 34 words, 8.5 s): If researchers are chasing results that look good, their data might just reflect that bias instead of real truth. The numbers they report could be a mirror of how they were looking for answers.
  - Note: explains. The reported numbers may mirror the bias in how people looked for answers.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 29 words, 4.9 s): Scientific results might not be showing the truth. Instead, they often just reflect the unfair opinions or personal beliefs that the researchers already had before they started their work.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 28 words, 6.6 s): The study says that what scientists claim might just show how much they are wrong about their own methods. It's like a mirror showing the mistakes people make.
  - Note: partly. 'How much they are wrong about their own methods' is vaguer than prevailing bias, though the mirror idea is in the right direction.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.14, 31 words, 2.8 s): Published results often reflect systematic errors or preconceived notions within a field rather than objective reality. These findings quantify the influence of bias instead of measuring the actual phenomenon under investigation.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 36 words, 6.9 s): The paper argues that many published results are just reflections of systematic errors in how studies are designed or funded, rather than truths about nature. Essentially, the data itself is a mirror of the methodological flaws.
  - Note: explains. Systematic errors in design or funding, not truths about nature.

### h15 · simpler

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 26 words, 7.7 s): Scientific results might just be a mirror reflecting whatever widespread prejudice or unfair leaning already exists, like a biased scale that always tips the same way.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 28 words, 7.7 s): This means some results are just reflecting what researchers already want to see or how they are biased. It's like a mirror showing only what you already expect.
  - Note: explains. Results can reflect what researchers already want to see.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 26 words, 3.8 s): Scientists sometimes just report what they already expect to see instead of the truth, like a mirror reflecting only what is placed in front of it.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 28 words, 7.3 s): Some studies might just show what people already believe instead of finding new truth. If a team pushes their favorite idea, they might accidentally prove it is true.
  - Note: partly. 'They might accidentally prove it is true' muddles the point: the finding may only reflect the bias, not prove a true idea.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 25 words, 6.8 s): Published scientific claims often just measure the hidden prejudices of the researchers, like a crooked scale that always weighs in favor of what scientists want.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 30 words, 6.2 s): When a study is small or biased, its result might just reflect that bias rather than a real effect. In many fields, false claims are more common than true ones.
  - Note: explains. A small or biased study may reflect the bias rather than a real effect.

### h15 · detail

**default**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.03, 76 words, 3.9 s): This means that instead of discovering a new scientific truth, a study might just be reporting results that confirm what researchers already wanted or expected to find. It matters because it suggests that scientific data can be skewed by human prejudice or financial interests. When this happens, the study does not actually reveal facts about the world, but instead acts as a mirror that reflects the existing opinions or biases of the people conducting the research.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 46 words, 9.8 s): The authors warn that many published results might just reflect the researcher's expectations or hidden influences. If a study is small or biased, the result could match what the researchers hoped to find rather than reality. It means the number doesn't prove truth on its own.
  - Note: explains. Expectations or hidden influences; a number does not prove truth on its own.

**beginner**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.03, 47 words, 13.8 s): This means that instead of discovering new scientific truths, many published research studies are just accurately measuring the unfair prejudices or errors that scientists already held. This matters because it shows that science can sometimes be misled by human mistakes or outside influences rather than actual facts.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 39 words, 9.2 s): This means a result might just show how much the study was pushed by money or expectations, not what is actually true. If a team wants to find a link, they might design the study to make one appear.
  - Note: explains. Pushed by money or expectations; a study can be designed to make a link appear.

**grad**
- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 67 words, 4.8 s): This statement suggests that in fields with high researcher flexibility and strong incentives for positive results, reported findings frequently reflect systematic error rather than biological reality. Instead of capturing true effects, the data effectively quantifies the researcher's prior expectations or the field's collective prejudice. This implies that the statistical significance observed is often an artifact of the experimental design choices that favor confirmation bias over objective discovery.
  - Note: explains. Claimed findings may just measure prevailing bias or researchers' expectations, not a real effect.
- **Qwen 3.5 4B, new prompts** (overlap 0.05, 35 words, 9.4 s): When many studies chase statistical significance with small samples and flexible designs, they amplify bias. Here, a positive result might not reflect a real effect but rather the systematic error introduced by these methodological weaknesses.
  - Note: explains. Small samples and flexible designs amplify bias; a positive result may be systematic error.
