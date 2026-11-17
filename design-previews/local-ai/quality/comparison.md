# Paper Tree local reader: quality test

Speed and number pass, run 44082736137 at 75df9f5 (Linux CI, 4 vCPU, CPU only, llama.cpp b12428, prompt cache on). The previous pass is run 44067176475. Times on this CI machine are far slower than a real Apple Silicon Mac.

## Summary (the 15 real highlights)

| Model | Restating (overlap 0.5 or more) | Avg overlap | Avg words | Avg time per explanation | Guard retries | Numbers not in the paper (auto check) | My read: explains / partly / restates / has an error |
|---|---|---|---|---|---|---|---|
| Gemini (gemini-3.1-flash-lite, via the Worker) | 0 of 15 (0%) | 0.12 | 33 | 1.8 s (Paper Tree Worker (read-only)) | 0 | 4 of 15 | 15 / 0 / 0 / 0 |
| Qwen 3.5 4B, new prompts | 0 of 15 (0%) | 0.15 | 35 | 32.9 s (GitHub ubuntu-latest, 4 vCPU, 15 GB, CPU only) | 2 | 0 of 15 | 12 / 2 / 0 / 1 |
| Qwen 3.5 9B, new prompts | 0 of 15 (0%) | 0.10 | 37 | 55.1 s (GitHub ubuntu-latest, 4 vCPU, 15 GB, CPU only) | 1 | 0 of 15 | 12 / 2 / 0 / 1 |
| Qwen 3.5 4B, previous pass (run 44067176475) | 0 of 15 (0%) | 0.06 | 34 | 52.8 s (GitHub ubuntu-latest, 4 vCPU, 15 GB, CPU only) | 0 | 7 of 15 | 9 / 1 / 0 / 5 |
| Qwen 3.5 9B, previous pass (run 44067176475) | 0 of 15 (0%) | 0.09 | 37 | 99.8 s (GitHub ubuntu-latest, 4 vCPU, 15 GB, CPU only) | 0 | 6 of 15 | 12 / 1 / 0 / 2 |

Overlap is the share of an answer's content words that already appear in the highlight (stop words left out). It catches word-for-word restating, not a paraphrase in new words, so each answer also has my own short note.

## r00. Leaves in a dry spell (Paper Tree's own sample text, the highlight the 2B restated) (regression check, not scored)

Source: Sources/PaperTree/Snapshots.swift  
Mode: plain  
Highlight: "Rubisco also reacts with oxygen, and that side reaction becomes more common as carbon dioxide inside the leaf drops."

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.56, 24 words, 1.7 s): Rubisco sometimes accidentally reacts with oxygen instead of carbon dioxide. This wasteful side reaction increases when carbon dioxide levels inside the leaf go down.
  - Note: restates. Closest to the highlight of any Gemini answer (overlap 0.56). It rephrases the same two facts and adds almost no why, though the glossary helps.
- **Qwen 3.5 4B, new prompts** (overlap 0.19, 30 words, 67.0 s): Rubisco is a bit like a confused worker who sometimes picks up the wrong task. When there is less CO2, it mistakes oxygen for its target instead of fixing carbon.
  - Note: explains. Oxygen picked by mistake when CO2 is low; no restating.
- **Qwen 3.5 9B, new prompts** (overlap 0.19, 27 words, 130.3 s): The enzyme Rubisco grabs carbon to help plants grow, but it sometimes grabs oxygen instead when there isn't enough carbon. This mistake wastes energy and slows growth.
  - Note: explains. Oxygen grabbed instead when carbon is short, wastes energy.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.31, 21 words, 47.0 s): Rubisco mistakes oxygen for carbon dioxide. When CO2 gets low, this mistake happens more often, wasting energy fixing the wrong carbon.
  - Note: explains. Explains the mistake and that it gets worse as CO2 drops. 'Fixing the wrong carbon' is a little loose, but this is no longer a restatement.
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.18, 32 words, 87.8 s): When CO2 gets low, Rubisco grabs oxygen by mistake instead. That wrong reaction wastes energy because the plant has to fix the damage, so it's like a costly error in the factory.
  - Note: explains. Adds the why the 2B restatement missed: the oxygen reaction is a costly mistake that wastes energy.

## h01. Attention Is All You Need

Source: https://arxiv.org/abs/1706.03762  
Mode: plain  
Highlight: "dispensing with recurrence and convolutions entirely"

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 20 words, 2.1 s): The authors are creating a new model that completely removes the need for traditional recurrent or convolutional neural network structures.
  - Note: explains. Correct, but mostly a paraphrase of the claim rather than why skipping recurrence and convolutions matters.
- **Qwen 3.5 4B, new prompts** (overlap 0.12, 32 words, 36.0 s): Old computer brains used two heavy tools called recurrence and convolutions, but this new design skips them completely. It works by looking at all words at once instead of one by one.
  - Note: explains. Contrasts the old tools with reading all words at once. "Computer brains" is a bit loose.
