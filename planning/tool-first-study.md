# The tool-first study — deriving the merged page from function

**2026-08-14.** The user challenged the provenance of D15's option space: three spikes authored
by one model from one prompt lineage are three samples from one prior — the canned Material
desktop grammar — not three explorations of design space. Picking the best of three siblings is
not choosing a design. This study is the corrective: **no layout exists until the function
inventory below is corrected by the user**, every structural choice must name the task that
justifies it, and model memory is demoted from generator to compiler.

## The gates, answered by the user 2026-08-14

1. **Form source: tool-first.** A deliberate break from BG:EE's and EE Keeper's UI/UX. The
   game-as-form-oracle route (reading `UI.MENU`, echoing the paper-doll) and the EE Keeper
   reference were both offered and both declined. The layout derives from tasks and
   co-visibility alone.
2. **Flows to optimize, in the user's own selection**: inventory manipulation, quick field
   edits, full-character audit. The create/export round-trip was *not* selected — it stays
   correct but does not drive layout; creation is untouched by this study.
3. **EE Keeper: ignored** — not even as a usability reference.
4. **Session shape: both, evenly.** One-character-deep and whole-party passes are equal;
   the layout must not privilege either. Member switching is a first-class, zero-cost action.

Standing constraints from the same day: **the page is a fixed grid** — cells sized by content,
positions an authored map, nothing rearranges on resize (no `MediaQuery`/`LayoutBuilder`; raise
the minimum window if the grid needs it; vertical scrolling only). And the function-derived
invariants survive any form: D16's verdicts, the label doctrine, the command/undo model, the
semantics work.

## The task inventory — DRAFT, for the user's correction

Frequency marks are guesses (`???`) where only the user knows. A task the user strikes or adds
changes the derived requirements, so correct this before the variants are drawn.

### Flow A — inventory manipulation

| # | task | sequence today | must be co-visible | freq |
|---|---|---|---|---|
| A1 | add an item from the catalogue | search → Add → placed at first free slot | results · the backpack · capacity | ??? |
| A2 | give an item to another member | drag onto portrait, or menu → Move to | source pack · target member · target's room | ??? |
| A3 | rearrange within the backpack | menu → Move to (slot) | the 4×4 grid | low ??? |
| A4 | remove an item | menu → Remove | the item · undo affordance | ??? |
| A5 | inspect an item | hover/none (properties loaded, unrendered — §8 owed) | name · weight · price · type · description · identified | ??? |
| A6 | equip / unequip *(future, gated on Recalculate Stats)* | — does not exist yet — | **the item AND the numbers it moves (AC, THAC0, saves)** | the §8c driver |
| A7 | check weight vs capacity *(§8 owed)* | — does not exist yet — | total weight · `WEIGHT_ALLOWANCE` · Strength | ??? |

### Flow B — quick field edits

| # | task | sequence today | must be co-visible | freq |
|---|---|---|---|---|
| B1 | open → change one field → save → quit | open save → member → scan or Ctrl+K → row → side sheet → Apply → Save | the field · its verdict · dirty state | high ??? |
| B2 | set a proficiency's pips | Proficiencies panel → pips | ceiling · verdict | ??? |
| B3 | fix a save / resistance / skill | as B1 | stored · derived · in-game triplet | ??? |
| B4 | gold / XP / HP | as B1 (gold is party-level on a save) | — | ??? |

### Flow C — full-character audit

| # | task | sequence today | must be co-visible | freq |
|---|---|---|---|---|
| C1 | read the whole record | scroll seven panels in authored order | stored · derived · in-game per row, dense | ??? |
| C2 | find what's wrong | findings badge → palette (savegame editor only — review 3.8) | the findings · jump-to-row | ??? |
| C3 | compare intention vs engine | `in game` chips per row | the chip beside the stored value | ??? |

### Cross-cutting

| # | task | requirement |
|---|---|---|
| X1 | switch member | one action, both session shapes, state preserved — e.g. Imoen to Jaheira and back without losing place |
| X2 | undo/redo | one history across stat and item edits (already true — `EditSession`) |
| X3 | save with confidence | dirty state always visible; `.bak` behaviour unchanged |
| X4 | rules-check toggle | mode visible; verdicts respect the three kinds of wrong wherever they render |

## Requirements the draft already forces (revised when the inventory is corrected)

- **R1 — an always-visible numbers cell.** The values that *move* — AC, THAC0, saves, HP, weight
  — live in a dense cell that never scrolls away. It serves A6/A7 (watch the number change),
  B3 (edit against context) and C3 (the engine comparison), and it is the grid's anchor.
