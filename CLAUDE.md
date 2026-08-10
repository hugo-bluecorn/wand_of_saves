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
| UI | Win32/MFC, MDI, 31 modal dialogs | Material 3, adaptive desktop layout |
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
6. `context/` — the pinned target-side canon (Flutter AI rules, Effective Dart, MVVM record,
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
- **Dart/Flutter are NOT on PATH** — use `fvm flutter …` / `fvm dart …`. SDK pinned to 3.44.8
  in `.fvmrc`.
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

**Phases 0, 2 and 2.5 are done. Both character plans are done** — the Characters plan (six
slices) and the creation flow (steps A–F).
Phase 1 is deferred on purpose — see below. `planning/roadmap.md` has all seven phases and the
four workflows they serve.

> ### 🔶 Where the last session stopped, 2026-08-10
>
> **The creation wizard is finished, and D14 is measured.** 543 app tests, 282 format tests,
> `analyze` clean, no suppressions.
>
> - **Ten steps**, the game's own order: Gender → Picture → Race → Class → Specialisation →
>   Alignment → **Abilities → Proficiencies → Spells** → Name. Three of them are conditional and
>   every condition is a table's answer: kits from `kitlist`, pips from `profs.2da`, spells from the
>   `mxspl*` progressions — which is how a **bard** correctly gets no spell step at first level.
> - ⚠️ **The record it grows now equals the engine's.** `creation_golden_test.dart` compares against
>   the character BG:EE itself made and they agree on the **proficiency map**, the **two known
>   spells**, the **memorised spell** and the **memorisation row** — all three sections `CHARBASE`
>   does not have. `contentEnd == bytes.length` after four resizes.
> - **Abilities are rolled from an injected `Random`** (`abilityDiceProvider`) — the first
>   non-deterministic thing in the app, and a provider so the flow can be tested at all.
> - **The list of level-1 wizard spells is in no table.** It comes from the `SPL` headers and needs
>   **three** filters; the third is that the resref's level digit must agree with the header's, or
>   `SPWI989` comes along. 108 candidates become the 22 the Mage Book screen shows.
>
> **⚠️ Two defects were found and fixed, one of them shipped:**
>
> - **`GrantProficiency` threw against the real `CHARBASE`.** The template is `effectVersion` **0**
>   — 48-byte v1 effects — and a proficiency is a 264-byte v2 record, so the first proficiency
>   granted to any created character was refused. **No test could see it**: the synthetic creature
>   wrote v2 unconditionally, which is true of every character in a save and of nothing a new one is
>   built from.
> - **`Tlk.get` could not be called concurrently** — a seek and then a read on one handle, so two
>   overlapping lookups broke both. Latent for weeks; it surfaced when one caller grew a few more
>   strrefs.
>
> **D14 closed by measurement.** A probe character with every field at an underivable value was
> imported, played and saved: **the engine overwrote six fields and left sixty-seven alone.**
> `tool/dev/make_probe_character.dart` builds it, `tool/dev/compare_characters.dart` diffs it.
>
> ⚠️ **The next plan is written and deliberately unstarted**:
> `~/.claude/plans/authored-and-derived.md`.
>
> ⚠️ **Still owed, and now the only thing between this and Phase 2 being finished:** one trip into
> BG:EE for the **export** half of the gate. This run got a savegame instead, because EXPORT is
> greyed out for an intoxicated character.

### What exists

- **`packages/infinity_formats`** — `Tlk`, `GamCodec`, `CreCodec`, `Table2da`, `IdsMap`, atomic
  file write. Format layouts are enhanced enums carrying offset, width and **signedness** (D6), so
  one table serves reader and writer and they cannot disagree. 282 tests.
  - **`Cre` resizes**: `withEntryInserted` (insert at an entry index, not only append),
    `withEntryField`, `withEffectVersion` and `readField`. The three spell sections have their own
    field tables and readers; `SplCodec` reads enough of an `SPL` header to list a spellbook.
  - **The whole character sheet reads**: saving throws, resistances, thief skills, attacks,
    armour class modifiers, morale, fatigue, luck. Homogeneous groups come back as **records**.
  - **`Effect`** — enough of the 264-byte v2 record to find proficiencies, which on BG:EE are
    opcode 233 effects and **not** header bytes. `Gam.withEffectField` patches one.
  - **`KeyIndex` + `BifArchive`** — `chitin.key` and the uncompressed archives, so the app can
    read the player's own tables. Why that is necessary at all: **D11**.
- **The app** — save browser → party shell, `go_router`, full MVVM, Material 3. **The whole
  character sheet is editable** and writes back: sealed `EditCommand`s over a curated
  `CharacterStat` table of 49 fields, plus `SetProficiency` for the pips that live in effects;
  undo/redo on immutable savegame snapshots, atomic write leaving a `.bak`. 543 tests.
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
- **A rules layer** — `lib/domain/rules/`, generated from IESDP's copies of the game's own `2DA`
  and `IDS` tables. Turns stored numbers into what the game displays. Two traps, both paid for:
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
- Party portraits come from `PORTRT<n>.bmp` beside each save; `dart:ui` decodes them, so no BIFF
  index or BAM decoder is involved. `PORTRT<n>` is the n-th **party slot**, settled 2026-08-08.

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
| Which fields the engine owns | **Closed 2026-08-10 — D14.** A probe character with every field at an underivable value was imported, played and saved: the engine overwrote **six** fields and left **sixty-seven** alone. Hit points and Lore store the class-and-level part only, with the ability bonus added at display. |

⚠️ **Seeing the screen is still the only way some defects surface.** The panel's stat tiles have
now been too narrow **twice** — 148 truncated "Exceptional strength", 222 was needed for
"Paralysis / Poison / Death" — and both times the suite, the analyzer and code review all passed.
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

### Phase 1 is deliberately deferred, and that is not an oversight

Phase 1 is the writer's **layout pass** — the cascade where a resized section shifts every offset
after it. It was skipped because **nothing in Phase 2 needs it**: gold, XP, HP, THAC0, ability
scores and reputation are all *fixed-width* fields, and the existing patch-a-copy writer already
handles them, proven in-game.

**So the hard problem is untouched.** Every CRE section is variable-length: adding one item moves
everything after it in the CRE, then the CRE's size in the GAM NPC struct, then every GAM offset
past that. Two facts recorded for whoever picks it up, both in
`docs/findings/verified-format-offsets.md`:

- **`GamHeaderField` records five of the GAM's nine offset fields.** A layout pass that relocates
  data without patching all nine corrupts the save silently.
- **"Absent" is encoded three different ways** in that one header — `0`, `0xFFFFFFFF`, and
  *offset-equals-EOF with count 0*. The `offset != 0` rule used elsewhere is not sufficient there.

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
