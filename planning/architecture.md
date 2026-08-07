# Architecture

Full MVVM per `context/mvvm-architecture-record.md` (D5). Development proceeds **model → UI**.
State management is **Riverpod 3.x with manually declared providers — no code generation** (D2,
a declared deviation from the canon's native-first default).

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
    spec/       offset/enum tables as data (YAML/JSON), not code
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

**Why `infinity_formats` is a separate package and not just a folder:** it makes the Flutter-free rule
mechanical rather than aspirational. Its suite runs under `dart test` (from
`packages/infinity_formats`), where a `package:flutter` import fails to compile and names the offending
file. A Flutter-hosted suite links `dart:ui` and cannot see the mistake.
`packages/infinity_formats/dart_test.yaml` pins `platforms: [vm]`, and `test/flutter_free_test.dart`
walks every source file so the rule also covers code no test imports yet.

**Put offsets in `spec/` as data where practical.** Facts stay visibly facts (which matters for
D1), and the version matrix becomes data rather than branching code — which is how D3's
"pluggable dispatch" requirement gets satisfied cheaply.

## The provider graph

Providers are declared by hand as top-level finals — no `@riverpod`, no `*.g.dart`, no
`build_runner` (D2). The shape follows the MVVM layers:

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
testing seam:** `ProviderScope(overrides: [saveGameRepositoryProvider.overrideWithValue(fake)])`
is why repositories are interfaces and why ViewModels never touch `infinity_formats` themselves.

`ProviderScope` wraps the app in `lib/main.dart`.

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

1. **Parse into an immutable domain model** for the UI to read.
2. **Retain the original bytes.** GAM and CRE contain unused and undocumented regions. On save,
   patch known fields into a *copy of the original buffer*. Never regenerate a file from the model
   alone — that silently destroys everything the model does not understand.
3. **Edits are commands**, not mutations. This is what gives undo/redo, and it makes the dirty-state
   tracking trivial.
4. **Writes are atomic**: temp file, then rename. Always leave a `.bak`.

## Offset recalculation — where corruption comes from

Two facts that must shape the writer:

- **Offsets are not ordered.** On the real fixture, the party inventory block precedes the party
  block. Never infer a size or stride from the difference between two offsets. (This was a live bug
  in the spike — see `docs/findings/verified-format-offsets.md` §Known bugs.)
- **Editing changes sizes.** A CRE that grows moves every subsequent offset in the GAM. The same
  applies within CRE itself: known spells, memorisation info, memorised spells, item slots, items
  and effects each carry offset+count headers.

Therefore the writer needs an explicit **layout pass**: compute all section sizes, assign offsets,
patch every offset field, then emit. Do not attempt incremental patching of a resized structure.

## Concurrency

- Resource indexing (KEY/BIFF — 37,815 resources on this install) runs in an **isolate**. It is the
  only genuinely heavy operation; everything else is small.
- `dialog.tlk` lookups are lazy `RandomAccessFile` seeks behind an LRU. Do not load 34,000 strings
  into memory.

## Testing

| Gate | What it means |
|---|---|
| **Round-trip byte identity** | read a real file → write it back with no edits → identical bytes. Every writer, over the format's domain. Non-negotiable. |
| **Fixture-driven parsing** | assertions against known values from the three real saves. |
| **Differential vs NearInfinity** | run NI as a black-box oracle and compare field values. Creates no derivative work, so available under any D1 outcome. |
| **Load in-game** | the only test that proves a save is not corrupt. Manual, slow, final authority. |

Fixtures are **copies**. The originals under `~/.local/share/Baldur's Gate - Enhanced Edition/save/`
are the user's real game and are never written to.
