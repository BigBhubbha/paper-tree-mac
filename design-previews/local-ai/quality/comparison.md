# Local AI quality test (CI run 44067176475)

Answers are real outputs. Times: Gemini through the Worker; local models on a 4 vCPU Linux CI runner, CPU only (a real Mac should be faster).

| Model | Repeats highlight (overlap 0.5 or more) | Avg seconds |
|---|---|---|
| Gemini | 1 of 16 | 1.8 |
| 2B | 0 of 16 | 15.1 |
| 4B | 0 of 16 | 52.5 |
| 9B | 0 of 16 | 99.0 |

## r00

Highlight: "Rubisco also reacts with oxygen, and that side reaction becomes more common as carbon dioxide inside the leaf drops."

- **Gemini:** Rubisco sometimes accidentally reacts with oxygen instead of carbon dioxide. This wasteful side reaction increases when carbon dioxide levels inside the leaf go down.
- **2B:** This enzyme steals energy to make sugar. But if it meets oxygen instead, it makes acid instead of sugar, wasting the plant's effort. Oxygen wins when there's little CO2, so plants with a different pathway avoid this problem.
- **4B:** Rubisco mistakes oxygen for carbon dioxide. When CO2 gets low, this mistake happens more often, wasting energy fixing the wrong carbon.
- **9B:** When CO2 gets low, Rubisco grabs oxygen by mistake instead. That wrong reaction wastes energy because the plant has to fix the damage, so it's like a costly error in the factory.

## h01

Highlight: "dispensing with recurrence and convolutions entirely"

- **Gemini:** The authors are creating a new model that completely removes the need for traditional recurrent or convolutional neural network structures.
- **2B:** They use only attention, skipping back-and-forth loops and special math tricks that used to be needed. That means they can work in parallel, so the whole team trains faster.
- **4B:** Older models used slow step-by-step memory or scanning filters, but this new design skips both. It just looks at every word at once to decide which parts matter most.
- **9B:** They throw away the old way of processing words one at a time or sliding a window. Instead, every word talks directly to every other word, which lets them train faster and handle longer sentences.

## h02

Highlight: "a false alarm rate estimated to be less than 1 event per 203 000 years, equivalent to a significance greater than 5.1 σ"

- **Gemini:** This means scientists are extremely certain the signal was real and not random noise. A chance accident like this would only happen once every 203,000 years.
- **2B:** It means the signal was so strong it's almost impossible to be a mistake. If you had to wait that long to find one fake signal, it's so rare it's effectively proof.
- **4B:** This signal was so strong it would have taken over half a million years to happen by pure chance. It's a discovery-level finding, not a fluke or a glitch.
- **9B:** That means the signal is so rare that you'd expect to see it by chance less than once every two hundred thousand years. It's like winning a lottery twice in a row with odds worse than one in a billion.

## h03

Highlight: "5.9 standard deviations"

- **Gemini:** This is a statistical measurement showing that the discovery is extremely unlikely to be a random error. It confirms that the particle detected is almost certainly real and not just a fluke.
- **2B:** It's a very strong signal. In statistics, it means the result is so unlikely to be random noise that you can be 99.9% sure it's real.
- **4B:** It's like rolling a die and finding that result five times in a row by pure chance. That probability is so tiny, it proves the signal isn't just random noise.
- **9B:** That's a very strong signal. In physics, five standard deviations means there's less than one chance in a billion that it's just random noise, so the result is considered a discovery.

## h04

Highlight: "We explicitly reformulate the layers as learning residual functions with reference to the layer inputs, instead of learning unreferenced functions."

- **Gemini:** The authors are changing how neural network layers process information. Instead of asking each layer to learn a completely new output from scratch, they design the layers to learn the difference, or residual, between the input and the desired output. This approach makes it much easier for the network to train because the layers only need to focus on small adjustments rather than mapping everything from the beginning.
- **2B:** Instead of trying to learn a new pattern from scratch every time, these networks use an old shortcut and add only the difference between the old shortcut and the new one. This way, the network can get much deeper without breaking down, which is why it's so strong at spotting objects.
- **4B:** Normal layers try to learn a brand new function from scratch, which gets harder as you add more. These layers instead teach how to adjust what came in, subtracting that input and learning just the difference. This shortcut keeps the signal flowing through hundreds of layers without dying out.
- **9B:** Instead of trying to learn the whole output from scratch, each layer only learns the small change needed to get from its input to the next step. This makes it much easier for the network to train very deep, because it avoids the problem where deeper layers cancel out what earlier ones learned.

