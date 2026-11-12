# Human craft: making Paper Tree feel authored, not generated

Research notes and a working checklist, Oct 29, 2026. Builds on `paper-tree-ext/research.md` (the landing site audit). Written for the Mac app: onboarding, the notch island, the explanation card, Settings, menus, release notes.

## What the research says

**Slop is not "AI was used". Slop is "nobody decided".** The generated look is a finite set of statistical defaults that show up together: indigo-to-violet gradients, Inter on white, a centered hero, three identical rounded cards with thin line icons, one radius and one soft shadow everywhere, and a headline that could sell anything. A study of 202 real top-tier sites (The Tells, IOV Studio Labs) found that no single choice is the tell. Stripe uses purple and Linear uses Inter and both read as designed, because they surround those choices with a real system: a type scale, optical tracking, a radius hierarchy, semantic color. The tell is the *unchosen co-occurrence*. [1][2][3]

**Banning defaults just produces the next default.** Ban Inter and purple and you get Instrument Serif, mono eyebrows, and a dark glow. The way out is not a blacklist, it is a concept you commit to and write down. [prior research.md, 13-15]

**Specific beats pretty.** The fastest de-slop moves, in order of effect (21st.dev, UOVA, anticode): show the real product; write one sentence that could only be about you; a palette that starts from one color with a reason; a typeface nobody else in your space uses, paired with something plain; break the symmetry once; put a person in it. "One detail only this subject has. Build the page around it." [4][5][6]

