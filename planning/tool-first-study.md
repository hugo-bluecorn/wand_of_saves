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
