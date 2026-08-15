# The inventory-era review — conformance, findings, and the merge decision

**2026-08-14, on the Flutter 3.47.0 baseline, immediately after the inventory branch merged to
`main`.** This is the review `known-defects.md` §8c asked for before the next architectural step:
three whole-file review passes (MVVM and the provider graph against `context/`; the UI layer
against Material 3 and D15/D16/D17; the written record against the code), five captures of the
running app, and talk-table checks against the live installation. Ten load-bearing claims were
re-verified independently before entering this document; all ten held — the one miscount of the
day was the verifier's, not the reviewers' (the `CharacterStat` enum answers `values.length = 50`
where the record said 49).

**This document is the record of these findings.** Nothing here is copied into
`known-defects.md` — an entry moves there only if it is deliberately parked *after* the D19
decision below. A finding leaving this file means a fix, not a re-reading.

---

## 1 The state, assessed

The purpose holds as recorded: **a character editor** — the savegame is the medium, not the
subject — serving the four workflows, and the basic workflow is shipped and engine-verified
through a relocated save. The current state is `main` at Flutter 3.47.0 / Dart 3.13.0, 844 app
tests and 399 format tests green (re-run for this review), analyze and format clean, zero
suppressions in project-written code. The proposed next state is exactly what the record says it
is: an architectural decision about merging the character and inventory screens, which this
review was commissioned to inform. §7 is that decision.

## 2 What holds

The canon is not in trouble; most of what the record promises, the code does. Verified, with the
strongest evidence sites:

- **D15/D17 are clean.** `MediaQuery` and `LayoutBuilder` appear zero times in `lib/` (the one
  textual match is a doc comment about a deleted screen, `home_screen.dart:44`). The sheet is one
  column in the named panel order (`character_sheet_view.dart:110-123`). No breakpoint logic has
  crept in anywhere — including the inventory, which is single-column today, so §8's feared
  *quiet* two-column divergence has not happened.
- **D16's three kinds of wrong reach every verdict surface found**: `tag.dart:130-146`,
  `side_sheet.dart:162-171`, `character_sheet_view.dart:363-374`, `sheet_view_model.dart:186-192`.
  The inventory's withheld/immovable handling is correctly the *impossible* class and needs no
  toggle.
- **The query layer is exemplary where it exists**: hand-declared queries with per-query
  `retry: neverRetry` (`providers.dart:300-395`), scope backstop (`main.dart:34`), precise
  invalidation after writes. **The command layer is near-textbook**: one sealed hierarchy, one
  exhaustive switch (`save_editor.dart:52-437`), stale-index protection by resref, capability
  split by type. **Repositories never know each other** — zero cross-repository imports; merges
  live in use-cases as `architecture.md:34-38` predicted.
- **The movability rule is one copy** — `_movesBetweenCharacters` (`inventory_screen.dart:161-167`)
  feeds menu and drag alike. The recorded two-copies fix held.
- **The label doctrine holds.** Slot names carry their strrefs and resolve against the live talk
  table (6671, 11997, 12006 spot-checked exact); no invented in-game value was found anywhere;
  "Equipped"/"In no slot" are documented project coinages. One case nit: `'Quick item 1'`
  (`inventory_screen.dart:610`) cites strref 12012, which the game spells **"Quick Item"**.
- **The captures confirmed the screens tell the truth about the bytes.** The suspicious-looking
  `Ashideena +2` under a `Shield` chip was dumped from both fixtures: the war hammer really is at
  slot index 2 — BG:EE stores the off-hand weapon in the shield slot, as the slot enum's own
  dartdoc records from `Aard1.chr`. Honest display, engine convention, no defect.

## 3 Live defects — new, none previously recorded

Each verified at its site; the first three are plain bugs, the rest are broken-on-arrival visuals
or reach gaps.

1. **The side sheet's draft lives twice and drifts.** `_draft` updates on typing
   (`side_sheet.dart:219`) but the chip row highlights against `controller.text` (`:391`) and a
   chip pick updates only the draft (`:676-678`). Repro: on *Attacks per round* type `10`, click
   chip `2` — the field still reads `10`, no chip highlights, Apply writes `2`. The project's
   most recurrent bug class, inside one widget.
2. **The inventory-full message is false.** "Nothing can be added until something is taken out
   **in game**" (`inventory_screen.dart:277-280`) — the same screen's own menu offers Remove and
   Move to, both of which free a slot.
