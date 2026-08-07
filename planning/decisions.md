# Decisions

The decision log. One entry per decision, with the reasoning that produced it. A decision recorded
here is **closed** — do not re-litigate it; if it turns out wrong, supersede it with a new entry
that says so.

---

## D1 — Licensing: **Apache-2.0** · CLOSED (2026-08-07)

The project is licensed under the **Apache License, Version 2.0**. `LICENSE` holds the text,
`NOTICE` records third-party material. Every source file carries the standard Apache header.

### The constraint this imposes — read this before writing any codec

**Apache-2.0 is one-way incompatible with LGPL-2.1.** Apache-2.0 code can be combined into GPLv3 /
LGPL-3.0 work, but LGPL-2.1 code **cannot** be incorporated into or derived from within an
Apache-2.0 project: Apache-2.0's patent-termination and indemnification provisions are additional
restrictions that the GPLv2 family does not permit.

NearInfinity is LGPL-2.1. Therefore:

- ❌ **Do not read NearInfinity's Java while writing codec code.** Not as a template, not for
  "how did they structure this", not to check an algorithm. The earlier plan of using it as a
  reference for read/write mechanisms is **withdrawn** — that approach is incompatible with this
  license choice.
- ✅ **IESDP is the specification source.** `../iesdp` documents every format this
  project needs. Verified 2026-08-07: `cre_v1.htm` and `gam_v2.0.htm` independently carry every
  offset in `docs/findings/verified-format-offsets.md`.
- ✅ **NearInfinity remains available as a black-box oracle.** *Running* a program creates no
  derivative work. Open the same file in it, compare field values, diff outputs. This is the
  intended use and it is unrestricted.
- ❌ **Shadow Keeper stays out**, as before — its clause 3 (startup attribution) and clause 4
  ("may not charge a fee") are additional restrictions incompatible with Apache-2.0 too.

The practical rule: **facts flow freely, expression does not.** "CRE V1.0 Strength is at `0x0238`,
1 byte" is a fact about a file format and is not copyrightable. A method decomposition, a control
flow, a set of identifier choices — those are expression. Take facts from IESDP; take behaviour
from the oracle; write the expression yourself.

### The tension this resolved (retained for context)

The plan **had been** to use NearInfinity's Java as a reference for how the formats are read and
written, without translating it verbatim. That is the middle ground, and it is the legally
ambiguous one. Choosing Apache-2.0 removes the ambiguity by removing the option.

- **Facts are free to take.** "CRE V1.0 STR is at offset 560, 1 byte" is a fact about a file
  format. NearInfinity is merely reporting it. Lifting offset tables is not infringement.
- **Structure is protected even without verbatim copying.** If the Dart mirrors NI's class
  decomposition, method breakdown and control flow, that is a derivative work regardless of whether
  any line matches.
- **In our favour:** for binary format readers there is often only one sensible way to write it, and
  that expression is not protectable either. Much of a GAM reader genuinely is unprotectable.

The problem is that you cannot know which side a given routine landed on without auditing it, and
auditing per-file costs more than the license does.

### How it was resolved

Three options were on the table: LGPL-2.1 throughout; a split (LGPL-2.1 format package + permissive
app); or permissive throughout. **Apache-2.0 throughout was chosen** (user decision, 2026-08-07).

That choice is only coherent with the independent-implementation method above. It trades the convenience of
consulting NearInfinity's Java for a permissive license and a patent grant. The trade is affordable
here precisely because IESDP is thorough enough to specify the formats on its own, and because the
oracle — the genuinely valuable part of NearInfinity for this project — survives the boundary
untouched.

### Consequences already applied

- `LICENSE` (Apache-2.0) and `NOTICE` added.
- `docs/findings/verified-format-offsets.md` re-sourced to IESDP. It previously cited NearInfinity
  `file:line` as the source for offsets. Offsets are facts and were never a licensing problem, but
  the provenance record should show the independent path, so IESDP is now the citation and the Java
  is recorded only as a cross-check.
- `context/java-semantics-notes.md` was original work of `near_infinity_flutter`, which is
  LGPL-2.1. It is **relicensed into this project under Apache-2.0 by its copyright holder**
  (hugo-bluecorn, who authored both) — **confirmed 2026-08-07**. Recorded in `NOTICE` and in the
  file's own header. The other `context/` files are third-party reproductions under their own
  terms and are unaffected.
- That file's *content* was also partly superseded by this decision: it was written to help read
  NearInfinity's Java, which D1 forbids. Its header now says so, and directs readers to the
  Dart-side hazards, which remain valid — cp1252 in particular.

> Not legal advice. This records the reasoning available to the project, not a lawyer's opinion.

