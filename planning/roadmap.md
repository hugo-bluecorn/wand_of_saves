# Roadmap

Phases 0–2 produce a genuinely useful tool. Everything after is breadth. Scope is BG1EE (D3).

---

## Phase 0 — `infinity_formats` read path · **next**

Promote `tool/spike/gam_cre_tlk_spike.dart` into real code.

- `GamCodec`, `CreCodec`, `Tlk` as proper classes in `packages/infinity_formats`.
- Offset/enum tables into `lib/src/spec/` as data.
- Fixture suite against copies of the three real saves.
- **Fix the three spike bugs properly** — stride inference, `strref = -1`, and the tautological
  round-trip check. See `docs/findings/verified-format-offsets.md` §Known bugs.
- **Fix cp1252** — `String.fromCharCodes` is wrong for non-ASCII TLK strings
  (`context/java-semantics-notes.md` entry 3).

**Gate:** spike behaviour reproduced by tests, all three bugs fixed, non-ASCII strings correct.

## Phase 1 — the writer

The hard phase. See `planning/architecture.md` §Offset recalculation.

- Layout pass: compute sizes, assign offsets, patch offset fields, emit.
- Original-byte retention and patching.
- `BackupService`: atomic write via temp+rename, `.bak` always.

**Gate: round-trip byte identity on every fixture.** No writer ships without it.

## Phase 2 — first useful app

- Flutter shell: save browser → party → stats/gold/XP/HP editing.
- MVVM wiring per `architecture.md`; D2 (state management) must be settled here.
- Edit commands + undo/redo.

**Gate:** an edited save loads in-game with the change applied and nothing else altered.

---

## Phase 3 — resource index

KEY/BIFF reader in an isolate; 2DA/IDS tables; item and spell pickers.
**Gate:** 37,815 resources indexed in under a second, UI never blocks.

## Phase 4 — inventory, spells, proficiencies

Needs Phase 3's pickers. Inventory slot records are 20 bytes (from EE Keeper's disassembly).

## Phase 5 — graphics

BAM v1/v2 + BMP decode → portraits and item/spell icons. BAM v2 needs PVRZ (DXT1/3/5).
Render via `decodeImageFromPixels`; cache decoded icons.

## Phase 6 — effects editor

Generate the opcode database from `iesdp/_opcodes/` (911 files, YAML front-matter) at build time.
Do not hand-write an opcode table. Effect v1 (48 bytes) vs v2 (264) is selected by a CRE flag.

## Phase 7 — remaining breadth

Journal, global/local variables, appearance/portraits, `.CHR` export, `.tot`/`.toh` name editing.

---

## Explicitly deferred

- **`BALDUR.SAV` (area archive).** Party editing does not need it on BG:EE — the GAM is
  uncompressed and standalone. Only required for area-embedded creatures.
- **Other games.** D3.
- **EE Keeper's derived behaviours** — "Recalculate Stats", "Update Bonus Stats", "ID All",
  "Re-roll", "All Max Qty". These need game-rules tables and have no oracle but EE Keeper itself
  under Wine. Decide whether parity is wanted before building any of them.
- **Multiplayer / Black Pits / additional campaigns** save types.
