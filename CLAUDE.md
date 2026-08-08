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
  *for Riverpod*** (D2). No `@riverpod` annotations, no `*.g.dart`. This is a *declared
  deviation* from `context/flutter-ai-rules.md`'s native-first default; everywhere else, a
  disagreement with `context/` is still a defect. See `planning/architecture.md` §The provider
  graph.
- **Code generation is decided per dependency** (D9). D2's denial covers Riverpod, not the
  project — it has already been misread as a blanket ban. Serialization and data classes use
  **`dart_mappable`**, which brings `build_runner` in with it when the first domain model lands
  in Phase 2.
- **Work test-first, and plan before coding.** Write the failing test, **run it to confirm it
  fails for the right reason**, then implement. Before starting any implementation not already
  covered by an approved plan, enter plan mode and get the plan agreed. **Do not use the
  `tdd-workflow` plugin** — not its skills, agents or slash commands. Hand-rolled TDD only; the
  point is the discipline, not the scaffolding.
- **Lint is `very_good_analysis`, applied whole, with NO suppressions** (D8). No `exclude:`
  entries, no rule carve-outs, no `// ignore` or `// ignore_for_file` anywhere. This is
  checkable, so check it:
  `grep -rn 'ignore_for_file\|// ignore:' --include='*.dart' .` must return nothing. If a rule
  is unsatisfiable, fix the code or reopen D8 — do not silence it.
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
fvm dart run tool/spike/gam_cre_tlk_spike.dart   # the working read-path spike

