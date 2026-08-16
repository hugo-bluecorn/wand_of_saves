# Build brief — the two grid spikes, G1 and G2

> ⚠️ **Status, 2026-08-15 — the brief below is the plan as approved and is kept unedited; what was
> built and then reshaped is `## Build report` onwards.** Both spikes were built; the user made
> eleven
> changes to G1 and had **G2 deleted**. D19 now decides on one page, **`G1MergedPage` — "the merged
> page"** — and the brief's `G1 — "Two benches"` section describes a structure it lost at the
> second change. **Jump to `## G2 deleted — G1 is what D19 decides on` for what exists.**

**2026-08-14.** This brief is a hand-off: it is written to be executed by a session that has no
other context, and it is **the approved plan** — build what it says; do not re-litigate the
design. A deviation you believe necessary is a question to bring back, not a decision to make.

**Read first, in this order:** `planning/tool-first-study.md` (the variants being built, their
ASCII maps, cell-by-task annotations, and what the spikes exist to settle);
`planning/inventory-merge-review.md` §7 (why a merged page at all); `CLAUDE.md` (hard rules —
fvm, D8's zero suppressions, never touch real saves). Do not read further history; the study is
the authority for this work.

## What is being built, and why

Two throwaway **spike screens** that put the study's two grid layouts on a real Linux window
with real data, so the user can look at both and close decision **D19** (which grid the merged
character/inventory page uses). They are look-and-feel artifacts with working cores — not
refactors, not the production merge. **The winning grid is rebuilt test-first in the merge slice
later; both spikes are deleted after D19.** That is the recorded lifecycle of this project's UI
spikes (D15/D17 precedent).

## Ground rules

- `fvm flutter …` / `fvm dart …` — Dart/Flutter are not on PATH.
- **D8 applies in full**: `very_good_analysis` whole, zero suppressions, no `// ignore`, no new
  `exclude:`. `fvm flutter analyze` and `dart format` must end clean.
- **No test-first for the spike screens** — a recorded exemption for artifacts that exist to be
  looked at and then deleted. But the existing **844 + 399 tests must still pass**; spikes may
  not alter any tested behaviour.
- **Production surfaces are untouched** except the single entry point below. No route changes,
  no shared-widget edits that change existing screens' behaviour, no new dependencies, no edits
  under `packages/infinity_formats`.
- **Reuse over rebuild.** The panels, cells, rail tiles, tags and editors these grids need all
  exist. If a piece is not reusable as-is (e.g. a panel widget is private to a view), extract it
  minimally and mechanically — same behaviour, same name, now shared. If something cannot be
  reused cheaply, stub it visually and say so in the build report; **never invent data** — a
  value the app does not already compute is omitted, not faked (no weight totals, no equip
  effects).
- The user's saves are opened through the normal browser flow; nothing is written. The spikes
  never call save.

## The entry point

A **debug-only** block on the home screen (guarded by `kDebugMode`): a small "Layout spikes"
row with two buttons, `G1 — Two benches` and `G2 — Ledger grid`. Each opens the corresponding
spike screen for a save slot the user picks first (simplest correct wiring: the buttons appear
only when a save is already open in the party shell, or take the most recent slot — builder's
call, report which). Release builds show nothing.

## Spike G1 — "Two benches" (adjacency-biased)

Per the study's map, a fixed three-column grid, authored positions, no `MediaQuery`/
`LayoutBuilder`, nothing rearranges on resize:

- **Left — slow bench** (its own scroll): the existing Character, Abilities, Skills,
  Proficiencies panels, in that order.
- **Centre — fast bench**: Combat, Resistances, Condition panels **pinned at the top, never
  scrolling**; beneath them the item search, the 4×4 backpack grid, Equipped and In-no-slot
  (this lower region scrolls on its own).
- **Right — party column**: portrait tiles (drag targets, as the rail already is), identity
  block, save/undo/redo/dirty chrome, findings badge, rules toggle. **The party column is on
  the right, beside the inventory — that placement is derived and deliberate; do not "fix" it.**
- **Editing is inline**: selecting an editable row expands the existing field editor beneath it
  (reuse the side sheet's editor content; the sheet itself does not appear on G1).
- **Finds are split**: Ctrl+K field palette over the slow bench; the item search where it is.
- Working: drag pack → portrait (existing wiring), one real field edit end-to-end, both finds.

## Spike G2 — "Ledger grid" (audit-biased)

- **Full-width top band**: identity, a **horizontal** member switcher, ONE **unified find**, and
  the same chrome. The unified find merges the field palette's results and the item catalogue's
  results into one list with the two kinds visibly labelled — compose the two existing searches;
  do not write a new search engine.
- **Three record columns below, each its own scroll**: column 1 Character, Abilities, Skills;
  column 2 Proficiencies, Combat, Resistances, Condition; column 3 item results, backpack 4×4,
  Equipped, In-no-slot.
- **Editing keeps the side sheet**, authored to overlay **column 1 only** — never the numbers,
  never the items.
- Working: the unified find (this is G2's whole reason to exist — the deepest question the
  spikes settle), drag pack → switcher tiles, one real field edit via the sheet.

## Measurements to report (not to act on)

- The minimum window size each grid genuinely needs (the study estimated ≈1280×860; measure the
  truth). **Do not change `linux/runner/my_application.cc`** — report the numbers.
- Whether G1's pinned band leaves the backpack usable height at that minimum.

## Definition of done

1. `fvm flutter analyze` clean; `dart format` a no-op; `fvm flutter test` and the
   `packages/infinity_formats` suite green; tree committed on a branch named
   `spike/grid-variants` (do not push to `main`; do not open a PR).
2. The app runs on Linux; both spikes reachable via the debug entry; drag, find(s) and one field
   edit demonstrably work on each.
3. **A build report appended to this file** under `## Build report`: what was reused vs
   extracted vs stubbed (with file paths), the entry-point choice made, the min-window
   measurements, and any deviation with its reason.
4. **Leave the app running** and tell the user it is ready for the capture session. The user
   takes the captures (the window is native Wayland; the session cannot). Ask for, per spike:
   the full window at the measured minimum size and at a comfortable size; mid-drag over the
   party tiles; the field editor open (G1 inline / G2 sheet); and the find showing results for
   a query that matches both a field and an item (e.g. `strength`) — on G2 that exposes the
   result-mixing question.

The captures go back to the review session / the user; **the user's eyes close D19**. Nothing
in this brief decides which grid wins.

---

## Build report

**Built 2026-08-14 on branch `spike/grid-variants`.** `fvm flutter analyze` clean, `dart format`
a no-op across 242 files, **844 app tests + 399 format tests green**, zero suppressions
(the D8 grep returns nothing). Both spikes reachable, and everything the brief calls "working"
was exercised before hand-over — see *What was proved* below.

### ⚠️ The one deviation, and it was brought back as a question

**G1's pinned band could not exist as the brief drew it.** Measured, the three panels the brief
pins are:

| panel | height at 520 pt wide |
|---|---|
| Combat | **934** |
| Resistances | **604** |
| Condition | 163 |

**≈ 1,700 pt** — about twice the whole window, before the item search and the backpack start.
(Combat alone is eighteen rows; Resistances is eleven.) So the band was put to the user with
three options, and the user chose: **draw the pinned numbers compactly.** That is
`lib/ui/grid_spikes/compact_numbers.dart` — one line per number (label · stored · `in game`),
without the arithmetic line, the two limits, the ⓘ and the finding's sentence, all of which stay
one tap away in the editor.

⚠️ **It is a second *rendering* and not a second *copy*.** R1 of the study forbids a summary
strip, and the reason it gives is duplication. On G1 these three panels appear **nowhere else** —
the slow bench holds Character, Abilities, Skills and Proficiencies and nothing more — so each
number still exists exactly once, and it sits where the items are, which is what R1 asks for. The
rows are read out of `indexOf()`, so a field added to the projection appears in the band without
that file being touched.

Two densities, because two kinds of panel: **Combat keeps a line per number** (its rows carry
what the engine draws instead, which is the comparison the pin is *for*); **Resistances and
Condition flow** as captioned pills, because eleven rows saying `0%` is three hundred points
spent on nothing. That flowing style still promotes an `in game` value to its own pill if one
ever appears.

### Measurements — reported, not acted on

⚠️ **Every width below is an over-estimate.** `flutter test` draws with a font whose every glyph
is a full em square, so labels wrap earlier than they will on screen; heights are close to true,
widths are pessimistic. The real minimum is somewhere at or below each figure. **The window
minimum in `linux/runner/my_application.cc` was not touched** — it is still 900 × 600, default
1280 × 720.

| | smallest window with no overflow | driven by |
|---|---|---|
| **G1** | **940 × 740** (740 measured at 1600 wide; at 1280 wide the floor is ≈ 785) | the pinned band's height; the 480 + 232 fixed columns |
| **G2** | **1240 × 360** | the top band's row — 260 identity + ~550 switcher + ~340 chrome; the columns themselves scroll, so height barely binds |

⚠️ **G1's minimum height is not a constant**, because the band's labels rewrap as the centre
column changes width. That is text reflow inside a fixed cell rather than the layout rearranging,
so it does not break the no-`LayoutBuilder` rule — but it means "the minimum window" is a curve
for G1 and a point for G2.

**Does G1's pinned band leave the backpack usable height?** This is the brief's second
measurement and the answer is **no, not until the window is very tall**:

| window | pinned band | left for search + backpack |
|---|---|---|
| 1280 × 720 *(the app's own default)* | 753 | **−62 — it does not fit at all** |
| 1280 × 860 *(the study's estimate)* | 753 | **78** — less than one row of cells (a cell is 84 tall) |
| 1440 × 900 | 725 | 146 |
| 1920 × 1080 | 697 | 354 — about three of the four rows |
| 2560 × 1440 | 669 | 742 — all four, with room |

So even compacted by a thousand points, **the numbers G1 pins cost most of the window.** The
lower region scrolls, so nothing is lost or clipped — but G1's central claim (an equip changes a
number you can already see, with the items right there) is only true on a large monitor. That is
a finding for D19 rather than something to fix here.

### The entry point — which option was taken

A debug-only block at the bottom of the home screen (`_LayoutSpikes` in
`lib/ui/saves/home_screen.dart`, guarded by `kDebugMode`), with `G1 — Two benches` and
`G2 — Ledger grid`. **It opens the most recently modified save** — the browser already sorts that
way, and that is `000000023-Conan Inventory Move`, the six-member party the study asks for. The
row names the save, so it is never a guess which file is open. Each button is a plain
`Navigator.push`; **no route was added**, per the brief.

### Reused · extracted · stubbed

**Reused unchanged:** `PortraitRail`, `PortraitTile`, `CommandPalette`, `SideSheet`, `PanelCard`,
`Tag`/`stateTagFor`, `ScreenTone`, `SaveButton`, `RulesToggle`, `FindingsBadge`, `PipMeter`,
`ItemDrag`/`ItemDragFeedback`, `ItemMenu`, `InventoryCell`, `sheetCharacterFrom`, `indexOf`,
`findingsFor`, `partyProvider` and every `EditCommand`.

**Extracted — mechanical, behaviour-preserving, and all 844 tests still pass:**

| what | where | why |
|---|---|---|
| `sheetPanelsOf()` + `sheetPanelOrder` | `character_sheet_view.dart` | the panels, by name, so a grid can put named panels in named cells. `CharacterSheetView` now draws `.values`; the ordering rule stays one copy. Gained an optional `inlineEditor` hook, which the single column passes as `null` |
| `_Identity` → `SheetIdentity` | same | G1's party column names the character |
| `SubjectEditor` | `side_sheet.dart` | the editor lifted out of the `Drawer`. `SideSheet` is now `Drawer(SafeArea(SubjectEditor))` and nothing else. `fillsHeight: false` is what lets G1 expand it beneath a row. **Every rule about what an edit means stays in one place** |
| `subjectKey()` | same | was the private `_identityOf`; G1 needs the same answer to decide which row is open |
| `subjectsMatching()`, `PaletteRow`, `PaletteEmpty`, `canOpenSubject()` | `command_palette.dart` | G2's unified find **composes** the palette's matcher rather than writing a second one |
| `InventoryPanels` + `ItemSearchField`, `ItemResults`, `CarriedSections`, `CarriedPanel`, `BackpackGrid` | `inventory_screen.dart` | everything `InventoryScreen` held except its Scaffold. `InventoryScreen` now renders `InventoryPanels` inside the same scroll shell. Two new parameters, both defaulting to today's behaviour: `query` (for a surface whose search box lives elsewhere — G2) and `autofocusSearchField` (two boxes on one grid cannot both take focus) |
| `firstFreePackSlot()` / `hasPackRoom()` | **new** `lib/ui/inventory/pack_slots.dart` | ⚠️ the free-slot rule had two copies already (the inventory's and the rail's) and G2 would have made a third. It is now one, which also does §7 constraint 4c of the merge review ahead of time |

**Stubbed or omitted — nothing was invented:**

- **No weight, no capacity, no equip effects.** The app does not compute them, so they appear
  nowhere on either grid. `known-defects.md` §8 still owns them.
- **No item detail/properties panel.** Same reason — §8's third open item.
- **G1's party column has no Export button.** It is not in the brief's list for that cell and it
  is not part of what D19 decides.
- **`SelectionArea` covers the record columns only**, not the item cells, on both grids —
  a drag and a selection gesture over the same cell is a fight neither spike needs to pick.

### Interpretations worth flagging, none of them silent

1. **A pinned row's editor opens below the band, not inside it** (G1). Expanding it inside would
   change the band's height, which is the one thing a pin may not do. It opens at the top of the
   scrolling region immediately beneath — still inline, still adjacent, and the numbers stay put.
   Slow-bench rows expand beneath themselves exactly as the brief says.
2. **G2 shows item results twice, from one search**: in the find's own dropdown (labelled by
   kind) and in column 3, which the study's map draws as "item results". Both read the same
   `ItemCatalogue.search(query)` call — one engine, two views — and choosing an item closes the
   box **on the query rather than on the item's name**, so the results the column is showing
   survive the add.
3. **G2's switcher makes a drop target of all six portraits; G1's rail makes five.** Not a
   difference in behaviour — the rail simply does not build a target for the selected member,
   because that is always the one the item is leaving, and G2's target refuses a self-drop. Worth
   knowing if you count them in a capture.
4. **Neither spike has an app bar.** The chrome lives in the cell the study puts it in, and a bar
   above that would both duplicate it and steal 56 points from the height being measured. The way
   out is the ✕ in each grid's own chrome.

### What was proved before hand-over

⚠️ **The window is native Wayland and this session cannot drive it or capture it**, so the
interactions were exercised as throwaway widget tests, run green, and then deleted (spike screens
are exempt from test-first; leaving tests behind for code that is about to be deleted is not). All
eight passed:

- **G1** — the compact band renders; a band row (`THAC0 (base)`) opens `SubjectEditor` and **no**
  `SideSheet`; a slow-bench row (`Strength`) expands the editor inline, `18 → 17` applies, the row
  redraws and **Save goes live**; Ctrl+K opens the field palette; an added item is a
  `Draggable<ItemDrag>` with five live portrait targets.
- **G2** — one query (`strength`) returns **both kinds under both headings** — *On this record*
  and *In the item catalogue* — with a field and an item matching at once; choosing the field
  opens the `SideSheet`; an edit through it applies and Save goes live; there is **no**
  `ItemSearchField` anywhere, so the band's one box really is the only way in; adding through it
  puts the item in the backpack; six switcher targets.

### Owed to the user

The captures. Per spike: the full window at the measured minimum and at a comfortable size;
mid-drag over the party tiles; the editor open (G1 inline / G2 sheet); and the find showing
results for a query matching both a field and an item — `strength` is the one to type, and on G2
it is the whole result-mixing question in one picture.

---

## Amended the same day — the user favours G1, and reshaped it

**The user looked at the built spikes and is favouring G1**, with two changes. Both go against
what the study derived on paper, and both are the user's to make — recorded here rather than
quietly applied, because **the paper scores no longer describe what G1 is.**

**1 — The party column moved from the right edge to the left.** The study put it on the right by
derivation rather than by default: the dominant drag is pack → member, and a right-hand party
column made that travel one column instead of the window. On the left it travels the full width,
which is the margin that won G1 the **W-A2** script. The concern was raised and the change made
as asked. The rest of the app puts its rail on the left, so this is also the conventional
arrangement.

**2 — The fast bench is one scroll, items first, and the numbers are no longer pinned.** It was a
fixed band of numbers above a scrolling item region; it is now a single scrolling column with the
inventory group at the top and the numbers directly beneath. This trades away **R1's pin** — the
property G1 was built to demonstrate — and it is exactly the trade the measurement above argues
for: the band cost ~750 points and left 78 for the backpack at 1280 × 860, so the pin was bought
at the price of the thing it sat above.

**What the change bought, measured the same way:**

| | before | after |
|---|---|---|
| G1 minimum width | 940 | **720** |
| G1 minimum height | 740 (a curve — ≈ 785 at 1280 wide) | **300** |

⚠️ **G1 now fits inside the application's own 900 × 600 floor, at any window it allows** — and its
minimum height stopped being a function of its width, because nothing has to fit any more. The
brief's two measurement questions are answered and closed by this: the minimum is no longer
≈1280 × 860, and the backpack has its full height at every size.

**What it cost:** the numbers are ~500 points down the column, so at an ordinary window you scroll
to see them. Watching an equip move an armour class — **W-A6**, and the §8c property that started
the merge — is a scroll again rather than a glance. The numbers stay in the **compact** rendering
for exactly that reason: 700 points of numbers rather than 1,700 keeps them one short scroll away
instead of a long one.

**Two consequences inside the code, both simplifications:**

- **Every row on the page now edits beneath itself**, whichever bench it is on. The special case
  where a band row opened *below* the band existed only because the band's height could not
  change; with the fast bench scrolling as a whole, it is gone. `CompactNumbers` takes the same
  `inlineEditor` hook `sheetPanelsOf` does. A *flowing* panel opens its editor under the whole run
  of pills rather than under one — "beneath the row" has no meaning for a pill sharing its line
  with five others.
- The doc comments on `g1_two_benches.dart` (now `g1_merged_page.dart`) and `compact_numbers.dart`
  were rewritten rather than
  left describing a pin that no longer exists.

**Re-proved after the change**, as throwaway widget tests, run green and deleted: the party is the
leftmost column; the items and the numbers share a column with the items above; a number edits
inside the numbers block and `20 → 19` writes with Save going live; a slow-bench row still edits
inline; Ctrl+K still reaches the palette; an added item still drags to the other five portraits.
`analyze` clean, `dart format` a no-op, 844 + 399 green.

### Amended again — the two content columns became one

**Third change, same day, also the user's: the middle and right columns are merged.** G1 is now
**the party rail and one column**, which is the shape `inventory-merge-review.md` §7 called
**option A** — the inventory joining the sheet's single column as panels — arrived at by building
rather than by argument. **D15's single column, extended.** The two benches G1 is named for no
longer exist; the name is kept because it is what the study and D19 call this variant.

The column's order keeps the two old columns' relative order, so it reads: field palette →
Character, Abilities, Skills, Proficiencies → **inventory** → Combat, Resistances, Condition. That
preserves the sheet's authored order *and* leaves the items directly above the numbers equipment
moves, which is the last thing left of R1. Width is capped at **900** and centred — the
inventory's number rather than the sheet's 820, because the 4 × 4 backpack is now in the same
column and is what wants the width. That is the 820-vs-900 reconciliation the merge review lists
as a constraint, settled here by the first surface that has to hold both.

| | pinned band | merged fast bench | one column |
|---|---|---|---|
| minimum width | 940 | 720 | **520** |
| minimum height | 740 | 300 | **300** |

⚠️ **And here is the cost, measured, which is the strongest argument against this order.** In one
column the record comes before the items, and the record is long:

| | starts at |
|---|---|
| Abilities | 411 |
| **the inventory** | **1,438** |
| the numbers | 1,960 |

**The backpack is below the fold at every window size the app allows** — you scroll past the whole
record to reach the thing you came to drag. ⚠️ **And the real figure is worse than this**: the
measurement ran with an empty proficiency catalogue, so it has **no Proficiencies panel at all**.
With a real installation's twenty-four proficiencies that panel adds roughly another 1,100 points,
putting the inventory about **2,500 points down**.

**The fix, if the user wants it, is one line: lead the column with the inventory** — the same
instruction that was given for the centre column before the merge, applied to the merged one. It
would put the items first, the numbers they move second, and the read-once panels last. Not done
unasked, because it inverts the sheet's authored reading order, which is D15's other half.

Re-proved after this change, again as throwaway tests run green and deleted: one content column
beside the party, in that order; a record row and a number both expand the editor beneath
themselves and `20 → 19` writes with Save going live; Ctrl+K still reaches the palette; an added
item still drags to the other five portraits.

### Corrected — "merged" meant one PAGE in two columns, not one column

⚠️ **The previous step was built from a misreading and has been redone.** "Merge the middle and
right columns" was taken as *stack their contents*, which produced a single column of everything;
what was wanted was **one page laid out in two columns** — the two benches stop being independent
panes and become one document. The distinction is the scroll: the three-column G1 gave each bench
its own scrollbar, and a page has one.

**G1 as it now stands:**

```
┌─PARTY─┬────────────── ONE page, two columns ──────────────┐
│ ┌───┐ │ ⌕ Ctrl+K                │ Inventory               │
│ │Con│ │ Character               │  ⌕ Find an item         │
│ └───┘ │ Abilities               │  ┌────┬────┬────┬────┐  │
│ ┌───┐ │ Skills                  │  │    │    │    │    │  │
│ │Imo│ │ Proficiencies           │  └────┴────┴────┴────┘  │
│ └───┘ │                         │ Equipped · In no slot   │
│ ident │                         │ Combat · Resistances    │
│ chrome│                         │ Condition               │
└───────┴─────────────────────────┴─────────────────────────┘
                    ↕ ONE scrollbar moves both columns
```

The two columns share one `ScrollController` and sit in a `Row` **inside** the scroll view, rather
than being two scroll views in a `Row`. The pair is capped at **1600** and centred, so a wide
monitor does not give each column eleven hundred points and put a row's two words a metre from its
number. The party rail keeps its own column and its own height.

**And this is what fixed the fold problem the previous step measured:**

| | one column (previous step) | two columns (now) |
|---|---|---|
| the record starts at | 411 | 411 |
| **the inventory starts at** | **1,438** *(≈2,500 with real proficiencies)* | **20** |
| the numbers start at | 1,960 | 542 |
| minimum window | 520 × 300 | **780 × 300** |

**The backpack is the first thing in its column**, so it is above the fold at every window the app
allows, and the numbers equipment moves are ~540 points under it rather than two thousand. The
extra 260 points of minimum width is what a second column costs, and it is still well inside the
application's own 900 × 600 floor.

⚠️ **Two things a capture should be looked at for**, both consequences rather than defects:

1. **The columns are wildly unequal in height.** The record column with a real installation's
   twenty-four proficiencies runs perhaps 2,500 points; the items column about 1,200. The right
   column simply ends, leaving white space beside the bottom half of the left one. Nothing
   rebalances them — that is D17's zigzag, and this project has already paid for it once.
2. **The numbers are still in the compact rendering** the pinned band needed, now sitting under an
   inventory drawn at full height. The reason for compactness is gone; what it still buys is a
   short scroll from the items to the numbers. Making the column uniform — either everything full
   or nothing — is a one-line change, not made unasked.

Re-proved after this change: party column, then two columns side by side with the items level with
the record rather than below it; **exactly one `Scrollbar` on the page**; a row in either column
expands the editor beneath itself and `20 → 19` writes with Save going live; Ctrl+K reaches the
palette; an added item still drags to the other five portraits. `analyze` clean, `dart format` a
no-op, 844 + 399 green.

### Balanced — Proficiencies moved right, the numbers and In-no-slot moved left

**The user's fix for the unequal columns**, and it is the right kind of fix: rather than an
algorithm balancing heights — which is D17's zigzag and this project has paid for it once — two
named blocks swap sides in the authored map.

```
┌─PARTY─┬───────────────── ONE page, two columns ────────────────┐
│ ┌───┐ │ ⌕ Ctrl+K                  │ Inventory                  │
│ │Con│ │ Character                 │  ⌕ Find an item            │
│ └───┘ │ Abilities                 │  ┌────┬────┬────┬────┐     │
│ ┌───┐ │ Skills                    │  └────┴────┴────┴────┘     │
│ │Imo│ │ In no slot                │ Equipped                   │
│ └───┘ │ Combat                    │ Proficiencies              │
│ ident │ Resistances               │  Long Sword     ●●○○○      │
│ chrome│ Condition                 │  … twenty-four of them     │
└───────┴───────────────────────────┴────────────────────────────┘
```

⚠️ **Measured with a real installation's twenty-four proficiencies** — every earlier figure in
this report ran on an *empty* catalogue and so had no Proficiencies panel at all, which is exactly
the block being moved:

| | before the swap | after |
|---|---|---|
| left column | ≈ 2,340 | **2,183** |
| right column | ≈ 1,120 | **1,472** |
| ratio | 2.1 : 1 | **1.48 : 1** |
| minimum window | 780 × 300 | **880 × 300** |

**Better, and not yet balanced.** The blocks measure roughly: palette 56 · Character 289 ·
Abilities 454 · Skills 555 · the numbers 780 · the inventory 460 · Proficiencies 990. An even
split would be about 1,790 a side, so the left is ~390 long. ⚠️ **Moving `Character` (289) across
would land it at 1,878 against 1,777** — one further named move, and the closest any single swap
gets. Not made unasked.

⚠️ **And the gap is smaller than it looks on paper.** These are `flutter test` figures, where every
glyph is a full em square, so text wraps earlier than it will on screen — and the left column is
almost all text while the right is a grid and a stack of pip meters. The inflation is not even
between them.

The split needed one parameter in production code: `CarriedGroup` and `CarriedSections.groups`, so
a surface can draw the backpack and Equipped in one place and In-no-slot in another. Everything
defaults to all three, so `InventoryScreen` is unchanged. **In-no-slot went left with the record
deliberately** — those items are not a place anything can be put and the game will not draw them
at all, so they read as something wrong with the record rather than as inventory.

Re-proved: Proficiencies really are in the right-hand column; one item search box on the page; the
editor still opens under a number and writes; the added item is in a backpack cell with its
`Draggable` and five portrait targets; Ctrl+K reaches the palette. `analyze` clean, `dart format` a
no-op, 844 + 399 green.

### The party became a band across the top — and G1 met G2

**Fifth change, the user's: the party column moves to the top as a row spanning the page.**

```
┌──────────────────────────── PARTY BAND ────────────────────────────┐
│ Conan · Fighter 1 · 325 XP  [Con][Imo][Jah][Kha][Xza]  ⚑3 ↶ ↷ Save │
├───────────────────────────────┬────────────────────────────────────┤
│ ⌕ Ctrl+K                      │ Inventory                          │
│ Character · Abilities · Skills│  ⌕ Find an item · the 4 × 4 grid    │
│ In no slot                    │ Equipped                           │
│ Combat · Resistances          │ Proficiencies                      │
│ Condition                     │                                    │
└───────────────────────────────┴────────────────────────────────────┘
```

⚠️ **G1 now has G2's chrome.** The band is `MemberSwitcher` — **G2's widget, reused, not a second
one** — because `NavigationRail` is vertical by construction and a party laid across a band needs
the other thing. Two horizontal switchers would be two answers to "which portraits will take a
drop", which is the bug this project keeps paying for. So the variants no longer disagree about
where the party lives, and the study's **W-X1** row cannot separate them at all now.

**And the drag changed shape rather than distance.** Pack → member used to travel one column (the
study's derivation), then the whole window (the left-hand column), and now travels *up* — with
every portrait the same distance from the backpack, which is the one thing neither edge placement
gave. **W-A2**'s margin is gone either way.

| | party as a column | party as a band |
|---|---|---|
| minimum width | 880 | **1,260** |
| minimum height | 300 | **160** |
| band height | — | 116 |

⚠️ **This is the first time G1 asks for more than the application will guarantee.** The window's
own floor is **900 × 600** (`linux/runner/my_application.cc`, untouched per the brief), so a window
can be made narrower than G1 now needs and the band will overflow. The band is what costs it:
identity 300 + six portraits ~550 + chrome ~400 leaves nothing to give. **G2 measured 1,240 for the
same reason** — the two variants have converged on the same minimum, from opposite directions.

If the band is kept, `min_width` wants raising to about 1,280. That is a one-line change to
`my_application.cc` and the brief reserves it: report the number, do not make the change.

Re-proved: the band sits above both columns with six drop targets; the editor still opens under a
number and writes with Save going live; one item search box; an added item is draggable; Ctrl+K
reaches the palette. `analyze` clean, `dart format` a no-op, 844 + 399 green.

### Condition folded away, Resistances under Skills, Combat as a footer

**Sixth change, the user's, and the first to touch the sheet's own grouping rather than only its
arrangement.**

```
┌──────────────────────────── PARTY BAND ────────────────────────────┐
│ Conan · Fighter 1 · 325 XP  [Con][Imo][Jah][Kha][Xza]  ⚑3 ↶ ↷ Save │
├───────────────────────────────┬────────────────────────────────────┤
│ ⌕ Ctrl+K                      │ Inventory                          │
│ Character  … Fatigue · Intox. │  ⌕ Find an item · the 4 × 4 grid    │
│ Abilities                     │ Equipped                           │
│ Skills                        │ Proficiencies                      │
│ Resistances  [pills]          │                                    │
│ In no slot                    │                                    │
├───────────────────────────────┴────────────────────────────────────┤
│ Combat                                                             │
│  THAC0 (base)   20 │ Save vs. death 14 │ AC crushing        0      │
│  AC (natural)   10 │ Save vs. wands 16 │ AC missile         0      │
│  AC (effective) 10 │ …                 │ Morale · Luck             │
└────────────────────────────────────────────────────────────────────┘
```

- **Condition is not a panel any more.** Its two rows — fatigue and intoxication — are the last two
  rows of Character. A card of its own for two values was a heading costing more than what it
  headed. ⚠️ **The projection was not changed**: `sheetPanelsOf` gained a `foldInto` parameter
  naming which groups join which panel, empty by default, so the production sheet still draws
  Condition exactly as it did. `sheetPanelOrder` still names it and simply finds nothing.
- **Resistances moved under Skills**, still as pills — eleven values, each a word and a percentage,
  none of which the engine draws differently.
- **Combat became the page's footer**, spanning both columns at the full 1,600 and splitting its
  eighteen rows into three. It is the one panel neither half owns: the items move its numbers and
  the record explains them, so it sits under both rather than inside either. ⚠️ The three columns
  are filled **in reading order, 1–6 · 7–12 · 13–18** — nothing measures anything and nothing
  balances. Balancing by height is D17's zigzag.

**Measured**, at 1,700 × 1,400 with twenty-four proficiencies:

| | |
|---|---|
| left column | ends 1,802 (Skills 1,115–1,670, Resistances 1,686–1,802) |
| right column | ends 1,622 |
| **footer** | 1,842–2,061, x 50–1,650 — the full width, 219 tall |
| minimum window | **1,260 × 160**, unchanged — the band still sets it |

⚠️ **The columns are now nearly level**: 1,802 against 1,622, where the first attempt was 2.1 : 1.
Moving Combat out from under either of them is what did the rest of the balancing that the
Proficiencies swap started.

Re-proved: no panel headed Condition anywhere, and Fatigue and Intoxication are inside the
Character card; Resistances is in the same column as Skills and directly below it; the footer
begins below both columns and is more than 1.9× either's width; `THAC0 (base)` sits at x 66 and
`Luck` at x 1,127, which is three columns and not one; the editor still opens under a number in
the footer and writes with Save going live; one item search box, an added item draggable, six
portrait targets, Ctrl+K live. `analyze` clean, `dart format` a no-op, 844 + 399 green.

### The field palette removed — ⚠️ and with it the last axis between G1 and G2

**Seventh change, the user's: the field-and-proficiency search comes off the page.** The Ctrl+K box
that headed the left column is gone, and so is the shortcut that opened it.

**Two things went with it, both stated rather than left to be discovered:**

1. **There is now no way to search the record on G1 at all.** The panels are the index. On a page
   that draws every field at once that is arguable — the palette was built when the sheet showed
   forty of fifty-three fields behind a click — but it is a capability the page had this morning
   and does not have now.
2. **The findings badge has nowhere to send anybody**, because the palette was its destination.
   It now shows the count and is **not pressable** — `FindingsBadge` documents a null `onPressed`
   for exactly this case, and an enabled button that does nothing is the dead control this project
   keeps deleting. `spikeChrome` takes `onFindings` as optional; G2 still passes its find.

⚠️ **This is the last thing the two variants disagreed about.** The study's **R5** — one find
surface or two — was the question the spikes existed to settle, and it was already the only axis
left after the party band gave G1 G2's chrome. It is now settled by removal rather than by
comparison: **G2 has one box over the record and the catalogue; G1 has one box over the catalogue
and nothing over the record.** Whatever D19 decides, it is no longer deciding between two
arrangements that differ in more than one place — and the paper scores in
`planning/tool-first-study.md` describe neither of these pages any more.

Re-proved: no `CommandPalette` and no `SearchBar` on the page; Ctrl+K does nothing; exactly one
`ItemSearchField` remains; every `FindingsBadge` on the page has a null `onPressed`; the editor
still opens under a footer number and `20 → 19` writes with Save going live; an added item is
draggable with six portrait targets. Minimum window unchanged at **1,260 × 160**. `analyze` clean,
`dart format` a no-op, 844 + 399 green.

### Combat moved from the foot of the page to its head — and that gets R1 back

**Eighth change, the user's, and the smallest one with the largest effect on what the study
cared about.**

```
┌──────────────────────────── PARTY BAND ────────────────────────────┐
│ Conan · Fighter 1 · 325 XP  [Con][Imo][Jah][Kha][Xza]  ⚑3 ↶ ↷ Save │
├────────────────────────────────────────────────────────────────────┤
│ Combat                                        ▲ top of the scroll  │
│  THAC0 (base)   20 │ Save vs. death 14 │ AC crushing        0      │
│  AC (natural)   10 │ Save vs. wands 16 │ AC missile         0      │
│  AC (effective) 10 │ …                 │ Morale · Luck             │
├───────────────────────────────┬────────────────────────────────────┤
│ Character  … Fatigue · Intox. │ Inventory                          │
│ Abilities                     │  ⌕ Find an item · the 4 × 4 grid    │
│ Skills                        │ Equipped                           │
│ Resistances  [pills]          │ Proficiencies                      │
│ In no slot                    │                                    │
└───────────────────────────────┴────────────────────────────────────┘
```

**Measured**, 1,700 × 1,400 with twenty-four proficiencies:

| | |
|---|---|
| party band | 16–133 |
| **Combat** | **170–389**, x 50–1,650 — full width, 219 tall |
| both columns start | 409 |
| minimum window | 1,260 × 160, unchanged |

⚠️ **This is the closest anything has come to R1 since the pin was given up.** The numbers
equipment moves are what an unscrolled window opens on, and the backpack starts 20 points beneath
them — so an equip and the number it changes are **both on screen at once, at every window height
the app allows**, without anything being pinned and without the band that cost 750 points and left
the backpack 78. **W-A6** is a glance again rather than a scroll, and it costs nothing this time.

It also puts the page in a defensible reading order for the first time: the party, then what the
character *is in a fight*, then who they are on the left and what they carry on the right.

Re-proved: Combat is first in the scroll, above both columns, and more than 1.9× either's width;
the editor still opens under one of its numbers and `20 → 19` writes with Save going live; the item
search still adds and the added item drags to six portrait targets. `analyze` clean, `dart format`
a no-op, 844 + 399 green.

⚠️ **Two stale doc comments were corrected in the same commit**, because a comment describing
behaviour the code no longer has is a bug report: the file still said "four changes" over a list of
six, and still described the compact rendering as sitting "under an inventory drawn at full
height".

### Resistances above Skills — and ⚠️ the type scale went back to Flutter's

Two more, and **the second is production, not spike**: it changes every screen in the application.

**Resistances moved above Skills.** A resistance is something the character *is*, like an ability
score, rather than something they have learnt. The left column reads Character · Abilities ·
Resistances · Skills · In no slot.

**The hand-tuned type scale is gone.** `_textThemeFor` had authored every size, weight, letter
spacing and line height — roughly M3 minus a point and a half, on the argument that a desktop
window wants tighter text than a phone. It is now `Typography.material2021` for the platform,
unretuned, and **nothing in this application states a font size anywhere.**

⚠️ **Why the old ramp was half right, measured on the machine it runs on.** Flutter's default
`Text` style is `bodyMedium`; that was **13.5**, and this desktop's own UI font is Noto Sans 10 pt
= **13.33 px** at 96 DPI (`gtk-xft-dpi 98304`, `text-scaling-factor 1.0`). The *base* was already
within a fifth of a pixel of the platform. What sat under platform size was the small end —
captions at 11, pill values at 12 — which is what a page now carrying eleven resistance pills and
an eighteen-row compact footer put on screen in quantity.

| role | was | now (M3 default) |
|---|---|---|
| displaySmall · headlineSmall · titleLarge | 30 · 22 · 19 | **36 · 24 · 22** |
| titleMedium · titleSmall | 16 · 13.5 | **16 · 14** |
| bodyLarge · bodyMedium · bodySmall | 14.5 · 13.5 · 12.5 | **16 · 14 · 12** |
| labelLarge · labelMedium · labelSmall | 13 · 12 · 11 | **14 · 12 · 11** |
| body line height | 1.35 flat | M3's own — 1.5 / 1.43 / 1.33 |
| weights | w500–w600 throughout | M3's w400 / w500 |

**It is built rather than left null on purpose**: the sub-themes below it derive their own styles
from a `TextTheme`, and this is exactly what `ThemeData` would have computed — the typography for
the platform, the set matching the brightness, and `onSurface` already applied as body and display
colour because `Typography.material2021` is handed the `ColorScheme`. Verified from inside a
pumped tree, where the geometry is actually merged: **36/24/22 · 16/14/12 · 14/12/11**, M3 heights,
M3 weights, text still `onSurface`.

**What it cost the page**, same fixture and window as before:

| | before | after |
|---|---|---|
| Combat band | 219 | **228** |
| columns start at | 409 | 439 |
| left column ends | 1,969 | 2,013 |
| minimum window | 1,260 × 160 | **1,260 × 180** |

**About 2–4 %, which is less than the +10 % on `bodyLarge` suggests** — because the sheet's
secondary text did not grow: `bodySmall` went *down* (12.5 → 12) and the two label roles the tags
use are unchanged at 12 and 11. Primary text is bigger, secondary text is the same or smaller, and
the page is barely taller.

⚠️ **`iconTheme` was left at 20** against Material's 24. The ask was font sizes; icons are a
separate call, and 24 would grow every chrome row.

⚠️ **This is the first production change in this branch that is not a behaviour-preserving
extraction.** It touches the home screen, the character sheet, the character-file editor, creation
and both spikes. 844 + 399 still green, `analyze` clean, `dart format` a no-op, zero suppressions —
but the suite cannot see type: the two defects this project has shipped from text metrics were both
found by looking at a capture. **Worth a look at the home screen and the creation flow, not only
the spike.**

---

## G2 deleted — G1 is what D19 decides on

**2026-08-15.** The user looked at the built pages, kept shaping G1 over eleven changes, and then
**asked for G2 to be removed.** So the comparison this brief was written to set up did not happen:
D19 is no longer a choice between two arrangements, it is a judgement on one page.

**Deleted:** `g2_ledger_grid.dart`, `unified_find.dart`, and the second button on the home screen's
debug block. Three things G2 alone kept alive went with it — `spikeChrome`'s `onFindings`
parameter, `InventoryPanels.query`, and the second entry point.

**Kept, because G1 inherited it:** `MemberSwitcher`. G1's party band is G2's widget — written for
the ledger grid, reused when G1's party column became a band, which is why there was never a
question of two switchers lighting up for different drops.

⚠️ **One thing left behind, and it is small but real.** `command_palette.dart` was made partly
public *for* G2's unified find — `subjectsMatching`, `PaletteRow`, `PaletteEmpty`,
`canOpenSubject`. Every one still has a caller inside its own file, so nothing is dead and nothing
lints, but four symbols are public with no external user. **Left public deliberately**: a merged
page that wants a find again is the most likely next request, and re-privatising and un-privatising
is more churn than the smell is worth. Worth knowing rather than worth fixing today.

### What G1 is, for whoever evaluates it next

```
┌──────────────────────────── PARTY BAND ────────────────────────────┐
│ Conan · Fighter 1 · 325 XP  [Con][Imo][Jah][Kha][Xza]  ⚑3 ↶ ↷ Save │
├────────────────────────────────────────────────────────────────────┤
│ Combat            (three columns, full width, top of the scroll)   │
├───────────────────────────────┬────────────────────────────────────┤
│ Character  … Fatigue · Intox. │ Inventory  ⌕ Find an item · 4 × 4   │
│ Abilities                     │ Equipped                           │
│ Resistances  [pills]          │ Proficiencies                      │
│ Skills                        │                                    │
│ In no slot                    │                                    │
└───────────────────────────────┴────────────────────────────────────┘
             ↕ ONE scrollbar moves the whole page
```

**Eleven changes to the page and one to the theme, all the user's, all made after seeing it built**
—
and **none of them what the study derived on paper.** `planning/tool-first-study.md`'s walkthrough
scores (W-A2, W-A6, W-C1, W-X1) and its R1/R5 requirements describe a page that no longer exists.
Read this section, not those scores.

⚠️ **Change 0 was not the user's instruction but their answer to a blocking question**, and it is
the one that made everything after it possible: the band the brief specified could not be built.

| # | change | the finding |
|---|---|---|
| 0 | the pinned numbers band became a **compact** rendering | Combat 934 + Resistances 604 + Condition 163 = **~1,700 pt** as the sheet draws them, against an 860 pt window. The band could not exist as briefed |
| 1 | party column right edge → left edge | spends **W-A2**'s margin, which was G1's only win on the manipulation flow |
| 2 | the fast bench's two parts merged, items on top | unpins the numbers. Minimum window **940 × 740 → 720 × 300** — the pin had been bought at the price of the thing it sat above (78 pt of backpack at 1280 × 860) |
| 3 | the middle and right columns merged | ⚠️ **built wrong first** — read as *stack them*, which put the inventory 1,438 pt down (≈2,500 with real proficiencies). Rebuilt as one page in two columns: **780 × 300**, backpack above the fold |
| 4 | Proficiencies → right; In-no-slot and the numbers → left | columns **2.1 : 1 → 1.48 : 1**. ⚠️ Every earlier height figure had run on an *empty* proficiency catalogue and so had no Proficiencies panel at all |
| 5 | the party column became a band across the top | **880 → 1,260** minimum width, the first time G1 asked for more than the app's own 900 pt floor. G1 inherits **G2's** switcher, so **W-X1** stops being an axis |
| 6 | Condition folded into Character; Resistances under Skills; Combat a full-width band in three columns | columns to **1,802 / 1,622**. `sheetPanelsOf` gained `foldInto` so the production sheet keeps its Condition panel |
| 7 | the field-and-proficiency palette removed | settles **R5** — the deepest question the spikes existed to put — by deletion. The record cannot be searched, and the findings badge loses its destination |
| 8 | Combat moved from the page's foot to its head | ⚠️ **the smallest change and the largest effect: R1 is back.** The numbers open the page, 20 pt above the backpack, at every window height — and it cost nothing |
| 9 | Resistances above Skills | a resistance is something the character *is*, like an ability score |
| 10 | the type scale returned to Flutter's *(production)* | the base was **already right** — `bodyMedium` 13.5 against this desktop's 13.33 px. What was under platform size was the small end. Page +2–4 % |
| 11 | **Equipped became a slot grid** | ⚠️ **a list of nothing is nothing; a grid of nothing is capacity** — so the panel now draws even when nothing is worn, reversing a rule a test pinned. See the section below |

**Four things about it are deliberate and will look like defects to a fresh eye:**

1. **No way to search the record.** One find, over the item catalogue. The findings badge counts
   and does not navigate, because the palette was where it went.
2. **Two densities on one page.** Character, Abilities, Skills, the inventory and Proficiencies are
   full panels; **Combat and the Resistances are compact** — a leftover from the pin that now only
   buys a shorter scroll. Making the page uniform is a one-line change either way.
3. **The columns do not balance themselves.** 2,013 against 1,995 at the fixture measured — near
   level, but by two named blocks having been moved, never by an algorithm. Balancing by height is
   D17's zigzag.
4. **The party band sets a 1,260 pt minimum width against the application's own 900 × 600 floor**
   (`linux/runner/my_application.cc`, untouched). A window can be dragged narrower than the page
   needs and the band will overflow. `min_width` wants raising to about 1,280 — one line, reserved
   for the user by this brief.

### Renamed — `G1MergedPage` in `g1_merged_page.dart`

⚠️ **`Two benches` named a structure the page lost at change 2**, which is the stale-comment defect
this project treats as a bug report. The descriptive half is replaced; **`G1` is kept as a lineage
marker**, because the study, this brief, the commit trail, the memories and D19 all address the page
by that token and severing it would leave the next session unable to connect the page to its own
build report.

**What D19 should call the arrangement is "the merged page."** Every other candidate considered —
*the Record* (the game's own word, but it names only half of what is merged), *the Workbench page*
(D15 already uses Workbench for the whole UI), *the banded page*, *one page two columns* — names
part of an arrangement that moved ten times in a day. The **merge** is the decision, and it never
moved.

### Equipped became a slot grid — ⚠️ and it changed a tested behaviour

**Eleventh change, the user's, and the first that alters what a test pinned.**

Equipped was a list of only what is worn, each row led by a tag naming its slot. It is now **the
same grid the backpack is**: `BackpackGrid` became **`SlotGrid`**, taking the run of slots to draw,
and `InventoryCell` gained an always-drawn `slotLabel`. Two groups, one cell widget, one grid
widget — the alternative was a second rendering of an item, which is the disease this project keeps
paying for.

- **Twenty-two cells, in an authored order** (`equipmentSlots`): the worn things, the four weapons,
  the four quivers, the three quick slots, then the magic-weapon slot the engine fills itself.
  ⚠️ **Not the record's order** — `CreItemSlot` stores the cloak between quiver 4 and quick 1.
- **The backpack's cells stay unlabelled.** Its sixteen slots are interchangeable and the game
  calls all of them *Inventory*; a caption on each would be the panel's heading said sixteen more
  times. An equipment slot is the opposite — *Helmet* is the only thing telling one empty cell from
  the next.
- The last row is padded, so two leftover cells do not stretch to half the panel each.

⚠️ **`no Equipped panel when nothing is worn` was a test, and it is now the reverse.** The
reversal follows from the grid rather than overriding it: a *list* of nothing is nothing, so hiding
the panel was right; twenty-two empty *cells* say **these are the places things go and all of them
are free**, which is exactly what the sixteen backpack cells have always said. The test now pins
the new rule and carries the reason.

⚠️ **This changes the production inventory screen too**, not only the spike — `CarriedSections` is
shared, and giving the spike its own Equipped rendering would have been the second copy. That
screen is due for deletion in the merge slice anyway.

⚠️ **One thing a capture should be looked at for**, surfaced by a test: an **unidentified Belt of
Antipode in the backpack now puts the word "Belt" on screen twice** — once as the item's own name
(the engine draws the plain name when the identified flag is clear) and once as the empty *Belt*
equipment slot's caption. Not wrong, but it reads oddly, and it is the kind of thing only looking
settles.

**Still owed:** the captures, and D19 itself. `analyze` clean, `dart format` a no-op, zero
suppressions, **844 + 399 green**, branch `spike/grid-variants`, not pushed, no PR.

---

## The evaluation's decisions — 2026-08-15

The review session put its critique to the user as eight questions, and every one was answered.
**This section is the approved work package for the next builder session** — the resolutions are
decisions, not suggestions; a necessary deviation is a question to bring back.

| # | criticism | decision |
|---|---|---|
| 1 | empty equipment cells promise an operation that does not exist | **Tone empty equipment cells down** until equip exists, and **remove the Magic weapon cell**. Future contract recorded: equip/unequip arrives as **drag/drop + menu** with the Recalculate Stats phase |
| 2 | the findings badge counts and cannot navigate | **Remove the badge from the page.** A discrepancy-finding aid is a feature deliberately not being built now |
| 3 | the record cannot be searched | **Stands as designed.** The whole picture is the index — the user scrolls to see everything, so field jumping serves nothing |
| 4 | drags must start sideways while the targets sit above | **Vertical affinity on this page** — the party is *up*, and the equipment slots are *down* as future drop targets. Per-surface parameter; the production screen's left rail keeps horizontal |
| 5 | two densities, unstated | **Compact everything.** The whole page renders in the compact style, Proficiencies included. ⚠️ Knowingly spends the recorded sums-on-screen preference — the arithmetic lines move behind the tap, into the editor. Spent, not overlooked |
| 6 | the new surfaces carry no Semantics | **A merge-slice requirement**, written: every cell and switcher tile carries a Semantics label. The spike stays as-is |
| 7 | the 1,260 pt band vs the 900 pt window floor | **Undecided, on purpose.** Recorded open; the merge slice forces it |
| 8 | the type scale changed production sight-unseen | **Accepted sight-unseen** — the user's call against the recommendation, recorded as accepted risk (both prior text-metric defects were capture-found) |

Fixed by the review session on this branch, being plain bugs by the project's own doctrine: the
stale autofocus comment in `g1_merged_page.dart` (it described the removed palette), and the
quick-item captions now carry the game's own casing — **"Quick Item"**, exactly as strref 12012
spells it — with the pinning test updated.

### The work package, itemized

1. **Compact everything** (`g1_merged_page.dart`, spike-only): every panel renders through
   `CompactNumbers` — Character, Abilities and Skills as **lines** (they carry in-game values);
   Resistances stays **pills**; **Proficiencies as flowing pills carrying the name and its pips**
   — keep the dot language, drawn small, never a bare numeral. The head band, the two columns and
   the single scroll stay exactly as they are; only the panel renderings change. Inline editing
   must keep working from every compact row.
2. **Tone empty equipment cells** (`SlotGrid`/`InventoryCell`, production-shared): an empty,
   captioned cell draws on the unlit plate (the `ScreenTone` mechanism the sheet uses for
   unavailable fields) with a muted caption; filled cells unchanged. One rule in one place — the
   production Equipped grid gets it too, because the promise-gap exists there as well.
   **Test-first: this is production behaviour.**
3. **Remove the Magic weapon cell**: drop `CreItemSlot.magicWeapon` from `equipmentSlots`
   (21 cells; the last row pads). ⚠️ **An item the engine has put in that slot must still
   surface** — `CarriedSections` counts it as worn, and a slot missing from the drawn list would
   make it silently invisible, the exact trap the seed recorded. The rule to build, test-first: a
   **filled** magic-weapon slot draws its cell; an empty one draws nothing.
4. **Remove the findings badge** from the spike chrome (`grid_spike_host.dart`, spike-only).
5. **Vertical drag affinity on this page**: `CarriedSections` gains a drag-affinity parameter
   defaulting to `Axis.horizontal` (production unchanged — test-first on the default); the merged
   page passes `Axis.vertical`. Rewrite the "portraits are to the LEFT of here" comment to cover
   both geometries.
6. **Mark unidentified items at glance distance** (`InventoryCell`, production-shared) — the
   user's resolution of the Belt/Belt collision, decided 2026-08-15: an unidentified item is a
   **valid state the record already holds**, so the cell says so visibly — the item's *name*
   takes a distinct treatment (muted or role-coloured per the theme's meaning-bearing rules — a
   role colour, never another surface tone), in addition to the existing `unidentified` tag chip.
   One rule, one place; the caption collision then dissolves because a slot caption and an
   unidentified item stop reading as the same kind of word. **Test-first: production behaviour.**
7. Definition of done unchanged: `analyze` clean, `dart format` a no-op, both suites green, zero
   suppressions, commits on this branch, **not pushed**, a report appended here, the app left
   running for the captures.

### The captures, superseding the earlier list where they overlap

1. The full page, compact everywhere, at ≥1,260 wide and once at 900 (the band's overflow).
2. Empty equipment cells toned — beside filled ones, and beside the backpack's untoned empties.
3. Mid-drag, twice: backpack → band portrait (the vertical start), and backpack → a toned
   equipment cell, where nothing should invite the drop yet.
4. The unidentified belt beside the empty *Belt* slot caption — now verifying the collision
   **dissolves** under the glance-distance marking, rather than asking whether it matters.
5. An inline editor open from a compact row, once per column.
6. Dark and light of the same view.

---

## Build report — the evaluation's eight decisions, executed 2026-08-15

**All seven items of the work package are done.** `fvm flutter analyze` clean, `dart format` a
no-op across 240 files, **853 app tests + 399 format tests green**, zero suppressions (the D8 grep
returns nothing), six commits on `spike/grid-variants`, **not pushed, no PR**. The app is running
on Linux and is waiting for the captures.

**853, up from 844**, and all nine new tests are **production** behaviour written test-first — the
spike's own eight were written, run green and deleted, as the recorded practice for a screen that
is about to be deleted.

| # | decision | where it landed |
|---|---|---|
| 1 | compact everything | `compact_numbers.dart`, `g1_merged_page.dart`, `pip_meter.dart` — spike, plus one behaviour-preserving extraction |
| 2 | tone empty equipment cells | `InventoryCell` — **production**, test-first |
| 3 | remove the Magic weapon cell | `equipmentSlots` + new `equipmentSlotsFor` — **production**, test-first |
| 4 | remove the findings badge | `spikeChrome` — spike |
| 5 | vertical drag affinity on this page | `CarriedSections`/`InventoryPanels` — **production** default unchanged, test-first |
| 6 | mark unidentified at a glance | new `ItemName` — **production**, test-first |
| 7 | definition of done | below |

### What the page is now

```
┌──────────────────────────── PARTY BAND ────────────────────────────┐
│ Conan · Fighter 1 · 325 XP  [Con][Imo][Jah][Kha][Xza]   ⚖ ↶ ↷ Save │
├────────────────────────────────────────────────────────────────────┤
│ Combat   THAC0 (base) 20 │ Save vs. death 14 │ AC crushing 0  …    │
├───────────────────────────────┬────────────────────────────────────┤
│ Character  … Fatigue · Intox. │ ⌕ Find an item                     │
│ Abilities                     │ Inventory   4 × 4, sixteen cells    │
│ Resistances  [pills]          │ Equipped    21 cells, empties unlit │
│ Skills                        │ Proficiencies                      │
│ In no slot                    │  ⟨Long Sword ●●○⟩ ⟨Axe ●●○⟩ …      │
└───────────────────────────────┴────────────────────────────────────┘
             ↕ ONE scrollbar moves the whole page
```

Every panel is drawn compactly. The head band, the two columns and the single scroll are exactly
where they were; only the renderings changed.

### 1 — Compact everything

**Character, Abilities and Skills are lines**; **the Resistances are pills**; **Combat keeps its
three columns of lines** at the head. `sheetPanelsOf` is no longer called by this page at all —
`CompactNumbers` gained the `foldInto` parameter it needed (so Condition still folds into
Character) and it now reads the same projection directly.

**Proficiencies are flowing pills, and the dot language survived intact.** ⚠️ **`PipRow` is
extracted out of `PipMeter`** — same dots, filled/empty/surplus/ceiling, with a `pipSize`
parameter defaulting to today's 13. A second rendering of *what a pip means* is the recurring
defect this project pays for, so there is one copy and the pill asks for it at 8.

**What a pill drops, and why each is safe:**

| dropped | why |
|---|---|
| the `2/5` numeral | the dots *are* the reading; a numeral beside them is the picture said twice |
| `at ceiling` | a pill whose dots are all filled is at its ceiling — the dots say it |
| `not for this class` | a `0/0` proficiency draws **no dots at all** and goes muted, which is the dot language's own way of saying there is nowhere to go. ⚠️ The ceiling mark alone would have read as a limit *spent* |
| **nothing else** | ⚠️ **`over ceiling` keeps its word.** It is a conflict, and a conflict a reader has to infer from a red dot is one this project would ship |

⚠️ **What the whole compaction spends, named rather than discovered later.** A full row carries a
second line — the arithmetic **with its amount**, the two limits under D16, the ⓘ, the finding's
own sentence. All of it is now one tap away in the editor. That is the recorded sums-on-screen
preference, spent deliberately, exactly as decision 5 says.

**What it does not spend**, and all four are pinned by the throwaway suite:

- **the group's own note** — *"Fighter/Mage has no thief skills — the greyed rows are what the
  class cannot allocate."* It is not arithmetic and it is not per row; it says what a whole panel
  means. `CompactNumbers` now carries `group.note` through to the card.
- **the unlit plate** on a row the class cannot allocate.
- **the finding's coloured left rule**, in place, on the row it is about.
- **inline editing from every row**, in either column and in the head band.

### 2 · 3 · 5 · 6 — the four production changes, each test-first

**Empty equipment cells are drawn unlit.** An empty cell that *names its slot* now sits on the
`ScreenTone` plate — the same widget the sheet puts an unavailable field on. It still says where a
helmet goes; it no longer offers to take one. ⚠️ **An empty backpack cell stays lit**, and that is
the whole distinction: its emptiness is capacity, and adding really does put an item in one today.

**The Magic weapon cell is gone — and `equipmentSlotsFor` is why that is safe.** Dropping a slot
from the drawn list does not hide a caption, it hides an *item*, silently, on a screen whose only
job is to show the record. So the drawn list is `equipmentSlots` **plus any slot the record
actually occupies that the authored list does not name**. Today that is exactly `magicWeapon`,
which appears only when the engine has filled it; the rule is written against any omission,
because the failure it prevents cannot be seen. Twenty-one cells, last row padded.

**Drag affinity is a per-surface parameter.** ⚠️ It is a trade in both directions, not a fix:
Flutter's own note on `Draggable.affinity` is that a vertical draggable "will out-compete the
Scrollable for vertical gestures". `Axis.horizontal` — the default, and the pushed inventory
screen's, unchanged — buys a scrollable list at the price of a sideways pull. `Axis.vertical`,
which the merged page passes, buys the natural pull towards a party band overhead **at the price
of scrolling by dragging an item**. ⚠️ **The merged page is one long scroll, so that price is
real: a pull that starts on a backpack cell picks the item up rather than scrolling the page.**
Worth a look during the captures; it is the decision as written, not a deviation.

**An unidentified item's name carries a role colour.** `ColorScheme.tertiary` — the ink this
application already uses for *worth knowing, and not wrong*, and a **role** colour rather than
another surface tone, which is the theme's own rule for anything meaning-bearing. The
`unidentified` chip stays beside it, because colour alone says nothing. ⚠️ **One rule in one
widget**: `ItemName` serves the grid cell **and** the In-no-slot row, which sit in *different
columns of this page* — a mark reaching only one of them is the second, wrong copy this project
keeps paying for. That is one line wider than decision 6 asked for and is stated here rather than
done quietly.

### 4 — the findings badge

Gone from `spikeChrome`, and `GridSpikeModel.findings` went with it — no other caller.
⚠️ **What did not go: a finding still marks its own row**, in place, with the coloured rule and
the sentence in the editor. That is the sheet's own rendering, shared with production, and it is
where a finding was always most use. Only the *count with nowhere to go* was removed.

### Measured — with the installation's real twenty-four proficiencies

⚠️ **Every earlier figure in this report except the last two rounds ran with a synthetic
catalogue.** This one did not: `weapprof.2da` was read out of the player's own copy on
2026-08-15 — ids 89–115, twenty-four live rows, every FIGHTER_MAGE cap 2 except `2WEAPON`'s 3 —
and all twenty-four names were resolved against the real talk table (strrefs 25000–25023). A
fixture with short invented names under-measures a column of pills.

⚠️ **Widths are still over-estimates**: `flutter test` draws with a font whose every glyph is a
full em square, so labels wrap earlier than they will on screen. Heights are close to true.

**At 1,700 × 1,400, six-member party, no items carried:**

| panel | compact | the full rendering, same 788 pt width | saved |
|---|---|---|---|
| Character *(+ Condition folded)* | **230** | 309 + 183 | 262 |
| Abilities | **254** | 472 | 218 |
| Resistances | 120 *(already pills)* | 624 | — |
| Skills | **330** | 575 | 245 |
| Combat | 228 *(already compact, 3 columns)* | 935 | — |
| **Proficiencies** | **288** | **1,046** | **758** |

| | before | after |
|---|---|---|
| left column | 439 → 1,963 = **1,524** | 439 → 1,409 = **970** |
| right column | 439 → 2,673 = **2,234** | 439 → 1,895 = **1,456** |
| the page's own height | **2,673** | **1,895** — 29 % shorter |
| minimum window | 1,260 × 180 | **1,260 × 180**, unchanged |

⚠️ **The minimum window did not move, and that is decision 7 standing open.** The party band still
sets it — identity 300 + six portraits + chrome — against the application's own 900 × 600 floor in
`linux/runner/my_application.cc`, untouched. A window can still be dragged narrower than the page
needs and the band will overflow. Removing the findings badge bought nothing here; the portraits
are what costs it.

### ⚠️ Compacting flipped which column is longer, and that unmakes change 4

**The right column is now half again the left: 1,456 against 970.** Before today it was the other
way about.

This is the arithmetic behind it. Change 4 moved Proficiencies to the right column *because it was
the one block big enough to balance a record column twice the height of the items*. As pills it is
**288 points rather than 1,046** — a quarter of what it was — so the reason it went right no
longer exists, and the swap now unbalances the page in the opposite direction.

⚠️ **And one of the numbers change 4 was justified by is stale.** This report's earlier
"2,013 against 1,995 — near level" was measured **before change 11 made Equipped a slot grid**.
Twenty-one cells is **622 points** that appeared in the right column and was never re-measured, so
the columns were already about 2,013 : 2,633 by last night.

**The single move that balances it, if the user wants it: send Proficiencies back to the left
column.** 288 + a 20 pt gap = 308, which lands it at **1,278 left against 1,148 right — 1.11 : 1**,
the closest any one move gets. The left column would then read Character · Abilities ·
Resistances · Skills · Proficiencies · In no slot, which is also the sheet's own authored order.
**Not done unasked** — the map is authored and it is the user's, and balancing by measurement
rather than by an algorithm is the whole point of doing it by hand.

⚠️ **What compaction cannot touch is why the right column is long at all**: 438 + 622 = **1,060
points of slot grid**, which is 73 % of that column and is 37 empty-or-filled cells drawn at
their `minHeight: 84`. No density change reaches it.

### A defect the measurement found on the way

⚠️ **A `Wrap` hands every child the run's full width and no less**, so a pill wider than the
column overflows rather than wrapping — and *Scimitar / Wakizashi / Ninjatō* is a real BG:EE
proficiency, twenty-nine characters. It overflowed by 41 points in a narrow window. The pill's
**name** is `Flexible` with an ellipsis now; the dots are never the thing that gives way. This is
the same fix `Tag` already documents, and it is only visible at a window narrower than the
comfortable one — which is exactly the window a capture at the 1,260 floor will show.

### What was proved before hand-over

⚠️ **The window is native Wayland and this session cannot drive or capture it**, so the
interactions were exercised as throwaway widget tests over a synthetic six-member savegame, run
green, mutation-checked, and deleted. All eight passed:

- every panel is compact, Condition is folded into Character, **no arithmetic line anywhere on the
  page** — and the Skills group note *is* there, with the unlit rows under it;
- proficiencies are `PipRow` pills and **no `PipMeter`**, no `2/5` numeral, `over ceiling` present
  once, and a `0/0` proficiency draws no dots;
- a compact row edits beneath itself in **both** columns — `Strength` on the left, `Flail /
  Morning Star` on the right — with `SubjectEditor` and **no** `SideSheet`;
- a head-band number (`THAC0 (base)`) opens the editor, `20 → 19` applies, and Save goes live;
- no `FindingsBadge` anywhere;
- an added item is a `Draggable<ItemDrag>` with **`affinity: Axis.vertical`** and a
  `MemberSwitcher` above it;
- no `Magic weapon` caption, `Helmet` present;
- exactly one `Scrollbar` on the page.

⚠️ **Two of them were mutation-checked**, because a test that passes the moment you write it is
the failure mode this project records: deleting the panel note reddened the note assertion, and
forcing `unavailable` false took the `PipRow` count from 2 to 3. One earlier version of the
editing test was a **false green** — the proficiency pill was below the fold at that viewport, so
the tap missed and the assertion was answered by the editor the previous line had opened. Fixed
with `ensureVisible` and an assertion that the editor is the *proficiency's*.

### Still owed

**The captures, and D19 itself.** The list in the section above stands. Two things to look at
particularly, both consequences of decisions rather than defects:

1. **Scrolling by dragging a backpack item no longer works** — the vertical affinity spends it.
2. **The right column is now the long one** — see the arithmetic above, and the one move that
   would fix it.

---

## Twelfth change — proficiencies read in the game's own weapon classes

**2026-08-16, the user's: a tabbed view of the proficiencies, one tab per weapon type and one for
style.** Asked with three groupings previewed; the user chose **the game's eight types + Style,
nine tabs**, which is the option whose caveat was that the assignment would have to be measured.

### ⚠️ It nearly had to be invented, and then it did not

**No table states it.** `weapprof.2da` has no type column. `itemtype.2da` is two sounds and a slot
number. `clasweap.2da` has the eight names — `SMALL_SWORD`, `LARGE_SWORD`, `BLUNT`, `MISSILE`,
`BOW`, `SPIKED`, `AXE`, `SPEAR` — but only as **columns**, saying which classes may use each; it
never says a Katana is a Large Sword. That is the shape of a rule this project would have written
by eye, which D13 forbids.

**Three sources together do state it, and the first is the game's own prose.**

1. ⚠️ **The obsolete BG1 rows describe themselves.** `weapprof.2da` still carries ids 0–7 — the
   same eight names — and each one's `DESC_REF` is a sentence naming the weapons it covers.
   Resolved against the player's own talk table:

   | strref | the game's sentence |
   |---|---|
   | 9589 | LARGE SWORD: "Bastard Swords, Two handed swords, Long Swords, and Scimitars" |
   | 9590 | SMALL SWORD: "Daggers and Short swords" |
   | 9591 | BOW: "Longbows, Composite Longbows, and Shortbows" |
   | 9592 | SPEAR: "Spears and Halberds" |
   | 9593 | BLUNT WEAPONS: "Maces, Clubs, Warhammers, and the Staff" |
   | 9594 | SPIKED WEAPONS: "Morning Stars and Flails" |
   | 9595 | AXE: "Battle axes and Throwing axes" |
   | 9596 | MISSILE WEAPONS: "Slings, Darts, and Crossbows" |

   **Nineteen of the twenty live weapon proficiencies are named outright.** The one placement a
   reader would most likely dispute — is a Crossbow a *Bow* or a *Missile*? — the sentences settle
   flatly: Missile.

2. **The shipped items place the twentieth.** BG1 had no katanas, so no BG1 class names one. Every
   `ITM V1` header carries both its `ITEMCAT` category (`0x1c`) and its weapon proficiency
   (`0x31`), and a sweep of **all 1,530 items BioWare ships** puts all four katanas in `BGSWORD`,
   the category of every bastard, long and two-handed sword. Weaker evidence than a sentence, so
   it carries its own test saying so.

3. **The same sweep corroborates the other nineteen** — one category per proficiency, with two
   instructive exceptions. `Flail / Morning Star` spans `FLAIL` and `MSTAR`, exactly as its own
   name says; and three of the twelve scimitar-family items are catalogued `SMSWORD` rather than
   `BGSWORD` — the wakizashi and ninjatō, which are short blades. The sentence settles both.

⚠️ **And the sweep found something else: `SLAYSH01` claims proficiency 116** — `EXTRA2`, a
**padding** row, with `ITEMCAT` category `MISC`. D18's measurement was over the 2,253 *creature*
records and found nothing in the padding band; this is the first observed use of one, in an
**item**. It changes nothing here (no character can have it offered) but it is the second time a
padding id has turned up in real data, and it is recorded rather than filtered away.

**Where it lives:** `WeaponClass` in `lib/domain/proficiency_catalogue.dart`, beside
`ProficiencyCatalogue.live` — the D18 measured constant it most resembles. **Production, test-first:
six tests, one of which was mutation-checked** (dropping Club from Blunt correctly made it appear
in the residual).

### ⚠️ The four styles are in NO class, and that is load-bearing

`WeaponClass.of` answers `null` for a style — and also for an obsolete row, a padding row, or any
id a future table introduces. **The last tab holds everything unclassified**, so a proficiency this
code cannot place is visible rather than in no tab at all. A test pins that, for the shipped table,
the residual is exactly ids 111–114.

"Style" is the one label the game does not state as a class name. It is **borrowed rather than
coined** — the word is in all four of those proficiencies' own names, and `stylbonu.2da` is the
table that gives them their bonuses.

⚠️ **One label is not its `NAME_REF`.** 8732 resolves to *"Short Sword"* — which is also live
proficiency 91 — so a heading reading "Short Sword" over a group containing "Short Sword" and
"Dagger" would state something untrue. The class's own description heads itself **"SMALL SWORD"**,
so that is the word used. Still the game's, and unambiguous.

### ⚠️ Tabs hide things, and one of the things they hide is a conflict

This was raised before building rather than discovered after. The page has **no findings badge and
no way to search the record**, both decided yesterday, and both rest on the page drawing everything
at once. Tabs break that premise for the one panel that can carry a conflict.

**So a tab whose group holds an over-ceiling proficiency marks itself** — an error-role icon on the
tab, with the *word* in its `Semantics` label, and the `over ceiling` chip still on the pill one tap
away. Pinned by a test that puts the conflict on an **unselected** tab.

**Not done, and offered rather than taken:** opening on the conflicted tab instead of the first.
It would make the conflict unmissable and it is two lines, but it is a surprising default and it
was not asked for.

### Measured, same fixture and window as the rest of this report

| | |
|---|---|
| Proficiencies panel | **174** tall — down from 288 as one flowing run, and 1,046 as full meters |
| right column | 1,456 → **1,274** |
| left column | 970, unchanged |
| the columns | 1.5 : 1 → **1.31 : 1** |

**So tabbing did most of the rebalancing the previous section asked for**, without moving a block.
Sending Proficiencies back to the left column — the move that section proposed — would now
*overshoot*: 1,144 against 1,100 is still an improvement, but the case for it is much weaker than it
was this morning. ⚠️ **That is the second time today a layout decision has been undercut by a later
measurement**; it is the same lesson as the stale 2,013 : 1,995 figure.

⚠️ **The one thing a capture must settle: the tab strip is wider than its column.** Nine tabs
measure **1,128** points of content in a **756**-point column — 372 off the end, about a third of
them behind a horizontal scroll. But this is `flutter test`'s em-square font, where widths are
over-estimates by roughly a third, so on screen it may fit or may not. **Look at it.** If it does
not fit, the options in order of honesty are: two rows of tabs; shortening the three "… Weapons"
labels to `Blunt` · `Spiked` · `Missile` (a departure from the game's words, but only a trim); or a
different control entirely.

Re-proved as throwaway tests, run green and deleted: nine tabs in the game's order and words; only
the chosen tab's proficiencies drawn; choosing Missile Weapons shows Sling/Dart/Crossbow and hides
Bastard Sword; the Style tab holds exactly the four styles; an unselected tab holding a conflict
marks itself while the word stays on the pill; **editing a pip does not throw you back to tab one**;
and a pip edit applies with Save going live. `analyze` clean, `dart format` a no-op, **859 + 399
green**, zero suppressions.

⚠️ **The tab taps missed on the first run** — the strip scrolls, the later tabs were off-screen, and
Flutter reports that as a *warning* rather than a failure. Two of the seven tests were false greens
for a minute. That is the same trap recorded yesterday, hit again the next day: `ensureVisible`
before every tap.

### One more for the capture list

7. The nine-tab strip: does it fit the column, or is a third of it behind a horizontal scroll?
   And the conflict mark on a tab — make Two-Weapon Style over its ceiling to see it.
