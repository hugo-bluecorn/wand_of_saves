# Known defects — measured, documented, not fixed

**2026-08-12.** Every entry here has been located precisely and left alone on purpose, so that the
Starfleet Workbench UI could ship for the basic workflow. None is a guess: each names the file and
the line, and says what would have to change.

⚠️ **Writing a defect down does not close it.** This file exists so nothing is quietly lost, not so
the list can be treated as handled. An entry leaving this file means a fix, not a re-reading.

---

## 1 ⚠️ The character sheet's proficiency pip ceiling is wrong

**Where.** `lib/domain/rules/character_sheet.dart:148-149`.

```dart
int? maximumPipsFor(int proficiencyId) =>
    proficiencies[proficiencyId]?.maximumFor(classColumn);
```

That is `weapprof.2da`'s class column **alone** — the *class* ceiling, which gives a fighter **5**
(Grand Mastery, reached over many levels). The rule closed in game on 2026-08-11 is
`min(profsmax.FIRST_LEVEL, weapprof[column])`, and creation implements it correctly at
`lib/ui/creation/creation_viewmodel.dart:305-314`.

**Effect.** On the character sheet a low-level fighter is offered up to five pips where BG:EE
refuses a second — engine-confirmed, with a slot still unspent. `PipMeter` draws
`max(pips, maximum)` dots, so the wrong ceiling is drawn, not merely permitted.

**Why it is not a copy-paste.** **Creation is always level 1 and the sheet is not.** A level-12
fighter legitimately exceeds `FIRST_LEVEL`, so the sheet needs `profsmax` resolved against the
character's own level, and `TableColumn` currently models only `firstLevel`.

**First step, before writing any rule:** `fvm dart run tool/dev/dump_table.dart profsmax` — find out
whether BG:EE's copy has by-level columns at all. If `FIRST_LEVEL` is the whole table, the sheet's
expression is creation's and no level input is needed. **Look before deciding.**

Also needed: plumb the table into `CharacterSheet` the way `proficiencies` and `skills` already are
(`character_sheet.dart:50-54`). `ResourceRepository` already reads it
(`resource_repository.dart:266`, `GameTable.proficiencyRankCap`).

---

## 2 Accessible names — A5 of `planning/ui-review.md`

`InputDecoration.labelText` never becomes a field's accessible name, so stat fields present to
assistive technology as unnamed text fields. The Workbench port **improves** this without finishing
it: the new sheet gives every value row and ability tile an explicit `Semantics` label carrying the
label, the stored value and the verdict. What is still missing is a sweep over the remaining
surfaces — the creation flow, the portrait picker, the side sheet's inputs.

Not a basic-workflow blocker, which is the only reason it is here rather than done.

---

## 3b The first row of the sheet looks greyed when the screen opens

`Focus(autofocus: true)` in `character_screen.dart` wraps the scrolling body so `Ctrl+K` reaches the
command palette without a click first. On Linux that hands focus to the first focusable descendant —
the first value row's `InkWell` — and its focus highlight paints a lighter plate across that row.

⚠️ **It reads as *unavailable*, which is the one thing it must not.** Starfleet's `ScreenTone` plate
for a field the class cannot have is **darker** than the card, so the two are distinguishable side by
side — but a reader who sees only the highlight has no way to know which of the two they are looking
at, and this is the row they see first.

**Not fixed because the obvious fix costs the shortcut:** dropping `autofocus` means `Ctrl+K` needs a
click into the body first. The route through is probably a focus node that is not also a tap target.

⚠️ Found by capture. **No test could have found it** — `flutter test` never draws a focus highlight.

---

## 4 The creation flow keeps its old components

`lib/ui/creation/creation_view.dart` was not ported — the spike had no creation flow — so it keeps
its current layout while picking up Starfleet's colour and type from the application theme. Three
component choices from `planning/ui-review.md` §Dimension 2 survive:

- A `SnackBar` reports a name collision where `errorText` on the field belongs. ⚠️ This is the worst
  of the three: creation has **ten answered steps and no undo**, so losing the answer costs most
  exactly here — and the app already does it correctly one file away, in the export dialog.
- Two `ChoiceChip`s for gender where `SegmentedButton` is scoped to 2–5 options.
- `Scaffold.bottomNavigationBar` for Back/Next where `persistentFooterButtons` belongs; the correct
  slot wraps children in an `OverflowBar` and gives a narrow-window column fallback the hand-rolled
  `Row` does not have.

Its **overflow** is fixed, in the runner — see below.

---

## 5 Keyboard: only `Ctrl+K`

The new character screen binds `Ctrl+K` for the command palette, via `CallbackShortcuts`. **Undo,
redo and save are still toolbar-only.**