- **Qwen 3.5 9B, new prompts** (overlap 0.00, 40 words, 66.7 s): Most AI models for translation use loops or filters that read text one piece at a time. This new design drops those parts completely, so it can learn faster and handle more tasks without needing to read step by step.
  - Note: explains. Drops step-by-step reading parts.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.00, 29 words, 51.2 s): Older models used slow step-by-step memory or scanning filters, but this new design skips both. It just looks at every word at once to decide which parts matter most.
  - Note: explains. Good contrast of recurrence and convolutions with looking at every word at once.
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.00, 35 words, 96.1 s): They throw away the old way of processing words one at a time or sliding a window. Instead, every word talks directly to every other word, which lets them train faster and handle longer sentences.
  - Note: explains. Explains the old one-step-at-a-time or sliding-window methods and why all-to-all attention helps.

## h02. Observation of Gravitational Waves from a Binary Black Hole Merger

Source: https://arxiv.org/abs/1602.03837  
Mode: plain  
Highlight: "a false alarm rate estimated to be less than 1 event per 203 000 years, equivalent to a significance greater than 5.1 σ"

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.20, 26 words, 3.1 s): This means scientists are extremely certain the signal was real and not random noise. A chance accident like this would only happen once every 203,000 years.
  - Note: explains. Keeps the 203,000-year figure and states the claim clearly.
- **Qwen 3.5 4B, new prompts** (overlap 0.24, 33 words, 39.4 s): The signal was so real it would happen by pure chance less than once every 203,000 years. This means the odds of a fake result are tiny and the finding is very strong.
  - Note: explains. Copies 203,000 years exactly and says what it means.
- **Qwen 3.5 9B, new prompts** (overlap 0.00, 22 words, 123.8 s, guard retried): The signal wasn't random noise because it is so rare to see a fake one. This rarity makes the result very trustworthy.
  - Note: partly. No number errors, but it leaves out the 203 000 years and 5.1 sigma it was asked about.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.07, 29 words, 55.4 s): This signal was so strong it would have taken over half a million years to happen by pure chance. It's a discovery-level finding, not a fluke or a glitch.
  - Note: error. Turns 203,000 years into 'over half a million years'.
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.11, 40 words, 104.6 s): That means the signal is so rare that you'd expect to see it by chance less than once every two hundred thousand years. It's like winning a lottery twice in a row with odds worse than one in a billion.
  - Note: explains. Keeps the ~200,000-year figure. The lottery analogy is loose, but the core claim is right.

## h03. Observation of a new particle in the search for the Standard Model Higgs boson with the ATLAS detector at the LHC

Source: https://arxiv.org/abs/1207.7214  
Mode: plain  
Highlight: "5.9 standard deviations"

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 32 words, 2.0 s): This is a statistical measurement showing that the discovery is extremely unlikely to be a random error. It confirms that the particle detected is almost certainly real and not just a fluke.
  - Note: explains. Correct reading of a discovery-level significance, without inventing a wrong probability.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 36 words, 53.0 s, guard retried): This number measures how unlikely it is that the result was just a random mistake. A value of 5.9 means the chance of a background fluctuation this strong is extremely small, making the finding very convincing.
  - Note: explains. Says 5.9 measures how unlikely a fluke is; no invented probability (first try said "1 in 100 million" and the number check caught it).
- **Qwen 3.5 9B, new prompts** (overlap 0.06, 32 words, 39.3 s): That number means the signal is far beyond random noise. It's like flipping a coin and getting heads 5.9 times in a row when tails should appear, so it's not just luck.
  - Note: error. "Heads 5.9 times in a row" turns the 5.9 standard deviations into a wrong coin-flip count.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.00, 30 words, 50.5 s): It's like rolling a die and finding that result five times in a row by pure chance. That probability is so tiny, it proves the signal isn't just random noise.
  - Note: error. The 'rolling a die five times in a row' analogy is the wrong scale: that is thousands-to-one, not a 5.9-sigma discovery.
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.13, 31 words, 95.0 s): That's a very strong signal. In physics, five standard deviations means there's less than one chance in a billion that it's just random noise, so the result is considered a discovery.
  - Note: explains. Uses the usual five-sigma discovery threshold. It says five rather than 5.9, and 'one in a billion' is a rough 6-sigma figure, close enough here.

## h04. Deep Residual Learning for Image Recognition

Source: https://arxiv.org/abs/1512.03385  
Mode: detail  
Highlight: "We explicitly reformulate the layers as learning residual functions with reference to the layer inputs, instead of learning unreferenced functions."

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.13, 68 words, 1.3 s): The authors are changing how neural network layers process information. Instead of asking each layer to learn a completely new output from scratch, they design the layers to learn the difference, or residual, between the input and the desired output. This approach makes it much easier for the network to train because the layers only need to focus on small adjustments rather than mapping everything from the beginning.
  - Note: explains. Clear account of residual vs unreferenced functions and why the change helps training.
