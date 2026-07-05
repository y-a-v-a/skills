---
name: strunk
description: Rewrite prose to conform to William Strunk Jr.'s *The Elements of Style* (1918). Accepts a file path or inline text as argument; prints the rewritten text silently with no commentary. Applies rules from all chapters — punctuation, composition, form, the Chapter V misused-words list, and spelling — at moderate aggressiveness: tighten, activate, cut, fix word misuse, but preserve meaning, paragraph order, and the author's claims. Code blocks, inline code, URLs, and quoted speech are passed through verbatim.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
---

# Strunk's Elements of Style — Rewriter

## Invocation contract
- Argument is either a path to a text file (read with Read) or inline text. Treat the argument as a path if it points to an existing file; otherwise as the source text.
- No argument → ask the user once for input. Empty input → empty output.

## Output contract
- Print **only** the rewritten text. No headings, no preface, no list of rules applied, no diff, no closing summary. First character out is the first character of the rewrite.
- Never write the rewrite to a file unless the user explicitly requests it.
- If after applying rules nothing changes, print the original text back as-is. Do not say so.

## Aggressiveness
Moderate. Do:
- Tighten freely, flip passive→active, cut needless words, fix word misuse, repunctuate.
- Combine clause-chains into denser single sentences when meaning survives.

Do not:
- Add, remove, or reorder facts, claims, examples, citations, footnotes.
- Reorganize paragraphs or change paragraph count.
- Modernize archaic words the author chose deliberately (proper-noun era, dialogue, period writing).
- Invent details to fill out a vague sentence — leave vague-but-correct prose vague.

## Preserve verbatim (do not rewrite inside)
- Fenced code blocks ` ``` … ``` ` and inline code `` ` … ` ``
- URLs, file paths, shell commands, regex
- Quoted speech (`"…"`, `'…'`) and block quotes (`> …`)
- Tables, math, equations, ASCII diagrams
- Proper nouns, named entities, technical terms-of-art

Rewrite freely in: ordinary prose, list-item prose, heading prose (but keep slug-able heading anchors stable when context suggests linking).

## Era caveats
Strunk wrote in 1918. Three of his rules now read as wrong or dated; apply with judgment, not blindly:
- **Singular *they***: Strunk prescribes *he* with distributives (*each*, *everybody*, *anybody*). Modern English accepts singular *they*. Preserve whichever pronoun the author chose; do not impose *he*.
- **shall / will**: the 1st-person *shall* vs *will* distinction is no longer observed. Do not introduce *shall* where the author wrote *will*.
- **to-day / to-night / to-morrow**: hyphenated forms are obsolete. Write *today*, *tonight*, *tomorrow*.

Apply every other rule.

---

## Ch. II — Elementary rules of usage

1. **Possessive singular: add `'s`** regardless of final consonant — *Charles's*, *Burns's*, *witch's*. Exceptions: ancient proper names in *-es*/*-is* (*Achilles' heel* → *the heel of Achilles*), *Jesus'*, *for conscience' sake*, *for righteousness' sake*. Pronominal possessives take no apostrophe: *hers*, *its*, *theirs*, *yours*, *oneself*.
2. **Oxford comma** in series of three or more single-conjunction terms — *red, white, and blue*; *He opened the letter, read it, and made a note of its contents.* Drop only inside firm names (*Brown, Shipley & Co.*).
3. **Parenthetic expressions go between paired commas** — never one. Always parenthetic: year inside a date (*April 6, 1917*), day-of-month after weekday (*Monday, November 11, 1918*), *etc.*, *jr.*, non-restrictive relative clauses (the `which` clause, not the `that` clause). Restrictive clauses take no commas.
4. **Comma before a conjunction (`and, but, or, nor, for, as, while`) joining coordinate clauses** — *The situation is perilous, but there is still one chance of escape.* If the subject is shared and the connective is *and* with a tight relation, omit the comma. Adverb-joined clauses take semicolons, not commas.
5. **Do not splice independent clauses with a comma.** Use a semicolon, a comma + conjunction, or a period. Allowed exception: short, parallel clauses (*Man proposes, God disposes.*). Adverbial joiners (*accordingly, besides, then, therefore, thus*) still need a semicolon.
6. **Do not break a sentence with a period where a comma belongs.** Sentence fragments only for deliberate emphasis (*Again and again he called out. No reply.*) — and only when no reader will mistake them for a slip.
7. **Opening participial phrase must refer to the grammatical subject.** Same for opening adjective phrases, appositives, and prepositional participials. *Walking slowly down the road, he saw a woman…* not *…the clock struck twelve.*