3. **Add buttons stay enabled at 16/16 and silently do nothing.** `FilledButton.tonal` is
   unconditional (`inventory_screen.dart:417`); the guard is a silent return (`:194-196`).
   Reachable: remove an item, type a query, press Undo — results linger with live Add buttons.
   The project's own dead-control doctrine (D17) says disable, visibly.
4. **Filled inventory cells paint `surfaceContainerHighest`, a token neither Starfleet scheme
   defines** (`inventory_screen.dart:825-827`; schemes at `theme.dart:1076-1079`, `:1154-1157`).
   The 3.47 framework falls back to `surface`, so by day the fill is byte-identical to the card
   behind it and by night it lands *below* the card — the direction of the unlit plate. Same
   class: `_NoPortrait` still paints the token (`portrait_image.dart:66-67`) although the theme's
   own doc (`theme.dart:58-63`) names both placeholders as that defect and only `_NoScreenshot`
   was fixed.
5. **`secondaryContainer` is mapped onto surface rungs** (`theme.dart:1066`, `:1144`), so the
   selected-card fill (`home_screen.dart:568`), the `enhanced` tag (`tag.dart:74-77`) and the
   drag chip (`item_drag.dart:65`) compute to ≈1.10:1 against their ground at night — a
   meaning-bearing colour channel that is effectively absent. Computed, not yet seen: capture
   list, §6.
6. **Right-click opens the item menu only on the `…` icon itself** (`inventory_screen.dart:936-947`)
   while its own comment says right-click is the gesture people will try — on the row or cell,
   where it does nothing. The framework's recipe wraps the whole child region.
7. **The findings count does not travel to the inventory screen** — no `FindingsBadge`, no
   `endDrawer` on its Scaffold (`inventory_screen.dart:204-246`) — and `findings_badge.dart:33-35,
   47-49` claims both. The surface where items change is the one that cannot see the record's
   flags, which is §8c's argument in miniature.
8. **The `.chr` editor is the lesser editor for no recorded reason**: no command palette, no
   `Ctrl+K`, findings badge inert (`character_file_view.dart:190, 274-293` vs
   `character_screen.dart:313-315, 423-427, 441-445`). Both review passes found it independently.
   Same record, same sheet, different reach.
9. **The inventory screen has zero explicit `Semantics`.** The five `Semantics(` sites in the app
   are all elsewhere; an empty cell is a `Container` with a null child — "a hole at `pack4` draws
   as a hole" does not reach assistive technology at all. Extends §2's owed sweep to a surface
   newer than the list.

## 4 Boundary and provider-graph findings

**4a. The repository boundary as recorded is not the boundary as built — and this needs a
decision, not a patch.** `SaveGameRepository.load` returns `Gam`
(`save_game_repository.dart:44`), `CharacterFileRepository.load` returns `Chr`; both editor
ViewModels hold and decode codec types; `EditSession<T extends CreatureDocument<T>>`
(`edit_session.dart:15,37`) parameterises a `lib/ui/` type over a format-package interface.
Meanwhile four doc comments assert the opposite boundary in prose
(`save_game_repository.dart:48-50`, `save_browser_viewmodel.dart:88-89`, `character.dart:28-29`,
`party_viewmodel.dart:200-201`) — the two-copies pattern in documentation form. The behaviour is
coherent and arguably right: the byte-retaining `Gam`/`Chr` *is* the domain document this
editing model demands, and a wrapper would duplicate it. **Recommendation: record the deviation
as a D-entry ("the byte-retaining codec document is the domain document") and correct the four
prose copies — rather than build a wrapper layer that exists to satisfy a sentence.** The
alternative (an opaque domain document type) buys testability the override seam already provides.

**4b. The domain slot vocabulary is missing, and that is the merge's gate.** `CarriedItem` claims
"nothing here knows about bytes" while defining its slot as "`CreItemSlot.index` numbers them"
(`carried_item.dart:23,49`) — so three view files import the format enum to interpret it
(`inventory_screen.dart:17,63,586-617`; `character_screen.dart:19,156`; `portrait_rail.dart:17,59`).
Folding inventory into the sheet without fixing this spreads the import into the sheet and
projection too. **Do the domain slot model before the merge.**

**4c. The free-backpack-slot rule exists in three copies across three layers** —
`Cre.firstFreePackSlot` (format, used by `MoveItem`), `_firstFreePack`
(`inventory_screen.dart:141-150`, used by `AddItem`), `_hasRoom` (`portrait_rail.dart:54-60`) —
and the two UI copies read a lossy last-wins inversion (`party_projection.dart:204-206`). They
agree on all current data; the divergence condition exists. Unify on the format copy, exposed
through the projection, as part of the merge.

