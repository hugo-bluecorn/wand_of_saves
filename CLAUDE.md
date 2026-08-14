# CLAUDE.md

This file guides Claude Code sessions in this repository.

## What this project is

**Wand of Saves** — a Material 3 desktop application that opens a Baldur's Gate: Enhanced Edition
save, edits the party (stats, inventory, spells, effects, journal, variables, appearance), and
writes it back safely.

*The name is a D&D pun: a wand for saving throws, and for save games.* The format package is
`infinity_formats`, after the **Infinity Engine** — the BioWare engine behind Baldur's Gate,
Icewind Dale and Planescape: Torment.

It is a **functional successor to EE Keeper**, not a port of it. EE Keeper is a 2017 Win32/MFC
application; this is a new Flutter application. The *feature set* is the target; the UI and the
architecture are deliberately different:

| | EE Keeper | This project |
|---|---|---|
| UI | Win32/MFC, MDI, 31 modal dialogs | Material 3, **single-column** desktop layout (Starfleet palette, D15) |
| Architecture | MFC Document/View (MVC-ish) | Flutter **MVVM** (`context/mvvm-architecture-record.md`) |
| State | one 11,848-byte mutable `CEEKeeperDoc` | immutable domain model + edit commands (gives undo/redo) |

**v1 scope is BG1EE only** — `GAM V2.0` + `CRE V1.0`. That is a deliberate decision (D3); it drops
IWDEE's `CRE V9.0`, IWD2's `V2.2`, PST's field set and the alternate item-slot layouts. Keep codec
*dispatch* pluggable (selected by the version signature) even though only one implementation
exists — sealing the layout into a single hardcoded reader is the one shortcut that is expensive
to undo.

## Read this first, in order

1. `planning/decisions.md` — **D1 (licensing) is closed: Apache-2.0, and it constrains how you
   may work.** Read its "constraint this imposes" section before writing any codec.
2. `planning/using-nearinfinity.md` — **what you may and may not do with the Java.** Short, and
   it answers the question D1 raises. Read it before the first codec.
3. `planning/architecture.md` — layering, package split, folder layout, the provider graph.
4. `docs/findings/verified-format-offsets.md` — the format facts already established and
   **verified against real save data**. Do not re-derive these.
5. `docs/findings/eekeeper-reverse-engineering.md` — what EE Keeper actually does, recovered from
   the binary. This is the feature checklist.
6. `docs/findings/known-defects.md` — **what is measured, located and deliberately not fixed.**
   Read it before reporting a bug or picking up work; every entry names the file and line, and
   ⚠️ **entry 1 is a live rules defect** — the character sheet's pip ceiling.
7. `context/` — the pinned target-side canon (Flutter AI rules, Effective Dart, MVVM record,
   Java semantics ledger, **Dart data-modelling ledger**). Where code disagrees with `context/`,
   that is a defect or a recorded deviation, not a preference. Deviations recorded so far:
   D2, D6, D7, D8, D9.

## Hard rules

- **All reference material is read-only.** Never modify anything under `../NearInfinity`,
  `../iesdp`, `../EEKeeper`, the Steam game install, or the user's saves.
  See `reference/README.md`.
- **Never edit a real save in place.** Always write to a temp file and rename, and always keep a
  `.bak`. Test fixtures are *copies*; the originals under
  `~/.local/share/Baldur's Gate - Enhanced Edition/save/` are the user's actual game.
- **Dart/Flutter are NOT on PATH** — use `fvm flutter …` / `fvm dart …`. SDK pinned to 3.47.0
  (Dart 3.13.0) in `.fvmrc`; the `sdk: ^3.12.2` floor in both pubspecs is deliberate — raising it
  forces `dart format`'s 3.13 whole-repo reformat, which is its own commit when it happens.
- **`packages/infinity_formats` must never import `package:flutter`.** It is pure Dart so its suite runs
  under `dart test`, which makes the rule mechanical: a Flutter import fails to compile there and
  names the file. `packages/infinity_formats/dart_test.yaml` pins `platforms: [vm]` to keep that true,
  and `test/flutter_free_test.dart` walks every source file so the rule covers code no test has
  reached yet.
- **State management is Riverpod 3.x with manually declared providers — NO code generation
  *for Riverpod*** (D2). No `@riverpod` annotations, and no generated companion for a provider.
  This is a *declared deviation* from `context/flutter-ai-rules.md`'s native-first default;
  everywhere else, a disagreement with `context/` is still a defect. See
  `planning/architecture.md` §The provider graph.
- ⚠️ **A repository read the UI depends on is a query provider, never an `await` inside a
  ViewModel's `build()`** (D12). A read that is a method call can be neither invalidated nor
  shared, and that gap produced three defects in one afternoon. A write invalidates exactly the
  query it changed. **Providers never retry** — Riverpod's default is ten attempts over 6.4
  seconds, and every data source here is the local filesystem where "no game installed" is an
  ordinary answer rather than a transient fault.
