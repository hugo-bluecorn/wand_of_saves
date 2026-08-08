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

**Dependencies are kept at latest.** The project was created and then immediately brought up to
date with `fvm flutter pub upgrade --major-versions`. Prefer current versions over pinning. Note
that `matcher`, `meta`, `test_api` and `vector_math` will always report as outdated in the app —
they are pinned by `flutter_test` from the SDK and cannot be upgraded independently. That is
expected, not a problem to fix.

## Current stage

**Phases 0, 2 and 2.5 are done and merged to `main` (PR #3, 2026-08-08). Phase 3 is next.**
Phase 1 is deferred on purpose — see below. `planning/roadmap.md` has all seven phases.

### What exists

- **`packages/infinity_formats`** — `Tlk`, `GamCodec`, `CreCodec`, `Table2da`, `IdsMap`, atomic
  file write. Format layouts are enhanced enums carrying offset, width and **signedness** (D6), so
  one table serves reader and writer and they cannot disagree. 140 tests.
- **The app** — save browser → party shell, `go_router`, full MVVM, Material 3. Stats are editable
  and write back: sealed `EditCommand`s over a curated `CharacterStat` table, undo/redo on
  immutable savegame snapshots, atomic write leaving a `.bak`. 137 tests.
- **A rules layer** — `lib/domain/rules/`, generated from IESDP's copies of the game's own `2DA`
  and `IDS` tables. Turns stored numbers into what the game displays.
- Party portraits come from `PORTRT<n>.bmp` beside each save; `dart:ui` decodes them, so no BIFF
  index or BAM decoder is involved.

### The gate that matters, and it passed

**An edited save loaded in BG:EE with Strength 19 and THAC0 15 applied and every other value
intact** (2026-08-07). In test, `Gam.withCreatureField` changes *exactly one byte* of the real
95,968-byte fixture.

### What the game taught us that reasoning did not

Read `docs/findings/verified-format-offsets.md` §Stored vs displayed before touching a stat. In
short: **a savegame stores base values.** Hit points and THAC0 are both modified before display,
and armour class is read from the **effective** field (`0x48`), not the "natural" one — which
reversed the reasoning that had picked natural. Each of these was settled by loading the game, and
each contradicted an argument from the spec.

The cheapest oracle is the one nobody noticed: **the game bakes its own HUD into `PORTRT<n>.bmp`**,
so every save ships a picture of what the engine believed when it was written.

### Open, and recorded rather than guessed

None of these is blocking; none is guessed at in code. All are in the findings.

| Question | What it needs |
|---|---|
| Multi-class hit-point multiplier | a higher-level multi-class character |
| `hpconbon` warrior column | a character with Constitution 17+ |
| Kit encoding | Phase 3, or a kitted character |
| `PORTRT<n>` index mapping | a save with 2+ party members |

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