# The infinity_formats suite is a separate package and runs from its own directory.
# `fvm dart test` at the repo root finds nothing and prints usage.
cd packages/infinity_formats && fvm dart test
```

**There is no CI** — deliberately (solo project, one machine). Nothing enforces the checks above,
so run them yourself before committing: `analyze`, `dart format`, and the `infinity_formats` suite.
Consequence to keep in mind: **`macos/` and `windows/` are never built by anything**, so breakage
there will surface only when someone first tries to build on those platforms.

**Platforms: desktop only** — `linux/`, `macos/`, `windows/`. No web, no mobile, deliberately: this
app reads a local game installation and writes to local save files, which is not a sandboxed-mobile
or browser workload. Development happens on Linux; macOS and Windows are scaffolded but unverified.

**Dependencies are kept at latest.** The project was created and then immediately brought up to
date with `fvm flutter pub upgrade --major-versions`. Prefer current versions over pinning. Note
that `matcher`, `meta`, `test_api` and `vector_math` will always report as outdated in the app —
they are pinned by `flutter_test` from the SDK and cannot be upgraded independently. That is
expected, not a problem to fix.

## Current stage

**Phase 2 — the app has a window.** Phase 0's read path is complete and Phase 1 is deliberately
deferred (see below). What exists:

- ✅ Flutter scaffold (`flutter create --empty --platforms=linux,macos,windows`), SDK pinned,
  dependencies brought to latest with `pub upgrade --major-versions`.
- ✅ Apache-2.0 adopted (D1), `LICENSE` + `NOTICE` in place.
- ✅ Riverpod 3.x wired, no code generation (D2); `ProviderScope` wraps the app.
- ✅ Target-side canon carried over in `context/`.
- ✅ EE Keeper reverse-engineered; feature set and UI spec extracted
  (`docs/findings/eekeeper-ui-spec.json`, 72 dialogs / 927 controls / 173 classes —
  structure only; proprietary prose deliberately redacted, do not re-add).
- ✅ Format offsets for `GAM V2.0` and `CRE V1.0` verified against a real save.
- ✅ **A working read-path spike** — `tool/spike/gam_cre_tlk_spike.dart` parses
  GAM → party → embedded CRE → `dialog.tlk` in ~120 lines of pure Dart, and runs today.
- ✅ **`Tlk` shipped** — `packages/infinity_formats/lib/src/tlk/`, written test-first, 20 tests
  passing. 16 are hermetic (built against synthetic in-test fixtures, so they run on a fresh
  clone with no game installed); 4 confirm documented values against the real `dialog.tlk` and
  skip when it is absent. `InfinityFormatException` lives alongside it.
- ✅ **Fixture harness + `FormatField` + `GamCodec` header read/write.** `tool/dev/sync_fixtures.dart`
  copies real saves into a gitignored fixture directory; format layouts are enhanced enums with a
  reusable layout invariant; `Gam` keeps the source bytes as an unmodifiable view and edits patch a
  copy.
- ✅ **The write path is proven in-game** (2026-08-07) — party gold edited on a real save, 2 bytes
  changed out of 95,968, loads in BG:EE showing the new value. See
  `docs/findings/verified-format-offsets.md` §Write path. **It proves the mechanism, not offset
  recalculation** — nothing resized.
- ✅ **GAM NPC structs and `CreCodec` read path.** The 352-byte NPC struct with an exact-fit layout
  invariant, party and non-party arrays, embedded-CRE location, and the CRE header with its six
  sections. All 37 creatures in a real save parse, and the CRE section chain closes on each one's
  declared length.
- ✅ **The Flutter app has a window** — save browser with real save screenshots, full MVVM
  (`GameProfileService` → `SaveGameRepository` → `SaveBrowserViewModel` → view), Material 3 theme.
  `lib/` is no longer a stub.
- ✅ **The editor shell opens a save** (2026-08-07) — `go_router`, the party as a portrait rail,
  and a read-only character pane showing HP, XP, gold, THAC0, AC, reputation and the six ability
  scores. `Character`/`AbilityScores` domain models via `dart_mappable`, `StringRepository` over
  `dialog.tlk`, and `PartyViewModel` merging the two repositories. Two recorded spike bugs closed:
  **#4 (arbitrary locale)** and the display half of **#2 (`strref = -1`)**.
  - **Party portraits come free.** Every save slot carries `PORTRT<n>.bmp` (54×84, 24-bit), which
    `dart:ui` decodes — no BIFF index, no BAM decoder. Its *index mapping* is unverified: every
    fixture here is a one-character party.
  - ⚠️ **Hit points are stored without the Constitution bonus** — the save says `6/7` where the
    game shows `8/9`. Found by reading the game's own HUD overlay baked into the portrait, which
    makes those BMPs a **fourth oracle**. The UI labels the field "Hit points (base)". Suspect the
    same of AC and THAC0; both unchecked.
- ✅ **The Phase 2 gate is met** (2026-08-07) — stats are editable and write back. Sealed
  `EditCommand`s over a curated `CharacterStat` table, undo/redo on immutable savegame snapshots,
  atomic write with a `.bak`. **An edited save loaded in BG:EE with Strength 19 and THAC0 15
  applied and every other value intact.** `Gam.withCreatureField` changes exactly one byte of the
  real 95,968-byte fixture.
  - **THAC0 is a base, like hit points** — the game showed `15` − 3 (Strength) + 2 (Proficiencies).
  - **The Constitution finding is confirmed by the engine itself**, which prints
    "Bonus Hit Points/Level: +2".
  - ✅ **Armour class settled** (2026-08-08): the engine reads the **effective** field (`0x48`).
    Writing `6` there showed `Armor Class: 6` in game; natural (`0x46`) moved nothing in either
    run. This reversed the reasoning that picked natural, and it means **equipping an item will
    not update armour class by itself** — "Recalculate Stats" is required, not optional.
- ✅ **Phase 2.5 — the rules layer** (2026-08-08). `Table2da` and `IdsMap` in the package;
  `tool/gen/generate_rules.dart` turns IESDP's copies of the game's own tables into committed Dart;
  `GameRules` and `CharacterSheet` above them. **No KEY/BIFF reader was needed** — IESDP ships 198
  BG:EE `2DA` files and the `IDS` tables as plain data.
  - The pane now reads `Male · Elf · Fighter / Mage · Neutral Good`, shows hit points and armour
    class **as the game will show them**, and puts each ability's modifier in its label. Every one
    of those is asserted against a value BG:EE printed in a screenshot, so the suite is an oracle
    comparison needing no game installed.
  - **Bounds can depend on another field.** Current hit points are capped by *maximum* hit points,
    not by the field's width — the engine discards anything above it. A savegame that arrives
    inconsistent shows the error rather than rendering as if it were fine.
  - Three things the tables still cannot answer, all recorded in the findings rather than guessed:
    the rules-based **hit-point cap** (IESDP ships no per-class dice tables), the **warrior column**
    (needs a Constitution 17+ character), and the **kit encoding** (the obvious decoding names a kit
    for every character who has none).
- ⬅️ **Here: Phase 3, the resource index.** KEY/BIFF in an isolate. It buys the real 2DA/IDS tables
  from the player's own install — which is what a *modded* game needs, and what settles the three
  open questions above — plus item and spell pickers.

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

Also still outstanding: **four known bugs in the spike must be fixed properly rather than papered
over** — see `docs/findings/verified-format-offsets.md` §Known bugs.

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
