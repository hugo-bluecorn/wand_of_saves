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

> **Scope, clarified by D9 (2026-08-07):** this denial is about **Riverpod**. It is not a
> project-wide ban on code generation — it has been misread as one. Codegen is decided per
> dependency; `dart_mappable` is approved and brings `build_runner` with it.

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

---

## D6 — Format layouts are **enhanced enums**, not YAML/JSON · CLOSED (2026-08-07)

Each field in a binary structure is an enum *value* carrying its own offset and width, behind a
shared `FormatField` interface. Not YAML, not JSON, and not a class full of `static const int`.

```dart
enum GamNpcField implements FormatField {
  creOffset(0x04, 4),
  name(0xc0, 32),
  voiceSet(0x158, 8);

  const GamNpcField(this.offset, this.length);
  @override final int offset;
  @override final int length;

  static const int structSize = 352;
}
```

### This supersedes a line in `planning/architecture.md`

That document said *"offset/enum tables into `lib/src/spec/` as data (YAML/JSON), not code"*. It is
**not implementable idiomatically**: a pure-Dart library has no asset system, so shipping YAML means
adding this package's first dependency plus runtime path resolution to find a file beside its own
source — and surrendering compile-time constants and static checking to do it.

### Why enums specifically

Both reasons the original line gave still hold: facts stay visibly facts (which matters for D1), and
the version matrix stays data rather than branching code. Enums add a third the original never
thought to ask for — **`values` is iterable, so the table's own consistency becomes a test.** No
overlapping fields, everything inside `structSize`, and the last field ending *exactly* at
`structSize`.

That last assertion is the fact whose absence produced the stride bug
(`docs/findings/verified-format-offsets.md` §Known bugs). Under this decision it is a gate rather
than a comment.

It also serves the *preserve unknown bytes* rule directly: known ranges are enumerable, so unknown
regions are computed as their complement instead of maintained by hand.

### The prior art that disagrees, recorded because it does

`google/protobuf.dart` — the closest production Dart binary codec — uses the rejected shape:
`PbFieldType` is `static const int` bitmask constants. Three differences make it not transfer:
protobuf's field types are **composable bit flags** (`REQUIRED_BIT | REPEATED_BIT | …`) and enum
values cannot be bitwise-OR'd; its descriptors are **generated by protoc**, so human readability is
secondary; and the code predates enhanced enums by roughly a decade. GAM and CRE offsets compose
with nothing, are hand-transcribed from IESDP by a human comparing against a spec, and need
iteration for the invariant test.

Constructs, constraints and citations: `context/dart-data-modelling.md` §1.

---

## D7 — Dependency injection via Riverpod providers · CLOSED (2026-08-07)

Dependencies are supplied through the provider graph, not through constructor arguments threaded
down from `main()`.

### A declared deviation that was already being followed

`context/flutter-ai-rules.md` says *"Use simple manual constructor dependency injection to make a
class's dependencies explicit in its API"*. This project does not, and has not since D2.
`context/mvvm-architecture-record.md` already names the gap — *"itself a declared deviation from the
rules file's manual-DI bullet"* — but `decisions.md` never recorded it. This entry closes that hole;
it changes nothing in practice.

**Why:** having chosen Riverpod in D2, a second parallel wiring mechanism would be strictly worse
than one. The provider graph *is* the DI container, and `ProviderScope(overrides: [...])` is the
testing seam manual constructor injection would otherwise have supplied.

**What is given up:** a class's dependencies are no longer visible in its constructor signature. The
mitigation is that repositories and services are obtained only via `ref.watch` inside provider
declarations, all of which live in `lib/config/` — so the graph is readable in one place instead of
being reconstructed from signatures scattered across the tree.

`riverpod_lint` (via `custom_lint`) generates no code and so stays inside D2 if hand-written
providers start drifting. Not adopted yet.

---

## D8 — Lint ruleset: **`very_good_analysis`**, applied whole · CLOSED (2026-08-07)

`very_good_analysis` 10.3.0 replaces `flutter_lints` (app) and `lints` (package) in both
`analysis_options.yaml` files. **With no suppressions of any kind.**

### A declared deviation from the canon