---

## D2 — State management: **Riverpod, no code generation** · CLOSED (2026-08-07)

**`flutter_riverpod: ^3.4.2`**, with **manually declared providers and notifiers**. No
`riverpod_generator`, no `riverpod_annotation`, no `build_runner`.

### This is a declared deviation from the canon

`context/flutter-ai-rules.md` specifies a native-first default (`ChangeNotifier` + `Provider`).
This project departs from it deliberately. The rule that a disagreement with `context/` is a defect
still holds everywhere else — this is the one recorded exception, and it is recorded here so that a
future session finds a decision rather than an inconsistency.

### What "no code generation" means in practice

Declare providers by hand, as values:

```dart
final saveGameRepositoryProvider = Provider<SaveGameRepository>((ref) => ...);
final partyProvider = NotifierProvider<PartyNotifier, Party>(PartyNotifier.new);
final saveSlotsProvider = FutureProvider<List<SaveSlot>>((ref) async => ...);
```

Not `@riverpod` annotations with generated `*.g.dart` companions. Consequences to accept:

- **No `build_runner` step**, so no generated files in the tree, no watch process, and no
  regeneration hazard when the SDK moves. This is the whole point of the choice.
- **Provider types are chosen explicitly** — `Provider`, `NotifierProvider`,
  `AsyncNotifierProvider`, `StreamProvider` — rather than inferred from a function signature.
- **`ref.watch` / `ref.read` discipline is manual.** Codegen catches some misuse; without it, that
  falls to review. `riverpod_lint` (via `custom_lint`) is available and does *not* generate code —
  it is a linter, so adopting it stays inside this decision. Not added yet; add it if hand-written
  providers start drifting.

### How it maps onto MVVM

Per `context/mvvm-architecture-record.md` and `planning/architecture.md`:

| MVVM layer | Riverpod construct |
|---|---|
| ViewModel | `Notifier` / `AsyncNotifier` exposed via a `NotifierProvider` |
| Repository | `Provider` returning the repository instance |
| Service | `Provider`, usually `ref.watch`-ed by a repository rather than by the UI |
| View | `ConsumerWidget` / `ConsumerStatefulWidget` |

`ProviderScope` wraps the app in `lib/main.dart` — already in place.

**Overrides are the testing seam.** Repositories and services are provided, so a widget test
supplies fakes with `ProviderScope(overrides: [...])`. This is why the format layer stays behind
repository interfaces rather than being touched by ViewModels directly.

---

## D3 — v1 game scope: **BG1EE only** · CLOSED (2026-08-07)

`GAM V2.0` + `CRE V1.0` only. Exactly what is installed and testable today.

**Why:** it is the smallest matrix that produces a genuinely useful tool, and it is the only one
with real fixtures on this machine. Dropping IWDEE (`CRE V9.0`), IWD2 (`V2.2`) and PST removes most
of the format work.

**Constraint this imposes:** keep codec *dispatch* pluggable — select a codec by version signature
even though only one implementation exists. Costs about ten lines; sealing the layout into a single
hardcoded reader is expensive to undo.

---

## D4 — UI is a rewrite, not a port · CLOSED (2026-08-07)

The Flutter UI does **not** reproduce EE Keeper's. Material 3 and Win32/MFC have different
guidelines, and the target is feature and workflow parity, not widget fidelity.

`docs/findings/eekeeper-ui-spec.json` is a **completeness checklist** — "have we covered what it
covers" — not a layout to copy. It holds **structure only**: EE Keeper is proprietary, so its
string table and long captions were redacted before the first commit. Do not re-add them.

Concretely, the M3 divergence is mostly a simplification. EE Keeper is modal-dialog heavy: 31
dialogs, one with 78 controls, an item filter with 51. M3 favours inline panels, `SearchBar` +
`FilterChip`, and side sheets. Collapsing those filter dialogs into a live-filtered picker is a
straight improvement. Twelve tabs exceeds comfortable `TabBar` density, so a secondary
`NavigationRail` for editor categories — with the party as portrait avatars in the primary rail —
fits better than EE Keeper's MDI.

---

## D5 — Architecture: Flutter MVVM · CLOSED (2026-08-07)

Full MVVM per `context/mvvm-architecture-record.md`, developed **model → UI**. EE Keeper's MFC
Document/View is not a model for this.

The substantive consequence: EE Keeper's `CEEKeeperDoc` is an 11,848-byte mutable blob the tabs
poke directly. The MVVM equivalent is an immutable `SaveGame` in the repository plus per-editor
ViewModels emitting **edit commands** — which yields undo/redo, something EE Keeper never had (it
only warns via a "Changes Made" dialog).
