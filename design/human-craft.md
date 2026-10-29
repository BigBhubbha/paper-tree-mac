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