`context/flutter-ai-rules.md` §Analysis Options says *"Strictly follow `flutter_lints`"* and
supplies an exact yaml snippet naming three rules. This replaces it.

**It is a superset, not a weakening.** All three rules the canon names — `avoid_print`,
`prefer_single_quotes`, `always_use_package_imports` — are inside VGV's set. D8 subsumes the
canon's intent rather than overriding it, which is the mildest form this deviation could take.

### What it is

212 lint rules; three analyzer strictness flags (`strict-casts`, `strict-inference`,
`strict-raw-types`); three error-level promotions; and a formatter setting
(`trailing_commas: preserve`) that changes `dart format` output. `sdk: ^3.12.0`, matching the pinned
Dart 3.12.2. One package serves both Dart and Flutter, so both `analysis_options.yaml` files are
identical and a source file behaves the same wherever it lives.

### No suppressions. At all.

No `exclude:` entries, no rule carve-outs, no `// ignore` or `// ignore_for_file` anywhere in the
repository. A strict ruleset that is exempted wherever it bites is a weaker ruleset with extra
steps.

**Adopting it removed the one suppression that already existed.**
`tool/spike/gam_cre_tlk_spike.dart` carried `// ignore_for_file: avoid_print` over 24 `print(...)`
calls. Those became `stdout.writeln(...)` — a real fix rather than an exemption, since `avoid_print`
fires only on `dart:core`'s `print`, and an explicit stream is the better choice for a command-line
tool regardless.

**If a rule ever proves genuinely unsatisfiable, reopen this decision.** Do not silence the rule.

### Amended 2026-08-07 — scoped to hand-written code

**D8 as written and D9 could not both hold.** `dart_mappable` emits five `ignore_for_file` lines
into every generated file (`dart_mappable_builder/lib/src/builders/mappable_builder.dart:112-118`),
unconditionally, with no option to disable them. Generated files also cannot be edited.

**The invariant is now: zero suppressions in code this project writes.** Generated `*.mapper.dart`
files are excluded from analysis and from the check:

```bash
grep -rn 'ignore_for_file\|// ignore:' --include='*.dart' . | grep -v '\.mapper\.dart'
# must return nothing
```

This preserves what D8 was actually for — stopping *us* silencing a rule instead of fixing the
code. A suppression we cannot remove, in code we did not write and must not edit, is a different
thing entirely. **Everything else stands:** no `exclude:` covering hand-written code, no rule
carve-outs, no `// ignore` we author. If a rule bites our own code, fix the code or reopen this.

Generated output **is committed**. There is no CI, so a fresh clone must build without anyone
remembering to run `build_runner` first.

### The cost, paid on adoption

49 `info`-level issues across both packages, all fixed rather than suppressed. The ones worth
knowing because they will recur:

- **`sort_constructors_first`** — constructors go before fields. Restructured
  `InfinityFormatException` and `Tlk`.
- **`avoid_catches_without_on_clauses`** — `Tlk.open`'s cleanup `catch (_)` became `on Object`, an
  honest on-clause rather than an exemption.
- **`comment_references`** — a named constructor referenced from a doc comment must be qualified:
  `[InfinityFormatException.badSignature]`, not `[badSignature]`.
- `cascade_invocations`, `public_member_api_docs`, `lines_longer_than_80_chars`,
  `avoid_multiple_declarations_per_line`, `no_adjacent_strings_in_list`,
  `avoid_escaping_inner_quotes`, `only_throw_errors`.

---

## D9 — Code generation is per dependency; **`dart_mappable`** for models · CLOSED (2026-08-07)

### D2's scope, stated precisely

D2 is recorded as "Riverpod, **no code generation**". That is a decision about **Riverpod**, not a
project-wide prohibition — and it has already been misread as one.

**Code generation is decided per dependency.** D2's denial stands, unchanged. Future dependencies
wanting codegen are judged on their own merits, and a denial gets its own entry.

### `dart_mappable` for data models and serialization

Supersedes `context/flutter-ai-rules.md`'s *"JSON: Use `json_serializable` and `json_annotation`"*.