**4d. Dead code and dead capability, unrecorded**: `characterFileByNameProvider` has zero callers
(`providers.dart:389` is its only occurrence — the `.chr` ViewModel bypasses it with a direct
`await repository.fileNamed()` in `build()`, the shape D12 exists to prevent, while the sibling
editor routes through its query); `PortraitPicker.show` has no caller anywhere and `SetPortrait`
is wired only into creation — the Workbench promotion silently dropped "change portrait" from
both editors and neither D17 nor `known-defects.md` records it.

**4e. Session-loss latency.** Both editor `build()`s watch rules/name queries whose invalidation
would re-seed `EditSession` and silently discard unsaved edits (`party_viewmodel.dart:209-221`,
`character_file_viewmodel.dart:137-141`). Nothing invalidates those queries today, so it cannot
fire yet — but it bounds the merge: the item catalogue must stay watched in the view/section
(as `inventory_screen.dart:254` does), never in an editor ViewModel's `build()`.

**4f. Smaller conformance items, recorded here once**: `ref.watch` inside a pushed-route callback
where a captured value or `read` belongs (`character_screen.dart:176-181`; the `.chr` twin
already does it right) and a `read`-in-build beside a `watch` of the same provider
(`inventory_screen.dart:249-254`); the three AsyncNotifiers declare no per-provider
`retry: neverRetry`, which D12 records as test-container exposure
(`party_viewmodel.dart:386-390` et al.); views catch domain exceptions where the canon has the
ViewModel expose error state (`export_button.dart:81-98`, `creation_view.dart:208-221`) — and the
export collision arrives as a SnackBar *after* the dialog closed, losing the typed name, the
exact pattern §4 calls creation's worst defect; creation's terminal command lives on the home
screen's ViewModel (`creation_view.dart:172-174` → `save_browser_viewmodel.dart:201-348`);
`ui/core` imports a feature (`tag.dart:16`); `hasDeleted` is sync IO inside a notifier build
(`save_browser_viewmodel.dart:107-111`); the search field is a labelled `TextField` where the
prior review already ruled `SearchBar` (`inventory_screen.dart:322-333`), with a border override
that changes corner radius exactly when the field disables; `dialogTheme` and `sliderTheme`
remain unset, so prose dialogs have no max width and creation's sliders draw the superseded 2023
shape; the rail tooltip explains the two-portraits trap to the user on every member
(`portrait_tile.dart:57-59`); the ⓘ caveat widget exists twice privately and has already drifted
in one property (`character_sheet_view.dart:394-411` vs `value_readout.dart:81-97`), and both
copies are hover-only, invisible to the keyboard.

## 5 Record corrections owed

From the reconciliation pass (verdicts spot-verified):

- **§1 (pip ceiling) is confirmed live** — the one open rules defect. Citations drifted:
  `character_sheet.dart:149-150` (was 148-149), `:49-55` (was 50-54),
  `resource_repository.dart:267` (was 266); the repository reads profsmax through its own string
  constant, not `GameTable.proficiencyRankCap`, which sits unused by it.
- **CLAUDE.md**: test counts stale three ways (842→844 banner, 697→844 and 374→399 in "What
  exists"); "49 fields" → **50** (measured `values.length`); "SDK pinned to 3.44.8" → 3.47.0.
- **§3b's mechanism sentence is doubtful**: the palette's `SearchBar` now precedes the first
  value row inside the same autofocus subtree (`command_palette.dart:67-78`), so "focus lands on
  the first row's InkWell" may describe a superseded tree. One fresh-open capture re-diagnoses it
  (§6). The captures taken for this review show no greyed first row — consistent, not conclusive.
- **§4's survivor list is incomplete**: add the spell tile's `CheckboxListTile` with an `InkWell`
  in its title (`creation_view.dart:918-938` — tap-to-read and tap-to-toggle share one row) and
  the portrait picker's `AlertDialog`+`SizedBox` and labelled `TextField`
  (`portrait_picker.dart:61-70, 167-175`). §2's "ability tile" noun is stale (merged into
  `_ValueRow`).
- **The table-name vocabulary exists twice**: `GameTable`/`TableColumn` (38 + 13 values, counts
  verified) beside parallel bare-string constants in `resource_repository.dart:607, 725-733,
  749-761` — the exact disease `a-rule-with-two-copies-is-the-bug` names.