## h05

Highlight: "ballistic transport at submicron distances even at room temperature"

- **Gemini:** This describes how electrons move through a material without hitting obstacles or losing energy. It happens over very short distances even when the material is not cooled down.
- **2B:** It's like a super-fast highway where electrons zip around without bouncing off walls. They stay fast even if the road is just a tiny bit smaller than a hair, and they keep going hot.
- **4B:** Electrons move without bumping into anything, like a laser beam in a straight line. This happens only when the path is tiny and the material is perfect, which graphene does even when it's warm.
- **9B:** Electrons zip across without bumping into atoms. This happens only in tiny chips and usually needs near-zero heat, but they did it here in a normal room.

## h06

Highlight: "Hubble constant"

- **Gemini:** The Hubble constant is a number that describes how fast the universe is expanding. It measures the rate at which galaxies move away from each other over time.
- **2B:** That's how fast the universe expanded right now. It tells us how old the universe is and how much stuff there is, but it's a bit tricky because it's not the same number you'd see in a simple textbook calculation.
- **4B:** It's how fast the universe is expanding right now. This number tells you the speed of space itself, not how fast galaxies move through it.
- **9B:** That's how fast the universe expands right now. The numbers show it's about 67 km/s per megaparsec, which matches other ways to measure cosmic expansion.

## h07

Highlight: "BNT162b2 was 95% effective in preventing Covid-19 (95% credible interval, 90.3 to 97.6)"

- **Gemini:** The vaccine prevented 95 percent of Covid-19 cases in the study. The credible interval shows the range of statistical certainty for how well the vaccine works.
- **2B:** It stopped the virus in 95 out of 100 cases, but not every single person got sick. The real range is between 90 and 98 percent, so it's solidly effective.
- **4B:** Out of the people who got the shot, only one in twenty got sick with Covid-19, while a lot more in the placebo group did. The range from 90.3 to 97.6 shows how sure we are that this number is close to the true protection level.
- **9B:** Out of 43,548 people, the vaccine stopped severe illness in about 95 out of every 100 cases compared to placebo. That range means we're very sure the number is between 90 and 98, so it's a strong protection.

## h08

Highlight: "the potential to exploit the system for RNA-programmable genome editing"

- **Gemini:** This refers to using the CRISPR system as a tool to change DNA sequences by using specific RNA molecules to guide where those changes happen.
- **2B:** You can program which genes to cut by changing the RNA instructions, so scientists can use this bacteria tool to make precise edits in human DNA.
- **4B:** This system lets scientists program RNA to cut DNA at any spot, which could be used to fix genes or make new traits in living things.
- **9B:** You can design a custom RNA sequence that finds any specific gene and tells Cas9 to cut it out. That lets scientists rewrite DNA in cells on purpose, just by programming which RNA guide they use.

## h09

Highlight: "even in cases in which no similar structure is known"

- **Gemini:** This means the computer model can accurately predict a protein shape even when it cannot compare that protein to any other previously studied ones.
- **2B:** It's not just about guessing; it works even if you don't have a blueprint for the protein. The new AI uses physics rules to build the shape, so it doesn't need a similar protein to compare against.
- **4B:** Before this method, computers could only guess a shape if they had a close match to copy from. Now it can stand alone and get the right details without needing that template.
- **9B:** Before this, computers could only guess well if a very similar protein had been solved before. This new method works even when nothing close exists, so it can finally predict the shapes of most proteins we've ever seen.

## h10

Highlight: "hazard ratio with intensive treatment, 0.75; 95% confidence interval [CI], 0.64 to 0.89"

- **Gemini:** The hazard ratio shows that intensive treatment reduced the risk of heart events by 25 percent. The confidence interval means researchers are 95 percent sure the true risk reduction is between 11 and 36 percent.
- **2B:** That number means the intensive treatment group had a 25% lower chance of getting a bad heart event than the standard group. The confidence interval shows we're pretty sure this is true, but it's not perfect.
- **4B:** For every person in the low-blood-pressure group, there were about 75% as many heart attacks or strokes as in the normal group. The range from 64% to 89% means we are very sure this difference is real and not a fluke.
- **9B:** A hazard ratio of 0.75 means the intensive group had about a quarter less risk each year than the standard group, and we're pretty sure the real number is between 0.64 and 0.89.