- **Qwen 3.5 4B, new prompts** (overlap 0.04, 63 words, 31.8 s): Normally, a deep network tries to learn what changes from one step to the next. This method tells it to learn only the extra change needed to get from the input to the output. If the network doesn't need to change much, it just passes the input through. This makes the math easier and lets the network be much deeper without getting stuck.
  - Note: explains. Learns only the change from input to output; identity pass-through; why deeper works.
- **Qwen 3.5 9B, new prompts** (overlap 0.05, 44 words, 53.0 s): Normally, a deep network tries to learn everything from scratch, which is hard. Here, each layer just learns the small change needed on top of what came before. This makes training very easy and lets the model get much more accurate by going deeper.
  - Note: explains. Each layer learns the small change on top of what came before.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.20, 49 words, 56.1 s): Normal layers try to learn a brand new function from scratch, which gets harder as you add more. These layers instead teach how to adjust what came in, subtracting that input and learning just the difference. This shortcut keeps the signal flowing through hundreds of layers without dying out.
  - Note: explains. Solid residual-learning explanation, including the shortcut that keeps the signal from dying out.
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.12, 53 words, 102.5 s): Instead of trying to learn the whole output from scratch, each layer only learns the small change needed to get from its input to the next step. This makes it much easier for the network to train very deep, because it avoids the problem where deeper layers cancel out what earlier ones learned.
  - Note: explains. Clear residual-learning explanation, including why depth becomes easier.

## h05. Electric Field Effect in Atomically Thin Carbon Films

Source: https://arxiv.org/abs/cond-mat/0410550  
Mode: plain  
Highlight: "ballistic transport at submicron distances even at room temperature"

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.08, 28 words, 2.4 s): This describes how electrons move through a material without hitting obstacles or losing energy. It happens over very short distances even when the material is not cooled down.
  - Note: explains. Defines ballistic transport and why room temperature matters.
- **Qwen 3.5 4B, new prompts** (overlap 0.07, 24 words, 17.1 s): Electrons move in straight lines like a bullet without bumping into anything. This happens when the material is tiny, even at normal room heat.
  - Note: partly. Straight-line electrons is right, but "when the material is tiny" blurs the submicron distance point.
- **Qwen 3.5 9B, new prompts** (overlap 0.00, 31 words, 32.7 s): The electrons zip across without bumping into anything, so the current flows perfectly. That works even when the chip is warm like a normal day, which is amazing for tiny circuits.
  - Note: partly. "Current flows perfectly" overstates ballistic transport.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.00, 34 words, 47.7 s): Electrons move without bumping into anything, like a laser beam in a straight line. This happens only when the path is tiny and the material is perfect, which graphene does even when it's warm.
  - Note: explains. Clear, and correctly ties room-temperature ballistic transport to graphene.
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.06, 27 words, 88.5 s): Electrons zip across without bumping into atoms. This happens only in tiny chips and usually needs near-zero heat, but they did it here in a normal room.
  - Note: explains. Gets room-temperature ballistic transport. 'Only in tiny chips' is a bit invented, but the main point holds.

## h06. Planck 2018 results. VI. Cosmological parameters

Source: https://arxiv.org/abs/1807.06209  
Mode: plain  
Highlight: "Hubble constant"

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.15, 28 words, 1.3 s): The Hubble constant is a number that describes how fast the universe is expanding. It measures the rate at which galaxies move away from each other over time.
  - Note: explains. Accurate one-sentence definition of the Hubble constant.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 23 words, 34.2 s): It's a measure of how fast the universe is expanding right now, based on how fast distant galaxies are moving away from us.
  - Note: explains. Expansion rate now, from galaxies moving away.
- **Qwen 3.5 9B, new prompts** (overlap 0.11, 41 words, 66.2 s): The Hubble constant is a number that tells us how fast the universe is stretching right now. It's measured by looking at the light from distant galaxies, and this result matches what we expect in the simplest model of the universe.
  - Note: explains. Expansion rate now; matches the simplest model, from context.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.00, 25 words, 56.2 s): It's how fast the universe is expanding right now. This number tells you the speed of space itself, not how fast galaxies move through it.
  - Note: explains. Accurate definition of the Hubble constant.
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.00, 25 words, 106.4 s): That's how fast the universe expands right now. The numbers show it's about 67 km/s per megaparsec, which matches other ways to measure cosmic expansion.
  - Note: error. 67 km/s/Mpc is the Planck value, but 'matches other ways to measure cosmic expansion' is the wrong direction: this paper is part of the Hubble tension with local measurements.

## h07. Safety and Efficacy of the BNT162b2 mRNA Covid-19 Vaccine

Source: https://pubmed.ncbi.nlm.nih.gov/33301246/  
Mode: plain  
Highlight: "BNT162b2 was 95% effective in preventing Covid-19 (95% credible interval, 90.3 to 97.6)"

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.31, 26 words, 2.3 s): The vaccine prevented 95 percent of Covid-19 cases in the study. The credible interval shows the range of statistical certainty for how well the vaccine works.
  - Note: explains. Correctly treats 95% as case prevention, and explains the credible interval.