- **Code generation is decided per dependency** (D9), and the repo now contains three kinds — so
  D2 is emphatically *not* a project-wide ban, however it reads:
  - `*.mapper.dart` — `dart_mappable`, for domain models. Via `build_runner`.
  - `lib/domain/rules/*.g.dart` — the game's rules tables, from
    `fvm dart run tool/gen/generate_rules.dart`. **Not** `build_runner`: its input is the
    `../iesdp` sibling, which a fresh clone does not have.
  - Nothing for Riverpod. That is D2.

  **All generated output is committed**, because there is no CI and a fresh clone must build.
- **Work test-first, and plan before coding.** Write the failing test, **run it to confirm it
  fails for the right reason**, then implement. Before starting any implementation not already
  covered by an approved plan, enter plan mode and get the plan agreed. **Do not use the
  `tdd-workflow` plugin** — not its skills, agents or slash commands. Hand-rolled TDD only; the
  point is the discipline, not the scaffolding.
- **Lint is `very_good_analysis`, applied whole, with NO suppressions** (D8). No `exclude:`
  entries, no rule carve-outs, no `// ignore` or `// ignore_for_file` anywhere. This is
  checkable, so check it — **with the exclusion D8's amendment added**, since `dart_mappable`
  emits five `ignore_for_file` lines into every file it generates and they cannot be turned off:

  ```bash
  grep -rn 'ignore_for_file\|// ignore:' --include='*.dart' . | grep -v '\.mapper\.dart'
  ```

  That must return nothing. Without the `grep -v` it reports four files and looks like a
  violation. The invariant is **zero suppressions in code this project writes**. If a rule is
  unsatisfiable, fix the code or reopen D8 — do not silence it.
- **Round-trip byte identity is the gate for every writer.** Read a real file, write it back with
  no edits, compare bytes. A writer without a passing round-trip test is not done.
- **Preserve unknown bytes.** GAM and CRE contain unused and undocumented regions. Parse into a
  model *and keep the original bytes*; on save, patch known fields into a copy of the original.
  A model that re-serialises only the fields it understands silently destroys the rest.
- **Licensing: Apache-2.0, and codec work is INDEPENDENT IMPLEMENTATION** — written from public
  documentation and verified against a black-box oracle. (Not *clean-room*: that term means two
  isolated teams, which is not the process here.) This is the rule most likely to be broken by
  accident, so it is stated plainly: **do not read NearInfinity's Java while writing codec code** — not as a template, not to check an algorithm, not for "how did they structure
  this". Apache-2.0 cannot incorporate or derive from LGPL-2.1. Instead:
    - **IESDP** (`../iesdp`) is the specification source. It documents every format
      this project needs.
    - **NearInfinity is a black-box oracle** — run it, compare its output to yours. Executing a
      program creates no derivative work, so this is unrestricted and is the intended use.
    - **Shadow Keeper is off-limits entirely.**
  Every source file carries the Apache header (below). Facts flow freely; expression does not.
  **Full guidance, including the oracle's own licensing boundary:
  `planning/using-nearinfinity.md`.**

- **Apache header on every source file:**
  ```dart
  // Copyright 2026 hugo-bluecorn
  //
  // Licensed under the Apache License, Version 2.0 (the "License");
  // you may not use this file except in compliance with the License.
  // You may obtain a copy of the License at
  //
  //     http://www.apache.org/licenses/LICENSE-2.0
  //
  // Unless required by applicable law or agreed to in writing, software
  // distributed under the License is distributed on an "AS IS" BASIS,
  // WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  // See the License for the specific language governing permissions and
  // limitations under the License.
  ```

## Build & run

```bash
fvm flutter pub get
fvm flutter run -d linux        # primary dev target
fvm flutter analyze             # currently clean; keep it that way
fvm flutter test                # the app suite

# The infinity_formats suite is a separate package and runs from its own directory.
# `fvm dart test` at the repo root finds nothing and prints usage.
cd packages/infinity_formats && fvm dart test

# Code generation — both are committed, so these only matter when inputs change.
fvm dart run build_runner build                  # *.mapper.dart, after a model change
fvm dart run tool/gen/generate_rules.dart        # lib/domain/rules/*.g.dart, from ../iesdp
fvm dart run tool/dev/sync_fixtures.dart         # copy real saves into the gitignored fixtures

# Reading the player's own installation, which is where every rules fact should come from (D11/D13).
fvm dart run tool/dev/dump_table.dart weapprof   # any 2DA, exactly as it is stored
fvm dart run tool/dev/dump_table.dart --list sav # search the 604 tables by name
fvm dart run tool/dev/dump_table.dart --text 1076  # resolve a strref — ⚠️ this one is <FIGHTERTYPE>
```

**There is no CI** — deliberately (solo project, one machine). Nothing enforces the checks above,
so run them yourself before committing: `analyze`, `dart format`, and the `infinity_formats` suite.
Consequence to keep in mind: **`macos/` and `windows/` are never built by anything**, so breakage
there will surface only when someone first tries to build on those platforms.

