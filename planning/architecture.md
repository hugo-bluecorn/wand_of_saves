# Architecture

Full MVVM per `context/mvvm-architecture-record.md` (D5). Development proceeds **model → UI**.
State management is **Riverpod 3.x with manually declared providers — no code generation** (D2), and
dependency injection goes through those providers rather than constructor arguments (D7). Both are
*declared deviations* from `context/flutter-ai-rules.md`; everywhere else, a disagreement with
`context/` is a defect, not a preference.

Dart construct choices — which language feature models what — are recorded separately in
`context/dart-data-modelling.md`, with citations. This document says how the layers fit together;
that one says what to build them out of.

## The layers

Four core layers, one optional. Charter and rules from `context/mvvm-architecture-record.md`.

| Layer | Charter | State it owns |
|---|---|---|
| **View** | Presents data. `ConsumerWidget`s. May do show/hide, animation, layout, simple routing. | Pure UI state only |
| **ViewModel** | Exposes what a view needs to render; most app logic lives here. Surfaces **commands**. | Presentation state, survives rebuilds |
| **Use-Case** *(optional)* | Merges repositories, or logic reused across ViewModels. | None |
| **Repository** | Source of truth for a data type. Owns caching, retry, error translation. Outputs **domain models**. | Source-of-truth + app-wide session state |
| **Service** | Wraps one data source — platform APIs, **local files**. | **Nothing.** Stateless by rule. |

**Dependencies are unidirectional:** View → ViewModel → (Use-Case →) Repository → Service. Never
backwards. **View : ViewModel is 1 : 1** — a ViewModel pairs with a *collection* of widgets, and
each such pair defines one feature.

**Repositories must never be aware of each other.** This bites immediately: the party view needs
`SaveGameRepository` (the GAM), `StringRepository` (TLK strings) and later `ResourceRepository`
(item and spell names) at once. That merge belongs in a **use-case** or the ViewModel — never in a
repository reaching sideways.

**Resolved 2026-08-07: it is in the ViewModel, and there is no use-case layer yet.**
`PartyViewModel` reads both repositories and fills in the names the savegame does not carry. The
canon allows either home for cross-repository logic, and `ViewModel : Repository` is many-to-many,
so the smaller of the two is the honest choice while exactly one ViewModel needs it. It moves to a
use-case when a second one does — which is likely at the item and spell pickers.

## Package split

```
packages/infinity_formats/          pure Dart — NO package:flutter, ever
  lib/src/
    gam/        GamCodec, GamHeader, PartyNpc
    cre/        CreCodec, Creature, abilities, spells, items, effects
    tlk/        Tlk (lazy, LRU), TotToh (save-local string overrides)
    itm/ spl/   read-only metadata for pickers
    key/        Keyfile, BiffReader  (Phase 3)
    sav/        SavArchive — zlib entries (deferred; not needed for party editing)
    bam/        BamV1Decoder, BamV2Decoder, Palette  (Phase 5)
    tables/     Table2da, IdsMap
    spec/       format layouts as enhanced enums — data, no logic
    exceptions.dart
  test/         fixture-driven, round-trip gated

lib/                          the Flutter app
  ui/
    core/       theme, shared widgets
    saves/      save browser        view + viewmodel
    party/      party shell         view + viewmodel
    editors/    stats/ inventory/ spells/ effects/ journal/ vars/ appearance/
                                    each: *_view.dart + *_viewmodel.dart
  domain/       SaveGame, Character, ItemSlot, EffectInstance — plain, immutable
  data/
    repositories/  SaveGameRepository, ResourceRepository, StringRepository
    services/      GameProfileService, BackupService
  config/       provider declarations (the DI graph)
```

**Why `infinity_formats` is a separate package and not just a folder:** it makes the Flutter-free
rule mechanical rather than aspirational. Its suite runs under `dart test` (from
`packages/infinity_formats`), where a `package:flutter` import fails to compile and names the
offending file. A Flutter-hosted suite links `dart:ui` and cannot see the mistake.
`packages/infinity_formats/dart_test.yaml` pins `platforms: [vm]`, and `test/flutter_free_test.dart`
walks every source file so the rule also covers code no test imports yet.

**Machine discovery is not a format concern.** "Where is the game installed", "which locale did the
player configure" are facts about *this machine*. They live in `GameProfileService` in the app
layer. `Tlk.open` takes a path and asks no questions; every codec follows that rule. Putting
discovery in `infinity_formats` would quietly turn a codec library into a BG:EE-installation
library.

## Format layouts are enhanced enums (D6)

Each field is a *value* carrying its own offset and width, behind a shared `FormatField` interface:

```dart
enum GamNpcField implements FormatField {
  creOffset(0x04, 4),
  creResref(0x0c, 8),
  name(0xc0, 32),
  voiceSet(0x158, 8);

  const GamNpcField(this.offset, this.length);
  @override final int offset;
  @override final int length;

  static const int structSize = 352;
}
```