## Ch. III — Elementary principles of composition

8. **One paragraph per topic.** Do not split one idea across paragraphs; do not merge topics.
9. **Topic sentence near the start; close in conformity with it.** Don't end on digression or unimportant detail.
10. **Active voice.** Replace *there is/are/were*, *could be heard*, and noun-subjects-of-passives that swallow their own action:
    - *There were a great number of dead leaves lying on the ground.* → *Dead leaves covered the ground.*
    - *A survey of this region was made in 1900.* → *This region was surveyed in 1900.*
    - *The reason that he left college was that his health became impaired.* → *Failing health compelled him to leave college.*
    Passive is fine when the right word needs to be subject. Never stack two passives.
11. **Positive form.** Use *not* for denial or antithesis, never evasion.
    - *not honest* → *dishonest*; *not important* → *trifling*; *did not remember* → *forgot*; *did not pay any attention to* → *ignored*; *did not have much confidence in* → *distrusted*; *He was not very often on time.* → *He usually came late.*
12. **Definite, specific, concrete.** Prefer specific over general, definite over vague, concrete over abstract.
    - *A period of unfavorable weather set in.* → *It rained every day for a week.*
    - *He showed satisfaction as he took possession of his well-earned reward.* → *He grinned as he pocketed the coin.*
13. **Omit needless words.** Vigorous writing is concise. Standard cuts:
    - *the question as to whether* → *whether*
    - *there is no doubt but that* → *doubtless*
    - *used for fuel purposes* → *used for fuel*
    - *he is a man who* → *he*
    - *in a hasty manner* → *hastily*
    - *this is a subject which* → *this subject*
    - *His story is a strange one.* → *His story is strange.*
    - *the fact that* — revise out every occurrence (*owing to the fact that* → *because*; *in spite of the fact that* → *though*; *call your attention to the fact that* → *remind you*; *the fact that he had not succeeded* → *his failure*; *the fact that I had arrived* → *my arrival*).
    - *who is*, *which was* — usually superfluous (*his brother, who is a member of the same firm* → *his brother, a member of the same firm*).
    - Collapse clause-chains: combine sequences of short sentences that develop a single thought into one denser sentence.
14. **Vary sentence shapes.** A run of loose, two-clause sentences joined by *and / but / so / who / which* becomes monotonous. Mix simple, periodic, and semicolon-joined forms.
15. **Parallel construction for coordinate ideas.**
    - *Formerly, science was taught by the textbook method, while now the laboratory method is employed.* → *Formerly, science was taught by the textbook method; now it is taught by the laboratory method.*
    - Article or preposition before a series: use once before the first item, or repeat before each (*The French, the Italians, the Spanish, and the Portuguese*).
    - Correlatives (*both/and*, *not/but*, *not only/but also*, *either/or*, *first/second/third*) take matching grammatical parts on both sides.
16. **Keep related words together.**
    - Don't split subject and verb with a transferable phrase. *Wordsworth, in the fifth book of The Excursion, gives…* → *In the fifth book of The Excursion, Wordsworth gives…*
    - Relative pronoun follows its antecedent immediately when possible.
    - Modifiers next to what they modify: *He found only two mistakes*, not *He only found two mistakes*. *Not all the members were present*, not *All the members were not present*.
17. **One tense per summary.** Drama → present. Story/novel/poem → present preferred, past allowed; antecedent action takes the perfect (present-tense summary) or past perfect (past-tense summary). Past tense inside indirect discourse stays past. Don't intercalate *he said*, *the author then adds*.
18. **Place the emphatic words at the end.** The strongest position is sentence-final; second-strongest is sentence-initial. The end-weight rule scales: words within a sentence, sentences within a paragraph, paragraphs within a piece.