`dart_mappable` 4.8.0 + `dart_mappable_builder` 4.9.0, SDK `>=3.7.0 <4.0.0` — compatible with the
pinned 3.12.2. The builder requires `build_runner ^2.10.2`, so **build_runner enters this project
when the models do**.

**Why it earns the codegen cost.** It generates `==`, `hashCode`, `toString()` and **`copyWith`**
alongside from/to-JSON, with support for generics, inheritance and polymorphism. D5's architecture
is an immutable domain model mutated only through edit commands — which means `copyWith` and
structural equality on `SaveGame`, `Character`, `ItemSlot` and `EffectInstance`, written and
maintained by hand. That is exactly the surface where a forgotten field becomes a silently wrong
save, which is the failure mode this project is shaped around. Serialization alone would be a
weaker argument than the data-class generation.

⚠️ **Gotcha, before the first use:** `dart_mappable`'s `.toJson()` returns a **`String`**, not the
`Map<String, dynamic>` that `json_serializable` returns.

### Not added yet

Nothing serialises JSON today and `lib/domain/` does not exist. The dependency lands in Phase 2 with
the first domain model; adding it now would mean an unused dependency and a build step with nothing
to build.

Two questions deferred to that point: whether `dart_mappable` is used inside
`packages/infinity_formats` (it is pure Dart so it *could* be, but that package's zero-dependency
state is a feature and its types are byte-backed rather than JSON-shaped), and whether generated
output is committed.

---

## D10 — Level editing is deferred; the multi-class question waits for play · CLOSED (2026-08-08)

**Decision: do not add level editing, and do not edit a level to answer an open question.**

### What was being asked for

One measurement is still outstanding — whether the engine multiplies the Constitution hit-point
bonus by the *highest* class level or averages it across a multi-class character's classes. Every
run so far has been at level 1, where the readings are indistinguishable. Answering it needs a
multi-class character above level 1, which means either playing to one or writing a level into a
save.

### Why editing a level is not the cheap option it looks like

**A level is not a field, it is a commitment.** Writing `2` into `0x0235` produces a character the
engine will disagree with everywhere: hit points come from a per-class die rolled at level-up,
THAC0 and saving throws come from class progression tables, proficiency slots and spell slots are
granted on level-up, and the record screen's "Next Level" counts against a per-class experience
threshold the stored total no longer matches.

That is the same machinery as EE Keeper's **"Recalculate Stats"**, already recorded as *required
rather than optional* for Phase 4 because armour class is read from a stored effective field. So
the honest cost of "just bump a level" is the whole recalculation layer, brought forward to serve
a single derived display number. Not worth it, and doing it half-way would produce exactly this
project's stated failure mode: a save that loads and is quietly wrong.

### It also turns out not to be necessary

`000000100-Party` already carries recruitable multi-class companions above level 1, several with
*uneven* class levels — which is what makes the three hypotheses predict different numbers:

| Companion | Class | Levels | Why it discriminates |
|---|---|---|---|
| Yeslick | `FIGHTER_CLERIC` | **2/3** | Con 17, stored max 22: highest → 31, average → 29/30, lowest → 28 |
| Coran | `FIGHTER_THIEF` | 3/3 | even, so useless — all readings agree |
| Jaheira | `FIGHTER_DRUID` | 1/1 | level 1, same problem as the current party |

**And the protagonist gets there first.** The game printed Aard's own thresholds: Fighter level 2
at 2000 per class, Mage level 2 at 2500, against a stored total of 364 split evenly. So between a
**total of 4000 and 5000 experience** Aard is **Fighter 2 / Mage 1** — uneven, on the character
already in the party, with no companion required. At Constitution 18 and the warrior bonus of +4,
the three readings predict stored **+8**, **+6** and **+4**, which are three different numbers on
one screen.

The window closes at 5000 when the Mage half catches up, and reopens on the next uneven stretch.

### What to do instead

Nothing. Leave `CharacterSheet.hitPointBonus` reading "highest class level", which is right for
every single-class character and untested only for the multi-class case, and leave the getter's
doc comment saying so. Ask for a record-screen screenshot the next time the protagonist's total
experience is between 4000 and 5000.

**This decision is about sequencing, not about the feature.** Level editing is in scope for the
application; it arrives with the recalculation layer, not before it.