- **Qwen 3.5 4B, new prompts** (overlap 0.28, 34 words, 37.1 s): The vaccine stopped 95 out of every 100 cases from happening. The 95% credible interval means the true effectiveness is very likely between 90.3% and 97.6%, so we are very sure it works well.
  - Note: partly. Copies 95% and 90.3 to 97.6 exactly, but "stopped 95 out of every 100 cases" is a loose reading of efficacy.
- **Qwen 3.5 9B, new prompts** (overlap 0.19, 33 words, 60.0 s): The vaccine cut the risk of getting Covid-19 by 95%. The numbers in parentheses show how sure we are about that estimate, and even at the lowest end it still blocks most cases.
  - Note: explains. 95% risk cut, interval read correctly without new numbers.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.21, 46 words, 58.8 s): Out of the people who got the shot, only one in twenty got sick with Covid-19, while a lot more in the placebo group did. The range from 90.3 to 97.6 shows how sure we are that this number is close to the true protection level.
  - Note: error. Classic misread of vaccine efficacy: 95% effective does not mean one in twenty vaccinated people got sick.
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.05, 38 words, 109.8 s): Out of 43,548 people, the vaccine stopped severe illness in about 95 out of every 100 cases compared to placebo. That range means we're very sure the number is between 90 and 98, so it's a strong protection.
  - Note: error. The trial size is fine, but 95% efficacy was for symptomatic Covid-19, not specifically 'severe illness'.

## h08. A programmable dual-RNA-guided DNA endonuclease in adaptive bacterial immunity

Source: https://pubmed.ncbi.nlm.nih.gov/22745249/  
Mode: plain  
Highlight: "the potential to exploit the system for RNA-programmable genome editing"

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.15, 25 words, 1.3 s): This refers to using the CRISPR system as a tool to change DNA sequences by using specific RNA molecules to guide where those changes happen.
  - Note: explains. Plain, accurate description of RNA-guided genome editing.
- **Qwen 3.5 4B, new prompts** (overlap 0.14, 35 words, 24.6 s): This means scientists can use a natural bacterial defense system to cut specific parts of DNA with RNA instructions. It's like a programmable tool that allows researchers to change the genetic code of living things.
  - Note: explains. RNA-guided cutting of DNA as a programmable tool.
- **Qwen 3.5 9B, new prompts** (overlap 0.17, 32 words, 45.4 s): Scientists can reprogram this natural defense system with any RNA sequence. That lets them tell Cas9 exactly where to cut DNA, so they can fix or change genes anywhere in the genome.
  - Note: explains. Reprogram Cas9 with RNA to cut where you want.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.13, 26 words, 51.0 s): This system lets scientists program RNA to cut DNA at any spot, which could be used to fix genes or make new traits in living things.
  - Note: explains. Accurate and concise.
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.05, 36 words, 90.3 s): You can design a custom RNA sequence that finds any specific gene and tells Cas9 to cut it out. That lets scientists rewrite DNA in cells on purpose, just by programming which RNA guide they use.
  - Note: explains. Clear and accurate: a programmable RNA guide tells Cas9 where to cut.

## h09. Highly accurate protein structure prediction with AlphaFold

Source: https://pubmed.ncbi.nlm.nih.gov/34265844/  
Mode: plain  
Highlight: "even in cases in which no similar structure is known"

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 24 words, 1.6 s): This means the computer model can accurately predict a protein shape even when it cannot compare that protein to any other previously studied ones.
  - Note: explains. Gets the point: the model works without a known similar structure.
- **Qwen 3.5 4B, new prompts** (overlap 0.08, 28 words, 26.1 s): Scientists usually guess a protein's shape by comparing it to one already solved. This new method works even when there is no similar shape to compare it against.
  - Note: explains. Usual method needs a solved similar shape; this one does not.
- **Qwen 3.5 9B, new prompts** (overlap 0.14, 39 words, 44.1 s): Before this work, computers could only guess a protein's shape if they had seen a very similar one before. This new method works even when there are no similar structures to copy from, which is a big step forward.
  - Note: explains. Works without a similar known structure.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.00, 32 words, 51.1 s): Before this method, computers could only guess a shape if they had a close match to copy from. Now it can stand alone and get the right details without needing that template.
  - Note: explains. Correct: it no longer needs a close template.
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.06, 38 words, 98.9 s): Before this, computers could only guess well if a very similar protein had been solved before. This new method works even when nothing close exists, so it can finally predict the shapes of most proteins we've ever seen.
  - Note: explains. Correct contrast with template-based methods.

## h10. A Randomized Trial of Intensive versus Standard Blood-Pressure Control

Source: https://pubmed.ncbi.nlm.nih.gov/26551272/  
Mode: plain  
Highlight: "hazard ratio with intensive treatment, 0.75; 95% confidence interval [CI], 0.64 to 0.89"

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.33, 35 words, 1.7 s): The hazard ratio shows that intensive treatment reduced the risk of heart events by 25 percent. The confidence interval means researchers are 95 percent sure the true risk reduction is between 11 and 36 percent.
  - Note: explains. Correctly reads 0.75 as a 25% risk reduction and translates the confidence interval.