- **R2 — item grid adjacent to R1.** The §8c property by construction, not by scrolling.
- **R3 — field editing without leaving the grid.** Whether the side sheet survives tool-first is
  a variant question; the requirement is only that editing a field never hides R1.
- **R4 — a member switcher as a grid cell, equal-cost in both session shapes** (X1).
- **R5 — one find surface or two, decided by walkthrough.** Today fields and items have separate
  searches (palette vs. inventory field). A unified command surface is a genuine tool-first
  move; whether it wins is measured on B1 and A1 scripts, not asserted.
- **R6 — audit density without modes.** C1 must be readable in an authored order with no tabs
  and no collapsing — a mode switch is a walkthrough cost.
- **R7 — the fixed-grid mechanics**: authored position map, content-sized cells, raised minimum
  window, scrolling confined to designated cells (whether any cell scrolls at all is a variant
  axis).
- **R8 — findings and verdicts reach every surface** where an edit can happen (closes review
  findings 3.7/3.8 by construction).

## Method remaining

1. User corrects the task inventory (frequencies, missing tasks, struck tasks).
2. Walkthrough scripts written from the corrected inventory — one per flow, fixed step notation
   (actions, scrolls, eye moves, mode switches).
3. **Two grid variants derived from the same corrected inventory with different biases** —
   e.g. inventory-adjacency-biased vs. audit-density-biased; unified vs. split find — each
   element annotated with the task it serves. Scored on the scripts *on paper first*.
4. The two variants built with real data, fixed grid, captured. **The user's eyes close D19**,
   which then enters `planning/decisions.md` with this study and the review as its inputs.

The prep slice (`planning/inventory-merge-review.md` §7, slice 1) is layout-agnostic and may run
before or alongside all of this.

---

## The inventory as reviewed — and one refinement it forces

**2026-08-14, later:** the user reviewed the draft and changed nothing, so the task inventory
stands and the `???` frequencies become working assumptions: B1 high; A1/A2/A4/A5 and the C
tasks regular; A3 low; A6/A7 future but layout-reserved.

**R1 is refined before any drawing: the "always-visible numbers cell" must not be a summary
strip.** A strip showing AC beside a Combat panel also showing AC is the two-copies disease at
the layout level. R1 is satisfied by **placement** — the existing panels that hold the moving
numbers (Combat, Resistances, Condition) are *positioned* adjacent to the inventory and pinned,
so the number exists once and sits where the items are. This is what an authored position map is
for.

## Walkthrough scripts

Four costs, counted identically across variants — **S** actions (one click or key gesture),
**L** scrolls, **E** eye jumps between grid regions, **M** context losses (route push, dialog,
tab — anything that hides what the task needs; the §8c failure is an M by definition):

- **W-B1 quick edit** — open the save, set Imoen's Save vs. Spell 12 → 5, save.
- **W-A2 give** — move a Potion of Healing from Imoen's pack to Jaheira; end knowing it landed
  and that Jaheira had room.
- **W-A6 equip-watch** *(future control, scored now for adjacency)* — unequip Jaheira's armour;
  the armour-class change must be seen without any L or M.
- **W-C1 audit** — read Imoen's whole record, stored vs in-game, ending with the findings count.
- **W-X1 switch mid-task** — from Imoen's proficiencies, check Jaheira's, return; scroll
  positions preserved.

## The two variants, derived

Both: fixed grid, authored positions, content-sized cells, no reflow, no `MediaQuery`/
`LayoutBuilder`; scrolling confined to designated cells; minimum window raised (estimate
≈ 1280 × 860 — the spike measures the truth). Every cell names its tasks.

### G1 — "Two benches" · adjacency-biased

```
┌──────────────────────┬───────────────────────────┬──────────────┐
│ SLOW BENCH  [scrolls]│ FAST BENCH                │ PARTY   [X1] │
│                      │ ┌───────────────────────┐ │  ┌────┐      │
│ Character      [C1]  │ │ Combat · Resistances  │ │  │Imon│      │
│ Abilities   [B3,C1]  │ │ · Condition   PINNED  │ │  └────┘      │
│ Skills      [B3,C1]  │ │ [A6,A7,B3,C3]  never  │ │  ┌────┐      │
│ Proficiencies  [B2]  │ │        scrolls        │ │  │Jahe│      │
│                      │ └───────────────────────┘ │  └────┘      │
│ (field palette       │ item search        [A1]   │  identity    │
│  Ctrl+K jumps here   │ Backpack 4×4     [A1-A4]  │  save·undo   │
│  [B1])               │ Equipped           [A6]   │  findings    │
│                      │ In no slot   [scrolls]    │  rules  [X4] │
└──────────────────────┴───────────────────────────┴──────────────┘
```