⚠️ **There is a trap in the obvious fix.** On Linux `Ctrl+Z` is already bound to `UndoTextIntent`,
and `DefaultTextEditingShortcuts` sits *below* the root `Shortcuts` — so a root binding is shadowed
whenever a stat field has focus, which is most of the time in this app. The route through is
**`ShortcutRegistry`**, which `WidgetsApp` already installs and which nests inside the text-editing
shortcuts; `MenuBar`'s own dartdoc nominates exactly this. And note the division that dartdoc
insists on: the registry *handles*, a menu *discovers*, so doing shortcuts without a `MenuBar`
leaves anything non-obvious undiscoverable. Undo, redo and save are obvious; nothing else is.

---

## 5b `CHARBASE` stores 255 attacks per round, and nobody knows what that means

**Measured 2026-08-12** by reading the archives: the engine's own creation template holds
`numberOfAttacks = 255`, where every shipped NPC — `IMOEN`, `MINSC`, `KHALID` — holds `1`.

**So every character this app creates carries 255**, because it patches a copy of `CHARBASE` and
preserving the template's bytes is what it is supposed to do. The field declares 0–10 (0–5 whole
attacks, 6–10 halves), so 255 is outside the code entirely and the sheet now says **nothing** about
what the game will draw for it rather than extrapolating — it used to report `499/2`.

⚠️ **What 255 means to the engine is not known and is not guessed at.** Three readings fit and no
measurement separates them:

1. A sentinel for *the engine computes this*, like D14's six fields.
2. Junk in a template field the engine never reads.
3. A real value the engine clamps.

**How to settle it:** import a created character, look at the record screen's attacks figure, save,
and read the byte back. That is D14's own method and it costs one trip into the game. Until then the
app is right to preserve the byte and right to say nothing about it.

---

## 5c EE Keeper has a fourth item flag and IESDP does not name it

**Measured 2026-08-12** from EE Keeper's own dialog templates: `CSetItemFlagsDlg` (dialog 186) has
four checkboxes — **Identified**, **Given**, **Stolen**, **Undropable** (sic).

IESDP names bit 1 of the CRE item's flags **Unstealable**. `CreItemFlag` follows IESDP, because
IESDP is the specification source and EE Keeper is not readable as one (D1).

⚠️ **Whether "Given" and "Unstealable" are the same bit under two names is not established**, and
nothing separates them: both would sit at bit 1, and no fixture item has that bit set alone. Three
readings fit and no measurement chooses between them.

**How to settle it:** set bit 1 on an item, load the game, and see whether a thief can steal it —
or open the same file in EE Keeper under Wine and read which box it ticks. Neither has been done.

Not blocking: the app can offer the flag under IESDP's name, and the value it writes is the same
either way. It is the *label* that is uncertain.

---

## 8 The inventory screen is a list where it should be slots — agreed 2026-08-13

Inventory shipped narrow on purpose, and the user walked the app and named what is missing. **None
of this is a bug; it is the screen not yet being what it should be.** Recorded so it is not
rediscovered as a surprise.

| | what it needs |
|---|---|
| **Slots, not a list** | Sixteen fixed cells. A list hides that capacity is finite, which is the one thing an inventory has to convey. |
| **Weight and capacity** | ⚠️ **The table exists**: `strmod.2da` carries a `WEIGHT_ALLOWANCE` column keyed by Strength, and *"Weight Allowance"* is the game's own phrase (strref 10338). Item weight is ITM `0x4c` — measured zero negatives across all 1,530 items, so the unsigned read is safe. |
| **Item properties in results** | Weight, price, type and description are already loaded by `ItemEntry` and simply not rendered. |
| **Categories** | `itemType` → `ITEMCAT.IDS`. Swords, bows, helms. |
| **Two columns** | ⚠️ D15/D17 fixed **single column for the character sheet**, deliberately. The inventory is a different surface — a picker beside a grid — so two columns is not a contradiction, but it must be a **stated** divergence rather than a quiet one. |

### ⚠️ 8b Item pictures need a BAM decoder, and that is its own phase

The user asked for the item's picture in each slot with the name on hover. The icon is a **BAM**
resref at ITM `0x3a`.

**Portraits are not precedent.** They work because they are plain BMP and `dart:ui` decodes BMP for
free — no decoder was ever written. **BAM is palettised and RLE-compressed, and no Dart decoder
exists**; writing one is a new codec on the scale of the CRE work, plus a frame cache.

**Held back deliberately.** The screen is usable without it — names in slots, detail on hover — and
bundling a format phase into a UI phase is how a day's work becomes a week's.

---

## 6 Rules the record does not yet enforce

- **A Blade's Lore is half per level.** The walkthrough says so and `lore.2da` has no kit rows, so
  there is no table to read it from. Not in code, deliberately.
- **The Lore cap of 100** refuses a bard's legitimate ~120.
- **Who may Turn Undead, and who may Track** — half-closed 2026-08-10. A stored 25 and 100 on a
  Fighter/Mage/Thief both survived the record and the game showed neither, so the display is
  class-gated and a stored value grants nothing. *Which* classes qualify is in no table found, so
  both stay editable rather than take an invented rule.