**Platforms: desktop only** — `linux/`, `macos/`, `windows/`. No web, no mobile, deliberately: this
app reads a local game installation and writes to local save files, which is not a sandboxed-mobile
or browser workload. Development happens on Linux; macOS and Windows are scaffolded but unverified.

**`file_selector` is the one native plugin.** Added for `Add a portrait…`; it registers on
`linux/`, `macos/` and `windows/`, and the Linux debug build is confirmed to compile with it. It is
the only dependency in the project that needs anything from the platform side.

**Dependencies are kept at latest.** The project was created and then immediately brought up to
date with `fvm flutter pub upgrade --major-versions`. Prefer current versions over pinning. Note
that `matcher`, `meta`, `test_api` and `vector_math` will always report as outdated in the app —
they are pinned by `flutter_test` from the SDK and cannot be upgraded independently. That is
expected, not a problem to fix.

## Current stage

**Phases 0, 2 and 2.5 are done, and so is the UI.** Three plans are done — the Characters plan (six
slices), the creation flow (steps A–F) and **authored-and-derived** (six slices, which is what makes
a created character's numbers the ones the engine would have written) — plus the Starfleet Workbench,
which replaced the shipped UI rather than repairing it.

✅ **"Phase 1" is finished, and so is the last structural gap.** `Gam.withCreature` relocates
(2026-08-12), so **a resizing edit works inside a live savegame** and not only through export. See
`planning/roadmap.md`, which also carries the four workflows.

**The basic workflow is the product, and it works**: open a save or a character file, edit the
record, write it back. ✅ **Inventory now works too** — see `planning/inventory-seed.md` for the
researched brief and `~/.claude/plans/swirling-purring-aho.md` for the plan it was cut from.
✅ **The inventory redesign is largely done** (2026-08-14): sixteen slot-addressed cells, three
panels, a per-item menu, drag-to-portrait. Three items remain in `known-defects.md` §8 — weight and
capacity, item properties in results, categories.

⚠️ **Next, and it is an architectural decision rather than a slice: merging the character and
inventory screens.** The reasoning is `known-defects.md` §8c — equip/unequip needs *Recalculate
Stats*, and if items move the character's numbers then a screen showing the item while hiding the
numbers makes the change invisible. That reopens the recorded pushed-route shape and **D15**'s single
column, so reopen them deliberately.

> ### 🔷 The UI is the Starfleet Workbench, single column
>
> The three-spike branch **merged as `1a675af`** (PR #7) and the chosen spike has been **promoted
> into `lib/`**; `spikes/ui_spikes/` is deleted. Both decisions stand in `planning/decisions.md`:
>
> - **D15 — Workbench structure, Starfleet palette.** Picked by looking at three built options.
> - **D16 — a rules check the user can switch off**, distinguishing *impossible* from *beyond the
>   rules* from *the engine owns it*.
>
> ⚠️ **Single column, by direction and not by accident.** Panels stack in a named order —
> Character, Abilities, Skills, Proficiencies, Combat, Resistances, Condition. An earlier
> arrangement balanced them greedily across two columns and read as a zigzag. One column also
> removes the 222 px tile grid the review measured as 19.3 % dead space per row. There is **no
> breakpoint logic**: `MediaQuery` and `LayoutBuilder` are deliberately absent from the sheet.
>
> ⚠️ **Two of the review's eight defects are unreachable by the test suite**, so a Linux capture is
> the only evidence: `flutter test` runs as `TargetPlatform.android`, which pads tap targets and
> draws a full-em-square font — the 22 × 22 pip button measures 40 there, and no label-width
> assertion means anything. `planning/ui-review.md` is the critique; the widgets that answered it
> are `lib/ui/core/` and `lib/ui/character/`.

> ### 🔶 Where the last session stopped, 2026-08-14
>
> **844 app tests, 399 format tests**, `analyze` clean, `dart format` clean, zero suppressions, tree
> clean. On branch **`feat/inventory-format-layer`**, not pushed, no PR.
>
> ✅ **Flutter upgraded 3.44.8 → 3.47.0 (Dart 3.13.0), and Impeller is now the Linux renderer** —
> the launch log prints `Using the Impeller rendering backend (OpenGLESSDF)`. The upgrade surfaced
> one real defect: the home and inventory screens' `Scrollbar`s shared no controller with their
> scroll views, which 3.47 turns into a first-frame assertion on desktop (the suite runs as
> Android, where the primary controller hides it — the two new tests pin `TargetPlatform.linux`
> with the real app theme). D8 gained an amendment: 3.47's `pub get` writes seven `exclude:` lines
> into `analysis_options.yaml` itself, on every run.
>
> ✅ **THE ENGINE OPENED A RELOCATED SAVE — the project's oldest gate, closed 2026-08-13.** BG:EE
> loaded a **six-member** save this app had resized (`SCRL75` added to Xzar, fourth in the array on
> purpose), drew all six party members, and showed the scroll in his pack. Both hazardous header
> encodings were live in that file and both survived — `familiarInfo` at file-length − 400, and two
> sections parked at the **old EOF** carried to the new one. ⚠️ **Residual:** the engine *loaded*, it
> did not *re-save*, so a field it silently corrects is still invisible. **A load-then-save gives the
> byte diff** and is the cheapest strengthening left.
>
> ✅ **Inventory is now a real screen**: a 4 × 4 grid of sixteen cells addressed **by slot** (a hole
> at `pack4` draws as a hole), each cell carrying the name the game would draw *and* the resref;
> three panels — Inventory, Equipped, In no slot; the party rail and Save/undo/redo on its own app
> bar; drag an item onto a portrait to hand it over; and a `…`/right-click menu per item with
> **Remove** and **Move to**.
>
> ⚠️ **The subject is Conan, and the fixtures are his.** Arduin was deleted entirely — his `.chr`
> carried a `dialogFile` no code path explains, and his CRE resref was `*RDUIN` where an
> engine-created character carries `*HARBASE`. Fixtures hold a **2/4/6-member progression** plus the
> transfer pair, and `ConanEX.chr`. The old fixtures stay as regression data only.
>
> ⚠️ **The recurring fault of the day, four times over: a rule written twice, and the second copy
> wrong.** The naming rule, the pack-slot rule, the movable rule, the identified-name rule — each
> reached one surface correctly and another incorrectly. See
> [[a-rule-with-two-copies-is-the-bug]]. Every fix was to make it **one** copy, not to correct the
> second.

### What exists

- **`packages/infinity_formats`** — `Tlk`, `GamCodec`, `CreCodec`, `Table2da`, `IdsMap`, atomic
  file write. Format layouts are enhanced enums carrying offset, width and **signedness** (D6), so
  one table serves reader and writer and they cannot disagree. 374 tests.
  - **`Cre` resizes**: `withEntryInserted` (insert at an entry index, not only append),
    `withEntryField`, `withEffectVersion` and `readField`. The three spell sections have their own
    field tables and readers; `SplCodec` reads enough of an `SPL` header to list a spellbook.
  - **`Gam` relocates** — `withCreature` shifts the 43 pointers a resized record moves.
    `GamSection` names all nine header sections and the three encodings of "absent".
  - **`Itm` + `ItmCodec`** — the `ITM V1` header, bytes-as-the-model like `Spl`, plus the 8-byte
    resref read `Spl` has no branch for. ⚠️ **It checks the version where `SplCodec` does not**:
    `ITM` has three layouts across the Infinity games and reading V2.0 with V1's table yields a
    plausible name, type and price, all wrong.
  - **The CRE inventory layer** — `CreItemField`, `CreItemFlag`, `itemEntry`, `Cre.items`, and the
    slot table: `CreItemSlot` (⚠️ **38 slots, not 40** — the last two words are selection state),
    `itemSlots`, `withItemSlot`, `firstFreePackSlot` and `withItemRemoved`, which renumbers every
    slot above the one it drops. Adding is `withEntryAppended` then `withItemSlot`.
  - **The whole character sheet reads**: saving throws, resistances, thief skills, attacks,
    armour class modifiers, morale, fatigue, luck. Homogeneous groups come back as **records**.
  - **`Effect`** — enough of the 264-byte v2 record to find proficiencies, which on BG:EE are
    opcode 233 effects and **not** header bytes. `Gam.withEffectField` patches one.
  - **`KeyIndex` + `BifArchive`** — `chitin.key` and the uncompressed archives, so the app can
    read the player's own tables. Why that is necessary at all: **D11**.
- **The app** — save browser → party shell, `go_router`, full MVVM, Material 3. **The whole
  character sheet is editable** and writes back: sealed `EditCommand`s over a curated
  `CharacterStat` table of 49 fields, plus `SetProficiency` for the pips that live in effects;
  undo/redo on immutable savegame snapshots, atomic write leaving a `.bak`. 697 tests.
  - **Only what the class can actually have is offered.** The seven thief skills are greyed out
    when the player's `thiefscl.2da` gives that class or kit 0% of them — a Fighter/Mage has none
    — and proficiency tiles show their ceiling (`max 3`) rather than only refusing a bad value.
    ⚠️ A field whose *stored* value is non-zero stays editable whatever the table says: an anomaly
    you cannot touch is one you cannot correct.
  - **`ResourceRepository`** reads rules tables out of the player's own installation —
    `chitin.key` → BIFF → `2DA` — which is what D11 requires for anything carrying a strref.
    Names are left as strrefs there and merged with the talk table in `PartyViewModel`, because
    **repositories must never be aware of each other**. It reads `weapprof.2da` and
    `thiefscl.2da`, which share a column vocabulary — one kit-then-class resolver serves both.
- **A rules layer** — `lib/domain/rules/`, part generated from IESDP and part read from the
  player's own installation. ⚠️ **Every table is named through `GameTable` and every column through
  `TableColumn`, never a bare string** — 38 and 13 enhanced-enum values, named for *what they
  answer* rather than what the file is called, because `profs`/`profsmax` and
  `thiefskl`/`thiefscl` have each cost this project a shipped bug. `values` makes the invariants
  testable, including one that checks every resref really is in the archives. Turns stored numbers into what the game displays, **and says what a
  character's stored numbers should be in the first place**: `SavingThrowTables` (five class tables
  plus the two racial Constitution ones), `RulesTables` (THAC0, Lore, thief-skill points, the bard
  and ranger progressions, and the display modifiers), and `creation_derivation.dart`, which is the
  pure function creation uses. ⚠️ **A value you look up can still be a template** — see the
  `<FIGHTERTYPE>` defect above. Three traps, all paid for:
  - ⚠️ **`IDS` files repeat keys** — `KIT.IDS` numbers `0x4000` twice — so `IdsMap` keeps the
    *first* name and records the displaced ones; last-wins is what made the kit encoding look
    undecodable.
  - ⚠️ **IESDP's 2DA copies are per-game, and its `weapprof.2da` is the BG2:EE one.** Numeric
    tables survived that and are confirmed in game; **anything carrying a strref must come from
    the player's installation** or you ship tutorial prose as a proficiency name. **D11.**
    Confirmed against the real install 2026-08-08: proficiency 114 is `2WEAPON`, strref **25023**,
    "Two-Weapon Style". IESDP's copy says 31138 — a paragraph about temples.
  - ⚠️ **A `2DA` row label is not a key either.** BG:EE's `weapprof.2da` labels two rows `AXE` and
    two `SPEAR` — the obsolete BG1 proficiencies and the live ones — so the `ID` column is the
    key. `Table2da` keeps the displaced rows in `shadowed`, the same fix `IdsMap` needed.
  - ⚠️ **And a table can hold whole generations of itself.** `weapprof.2da` has 46 rows in three
    bands — obsolete BG1 at ids 0–7, live EE at 89–115, and fourteen padding rows at 116–129 whose
    `NAME_REF` is `4294967296` (2³², beyond any talk table). **Only the padding is detectable from the
    file**; the obsolete band carries valid names, valid descriptions and non-zero caps. So the live
    floor is a **measured constant** — D18, from reading all 2,253 shipped creature records — and
    `ProficiencyCatalogue.live` is where it lives. Offering the file whole put `Bow` beside `Long Bow`
    and fourteen rows called `EXTRA*` on the sheet, in creation as well.
- ⚠️ **Two portraits, two purposes, and confusing them is a shipped defect.**
  `Character.portraitBaseName` is the resref the record names and is **what a sheet shows**;
  `portraitPath` is `PORTRT<n>.bmp` beside the save — a stale snapshot the engine drew, kept only as
  this project's cheapest oracle. `dart:ui` decodes BMP, so no BAM decoder is involved, and
  `PORTRT<n>` is the n-th **party slot**, settled 2026-08-08.

### The gate that matters, and it passed

**An edited save loaded in BG:EE with Strength 19 and THAC0 15 applied and every other value
intact** (2026-08-07). In test, `Gam.withCreatureField` changes *exactly one byte* of the real
95,968-byte fixture.

**Passed again on 2026-08-08, one layer deeper — a field inside an *effect*.** Two edits, one
save, one load: Xzar's Save vs. Spell 12 → 5 (a header byte) and Aard's Two-Weapon Style 2 → 3
(parameter 1 of a 264-byte opcode 233 record). The file kept its 101,352 bytes and **exactly two
differ from the `.bak`**. BG:EE printed `Spell: 5` with the four neighbouring saving throws
untouched, and `Two-Weapon Style +++`.

⚠️ **The engine applied the pip, it did not merely display it.** Aard's off-hand THAC0 breakdown
reads `Two-Weapon Style: +2`, and the game's own `stylbonu.2da` gives `THAC0_LEFT` of 4 at two
pips and 2 at three — so `+2` is reachable only from three. His off-hand THAC0 moved 14 → 12
while the main hand correctly did not, `THAC0_RIGHT` being 0 in both rows. The second effect one
stride away was untouched, confirmed independently by the engine's own `Proficiencies: -1`
(`wspecial.2da` row 2 — still two pips in Flail/Morning Star).

### What the game taught us that reasoning did not

Read `docs/findings/verified-format-offsets.md` §Stored vs displayed before touching a stat. In
short: **a savegame stores base values.** Hit points and THAC0 are both modified before display,
and armour class is read from the **effective** field (`0x48`), not the "natural" one — which
reversed the reasoning that had picked natural. Each of these was settled by loading the game, and
each contradicted an argument from the spec.

The cheapest oracle is the one nobody noticed: **the game bakes its own HUD into `PORTRT<n>.bmp`**,
so every save ships a picture of what the engine believed when it was written. On a *multi-member*
party it doubles as an identity oracle — four members with four different hit-point totals
fingerprint which file belongs to whom, which is what settled the portrait mapping.

⚠️ **But a portrait is a snapshot, so it can only ever confirm the state it was written in.** The
Constitution-18 run nearly fell into this: the losing hypothesis predicted `39 / 42`, which is
exactly what the stale portrait already showed, so a wrong answer would have been
indistinguishable from "the save was never reloaded". When the run has to *change* something, read
the number the engine **prints** — `Bonus Hit Points/Level` — not the number it drew earlier.

**And the record lies in the direction of the fixtures you have.** A savegame does **not** zero
its unused class-level slots: only the player's own character stores `01 01 00`, while every
shipped NPC stores `01 01 01`. Read the slot count from `CLASS.IDS`, never from the bytes. The
same applies to the CRE resref — the engine overwrites its **first byte** with `*`, so
`CHARBASE` arrives as `*HARBASE` and the resref is not an identity key. Use `dialogFile`.

**The protagonist is not shaped like a companion**, and that has now cost four findings — the
level slots, the morale break point (`0` and recovery `1` against every NPC's `4`–`5` and `60`),
and reputation. ⚠️ **A value duplicated between the GAM and a CRE is not necessarily maintained
in both:** the party's reputation is 11.0 and the engine prints 11, while Imoen's, Montaron's and
Xzar's own copies sit stale at 10.0 and only Aard's agrees. Prefer the field the engine is known
to read, and find out which that is by looking. **A one-character party can never show any of
this**, because there the two always match.

**⚠️ And the game ships its own oracle, which took months to notice.** Every NPC is a creature
record in the archives, built by the people who wrote the rules, and `ResourceRepository.creature()`
reads one. On 2026-08-10 that settled the multi-class saving-throw rule — which BG:EE's own Aurel
could *not* separate — and exposed a racial Constitution bonus nobody had asked about. **Reach for
it before asking for a trip into the game**; the engine is still the only answer to *acceptance*
("does IMPORT take this file"), but this is far cheaper for *equivalence*. ⚠️ They are hand-authored
in places — `KHALID` holds a Lore no rule produces — so agreement is evidence and disagreement is
not disproof. Order of authority: **engine > table > shipped file**.

### Open, and recorded rather than guessed

None of these is blocking; none is guessed at in code. All are in the findings.

| Question | State |
|---|---|
| `PORTRT<n>` index mapping | **Closed 2026-08-08.** `PORTRT<n>` is the n-th party slot, fingerprinted by the hit points the game bakes into each image. |
| Kit encoding | **Closed 2026-08-08.** `0x0244 >> 16` is the `KIT.IDS` key; `0x0` and `0x4000` (`TRUECLASS`) both mean no kit. ⚠️ A kit **replaces** the class name — the game writes `Necromancer`, never `Mage (Necromancer)`. |
| `hpconbon` warrior column | **Closed 2026-08-08.** Raised to Constitution 18 and loaded: the engine printed `Bonus Hit Points/Level: +4`, the warrior row, on a **Fighter/Mage**. `warriorRoots` was right, and the rule is *containment* — half a fighter is a warrior. |
| Multi-class hit-point multiplier | **Closed 2026-08-09 — the MEAN class level, not the highest.** D10's route worked exactly as written: experience was set to 4000, no level was written, and the engine did the rest. A Fighter 2 / Mage 1 at Constitution 18 stores 12 and the game draws **18 / 18** into its portrait, so the bonus is 6 where highest gives 8. ⚠️ It hid for two days because **mean and highest are the same number for a single class**. `hitPointBonus` is fixed. Residual: how it rounds when the mean is not exact. |
| THAC0 after a level-up | **Closed 2026-08-10 — the engine never recomputes it.** The separating experiment was run: a stored **25** against a computed 20, *worse* either way, survived import and play. The screen printed `Base THAC0: 25`, `THAC0: 22`, `Strength Modification: -3`. The same run closed the percentile question — a stored `strengthBonus` of 100 prints **`18/00`**. |
| Who may Turn Undead, and who may Track | **Half-closed 2026-08-10.** Stored 25 and 100 on a Fighter/Mage/Thief both **survived** the record and the Skills tab showed **neither** — so the display is class-gated and a stored value alone grants nothing. *Which* classes qualify is still in no table that has been found, so both stay editable rather than take an invented rule. |
| Multi-class saving throws | **Closed 2026-08-10 — best of each column, each class at its own level.** QUAYLE, a Cleric/Mage, stores a row neither table holds. ⚠️ Plus a racial Constitution bonus: `savecndh` for dwarves and halflings, `savecng` for gnomes, whose death row is all zeros. |
| Multi-class **Lore** | **Closed 2026-08-11 — the HIGHEST, not the sum.** A Gnome Cleric/Illusionist made in BG:EE's own flow stores **3** where a sum gives 4. The shipped NPCs read like sums and cannot referee it (they hold a Fighter 1 with Lore 4); this record was written by the engine at creation. Code already followed the engine. ⚠️ Still open and *not* in code: the walkthrough says a **Blade** gets half Lore per level, and `lore.2da` has no kit rows. |
| The proficiency pip cap | **Closed 2026-08-11 — `min(profsmax.FIRST_LEVEL, weapprof[column])`.** `profsmax` gives every row 2; `weapprof` gives `CLERIC`/`THIEF`/`CLERIC_MAGE` **1** and `FIGHTER` 5. Engine-confirmed: a thief was refused a second pip with a slot unspent. ⚠️ **The column is not simply the kit's** — `SWASHBUCKLER` is 2 where `THIEF` is 1, but `ILLUSIONIST` is 0 for War Hammer where `CLERIC_MAGE` is 1 and the engine gave the gnome one. Kit's column when the kit is the whole class; class's column when multi-class. ⚠️ **Implemented in creation ONLY — the character sheet is still wrong, verified 2026-08-12.** `CreationViewModel.rankCapFor` (`lib/ui/creation/creation_viewmodel.dart:305-314`) takes the `min`; `CharacterSheet.maximumPipsFor` (`lib/domain/rules/character_sheet.dart:148-149`) returns `weapprof`'s class column **alone**, so the sheet offers a fighter **5**. This entry claimed both for a day. Not a copy-paste: creation is always level 1 and the sheet is not, so the sheet needs `profsmax` against the character's own level. **Owed.** |
| A forced specialisation | **Closed 2026-08-11.** A multi-class gets **no kit screen**, yet a Gnome Cleric/Illusionist stores `kit = 0x04000000` → `MAGESCHOOL_ILLUSIONIST`. `clsrcreq.2da`'s `GNOME` column allows exactly one school, so the choice is a lookup and only the forcing is a rule. **Implemented 2026-08-11**; `clsrcreq.2da`'s forty kit rows were being dropped by the catalogue, which also meant a gnome mage was offered all eight schools. |
| A specialist's forbidden school | **Closed 2026-08-10 — it is in each `SPL`,** exclusion flags at `0x1E`, bit = `mschool.2da` row + 5. Exact across all 22 first-level spells. No 2DA pairs the schools. |
| Which fields the engine owns | **Closed 2026-08-10 — D14.** A probe character with every field at an underivable value was imported, played and saved: the engine overwrote **six** fields and left **sixty-seven** alone. Hit points and Lore store the class-and-level part only, with the ability bonus added at display. |
| Which proficiencies are live | **Closed 2026-08-12 — ids ≥ 89, and it is a measured constant.** `weapprof.2da` holds three generations; only the padding band is detectable from the file, because the obsolete BG1 rows carry valid names, valid descriptions and non-zero caps. **All 2,253 shipped creature records** use 24 ids and **none below 89**. **D18**, and per-game. |
| `CHARBASE`'s `numberOfAttacks = 255` | **OPEN, and not guessed at.** The engine's own creation template stores 255 where `IMOEN`, `MINSC` and `KHALID` all store `1`, so every created character carries it. The field encodes 0–10, so the sheet says **nothing** about what the game draws for it rather than extrapolating — it used to report `499/2`. Three readings fit (an *engine computes this* sentinel, junk, or a value it clamps) and no measurement separates them. One trip into the game settles it: `docs/findings/known-defects.md` §5b. |

⚠️ **Seeing the screen is still the only way some defects surface, and the tally keeps growing.**
On 2026-08-12 a clean `analyze` and **743 passing tests** shipped, in one branch:

- **a red error screen** — `SelectionArea` in `MaterialApp.router`'s `builder` sits above the
  router's `Navigator`, so there is no `Overlay` and `SelectableRegion` throws on frame one. The app
  did not start;
- a findings badge reading **13** on a healthy character;
- a sheet that **named nobody**, because the identity header was missing and the app bar names the
  *document*;
- `in game 499/2` on attacks per round;
- the first row looking greyed, from a focus highlight that mimics the *unavailable* plate.

Before that the stat tiles were too narrow **twice** — 148 truncated "Exceptional strength", 222 was
needed for "Paralysis / Poison / Death" — and each time the suite, the analyzer and code review all
passed.
Rendering and measuring in a test does not help: `flutter test` draws with a font whose every
glyph is a full em square, so it reports labels as overflowing that fit perfectly well. What is
in the suite is a budget on the label *strings*. **Look at a capture after any panel change.**
On this machine the app is a Wayland window and XTEST cannot reach it, so driving it by
synthetic clicks does not work; rendering the widget tree to a PNG with a real font loaded via
`FontLoader` does.

⚠️ **All three of the closed ones were open only because the fixtures were too plain.** Two needed
a party of more than one; the third needed one number above 16. A save with four members and a
Constitution edit closed all three in an afternoon and exposed two defects the blind spot had been
hiding — `Level 1/1/1` on a single-class Thief, and an `IdsMap` that silently dropped a duplicate
key. **When a question's answer depends on a shape the fixtures do not have, the fixture is the
thing to go and get.**

⚠️ **One finding constrains Phase 4.** Because the engine reads a *stored* effective armour class
rather than recomputing it from equipment, equipping an item will not update armour class by
itself. EE Keeper's "Recalculate Stats" is therefore **required**, not the optional parity feature
the roadmap files it as.

### ✅ "Phase 1" is finished — the GAM relocation shipped 2026-08-12

**Shipped:** the CRE-internal layout pass (`Cre.withEntryInserted` creates an absent section, splices
an entry, raises its count, shifts every sibling offset and relocates the item-slot table), original-
byte retention, atomic write with a `.bak`, and now **`Gam.withCreature`**. **Superseded:** the
round-trip gate, because byte identity on an *unedited* file proves nothing — `return input` passes
it. The gate that shipped is *exactly N pointers differ*.

⚠️ **Its premise was false too.** It claimed the layout pass "becomes unavoidable at Phase 4, when
inventory and spells start resizing". **Spells already resized** through a `.chr`, where the same
edit costs one pointer.

⚠️ **The recorded cost was wrong, and building it is what found that.** This file said **39
pointers**; it is **43** — 36 non-party `creOffset` fields, **6** GAM header section offsets, and the
owning struct's `creLength`. Measured on `000000022-last`: the protagonist sits at 532, runs 6,780
bytes, and growing it shifts 95,436. The old figure counted only the header offsets `GamHeaderField`
happened to model, and the enum stopped at `0x58`.

**Now named, and all four were missing:** `familiarExtraOffset` `0x48`, `familiarInfoOffset` `0x68`,
`storedLocationsOffset` `0x6c`, `pocketPlaneOffset` `0x78`. ⚠️ **`0x68` is live on every save** —
always file length − 400 — so a relocation blind to it corrupts silently.

**"Absent" is encoded three different ways** in that one header, and `GamSection` is where that now
lives — `0` and `0xFFFFFFFF` are skipped; **offset-equals-EOF-with-count-0 is not**, because the
engine keeps those at the end of the file. It needs no special case: an offset equal to the old EOF
is past any splice, so the ordinary shift carries it to the new EOF for free.

### ✅ The engine opened a relocated save — 2026-08-13

**The trip was made and the relocation passed.** `000000023-Conan Inventory Move`, a **six-member**
party, had `SCRL75` added to **Xzar** — fourth in the array, so his growth moves the two records
after him as well as the header sections. BG:EE **loaded it, drew all six party members, and showed
the scroll in his pack.**

The write was byte-exact: 107,588 → 107,608, one 20-byte entry. Xzar `len 2868 → 2888`; **Jaheira
`18728 → 18748` and Khalid `21856 → 21876`, and nobody before Xzar moved at all.** Six header
sections shifted by exactly 20 — `nonPartyNpcs`, `globals`, `journal`, `familiarInfo`,
`storedLocations`, `pocketPlane`.

⚠️ **Both hazardous encodings were live in this file and both survived.** `familiarInfo` sat at
file-length − 400 before and still does after. `storedLocations` and `pocketPlane` were both parked
at the **old EOF** — the third encoding of "absent", the one that must *not* be skipped — and the
ordinary shift carried them to the new EOF exactly as predicted.

⚠️ **What this does not cover.** The engine was not asked to *re-save*, so nothing rules out a field
it silently corrects rather than rejects. A load-then-save would give a byte diff and is the cheapest
remaining strengthening.

The read-path spike that started this project was **deleted** on 2026-08-08 once all four of its
recorded bugs were answered and everything it did lived in tested code. It is in git history.

⚠️ **TLK strings are UTF-8, not cp1252.** Earlier notes throughout this repo said cp1252; that was
falsified against the shipped game data on 2026-08-07 and is corrected everywhere. cp1252 is real
for the *classic* engine, which D3 puts out of scope.

See `planning/roadmap.md` for Phases 1–7.

## A warning about this domain

This application writes to files that represent tens of hours of someone's play. The failure mode
is not a crash — it is a save that loads and is subtly wrong, or does not load at all. Two specific
hazards, both already observed:

1. **Never infer a size or a stride from the difference between two offsets.** An offset field of
   `0` means the section is **absent**, not that it sits at the start of the file — all three
   BG1EE fixtures carry `partyInventoryOffset = 0`, which is exactly how the spike computed a
   stride of **−180**. Read the documented struct size: the GAM party NPC struct is **352 bytes**,
   verified three ways in `docs/findings/verified-format-offsets.md`.
2. **Editing changes sizes.** A CRE that grows moves every subsequent offset in the GAM, and the
   same applies inside CRE itself (known spells, memorisation, item slots, effects each carry
   offset+count headers). Offset recalculation on write is where save corruption comes from.

Prefer verifying against an oracle over reasoning from a spec. See
`docs/findings/verified-format-offsets.md` §Oracles.