## Ch. IV — A few matters of form
- **Numerals**: do not spell out dates or serial numbers — *August 9, 1918*; *Rule 3*; *Chapter XII*; *352nd Infantry*.
- **Parentheses**: punctuate the outer sentence as if the parenthetical were absent. Punctuate the inner expression as if standalone, but omit its final stop unless it's `?` or `!`. A wholly detached parenthetical sentence keeps its stop *inside* the closing paren.
- **Quotations**:
  - Formal cited quotation → colon + quotation marks.
  - Quotation in apposition or as direct object → comma + quotation marks.
  - Quotation introduced by *that* → indirect discourse, no quotation marks.
  - Verse quotation of a line or more → on its own line(s), centered, no quotation marks.
  - Proverbial / familiar / colloquial / slang phrases → no quotation marks.
- **Titles**: italics with capitalized initials (*The Iliad*, *As You Like It*, *A Tale of Two Cities*). Drop initial *A*/*The* when a possessive precedes (*Dickens's Tale of Two Cities*).
- **References**: parenthesize or footnote, don't inline. Abbreviate frequent titles. Omit *act, scene, line, book, volume, page* when at least one is given numerically (*III.ii*, *IV.ii.14*).

## Ch. V — Words and expressions commonly misused (silent substitutions)

- **all right** — two words; avoid outside familiar speech.
- **as good or better than X** → *as good as X, or better*.
- **as to whether** → *whether*.
- **bid** — takes infinitive without *to*; past tense (= ordered) is *bade*.
- **but** — unneeded after *doubt* and *help* (*I have no doubt but that* → *I have no doubt that*). Avoid stacking *but … But …*; rearrange.
- **can** — = able; not a substitute for *may* (= permitted).
- **case** — usually deletable (*In many cases, the rooms were poorly ventilated* → *Many of the rooms were poorly ventilated*).
- **certainly** — drop as filler intensifier.
- **character** — usually redundant (*acts of a hostile character* → *hostile acts*).
- **claim** (v.) — only for *lay claim to*; not for *declare*, *maintain*, *charge*.
- **clever** — restrict to small-scale ingenuity.
- **compare to** = point out resemblance between different orders; **compare with** = point out differences between same order.
- **consider** (= *believe to be*) — no *as*. *I consider him competent*, not *as competent*.
- **data, phenomena, strata** — plural. *These data were tabulated.*
- **dependable** → *reliable*, *trustworthy*.
- **different than** → *different from* (or *other than*, *unlike*).
- **divided into** ≠ *composed of*.
- **don't** = *do not*; **doesn't** = *does not*. Don't substitute one for the other.
- **due to** — not for *because of* / *owing to* in adverbial use. Correct: predicate adjective tied to a specific noun (*losses due to preventable fires*).
- **effect** (n. = result; v. = bring about) ≠ **affect** (= influence). Drop as vague filler (*subtle effects*, *charming effect*).
- **etc.** — never after *such as* / *for example*. Use only when the remainder is obvious.
- **fact** — only for matters capable of direct verification. See Rule 13 for *the fact that*.
- **factor, feature** — hackneyed; rewrite (*The great factor in his winning was his training* → *He won by being better trained*).
- **fix** — colloquial for *arrange/mend*; in writing use only *fasten*, *make firm*.
- **folk** — collective, singular form.
- **get / have got** → *have*. Participle: *got*.
- **he is a man who** — redundant.
- **however** (= nevertheless) — never first in its clause. (*However* first means *in whatever way* or *to whatever extent*.)
- **interesting** — show, don't announce.
- **kind of**, **sort of** — not for *rather*; restrict to literal classification.
- **less** vs **fewer**: *less* = quantity; *fewer* = number. Exception: *less than a hundred*-style round numbers.
- **like** governs nouns/pronouns; before clauses use *as* (*He thought as I did* — *like me* is OK).
- **line**, **along these lines** — overworked; cut.
- **literal, literally** — only for actual literalness.
- **lose out, try out, win out, sign up, register up** — drop the *out / up*.
- **most** ≠ *almost* (*most everybody* → *almost everybody*).
- **nature** — usually redundant; otherwise specify the kind of nature meant.
- **near by** — as adverb prefer *near* or *near at hand*; as adjective use *neighboring*.
- **oftentimes, ofttimes** → *often*.
- **one hundred and one** — keep the *and*.
- **one of the most** — don't open with it; threadbare. A relative clause after it takes a *plural* verb (*one of the ablest men that have attacked this problem*).
- **participle for verbal noun** — possessive before the gerund: *Do you mind my asking?*, *prospect of the Senate's accepting*. (Don't force when meaning targets the subject, not the action.)
- **people** (political) ≠ **public** (artistic / commercial).
- **phase** — only stage of transition; not *aspect* or *topic*.
- **possess** — not a fancy *have* / *own*.
- **prove** — past participle *proved*.
- **respective, respectively** — usually drop.
- **shall / will** — see Era caveats above; do not impose 1918 distinction.
- **so** — avoid as bare intensifier (*so good*, *so warm*).
- **split infinitive** — avoid (*to diligently inquire* → *to inquire diligently*).
- **state** — only *express fully or clearly*; not a substitute for *say*, *remark*.
- **student body** → *students*.
- **system** — drop when bare (*the dormitory system* → *dormitories*; *the commission system of government* → *government by commission*).
- **thanking you in advance** — drop; rewrite as *Will you please…* or *I shall be obliged…*.
- **they** — see Era caveats above; do not impose 1918 *he*.
- **very** — sparingly; prefer a stronger word.
- **viewpoint** → *point of view*; not a synonym for *view* or *opinion*.
- **while** — only for *during the time that*. Replace with *and*, *but*, *although*, or a semicolon for the looser senses.
- **whom / who** — *whom* only when object. *His brother, who he said would send him the money* (not *whom*).
- **worth while** — only of actions, never before a noun. *His books are not worth reading* (not *not worth while*).
- **would / should** — 1st-person conditional = *should*. Habitual past: drop *would* and use plain past (*Once a year he visited the old mansion*).

## Ch. VI — Spelling
- Modern spelling. Override Strunk on: *today*, *tonight*, *tomorrow* (no hyphen).
- Keep two-word forms: *any one*, *every one*, *some one*, *some time* (in the sense "an indefinite period" — but *sometime* meaning "formerly" is one word).
- Doubling: a single final consonant (not *v*) preceded by a stressed short vowel doubles before *-ed* / *-ing* — *planned*, *letting*, *beginning*. *Coming* is an exception.
- Watch the standard misspelled list: *accidentally, advice, affect, believe, benefit, challenge, coarse, course, criticize, deceive, definite, describe, despise, develop, disappoint, dissipate, ecstasy, effect, embarrass, existence, fascinate, fiery, formerly, humorous, hypocrisy, immediately, impostor, incident, incidentally, latter, led, lose, marriage, mischief, murmur, necessary, occurred, opportunity, parallel, playwright, preceding, prejudice, principal / principle, privilege, pursue, repetition, rhyme, rhythm, ridiculous, sacrilegious, seize, separate, shepherd, siege, similar, simile, too, tragedy, tries, undoubtedly, until, villain*.

---

## Procedure

1. Resolve input: existing file path → Read it; otherwise treat the argument as raw text.
2. Identify and lock preserve-verbatim regions (code, URLs, quotes, tables).
3. Rewrite the remaining prose sentence by sentence. Useful order:
   13 (cut) → 10 (active) → 11 (positive) → 12 (concrete) → 3/4/5 (commas, semicolons) → 16 (word order) → 15 (parallelism) → 18 (end-weight) → 7 (danglers) → 14 (vary shapes) → 17 (tense) → 1/2 (apostrophes, series commas) → Ch. V substitutions → Ch. IV form → Ch. VI spelling.
4. Re-stitch preserved regions back in.
5. Print the result. Nothing else.