Not YAML, not JSON, not a class of `static const int`. The reasoning is in D6 and
`context/dart-data-modelling.md` §1; the short version is that **`values` is iterable, so the
table's own consistency is a test**: no overlapping fields, everything inside `structSize`, and the
last field ending *exactly* at `structSize`. That last assertion is the fact whose absence caused
the stride bug, so it becomes a gate rather than a comment.

It also serves *preserve unknown bytes* directly — known ranges are enumerable, so unknown regions
are computed as their complement instead of maintained by hand.

**Version dispatch (D3)** uses a `sealed` codec hierarchy and a `switch` **expression**. Verified by
compiling on the pinned SDK: a non-exhaustive switch is a compile-time **error**, for statements and
expressions alike. Adding a `GamV22` codec without handling it everywhere will fail the build.

## The provider graph

Providers are declared by hand as top-level finals — no `@riverpod`, no `*.g.dart`, no
`build_runner` (D2). Verified against Riverpod 3.4.2: `Provider`, `FutureProvider`,
`NotifierProvider` and `AsyncNotifierProvider` are all current API. What *is* legacy in 3.x is
`StateProvider` and `StateNotifierProvider` — do not use them.

```dart
// data layer — services, then repositories that depend on them
final gameProfileServiceProvider = Provider<GameProfileService>((ref) => ...);
final saveGameRepositoryProvider = Provider<SaveGameRepository>(
  (ref) => SaveGameRepository(ref.watch(gameProfileServiceProvider)),
);

// UI layer — one notifier per editor, each a ViewModel
final partyProvider = NotifierProvider<PartyNotifier, Party>(PartyNotifier.new);
```

Views are `ConsumerWidget`s and read ViewModels, never repositories directly. **Overrides are the
testing seam:** `ProviderScope(overrides: [saveGameRepositoryProvider.overrideWithValue(fake)])` is
why repositories are interfaces and why ViewModels never touch `infinity_formats` themselves.

`ProviderScope` wraps the app in `lib/main.dart`.

## Errors across the layers

| Layer | Throws / exposes |
|---|---|
| Codec | `InfinityFormatException implements FormatException`, with a named constructor per failure mode |
| Repository | Catches `InfinityFormatException`, translates to a domain failure. Never leaks a codec type upward. |
| ViewModel | Exposes UI-ready state — an error message or an `AsyncValue`, not an exception |
| View | Renders it. Never catches. |

**Never `Error`, always `Exception`.** Effective Dart reserves `Error` for programmatic mistakes;
malformed save data is not a programmer mistake, it is the expected input to a tool whose job is
reading other people's files. Implementing `FormatException` keeps the type catchable as the core
type while letting the repository catch *this library's* failures precisely — which is what makes
the translation above reliable. Details and citations: `context/dart-data-modelling.md` §6.

## The editing model

This is the part that differs most from EE Keeper, and it is load-bearing for correctness.

```
        load                    edit                       save
file ──────────► SaveGame ──────────────► SaveGame' ──────────► file
  │              (immutable)   EditCommand  (immutable)           ▲
  │                                                               │
  └──────────── original bytes retained ──────────────────────────┘
                     patched, never regenerated
```

1. **Parse into an immutable domain model** for the UI to read. Domain models are classes, not
   records — records are structurally typed, so `(int offset, int length)` and `(int count, int
   size)` are the same type and compare equal. Records are for *local* multi-value returns only.
   Those classes get their `copyWith`, `==` and `hashCode` from **`dart_mappable`** (D9) rather than
   by hand: an edit-command model calls `copyWith` constantly, and a field forgotten in a
   hand-written one is precisely how a save ends up silently wrong.