- **How the multi-class hit-point mean rounds** when it is not exact.

---

## 7 Not carried over from the spikes

- **The Ben-Day halftone.** The Pop palette's screen was the one device that provably escapes a
  contrast limit opacity cannot reach — 38 % alpha composites to 2.68:1 against a 3:1 requirement,
  while an uneven halftone gets past it because its coverage is not level. Starfleet supplies a flat
  unlit plate through the same `ScreenTone` mechanism instead. **The finding is preserved here; the
  code has no consumer for the halftone.**
- **Ledger's headline argument no longer reproduces.** Deleting the `What the game shows` group from
  the shared demo data broke the merge that was that spike's clearest claim — 13 fields becoming 11
  rows, with `Lore` appearing once. The published captures stand as history; the code did not.
  Recorded so nobody rediscovers it as a bug.

---

## Fixed since — entry 3, the GAM relocation

⚠️ **Closed 2026-08-12 by building it.** `Gam.withCreature` relocates rather than throwing, so
**adding an item or granting a proficiency now works inside a live savegame**, not only through
export. It was the last structural gap in the project.

The entry's own figure was wrong and the fix is what found it: **43 pointers, not 39.** The
recorded number counted only the header offsets the layout table modelled, and three live section
offsets — familiar info, stored locations, pocket plane — sat past the party creature unnamed.
`creLength` is the forty-third. See `verified-format-offsets.md` §"What adding a proficiency
actually costs" for the corrected table and the three encodings of "absent".

⚠️ **Two tests inverted rather than being deleted**, and that is deliberate: `save_editor_test.dart`
asserted that a savegame *refuses* a resizing edit. The refusal was the defect, so the assertions
that guarded the limitation now prove it gone.

⚠️ **Still owed: the engine has not seen one of these files.** Every gate here is a byte gate.
Only BG:EE can answer whether a relocated save *loads*, and that trip has not been made.

---

## Fixed in this pass, for contrast

So the list above is read as *what is left* rather than *what is wrong*:

- **A1/A3/A7** — read-only values were rendered as disabled `TextField`s: 2.3:1 contrast, not
  selectable, not focusable, announced as *unavailable*, and leaking a `TextEditingController` per
  rebuild. The new `ValueReadout` is not a text field at all.
- **A6 and five more surfaces** — `outlineVariant` is *specified* at 1.0:1 and carried the dividers,
  the tab underline, the card outlines, the portrait frames and the pips. Starfleet writes its
  `ColorScheme` by hand and never rides that curve.
- **A8** — no minimum window size. `linux/runner/my_application.cc` now sets one; KDE half-tiles a
  1366 px display at 683, where the creation flow tore.
- **L1/L2 and the zigzag** — the 222 px tile grid wasted 19.3 % of every row and the greedy
  two-column balance made the named panel order read as a zigzag. Single column removes both.
- **Nothing could be selected or copied.** `SelectionArea` now wraps the character sheet. ⚠️ It sits
  *inside* the screen and not at the application root: `MaterialApp.router`'s `builder` runs above the
  router's `Navigator`, so there is no `Overlay` and `SelectableRegion` throws on the first frame.
- **Transient scrollbars** — the theme sets `thumbVisibility`, so a panel with content below the
  fold no longer looks identical to one that ends at the fold.

### From the checklist walkthrough, 2026-08-12

Nine items were reported by driving the app. Six are closed:

- ⚠️ **`in game` was stating a number the engine never draws.** A Fighter/Mage's `Open Locks` read
  `stored 0` beside `in game 25` — `0 + Dexterity + race`, computed because the modifier tables answer
  for any character, and printed without asking whether the engine shows the row. It does not.
- ⚠️ **The party rail drew no portraits, and a second defect hid behind that.** `PORTRT<n>` is a
  filename, not a resref; and the `selectedIcon` that makes selection visible over an opaque portrait
  had been lost with the deleted `party_view.dart`.
- **`weapprof.2da`'s dead generations were being offered** — `Bow` beside `Long Bow`, and fourteen rows
  called `EXTRA*`. Settled by reading all 2,253 shipped creature records: no proficiency id below 89
  is in use. Creation had the same bug.
- **A ceiling of zero read as `at ceiling`**, which says the opposite of *not this class*.
- **Cards within a group now flow across**, and the home screen stopped repeating both the app name
  and the character's own name.
- **A value's row is two lines**, the helper line carries the sum rather than naming its terms, and
  `Enhanced` states both limits.

⚠️ **One is closed differently than reported: `Detect Illusion` showing no in-game value is
correct.** `skilldex.2da` has the column and it is `0` at every Dexterity, so in-game equals stored
and the chip is rightly absent. Investigated rather than assumed.

**Two remain, as entries 1 and 4 above:** the pip ceiling, and creation differing from the sheet.