- **Qwen 3.5 4B, new prompts** (overlap 0.35, 44 words, 38.2 s): The hazard ratio of 0.75 means people in the strict blood pressure group were less likely to have heart problems than those in the standard group. The 95% confidence interval of 0.64 to 0.89 shows how sure we are that this difference is real.
  - Note: explains. 0.75 and 0.64 to 0.89 copied exactly; no "25% less" conversion this time.
- **Qwen 3.5 9B, new prompts** (overlap 0.36, 42 words, 69.8 s): The hazard ratio of 0.75 means people in the intensive group had a lower risk of major heart events than those in the standard group. The 95% CI from 0.64 to 0.89 shows this difference is real and not just random chance.
  - Note: explains. 0.75 and 0.64 to 0.89 exact; no "a quarter less" conversion this time.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.00, 41 words, 60.1 s): For every person in the low-blood-pressure group, there were about 75% as many heart attacks or strokes as in the normal group. The range from 64% to 89% means we are very sure this difference is real and not a fluke.
  - Note: explains. Correctly reads 0.75 as about 75% as many events, with the interval in the same units.
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.35, 33 words, 112.6 s): A hazard ratio of 0.75 means the intensive group had about a quarter less risk each year than the standard group, and we're pretty sure the real number is between 0.64 and 0.89.
  - Note: explains. Correct reading of the hazard ratio and the interval.

## h11. Once-Weekly Semaglutide in Adults with Overweight or Obesity

Source: https://pubmed.ncbi.nlm.nih.gov/33567185/  
Mode: simpler  
Highlight: "-14.9% in the semaglutide group as compared with -2.4% with placebo"

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.07, 27 words, 2.4 s): People taking the medicine lost about fifteen percent of their body weight, like losing fifteen pounds out of one hundred, while the control group lost very little.
  - Note: explains. Clear contrast of 15% vs 2.4% weight loss, with a concrete analogy.
- **Qwen 3.5 4B, new prompts** (overlap 0.25, 32 words, 65.6 s, guard retried): People taking semaglutide lost 14.9% of their body weight on average, while those taking a fake pill only lost 2.4%. This shows the drug helps people lose more weight than a placebo.
  - Note: explains. 14.9% and 2.4% copied exactly (first try added "eight", caught by the number check).
- **Qwen 3.5 9B, new prompts** (overlap 0.10, 36 words, 59.9 s): On average, people taking the drug lost 14.9% of their starting weight, while those on the fake pill lost only 2.4%. That big difference shows the drug works much better at helping people shed extra pounds.
  - Note: explains. 14.9% and 2.4% exact.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.00, 27 words, 55.7 s): People on the new drug lost about 15% of their weight over six months, while those on the sugar pill only lost 2%. That's a big difference.
  - Note: error. The percentages are right, but the trial was 68 weeks, not 'over six months'.
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.07, 24 words, 111.2 s): The drug helped people lose about 15% of their starting weight, while the fake pill group lost only about 2%. That's a big difference.
  - Note: explains. Straightforward and accurate on the two percentages.

## h12. More than 75 percent decline over 27 years in total flying insect biomass in protected areas

Source: https://pubmed.ncbi.nlm.nih.gov/29045418/  
Mode: plain  
Highlight: "a seasonal decline of 76%, and mid-summer decline of 82% in flying insect biomass over the 27 years of study"

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.27, 28 words, 1.3 s): Over twenty seven years, the total weight of flying insects dropped by over three quarters during the season and by over eighty percent during the middle of summer.
  - Note: explains. Keeps the 27-year window and does not turn the declines into a within-year spring-to-summer drop.
- **Qwen 3.5 4B, new prompts** (overlap 0.45, 26 words, 23.8 s): Flying insects got 76% lighter in spring and 82% lighter in summer. This is a big drop in total weight, not just how many there are.
  - Note: error. Percentages copied exactly, but "76% lighter in spring" misreads the seasonal decline, and the 27 years is dropped.
- **Qwen 3.5 9B, new prompts** (overlap 0.32, 35 words, 41.2 s): Insects lost huge amounts of weight in total over 27 years, with 76% less in a typical season and 82% less in mid-summer. This drop happened everywhere and wasn't caused by weather or land use.
  - Note: explains. 76% in a typical season and 82% in mid-summer over 27 years, all exact and read correctly.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.27, 27 words, 50.2 s): Flying insects dropped by three-quarters from spring to summer, and by more than four-fifths by mid-summer. That's a massive drop that shows how much life is disappearing.
  - Note: error. Treats the 76% and 82% figures as a within-year spring-to-summer drop, not a 27-year decline.
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.17, 33 words, 95.4 s): That's a massive drop. Over three decades, flying insects lost most of their weight in summer and even more during other seasons, meaning fewer food sources for birds and less help for plants.
  - Note: partly. Catches that the drop is large and over decades, but then mixes up seasonal vs mid-summer ('even more during other seasons' is backwards).

## h13. PSYCHOLOGY. Estimating the reproducibility of psychological science