- **Stale prose in code**: `creation_viewmodel.dart:936-937` repeats the `.autoDispose` claim
  `providers.dart:184-191` records as false; `party_projection.dart:239-241` calls the portrait
  mapping unverified (closed 2026-08-08); `tag.dart:20-25`'s "only two places name a role
  directly" is false by a wide margin; `findings.dart` can never construct `Severity.notice`, so
  the badge's notice branches are dead.

## 6 Captures owed

The five captures in hand (home, `.chr` sheet, `.chr` inventory, save sheet, save inventory — all
dark theme) verified rendering under Impeller and the slot-truth question. Still wanted, each
with what to look for:

1. **Fresh-open character screen, no interaction** — where does focus land; does any row read as
   greyed (§3b re-diagnosis).
2. **Dark + light inventory with filled and empty cells** — is a filled cell's fill visible at
   all (finding 3.4)?
3. **Dark home screen in selection mode, one card ticked** — is the selection fill perceptible
   without the checkbox (3.5)?
4. **A rail member whose portrait fails to resolve** — does `_NoPortrait` read as a tile (3.4)?
5. **A sheet row wearing the `enhanced`/`rules say` tag, dark** — does the borderless pill read
   as a pill (3.5)?
6. **Maximised window, delete-confirmation dialog open** — unbounded line length (4f,
   `dialogTheme`).
7. **Inventory at 16/16 with lingering results** (remove → type → undo) — the inert Add buttons
   and the disabled search field's radius swap (3.3, 4f).
8. **Mid-drag over the rail** — is "will accept" legible over an opaque portrait, and
   distinguishable from the already-selected member's identical frame (`portrait_rail.dart:134-141`)?

## 7 The merge decision — candidate D19

**The question** (from §8c): equip/unequip requires Recalculate Stats; items that move a
character's numbers must not be edited on a screen that hides the numbers; therefore the
inventory probably belongs inside the sheet — which reopens two recorded decisions, the
inventory as "a pushed route, not a panel" and D15's single column.

**What the review established about the ground.** The merge is structurally cheaper than the
"thirty-four slots swamp the sheet" worry implies, and the current separation is actively
expensive:

- `InventoryScreen` never touches a ViewModel — document access is a closure, every edit a
  supplied callback (`inventory_screen.dart:36-112`). It re-parents with zero data-layer work.
- The pushed route lives *outside* the declared `go_router` table — an anonymous
  `Navigator.push(MaterialPageRoute(...))` duplicated in both editors
  (`character_screen.dart:164-244`, `character_file_view.dart:214-252`), each carrying its own
  staleness machinery whose two prior defects are memorialised in comments. The router's doc
  still claims nested categories; inventory bypassed it.
- The duplication bill is already being paid: undo/redo buttons ×3, dirty marker ×3, scroll
  shell ×3 (at two different max widths, 820 and 900), the rail|divider|content row ×2, and the
  whole editor shell ×2 across the two editors (`_applyField`, `_applyPips` with the D16 switch,
  SideSheet wiring, discard guard, projection call). A third surface would make this ×3.
- One `EditSession` already carries stat and item edits in a single history
  (`party_viewmodel.dart:244-251`) — on a merged surface, "unequip + recalculate" is naturally
  **one undo step**, the property §8c needs, with no state-model change.
- The rail is already shared and provider-driven; `SelectionArea` is already screen-local; the
  inventory Scaffold's `endDrawer` slot is free, so item detail can route through the existing
  `SideSheet` `Subject` mechanism — which also fixes findings 3.7 and 3.8 structurally.

**The constraints**: the domain slot vocabulary must exist first (4b); the free-slot rule must
become one copy through the projection (4c); the two autofocus claims (sheet `Ctrl+K`, search
field) must be arbitrated; 820 vs 900 must be reconciled; the `.chr` editor must merge in the
same motion or duplication triples; the item catalogue stays watched outside editor ViewModels
(4e).

**Options.**

- **A — inventory joins the sheet's single column as panels** (Backpack, Equipped, In no slot,
  after Condition), with search in the existing palette position and item actions/detail through
  the `SideSheet` as `Subject`s. D15 is *upheld and extended*, not reopened: one column stays
  the order a person reads a character in, and the panel list already appends by name
  (`character_sheet_view.dart:110-123`). The page gets long; the palette exists to jump.
- **B — one screen, two stated columns** (sheet | inventory). The §8-sanctioned divergence,
  legal only as a recorded decision. Solves density, but breaks D15's no-breakpoint rule the
  moment a narrow window forces a fold, and the captures do not yet show A failing.