- **The moving numbers are pinned at the top of the same column as the items** — W-A6 is E1/M0
  by construction.
- **The party column sits on the RIGHT, beside the inventory** — derived, not defaulted: the
  dominant drag (W-A2, pack → member) travels one column, not the full window. The
  left-rail convention lost to the task that actually uses the edge.
- **Editing is inline**: a selected row expands beneath itself (interaction-driven expansion is
  not resize reflow). Nothing ever overlays the fast bench. The side sheet retires.
- **Finds stay split**: field palette (Ctrl+K) over the slow bench, item search atop the fast
  bench.

### G2 — "Ledger grid" · audit-biased

```
┌────────────────────────────────────────────────────────────────┐
│ Imoen · Thief 5 · 343 XP   [Imon][Jahe][Mont]   ⌕ unified find │
│ [C1]                        [X1]                [B1,A1]  chrome│
├────────────────────┬─────────────────────┬─────────────────────┤
│ COLUMN 1  [scrolls]│ COLUMN 2   [scrolls]│ COLUMN 3   [scrolls]│
│ Character          │ Proficiencies  [B2] │ item results  [A1]  │
│ Abilities  [B3,C1] │ Combat   [A6,C3]    │ Backpack 4×4 [A1-A4]│
│ Skills     [B3,C1] │ Resistances         │ Equipped      [A6]  │
│                    │ Condition [A7]      │ In no slot          │
│ (side sheet slides │                     │                     │
│  over THIS column  │  [the moving        │                     │
│  only)       [R3]  │   numbers]          │                     │
└────────────────────┴─────────────────────┴─────────────────────┘
```

- **Three record columns visible at once** — W-C1 with minimal scrolling; the page reads left to
  right in the authored order.
- **Adjacency by column order**: the moving numbers (column 2) sit beside the items (column 3).
- **One unified find** in the top band, searching fields *and* items — the committed opposite of
  G1's split (the R5 axis is what these two variants disagree about most).
- **The side sheet survives** but is authored to slide over column 1 only — the slow column —
  never over the numbers or the items.
- **The switcher is horizontal in the top band** — X1 at constant cost from anywhere.

## Paper scores

Counted from the scripts; identical counting rules both sides. Not opinions — disagreements with
these counts are corrections to make.

| script | G1 | G2 | verdict on paper |
|---|---|---|---|
| W-B1 quick edit | S5 · L0 · E2 · M0 (palette → inline edit) | S5 · L0 · E2 · M0 (unified find → side sheet) | tie — the finds differ in kind, not cost |
| W-A2 give | S2 drag · E1 (pack → adjacent party column) | S2 drag · E2 (column 3 → top band) | G1, narrowly — after its derived right-edge party column |
| W-A6 equip-watch | E1 · M0 — number pinned in-column | E1–2 · M0 — number one column left | G1 |
| W-C1 audit | L2–3 across two benches · E3 | L1 across three columns · E2 | G2 |
| W-X1 switch | S1, positions kept | S1, positions kept | tie |

**G1 wins the manipulation flow; G2 wins the audit flow; the quick-edit flow cannot separate
them on paper.** Both proceed to build — which was always the method — with the scores telling
each spike what it must not lose while being itself.

## What paper cannot settle

1. **Unified vs. split find** — muscle memory, result mixing (a search returning both a *field*
   and an *item* named "Strength…"?), and whether one surface confuses more than it saves. The
   built spikes decide this; it is the variants' deepest disagreement.
2. **Inline editing vs. side sheet** — inline keeps context but grows the column; the sheet
   keeps rows stable but occupies a column. Feel, not counts.
3. **Whether the pinned fast-bench band leaves the backpack enough height** at the minimum
   window — a measurement, made by the spike.
4. **All eight capture questions from the review** remain open and several (fill visibility,
   selection fills) will be judged on whichever variant is built.

## Next

Build both variants as real spikes with real data (Conan's six-member save), capture both, and
the user's eyes close D19 into `planning/decisions.md`. That is implementation: **it opens in
plan mode, as its own phase.** The prep slice may still run first — it deletes the duplication
both variants would otherwise inherit.