**Controls should change something you can inspect.** A Billie M teardown of AI-built sites kept the controls that changed the drawing (a desk's width changes the desk) and cut a working bicycle-cog animation because it gave the visitor no reason to operate it. Motion and widgets earn their place by explaining. [7]

**Craft is iteration you can't see.** Things (Cultured Code): "When you open a to-do, it smoothly transforms into a clear white piece of paper." Their designer keeps a folder of at least 50 mockups behind almost every simple feature, and they built their own animation toolkit because Core Animation lacked the curves and springs they wanted, tuning expansion, shadow, and timing separately. Their test for an animation: use it constantly during development, and if you get tired of it, it goes. [8][9][10]

**Personality lives in small true things.** Rogue Amoeba's Audio Hijack 4 icon hides two Easter eggs: the waveform is a recording of the designer saying "Hijack", and the mic reads RA 2002, the year the company was founded. Its wires morph from arrows (direction of audio) into bouncing pills (level) when you press Run. Piezo's icon only worked once they went back to the reference photos and noticed real recorders have a handle. Panic's Coda icon was a leaf because the app helped you grow a site from a seedling. [11][12][13]

**Restraint as a voice.** Teenage Engineering reads as one author because the rules are few and strict: lowercase voice, tiny technical labels printed like silk-screen ("OUTPUT", "MIDI"), color rationed to a few coded blocks, separation by rules instead of shadows, and one moment of play (the fat rounded display face) used sparingly. The labels *are* the texture. [14][15][16]

**Forms can be objects.** The strongest questionnaires treat each question as a crafted thing (hand-drawn fields, one question at a time, varied input types instead of a wall of identical dropdowns) and pay the answers back immediately with visible personalization. [17][18]

## What that means for Paper Tree

Our committed concept is already approved: **a field journal from a lab bench.** Specimen sheets, catalog numbers (PT-0001), tape, pencil, a red-pen margin note, a green ink stamp, IM Fell for display, Newsreader for reading, Hanken for UI, Kalam for the hand, Special Elite for typed labels. The flask is the one character. The rest of this doc is about applying that concept everywhere instead of falling back to defaults wherever we got tired.

### The checklist

Use this on every new surface. If a line fails, fix it or write down why.

**Concept**
- [ ] Is this surface a recognizable object from the bench (a tag, a slip, a plate, a stamp, a notebook entry)? If it is "a panel with controls", rethink it.
- [ ] Is there one detail only Paper Tree would have here (a catalog number, a figure caption, a scale bar, the flask)?
- [ ] Remove one accessory before shipping. Tape on everything stops meaning tape.

**Type**
- [ ] Every face has a job: Fell = titles and figure captions; Newsreader = anything you read; Hanken = controls; Kalam = the flask's own voice and margin notes, never body copy; Special Elite = catalog labels only.
- [ ] No more than three faces visible at once.
- [ ] Hierarchy by size and placement before bold. No all-caps eyebrow above every heading.

**Color**
- [ ] Color means something: green = done / approved / on, red pen = a note or a problem, marker yellow = what you highlighted. Nothing gets a color for decoration.
- [ ] No gradients, glows, or glass. The island is the one black object and it is black because the notch is black.

**Shape and surface**
- [ ] Radii follow the object: paper slips 2-4 pt, the floating card 12 pt (it is a modern window on top of your reading), chips 4 pt, the island continuous with the notch.
- [ ] Shadows only where a thing physically sits on another thing (a taped sheet, a floating card). One shadow recipe per object type.

**Motion**
- [ ] Every animation explains a state change: the island grows out of the notch because it lives there; a stamp lands when something is approved; the pencil writes while we wait.
- [ ] Springs tuned by hand per object (the island is softer than a button). Use it 50 times; if it gets annoying, cut it.

**Copy**
- [ ] Specific nouns. "Highlight a line in Preview" beats "select content in any app".
- [ ] The flask speaks in first person, short sentences, a little dry. The app chrome speaks plainly.
- [ ] No em dashes. No "seamless", "effortless", "unlock", "supercharge", "the future of". No triples for rhythm.
- [ ] No fake stats, testimonials, or claims we cannot back. Samples are labeled as samples.

**Interaction**
- [ ] Every control changes something you can see right away (an answer re-tailors the sample line; a stamp lands; the island opens).
- [ ] Every step can be skipped and redone later.
- [ ] Nothing clips. Text is measured, not guessed.

## Audit of the app (0.2.3 branch)

| Surface | Felt generic because | Change |
|---|---|---|
| Welcome window (single page) | Good object (specimen sheet) but it is the only moment of craft, and it asks for a permission before saying who it is for | Replaced by a 5-entry setup notebook: two specimen-tag pages of questions, the Accessibility sheet, a live practice bench, and a closing entry. Each page is a numbered entry in the same journal |
| Questions (new) | Default would be a form of dropdowns | Each question is a manila specimen tag on a string, labeled in typewriter. Answers are handwritten words you circle in pencil (multi-select gets a pen tick). A "field note" line under the tags rewrites itself from your answers so you can see the effect |
| Practice (new) | Default would be a looping video or a 1-2-3 list | A real sample passage (labeled as written for practice) and three tasks that stamp themselves as you actually do them: double-tap opens the real island, triple-tap flips Research mode, highlighting shows a real card |
| Explanation card | Fixed-height box that clipped, plus a big italic title | Rebuilt as the website's card: measured height, short answer, a mini glossary under a hairline rule |
| Settings | Opened on "server address" and "app token" fields, which no reader needs and which said "your own small server" (no longer true) | Leads with "About you" (the same tag answers, editable) and Behavior. Server fields moved under a closed "For developers" disclosure. Accurate copy about what is sent. "Redo setup" added |
| Island | Fine; the user loves it | Copy only: hint line kept lowercase and short |
| Menu bar menu | Plain list, fine for a fallback | Added "Redo setup..." so it is findable |
| Release notes | Already plain and specific | Keep the voice: what changed, where to find it, no hype |
| DMG | Plain Finder window with a text file. No background image | Left as is for now; a drawn DMG background is a separate task |

## Second pass: Settings, and what reads as generated (Oct 29, 2026, afternoon)

Prompted by a screenshot of 0.2.2 Settings: a title, a rule, then three stacked sections of label, sentence, control. Correct, and exactly what a generator would make.

### What makes a screen read as AI-made

- **Every section has the same anatomy.** Heading, grey sentence, row of controls, repeat. Sites built by generators fall back on the same identical-card rhythm: same padding, same radius, same weight, so the eye learns the cards are interchangeable and skips them. The fix that keeps coming up is to change the layout from one section to the next and give one element clear dominance. [19][20][21]
- **Containers for everything.** Cards for stats, cards for settings, cards inside cards, all with the same big radius. Hierarchy can come from spacing, type, rules and placement instead; remove a container and see if anyone misses it. [21]
- **The obvious composition for the category.** A settings page that looks like every settings page: toggles on the right, labels on the left, perfect symmetry. The structure came from the category, not from this product. [21]
- **Uniform controls.** Five identical iOS-style switches say "a form". The Mac's own Settings app gets criticized for swapping checkboxes for toggles everywhere and grouping things by no clear idea. [22]
- **Stock type pairing with no jobs.** A display serif for headings and a sans for everything else, used the same way on every surface. Our 0.2.2 Settings did this: Fell for "Settings" and "Behavior", Hanken for the rest.
- **Filler copy.** Sentences that could describe any app ("Start when you log in"). Generic copy is one of the most cited tells. [19][20]

### What signals a person made it

- **Objects with a past.** Herbarium labels have a fixed anatomy that has barely changed in 200 years: a constant printed heading, typed field names, the collector's hand filling the blanks, a collector number, and later corrections added as separate small "det." slips, never written over the original. The label sits lower right, glued along one edge. Writing tools went from quill to nib to pencil to typewriter, and you can see the person in a rushed hand. These are real conventions we can borrow instead of inventing decoration. [23][24][25][26]
- **Weight and touch, used where they explain.** The new physicality in apps (Monologue's buttons studied from a light switch's shadow, Teenage Engineering's labels) works when the texture tells you something, like "this can be pressed", and fails as a texture pack. Keep one light direction and let color mean something. [27][28]
- **Considered hierarchy.** One dominant thing per screen, asymmetric columns (a 5:3 split instead of thirds), and type sizes that differ on purpose. [19]
- **Imperfect marks, rationed.** Hand-drawn, slightly irregular marks read as human (Inkdrop's raw, imperfect textures), but only if a few things get them. [29]
- **Personality in the copy, and in small true details.** Rogue Amoeba keeps posts about every design decision and moves crowded settings into their own window instead of cramming a tab. Nova is praised for "restraint" and for details that reward attention instead of demanding it. [30][31]
- **Ephemera with a ritual.** Postcard and stamp apps (Lost Post, Postpond) borrow the slowness and small ceremony of paper. A stamp landing when you approve something is a ritual, not an ornament. [32][33]

### Applied to Settings (0.2.3 branch)

Settings stops being a form and becomes **Plate II, the instrument drawer**, a sheet taped to the desk like the setup notebook:

| Was | Now | Why |
|---|---|---|
| "Settings" in Fell, a rule, a typewriter label far right | "Plate II. Instruments" in typewriter (red catalog number), the title "The instrument drawer", one plain sentence, a printer's double rule | A plate in the same journal as setup, not a generic page head |
| About you as rows of label plus menu | A printed herbarium label: centered heading "Paper Tree Herbarium", typed field names, answers handwritten in blue-black ink on dotted lines, "det. you" in the corner, "walk through setup again" | Real label anatomy; the answers look written by the reader |
| Nothing alive on the page | A taped slip with the real number of cards this Mac has opened (`specimenCount`, practice included, and it says so). Zero shows "None yet" | A live corner with true data only. There is no growth tree yet, so none is drawn |
| Three identical toggles | Three hanging specimen tags, each a slightly different width, tilt and indent, answered by circling "on" or "off" in pencil (green for on, red for off) | Controls become the same object the setup questions use; no uniform switch column |
| "Shortcut." sentence | Fig. 1: the right end of a Mac keyboard drawn in ink, the right Option key marked with highlighter, red pen notes for two and three taps. Clicking the key plays a double tap | Teach by drawing; the one interactive detail explains the real gesture |
| Permission dot | The green APPROVED stamp from setup when granted; a red pen note and "Let Paper Tree in" when not | Reuses the setup ritual |
| Server address and token as a section | "For tinkerers", a closed disclosure under the colophon | No reader needs it |
| Big "Check for Updates" stamp button | Colophon line: "Paper Tree 0.2.2, build N" and an underlined "Check for updates" | Quiet; this is a footnote |

Rules applied to the other screens: color only means something (green on, red off or problem, yellow what you highlighted); one hand-drawn accent per object; varied section anatomy. The island is unchanged on purpose. The card already follows the website card.

## Sources

1. The Tells, IOV Studio Labs (PDF): https://labs.iovstudio.kr/papers/ai-design-tells.pdf
2. Why AI Design Looks Generic, Superdesign: https://superdesign.dev/blog/why-ai-design-looks-generic
3. AI Slop Fonts and Gradients, 925 Studios: https://www.925studios.co/blog/ai-slop-design-tells
4. How to Make a Site Not Look AI Generated, 21st.dev: https://21st.dev/blog/website-not-look-ai-generated
5. How to Build a Website That Doesn't Look AI-Built, UOVA: https://www.uova.com/blog/sites-that-dont-look-ai-built
6. Make an AI-generated website look professionally designed, anticode: https://anticode.dev/guides/make-ai-website-look-professional
7. How to Make an AI Website Feel Like Someone Designed It, Billie M: https://dev.to/billiem/how-to-make-an-ai-website-feel-like-someone-designed-it-1kfl
8. Things features, Cultured Code: https://culturedcode.com/things/features/
9. Werner Jainek interview (Lars Bobach podcast 096): https://larsbobach.de/mit-things-fokussierter-arbeiten-interview-mit-werner-jainek-podcast-096/
10. sspai interview with Cultured Code: https://sspai.com/post/39724 ; 20 Years of Things episode notes: https://share.snipd.com/episode/e922cc6c-9e7f-4f8b-84df-d4dd7b145338
11. The Design of Audio Hijack 4, Rogue Amoeba: https://weblog.rogueamoeba.com/2022/09/09/the-design-of-audio-hijack-4/
12. The Evolution of Piezo, Rogue Amoeba: https://weblog.rogueamoeba.com/2012/02/15/the-evolution-of-piezo/
13. Coda icon, Iconfactory: https://files.iconfactory.net/archive/if6/design/detail/coda.html
14. Teenage Engineering design spec, tastekit: https://tastekit.dev/apps/teenage-engineering/marketing/DESIGN.md
15. Teenage Engineering: Constraints as Aesthetic: https://blakecrosley.com/guides/design/teenage-engineering
16. Teenage Engineering, Palate reference: https://palatemcp.com/gallery/teenage-engineering
17. FormQue: https://www.formque.online/
18. Personalization Form pattern: https://ui-patterns.com/patterns/PersonalizationForm
19. 10 Signs a Website Was Generated by AI, Sailop: https://sailop.com/blog/10-dead-giveaways-website-generated-by-ai
20. AI slop: 8 signs a website was generated by AI, Tenex: https://tenex.studio/en/blog/ai-slop-ui-8-signes/
21. Why Every AI-Generated UI Looks the Same (video): https://www.youtube.com/watch?v=XKDfs9xTzfw
22. What Makes an App Feel "Right" on the Mac?, Coyote Tracks: https://coyotetracks.org/blog/app-feel-on-mac/
23. Labels, University of Arizona Herbarium: https://herbarium.arizona.edu/labels
24. Annotation of Herbarium Specimens, Florida Museum (FLAS): https://www.floridamuseum.ufl.edu/herbarium/methods/annotations/
25. Make Your Own Herbarium Specimens, University of Melbourne (MELU): https://plantdorks.com/wp-content/uploads/2024/04/MELU_MakeYourOwnHerb_Specimen_Dec18.pdf
26. Analysis of museum labels description: https://bibliotekanauki.pl/articles/2171587.pdf ; Deciphering Handwriting on Botanic Labels, Nature Museum: https://naturemuseum.org/cas/blog/deciphering-handwriting-on-botanic-labels
27. How to Design Software With Weight, Roger Wong: https://rogerwong.me/2026/03/how-to-design-software-with-weight
28. Skeuomorphic UI in 2026, Tactile UI: https://tactileui.dev/blog/skeuomorphic-ui-in-2026
29. Inkdrop case study, Doan Nguyen: https://doannguyenn.myportfolio.com/inkdrop
30. SoundSource 6 Design Stories, Rogue Amoeba: https://weblog.rogueamoeba.com/2026/05/07/soundsource-6-design-stories/
31. Nova: An Editor with a Soul, Nathan A. King: https://www.nateking.dev/blog/nova-an-editor-with-a-soul
32. Lost Post, Daydrift: https://daydrift.design/work/lostpost/
33. Postpond, Lilith Yu: https://lilithyu.com/projects/postpond

## Motion and painted trees (beauty-v1, October 2026)

What we read, and what we took from each source.

### Apple: springs, continuity, Reduce Motion
- WWDC23 "Animate with springs": springs are the only kind of animation that stays continuous when it is interrupted or retargeted, because they carry their speed into the new target. Tune them with two numbers, a perceptual duration and a bounce. Bounce 0 is smooth, about 0.15 is a hint of give, and about 0.3 is clearly bouncy; avoid going above about 0.4. Duration is how fast it feels, not when it settles.
- Use one family of springs across the app so everything moves alike. Ours is in `Motion.swift`: open (response 0.5, damping 0.76, a little give), close (0.34, 0.94, no bounce, since things tucking away should not wobble), snappy (0.26, 0.82) for presses and toggles, page (0.46, 0.88) for page turns, and land (0.4, 0.62) for stamps.
- Continuity between states: content should not reflow while its container animates. The island now lays its content out once at the open size and lets the growing pill reveal it (clipped), so the grove fades up through a short blur instead of squeezing. A tree's own page zooms out of its sheet in the grove.
- matchedGeometryEffect would also tie a sheet to its page, but our trees are grown for the size they are drawn at, so resizing every frame would regrow them. We use a zoom-and-fade instead and keep the drawing at one size.
- Reduce Motion (`accessibilityDisplayShouldReduceMotion`, and `accessibilityReduceMotion` in SwiftUI): Apple recommends a crossfade in place of slides and zooms, not removing the change. With it on, every transition becomes a short fade, trees stand still (no wind, no growth), pencil branches appear already drawn, and the card shows its text at once.

### Lauren Hom
- She sketches loose in pencil on paper first, because an iPad makes it too easy to undo and tighten up too soon, then inks and finishes digitally, painting each shadow by hand layer by layer.
- She works in playful, saturated palettes with dimension and texture. One botanical piece uses dusty rose, sage, deep green-grey and a warm coral (#E86F67), with neutrals between.
- Taken: draw the pencil branch first and ink over it, keep a hand-wobble in every line, and use coral and dusty rose against greens instead of an all-green grove.

### Studio Ghibli botanicals (Kazuo Oga)
- Oga wets the paper, drops in broad soft color while it is wet, and puts the large soft passages in first and the details last.
- Ghibli trees use a small number of tightly controlled shapes, not thousands of leaves. Start with two masses, one of light and one of shadow. Split each into medium shapes, then add a few small ones, so the sizes run big, medium, small. Vary the edges, some crisp and some lost.
- Taken: every leaf mass is painted as a shadow wash (offset down and right), then a body wash, then a smaller lit wash toward the upper left, then a few crisp leaf dabs on the lit rim and in the shadow. Clumps group the crown into a handful of masses instead of one blob per twig.

### Vintage botanical plates (Curtis's Botanical Magazine and others)
- One specimen per plate, drawn accurately, often turned or cropped to fit the page, with generous bare paper around it.
- Engraved line work carries the drawing, and transparent watercolor is laid over it by hand, sometimes on only some leaves or flowers.
- Plates carry a plate number, the artist ("del.") and the engraver ("sculp."), with the plant's name below the image.
- Taken: ink only the outside edge of the wood and a few edge accents on the foliage, so the color stays transparent wash. Light comes from the upper left, and the herbarium label and sheet number stay as they are.

### Generative trees that look good
- Space colonization (Runions, Lane and Prusinkiewicz, 2007):
  - Scatter attraction points in a crown envelope. Each point pulls the nearest branch node within an influence radius, and each pulled node grows one step toward the average of its pulls. A point is used up once any node comes within the kill distance.
  - A dense crown with a short kill distance looks busy. Fewer points, or a longer kill distance, gives smoother limbs.
  - Afterward, move each node partway toward its parent. This softens the branching angles, which changes the look a lot.
  - Our setup: the paper branches are the scaffold, and the crown fills in from an envelope over all the paper tips plus a cloud around each tip. Coral uses a fan-shaped envelope, alien trees curl each step slightly, and willows are biased downward.
- Pipe model: a limb carries the cross-section of what it feeds, r^n = r1^n + r2^n, with n between 2 and 3. Lower n gives more contrast between trunk and twigs. We use n = 2 and map the result so the thinnest twig and the trunk land on fixed widths.
- Filled tapered limbs, not strokes:
  - Each chain follows its thickest child, and every other child starts its own chain, which avoids blobs at the joints.
  - Each chain is a ribbon around a smoothed center line.
  - All outlines are inked first and all fills go on top, so only the silhouette of the whole tree is inked.
  - A narrower, lighter ribbon nudged toward the light makes the wood read as round.
  - Wavy bark ridges follow the grain on thick wood.
- Watercolor (Tyler Hobbs):
  - Deform a polygon recursively: split each edge and push the midpoint by a Gaussian scaled to the edge length.
  - Use a few rounds for a shared base shape, then a few more rounds per layer.
  - Stack many nearly clear layers, so edges bloom softly while the overall shape holds.
  - We use 4 to 5 layers per mass (the app redraws every frame), edge darkening on one layer, and paper grain multiplied into the wash so it granulates.
- Growth over time:
  - The new paper's branch extends node by node along its length.
  - Then its crown twigs appear in the order they grew in the colonization.
  - Then its leaves unfurl on a damped spring (scale, plus a small turn).
  - Then its front page drops onto the tip with a little overshoot.
  - Last, the pencil branches draw themselves on, with the softer passes trailing behind like a second pass of the pencil.
- Wind: each node turns slightly around its parent, by an amount set by how thin it is (thin twigs flex and the trunk does not), with two slow sine waves at different speeds so it never loops visibly. The turns add up toward the tips.

### Not done, and why
- Painted texture assets: the plan was to commission hand-drawn SVG leaf, needle and blossom sets from QuiverAI. Its models were locked for this account and requests came back unauthorized, so every motif is still drawn in code. The shapes (almond leaves, trap lobes with cilia, needle chevrons, polyps) are procedural, and the noise grain is generated at launch.
- Metal shaders: not needed. Core Graphics through SwiftUI Canvas handles the washes at 30 frames a second on a tree page. Sheets in the grove redraw at 12 frames a second to save power.

### Sources for the motion and tree section
34. Animate with springs, WWDC23: https://developer.apple.com/videos/play/wwdc2023/10158/
35. Explore SwiftUI animation, WWDC23: https://developer.apple.com/videos/play/wwdc2023/10156/
36. Human Interface Guidelines, Motion: https://developer.apple.com/design/human-interface-guidelines/motion
37. Lauren Hom, process interviews and Daily Dishonesty: https://homsweethom.com/
38. Kazuo Oga background painting, Ghibli Museum exhibition notes and Oga Kazuo Art Collection
39. Curtis's Botanical Magazine, Biodiversity Heritage Library: https://www.biodiversitylibrary.org/bibliography/706
40. Runions, Lane, Prusinkiewicz, Modeling Trees with a Space Colonization Algorithm (2007): http://algorithmicbotany.org/papers/colonization.egwnp2007.pdf
41. Tyler Hobbs, A Guide to Simulating Watercolor Paint with Generative Art: https://www.tylerxhobbs.com/words/a-guide-to-simulating-watercolor-paint-with-generative-art
42. Shinozaki et al., the pipe model theory of plant form (1964), and Leonardo's rule on branch area

## Podcast (podcast-v1, November 2026)

What it is: the reader's Listen tab turns the open paper into a short talk between two AI hosts, Juniper (asks) and Rowan (explains), and plays it under the page.

- The object: a recording session in the field journal. The invitation hangs two manila host tags; recording is a numbered protocol (read, write, record, bind) with pen ticks, and the tape fills with the real loudness of each part as it arrives. The flask keeps you company in its own voice.
- The deck is a slip taped to the desk: an ink stamp to play, the waveform drawn as pencil strokes and inked up to a red pen playhead, a ribbon underneath in each host's ink showing who talks when, and speeds typed in a column with the chosen one circled in pencil (the same gesture as the setup questions).
- The transcript highlights the spoken line with a sweep of marker, and the matching passage on the page gets the same marker. Tap a line to play from there.
- Honest about what it is: "AI voices", "made by AI from the paper's text", real steps and real elapsed time while it works, and the server blanks any quote it can't find in the paper.
- Colors: Juniper is rose, Rowan is sage (two of the existing inks), marker yellow means "being read now", green means done (the pen ticks, the RECORDED stamp).

## Setup questions in long form (0.2.8)

- The four "about you" questions no longer offer fixed options. Each page asks for a sentence ("Where are you in school?", "Tell me about your science so far.", "What do you like to read?", "How should my notes read?") and gives a strip of ruled field-journal paper on the specimen tag to write on: pale blue rules under each written line, a red margin line ruled slightly by hand, the answer in Kalam in blue-black fountain pen ink, pencil placeholder words in the same hand.
- A quiet Newsreader hint sits under the tag ("a year, a grade, or wherever you are in school. Out of school counts too."). Nothing is required: with the field empty the footer says "Skip for now" instead of Next.
- The flask still acts out each page, and hops when you start writing and at the end of each sentence.
- The finish page's red-pen note quotes the reader's own words back ("noted, in your words:"), trimmed at a word with an ellipsis. The Settings label shows the same words; clicking one opens the same ruled slip.
- Answers from older builds (option ids) are turned into their words once, on first launch, so nobody sees "hs11".