Source: https://pubmed.ncbi.nlm.nih.gov/26315443/  
Mode: plain  
Highlight: "Thirty-six percent of replications had statistically significant results"

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.00, 30 words, 1.2 s): Only about one third of the repeated studies produced the same meaningful evidence as the originals. This shows that many initial findings were likely not as strong as first reported.
  - Note: explains. Correct implication: many original findings did not hold up.
- **Qwen 3.5 4B, new prompts** (overlap 0.06, 35 words, 21.1 s): Only 36% of the new tests showed a real result, while 97% of the original studies did. This means most of the findings that seemed important at first were not strong enough to be trusted.
  - Note: explains. 36% vs the 97% of originals from the context, both exact.
- **Qwen 3.5 9B, new prompts** (overlap 0.00, 36 words, 40.5 s): Only 36% of the repeated experiments showed a clear effect, which is much lower than the 97% seen in the first round. This means most of the original findings did not hold up when tested again.
  - Note: explains. 36% vs 97%, both exact.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.00, 25 words, 48.4 s): Only a little over one-third of the new studies showed real effects. That means most of the original findings didn't hold up when checked again.
  - Note: explains. Correct implication: most original findings did not hold up.
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.06, 36 words, 92.8 s): That's a big drop from the 97% of original studies that looked significant. It means most experiments didn't find the same strong effect again, so the original findings were often too optimistic or hard to repeat.
  - Note: explains. Best local answer here: brings in the 97% vs 36% contrast from the paper.

## h14. Microstructure of a spatial map in the entorhinal cortex

Source: https://pubmed.ncbi.nlm.nih.gov/15965463/  
Mode: detail  
Highlight: "any vertex of a regular grid of equilateral triangles spanning the surface of the environment"

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 75 words, 1.5 s): This phrase describes the specific locations where a grid cell fires or becomes active. Imagine a map covered in a perfectly repeating pattern of triangles. When an animal stands exactly on one of the points where these triangle corners meet, the brain cell fires. This matters because it shows how the brain creates a precise internal coordinate system, like a GPS grid, to help the animal track its exact location as it moves through space.
  - Note: explains. Best of the set: vertices of a triangular grid, and why that gives an internal map.
- **Qwen 3.5 4B, new prompts** (overlap 0.10, 43 words, 23.0 s): Imagine a floor covered with identical equilateral triangles. This brain map covers that same area and lights up only when the animal is standing at one of those triangle corners. It works like a giant ruler where every corner marks a specific spot.
  - Note: explains. Fires at the triangle corners of a grid covering the floor.
- **Qwen 3.5 9B, new prompts** (overlap 0.07, 61 words, 48.0 s): The brain has a map made of grids like a dot-to-dot puzzle. Each dot is a point where a special cell fires, and these dots form perfect triangles that cover the whole space. Neighboring grids line up like graph paper, but each grid starts at a different spot. This pattern helps animals figure out where they are even without looking outside.
  - Note: explains. Grid of firing points forming triangles; a bit long.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.04, 55 words, 51.1 s): Think of a giant invisible checkerboard on the floor of the animal's world. A 'grid cell' lights up only when the animal stands exactly on one of those tiny corners. This creates a map where every spot has its own unique address, letting the brain figure out where it is without needing to see anything.
  - Note: partly. Gets the firing-at-corners idea, but calls the lattice a 'checkerboard' (it is triangular) and says each spot has a unique address (one grid cell fires at many vertices).
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.05, 72 words, 100.0 s): Imagine the animal moving on a floor drawn with a big pattern of evenly spaced triangles. Every time the animal lands on a corner of any triangle, that cell fires. Neighboring cells share the same grid lines but start firing at different corners, so together they tile the whole space. This map lets the brain track position without landmarks by adding up steps, which is how animals navigate even in the dark.
  - Note: explains. Strong: triangular lattice, neighboring cells, and path integration even in the dark.

## h15. Why most published research findings are false

Source: https://pubmed.ncbi.nlm.nih.gov/16060722/  
Mode: plain  
Highlight: "claimed research findings may often be simply accurate measures of the prevailing bias"

- **Gemini (gemini-3.1-flash-lite, via the Worker)** (overlap 0.06, 27 words, 1.4 s): Scientific results might not reflect reality at all. Instead, they often just show the common prejudices or expectations that researchers already held before they started their study.
  - Note: explains. Faithful reading of Ioannidis: claimed findings may just reflect prevailing bias.
- **Qwen 3.5 4B, new prompts** (overlap 0.00, 36 words, 22.6 s): The study says some results just show what people want to see instead of real facts. It's like a mirror that only shows the strongest colors, so the picture looks more extreme than it really is.
  - Note: explains. Results can reflect what people expect rather than real effects.
- **Qwen 3.5 9B, new prompts** (overlap 0.00, 31 words, 35.7 s): Sometimes what scientists think they found isn't a real effect but just shows how their field is tilted. They chase big numbers, so their results reflect that push rather than truth.
  - Note: explains. Results can reflect a field tilt rather than truth.