2. **Retain the original bytes.** GAM and CRE contain unused and undocumented regions. On save,
   patch known fields into a *copy of the original buffer*. Never regenerate a file from the model
   alone — that silently destroys everything the model does not understand. Hold the buffer as
   `Uint8List.asUnmodifiableView()`, which is a *view* rather than a copy: retaining a 96 KB save
   costs nothing and mutation throws, so the rule is enforced by the type system rather than by
   discipline. (`google/protobuf.dart`'s `UnknownFieldSet` is the same principle in production.)
3. **Edits are commands**, not mutations — a `sealed` hierarchy consumed by an exhaustive `switch`,
   so adding a command without handling it fails to compile. This is what gives undo/redo, and it
   makes dirty-state tracking trivial.
4. **Writes are atomic**: temp file, then rename. Always leave a `.bak`.

## Offset recalculation — where corruption comes from

Two facts that must shape the writer:

- **Never infer a size or a stride from the difference between two offsets. Read the documented
  struct size.** The concrete hazard, measured on all three fixtures: **an offset field of `0`
  means the section is absent**, not that it sits at the start of the file. BG1EE saves carry
  `partyInventoryOffset = 0, partyInventoryCount = 0` — no shared party inventory at all — so
  `inventoryOffset - partyOffset` yields **−180**, which is how the spike's stride bug happened.
  Arithmetic on an absent section's offset is meaningless.
  *(For the record, the real layout in these files is strictly ordered: header → party structs at
  180 → party CRE at 532 → non-party structs at 7312 → non-party CREs from 19,984. The rule holds
  regardless; it just is not ordering that breaks it.)*
- **Editing changes sizes.** A CRE that grows moves every subsequent offset in the GAM. The same
  applies within CRE itself: known spells, memorisation info, memorised spells, item slots, items
  and effects each carry offset+count headers.

Therefore the writer needs an explicit **layout pass**: compute all section sizes, assign offsets,
patch every offset field, then emit. Do not attempt incremental patching of a resized structure.

## Concurrency

**`compute` is Flutter-only and therefore unavailable in `infinity_formats`.** It is declared in
`package:flutter/foundation.dart`, which that package may never import — a compile error, not a
style violation. The split:

| Where | Use |
|---|---|
| `packages/infinity_formats` | `Isolate.run` from `dart:isolate` |
| `lib/` (the app) | `compute` is available; `Isolate.run` is equally fine |

Resource indexing (KEY/BIFF — 37,815 resources on this install) is the only genuinely heavy
operation and runs off the main isolate. `dialog.tlk` lookups are lazy `RandomAccessFile` seeks
behind an LRU; do not load 34,000 strings into memory.

## UI: routing, theming, accessibility

Per `context/flutter-ai-rules.md`. None of this is built yet — it lands in Phase 2 — but the
choices are made here so they are not improvised.

- **Routing: `go_router` 17.4.0** — added 2026-08-07 with the second screen. `lib/config/router.dart`
  declares `/` (the save browser) with the party shell as a **child route**, `save/:slot`. Child
  rather than sibling deliberately: `go` then builds a stack of [browser, party], so the party shell
  gets a working back button instead of being a dead end, and D4's editor categories nest one level
  further in. The route carries the slot **directory name**, not its path — nothing to escape, and
  the repository resolves it from scratch, so a reload lands on the same save.
- **Theming:** a centralised `ThemeData` built with `ColorScheme.fromSeed`, with both `theme` and
  `darkTheme` supplied. `ui/core/` owns it; no widget defines its own colours.
- **Accessibility, as gates rather than aspirations:** text contrast at least **4.5:1**; `Semantics`
  labels on interactive elements; the layout must remain usable at increased system font size.

## Logging

`dart:developer`'s `log`, never `print`. The single exception is `tool/` diagnostics, where printing
*is* the output. `avoid_print` is enabled in the analyzer and has no suppressions anywhere (D8):
`tool/` writes to `stdout` explicitly, which satisfies the rule honestly rather than by exemption.

## Testing

Development is **test-first** throughout: write the failing test, run it to confirm it fails for the
right reason, then implement.

| Gate | What it means |
|---|---|
| **Round-trip byte identity** | read a real file → write it back with no edits → identical bytes. Necessary but **not sufficient** — a no-op writer passes it perfectly. Pair it with: change one field, round-trip, assert **only** the bytes backing that field differ. That is the one that catches offset-recalculation corruption. |
| **Layout invariants** | for every `FormatField` enum: no overlapping fields, all within bounds, last field ending exactly at the declared struct size. |
| **Fixture-driven parsing** | assertions against known values from the three real saves. |
| **Synthetic fixtures** | logic tests build their own input in-test, so the suite runs on a fresh clone. Real game data is for *confirming* documented values, in tests that skip when it is absent. |
| **Differential vs NearInfinity** | run NI as a black-box oracle and compare field values. Creates no derivative work. |
| **Load in-game** | the only test that proves a save is not corrupt. Manual, slow, final authority. |

Fixtures are **copies**. The originals under `~/.local/share/Baldur's Gate - Enhanced Edition/save/`
are the user's real game and are never written to.

## Analyzer

**`very_good_analysis`, applied whole (D8)** — 212 rules plus `strict-casts`, `strict-inference`
and `strict-raw-types`. Both `analysis_options.yaml` files are identical, so a source file behaves
the same wherever it lives. It supersedes the canon's `flutter_lints` line and is a *superset* of
the three rules that line names.

**No suppressions.** No `exclude:` entries, no rule carve-outs, no `// ignore` or
`// ignore_for_file` anywhere in the repository — that is a checkable invariant, not an aspiration:

```bash
grep -rn 'ignore_for_file\|// ignore:' --include='*.dart' .   # must return nothing
```

If a rule proves unsatisfiable, fix the code or reopen D8. Do not silence it. Two consequences that
catch people out: constructors go **before** fields (`sort_constructors_first`), and a named
constructor referenced from a doc comment must be qualified —
`[InfinityFormatException.badSignature]`, not `[badSignature]`.

**There is no CI** (deliberate — solo project, one machine), so run `analyze`, `dart format` and the
`infinity_formats` suite yourself before committing.

## Code generation

**Decided per dependency (D9).** D2 denied it for Riverpod; that is a decision about Riverpod, not
a project-wide ban.

Serialization and data classes use **`dart_mappable`**, superseding the canon's `json_serializable`
bullet — which brings `build_runner` in with it, when the first domain model arrives in Phase 2.
Nothing needs it yet, so it is not a dependency yet.
