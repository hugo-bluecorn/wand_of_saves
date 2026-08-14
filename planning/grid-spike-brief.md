# Build brief — the two grid spikes, G1 and G2

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