## h11

Highlight: "-14.9% in the semaglutide group as compared with -2.4% with placebo"

- **Gemini:** People taking the medicine lost about fifteen percent of their body weight, like losing fifteen pounds out of one hundred, while the control group lost very little.
- **2B:** Semaglutide made people lose 14.9% of their weight while losing only 2.4% on the other side, which is a huge difference.
- **4B:** People on the new drug lost about 15% of their weight over six months, while those on the sugar pill only lost 2%. That's a big difference.
- **9B:** The drug helped people lose about 15% of their starting weight, while the fake pill group lost only about 2%. That's a big difference.

## h12

Highlight: "a seasonal decline of 76%, and mid-summer decline of 82% in flying insect biomass over the 27 years of study"

- **Gemini:** Over twenty seven years, the total weight of flying insects dropped by over three quarters during the season and by over eighty percent during the middle of summer.
- **2B:** They found that insects are dropping year after year. Specifically, flying insects lost 76% in the fall and 82% in the middle of summer. This drop happened everywhere, not just in some special places.
- **4B:** Flying insects dropped by three-quarters from spring to summer, and by more than four-fifths by mid-summer. That's a massive drop that shows how much life is disappearing.
- **9B:** That's a massive drop. Over three decades, flying insects lost most of their weight in summer and even more during other seasons, meaning fewer food sources for birds and less help for plants.

## h13

Highlight: "Thirty-six percent of replications had statistically significant results"

- **Gemini:** Only about one third of the repeated studies produced the same meaningful evidence as the originals. This shows that many initial findings were likely not as strong as first reported.
- **2B:** About a third of the new studies found something important, while most of the old ones did too. That means many of the old findings were still useful for others to learn from.
- **4B:** Only a little over one-third of the new studies showed real effects. That means most of the original findings didn't hold up when checked again.
- **9B:** That's a big drop from the 97% of original studies that looked significant. It means most experiments didn't find the same strong effect again, so the original findings were often too optimistic or hard to repeat.

## h14

Highlight: "any vertex of a regular grid of equilateral triangles spanning the surface of the environment"

- **Gemini:** This phrase describes the specific locations where a grid cell fires or becomes active. Imagine a map covered in a perfectly repeating pattern of triangles. When an animal stands exactly on one of the points where these triangle corners meet, the brain cell fires. This matters because it shows how the brain creates a precise internal coordinate system, like a GPS grid, to help the animal track its exact location as it moves through space.
- **2B:** A neuron's firing pattern repeats at precise points in a geometric layout, like the corners of a giant, invisible puzzle. This pattern is built from many smaller neurons working together, creating a map of space that helps the animal know where it is without looking around.
- **4B:** Think of a giant invisible checkerboard on the floor of the animal's world. A 'grid cell' lights up only when the animal stands exactly on one of those tiny corners. This creates a map where every spot has its own unique address, letting the brain figure out where it is without needing to see anything.
- **9B:** Imagine the animal moving on a floor drawn with a big pattern of evenly spaced triangles. Every time the animal lands on a corner of any triangle, that cell fires. Neighboring cells share the same grid lines but start firing at different corners, so together they tile the whole space. This map lets the brain track position without landmarks by adding up steps, which is how animals navigate even in the dark.

## h15

Highlight: "claimed research findings may often be simply accurate measures of the prevailing bias"

- **Gemini:** Scientific results might not reflect reality at all. Instead, they often just show the common prejudices or expectations that researchers already held before they started their study.
- **2B:** A study might just show a real effect, but if everyone is trying to find significance, that result is just a trick. The real effect is small and hidden behind the noise of bias.
- **4B:** That means what scientists say is true might just match how they already want things to be. It's like a mirror showing only what we expect, not what actually exists.
- **9B:** Sometimes a result isn't new science but just reflects how researchers were biased toward finding something. It's like always looking for a pattern where none exists, and the data just shows that habit.
