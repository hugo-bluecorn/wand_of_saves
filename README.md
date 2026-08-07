# Wand of Saves

A **Material 3 saved-game editor for Baldur's Gate: Enhanced Edition**, built with Flutter for
desktop — Linux, macOS and Windows.

*A wand for saving throws, and for save games.* The format codecs live in `infinity_formats`,
named for the **Infinity Engine** behind Baldur's Gate, Icewind Dale and Planescape: Torment.

It is a functional successor to [EE Keeper](http://forum.baldursgate.com/discussion/16497/eekeeper/p1)
— the feature set is the target, but the UI and architecture are deliberately different: Material 3
rather than Win32/MFC, and Flutter MVVM rather than MFC Document/View.

> **Status: Phase 0, in progress.** The first codec has landed — `Tlk`, the talk-table reader,
> written test-first with 20 passing tests. The GAM and CRE codecs are next; the Flutter shell
> comes after them. Underneath sits the groundwork: the pinned target-side canon, format offsets
> verified against real save data, the reverse engineering of EE Keeper's feature set, and a
> working read-path spike.

## What's here

| Path | What it is |
|---|---|
| `CLAUDE.md` | **Start here.** Purpose, hard rules, current stage. |
| `planning/decisions.md` | The decision log. **D1 (licensing) is closed: Apache-2.0 — read the constraint it imposes before writing any codec.** |
| `planning/using-nearinfinity.md` | What may and may not be done with the Java reference. |
| `planning/architecture.md` | MVVM layering, package split, the editing model. |
| `planning/roadmap.md` | Phases 0–7. |
| `docs/findings/` | Verified format offsets; EE Keeper reverse-engineering results + extracted UI spec. |
| `context/` | Pinned Flutter/Dart canon (carried over from an earlier experiment). |
| `reference/README.md` | Pointers to read-only reference trees and game data. |
| `packages/infinity_formats/` | Pure-Dart format codecs. Must never import `package:flutter` — enforced by `test/flutter_free_test.dart`. |
| `tool/spike/` | The working GAM → CRE → TLK read-path spike. |

## Try the spike

```bash
fvm dart run tool/spike/gam_cre_tlk_spike.dart
```

Parses a real BG1EE save: party, embedded creature records, ability scores, and `dialog.tlk`
strings — in ~120 lines of pure Dart.

## Architecture at a glance

Flutter **MVVM** — View / ViewModel / Repository / Service — with state managed by
**Riverpod 3.x using manually declared providers, no code generation**. The Infinity Engine format
codecs live in `packages/infinity_formats`, a pure-Dart package that never imports Flutter, so it
can be tested without a Flutter host. See [`planning/architecture.md`](planning/architecture.md).

## Development

```bash
fvm flutter pub get
fvm flutter run -d linux        # desktop only: linux, macos, windows
fvm flutter analyze

# The infinity_formats suite is a separate package and runs from its own directory.
cd packages/infinity_formats && fvm dart test
```

Dart and Flutter are invoked through [fvm](https://fvm.app/); the SDK is pinned in `.fvmrc`.

## Licensing

Licensed under the **Apache License, Version 2.0** — see [`LICENSE`](LICENSE) and
[`NOTICE`](NOTICE).

One consequence is worth stating up front, because it shapes how the code is written:
Apache-2.0 cannot incorporate or derive from LGPL-2.1. [Near Infinity](https://github.com/Argent77/NearInfinity)
is LGPL-2.1, so the format codecs here are an **independent implementation** — specified from the
[IESDP](https://github.com/Gibberlings3/iesdp), with Near Infinity used only as a *black-box test
oracle* (executed, its output compared against ours). No code is copied, translated or derived
from it. See D1 in [`planning/decisions.md`](planning/decisions.md).
