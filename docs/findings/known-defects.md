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

## 3 Resizing edits inside a savegame — the GAM relocation

`Gam.withCreature` throws `UnsupportedError`. It is the single thing standing between the app and
**adding an item, or granting a proficiency the character does not already have, in a live save.**

Measured: **39 pointers, 81–93 KB shifted** — 3 GAM header offsets, the `creOffset` of the 0–3 later
party members, and the `creOffset` of each of the 33–36 non-party NPCs after it. ⚠️ Those 36 were
unrecorded until 2026-08-09; a relocation patching only the GAM header corrupts the save silently.

Everything else already works: fixed-width edits in place (engine-confirmed twice), and resizing
edits through export, where the same change costs one pointer.

**Consequence visible in the UI today:** the Proficiencies panel marks a proficiency the record has
no effect for as not editable, and says why. That is honest, not a bug — but it is a limit.

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