- **Qwen 3.5 4B, previous pass (run 44067176475)** (overlap 0.00, 30 words, 48.7 s): That means what scientists say is true might just match how they already want things to be. It's like a mirror showing only what we expect, not what actually exists.
  - Note: explains. Clear analogy for prevailing bias.
- **Qwen 3.5 9B, previous pass (run 44067176475)** (overlap 0.06, 33 words, 92.6 s): Sometimes a result isn't new science but just reflects how researchers were biased toward finding something. It's like always looking for a pattern where none exists, and the data just shows that habit.
  - Note: explains. Correct reading of bias vs a genuine finding.

## Podcast (21 lines, abstract only)

Paper: Estimating the reproducibility of psychological science (https://pubmed.ncbi.nlm.nih.gov/26315443/)

### Qwen 3.5 4B, new prompts

Title: Why Psychology Replications Fail  
21 lines, 368 words, 0 repeated lines, 183 s to write (1352 prompt tokens, 8.33 tokens/s)

1. Juniper: So does psychology actually prove what it says it proves?
2. Rowan: That's the big worry in Estimating the reproducibility of psychological Science. The authors worried that many findings might not hold up when tested again.
3. Juniper: Half the magnitude? What does that even mean?
4. Rowan: Think of it like measuring a force. If the original study said the push was five units, and the new one says only two and a half, the effect is much weaker than advertised.
5. Juniper: And how many studies did they actually check to know this?
6. Rowan: They looked at one hundred experimental and correlational studies from three top psychology journals. They made sure to use fresh materials whenever possible.
7. Juniper: Did they just copy the old test exactly or make new versions?
8. Rowan: They used high-powered designs meaning large sample sizes, and they grabbed original materials when those were available to keep things as true as possible.
9. Juniper: So ninety-seven percent of the originals worked. What about their new ones?
10. Rowan: Only thirty-six percent of those replications showed statistically significant results. That is a huge drop compared to the original findings.
11. Juniper: Why did so many original studies get such good results in the first place?
12. Rowan: Ninety-seven percent of those original studies had statistically significant results, which suggests some papers might have been lucky or had hidden bias.
13. Juniper: What about the numbers on the charts in the new study?
14. Rowan: Forty-seven percent of the original effect sizes fell inside the ninety-five percent confidence interval of the replication result. That means most effects were weaker than claimed.
15. Juniper: And what did people who looked at these results say?
16. Rowan: Thirty-nine percent of effects were subjectively rated by experts to have successfully replicated the original finding. That rating was lower than the raw numbers suggest.
17. Juniper: So if we mix both sets of data together, does it help?
18. Rowan: If we assume no bias in the original results and combine them, only sixty-eight percent would still have statistically significant effects overall.
19. Juniper: So the team quality didn't matter much? What did actually predict success?
20. Rowan: Correlational tests showed replication success was better predicted by how strong the original evidence was than by who ran the study.
21. Juniper: So until more data comes in, we probably can't trust most psychology findings right now.

### Qwen 3.5 9B, new prompts

Title: Can Psychology Studies Be Trusted  
21 lines, 347 words, 0 repeated lines, 346 s to write (1352 prompt tokens, 4.87 tokens/s)

1. Juniper: Okay, so how much can we really trust what psychology studies claim to prove?
2. Rowan: That is the core question in Estimating the reproducibility of psychologicalscience. The team wanted to check if results hold up when others repeat the exact work.
3. Juniper: So they just asked people to redo old experiments and see what happens?
4. Rowan: Not quite. They actually ran one hundred replications using high powered designs and original materials whenever possible.
5. Juniper: High powered? Does that mean they had lots of participants to find tiny effects?
6. Rowan: Exactly right. High powered designs give a better chance to detect the real effect size without noise.
7. Juniper: Okay, and what did they find when they compared the new results to the old ones?
8. Rowan: They found replication effects were only half the magnitude of original findings. That is a substantial drop.
9. Juniper: Half? So if the first study said an effect was strong, the second one says it is weak?
10. Rowan: Yes. Ninety seven percent of original studies showed significant results but only thirty six percent did so in replications.
11. Juniper: That sounds like a lot of original findings were probably just lucky guesses.
12. Rowan: It is possible. Only forty seven percent of original effect sizes fell inside the ninety five percent confidence interval of replication results.
13. Juniper: And did any experts just look at the numbers and say they match up?
14. Rowan: Some did. Thirty nine percent of effects were subjectively rated as replicating the original result by the judges.
15. Juniper: So even with all this failure, is there any good news in the whole report?
16. Rowan: Yes. If we assume no bias and combine original plus replication results, sixty eight percent still have statistically significant effects.
17. Juniper: Okay, but what else explains why some studies work and others do not?
18. Rowan: Correlational tests suggest replication success depended more on the strength of original evidence rather than team characteristics.
19. Juniper: So strong evidence in the first place matters most for getting a true replication.
20. Rowan: Right. Strong original evidence predicts better outcomes than who runs the study or where it is published.
21. Juniper: Thanks Rowan, I think I understand why psychology needs more rigorous checks now.

### Qwen 3.5 4B, previous pass (run 44067176475)

Title: Why Psychology Replications Fail  
21 lines, 320 words, 0 repeated lines, 143 s to write (1352 prompt tokens, 9.88 tokens/s)

1. Juniper: So does psychology actually prove what it says about human minds?
2. Rowan: That is the main worry in Estimating the reproducibility of psychological study. The authors wanted to see if new experiments match old ones.
3. Juniper: And they didn't just guess, they actually copied studies right?
4. Rowan: Exactly. They took one hundred existing studies from three psychology journals and ran their own versions.
5. Juniper: Did they use the same people or different ones to test if it holds up?
6. Rowan: They used original materials where available but with high powered designs to get clearer answers.
7. Juniper: So if the results changed a lot, that means science is shaky?
8. Rowan: Not shaky necessarily but the numbers are very different. Replication effects were exactly half the magnitude of the originals.
9. Juniper: Half? Like if they found something big before now it's tiny?
10. Rowan: Yes, and ninety seven percent of the original studies had significant results but only thirty six percent did in the new ones.
11. Juniper: So most of what was thought true turned out to be wrong?
12. Rowan: Mostly yes. If you combine both sets of results without bias only sixty eight percent still show significant effects.
13. Juniper: Is there any reason why the new teams failed to get these same numbers?
14. Rowan: Statistical tests suggest success depended more on how strong the original evidence was than who ran the study.
15. Juniper: So weak studies are just harder to repeat no matter how hard they try?
16. Rowan: That seems likely. The paper notes forty seven percent of original effect sizes fell in the ninety five confidence interval.
17. Juniper: Which means half the results could have been just luck originally?
18. Rowan: Yes, and thirty nine percent were subjectively rated as having replicated but most did not match well.
19. Juniper: So what should scientists do to fix this mess?
20. Rowan: Use stronger evidence from the start and be more careful about which studies they choose to repeat.
21. Juniper: Okay so we need to trust less and check harder before believing what we read?

Note: A usable 21-line episode with no repeated lines and the important numbers right (100 studies, half-size effects, 97% vs 36%, 68% combined, 47% in the 95% CI, 39% subjective). A couple of hedges are slightly overstated, and the paper title is slightly off.

### Qwen 3.5 9B, previous pass (run 44067176475)

Title: Can Psychology Studies Be Trusted  
21 lines, 440 words, 0 repeated lines, 270 s to write (1352 prompt tokens, 5.53 tokens/s)

1. Juniper: Okay, so why do we keep hearing about how hard it is to repeat psychological experiments?
2. Rowan: That's exactly what this paper from 2015 asks. The Open Science Collaboration wanted to check if results hold up when you try them again with better tools.
3. Juniper: So they didn't just repeat the same old tests? That sounds important for understanding real science.
4. Rowan: Right. They picked one hundred studies from three major psychology journals and used strong designs plus original materials whenever they could find them to make a fair comparison.
5. Juniper: Half the size of the first results? That seems like a big drop for people who trust these findings.
6. Rowan: Exactly. The original papers showed clear patterns in ninety-seven percent of cases, but only thirty-six percent of the new replications managed to show a statistically significant result.
7. Juniper: Wait, if most of the first ones were significant, does that mean scientists missed something important or just got lucky?
8. Rowan: Good guess. When they combined both sets of numbers without assuming any bias in the original work, sixty-eight percent ended up being statistically significant.
9. Juniper: So putting them together helped a bit, but not enough to make me feel totally confident in all those old claims.
10. Rowan: That's fair. They also found that nearly half the original effect sizes fell inside the ninety-five percent confidence interval of the replication numbers.
11. Juniper: Okay, so most of the effects were close enough to count as a match in their own way.
12. Rowan: Mostly. But only thirty-nine percent were rated by experts as having truly replicated the original result in their subjective judgment.
13. Juniper: I guess even with good numbers, people still disagree on what counts as a real success or failure.
14. Rowan: Yes. The team looked at whether the strength of the original evidence predicted if the replication would work better than team traits.
15. Juniper: So it wasn't about who did the study or where they worked, but how strong the first proof was?
16. Rowan: Precisely. Stronger original evidence made replication success more likely than characteristics of either the original team or the new replication team.
17. Juniper: That makes sense to me. If the first study had shaky proof, repeating it probably won't fix that on its own.
18. Rowan: Exactly. We only have this short summary of the paper, but it shows replication success depends heavily on how solid the original data was to begin with.
19. Juniper: So maybe future studies need stronger starting points before we expect others to repeat them successfully?
20. Rowan: That is the main takeaway. Better evidence upfront leads to better replication outcomes than just changing who runs the experiment.
21. Juniper: Got it. Strong foundations are needed for science to stand up when others try to check them.

Note: Best of the three local scripts: 21 lines, no repeats, and the key numbers (100 studies, 97% vs 36%, half-size effects, 68% combined, 39% subjective, evidence strength over team) are right. Juniper's fifth line jumps in with 'Half the size' before Rowan has said it, and one later line treats 47% CI overlap as 'most'.