- **C — keep two screens, add a numbers strip to the inventory.** Rejected: a strip is a second
  copy of the sheet's numbers on a second surface — the two-copies disease as a feature.

**Recommendation: A, in three slices, decided as D19.**

1. **Prep slice (no decision needed, pure de-duplication):** domain slot vocabulary (4b);
   free-slot rule to one copy (4c); extract the shared editor shell the duplication section
   names (undo/redo/save/dirty/discard/apply wiring). Fix findings 3.1–3.3 alongside — they are
   independent of the merge.
2. **Merge slice (D19 proper):** the inventory panels enter the sheet column; the pushed route
   and its two wiring copies are deleted; the `.chr` editor takes the same shell, closing
   finding 3.8; the findings badge reaches items, closing 3.7. "A pushed route, not a panel" is
   superseded by D19; D15 stands, extended.
3. **Recalculate Stats stays its own later phase** — the opcode interpreter over ITM equipping
   blocks with EE Keeper under Wine as oracle, exactly as §8c records. The merge is that phase's
   UI precondition, not its implementation, and equip/unequip controls ship only *with*
   recalculation, per §8c's "no small safe version".

If capture 2 or a post-merge capture shows the single column genuinely unusable at inventory
density, option B is the recorded fallback — taken then as its own decision, not by drift.

### Amended the same day — the user set the direction: a grid, not columns

Reviewing this document, the user chose differently: **the merged page is grid-based — fixed
cells, and no widget that rearranges when the window resizes.** Options A and B are both declined
("instead of columns"); C stays rejected. The no-reflow half was already doctrine and stands.

What this supersedes and what it keeps:

- **D15's single column is superseded for the merged page — by decision, not by drift**, which is
  exactly the deliberate reopening §8c demanded. D15's other halves stand untouched: the
  Starfleet palette, and **no breakpoint logic** — a fixed grid means a fixed column count with
  no `MediaQuery`/`LayoutBuilder`, a raised minimum window size if the grid requires one
  (`linux/runner/my_application.cc` already sets the floor A8 added), and vertical scrolling
  only.
- **The three-slice sequencing stands unchanged.** The prep slice is layout-agnostic.

The two ways the *last* grid failed, recorded in `planning/ui-review.md` and D17, which the new
one must answer by construction:

1. **Dead space from uniform tiles** — the 222 px tile grid wasted 19.3 % of every row. Cells are
   sized by their content's design, never by a shared tile module.
2. **The zigzag from greedy balancing** — panel positions are a **named, fixed map** of what sits
   where, never an algorithm balancing heights. The reading order is authored, as the column's
   was.

And the property that makes a grid *better* than the column for this page — the acceptance test
the spike is judged on: **the character's numbers and the items are simultaneously visible.** An
equip or a move must change a number the user can see without scrolling. The single column's
recorded weakness was exactly that the numbers would sit several panels away from the grid being
dragged over.

**How D19 closes: the way D15 did — by looking.** The merge slice therefore opens with a small
layout spike: two grid arrangements built with real data, captured, and put in front of the user.
The chosen arrangement becomes D19 in `planning/decisions.md`, with this document as its input.

**Amended again the same day:** the user challenged the provenance of D15's option space itself —
three same-model spikes are one prior sampled thrice, not a design space explored — and set the
study's gates: **tool-first, breaking deliberately from BG:EE's and EE Keeper's forms**, optimized
for inventory manipulation, quick edits and full audit, party-neutral. The grid arrangements are
now derived from a corrected task inventory, not generated from pattern memory. The study is
`planning/tool-first-study.md`, and it precedes the spike.

---

*Not done here, deliberately: no code was changed; engine-side assertions inside recorded claims
were not re-tested against BG:EE; screen-reader behaviour was inferred from code shape, not
heard. The fix work above enters plan mode as its own phase.*

---

## ⚠️ §7's recommendation is superseded — 2026-08-15

Option A was recommended above on paper. The user instead required a **grid** (amended in place),
commissioned `planning/tool-first-study.md`, had both grids built, reshaped one of them ten times
and deleted the other. **D19 now decides on a single page — `G1MergedPage`, "the merged page" —
recorded in `planning/grid-spike-brief.md`.**

By arriving there through building rather than argument, the page landed close to option A anyway:
one page per character with the inventory among its panels, a party rail turned into a band. **The
findings in §1–§6 of this document stand;** only §7's recommendation is stale. §7 constraint 4c —
the free-slot rule to one copy — was **done early** as `lib/ui/inventory/pack_slots.dart`, and the
820-vs-900 reconciliation was settled at 900 by the first surface holding both.
