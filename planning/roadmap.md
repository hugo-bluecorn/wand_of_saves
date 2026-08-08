# Roadmap

Phases 0–2 produce a genuinely useful tool. Everything after is breadth. Scope is BG1EE (D3).

---

## Phase 0 — `infinity_formats` read path · **done**

Promote the read-path spike into real code. (The spike was deleted once it had been;
see `docs/findings/verified-format-offsets.md` §Known bugs.)

- `GamCodec`, `CreCodec`, `Tlk` as proper classes in `packages/infinity_formats`.
- Offset/enum tables into `lib/src/spec/` as data.
- Fixture suite against copies of the three real saves.
- **Fix the four spike bugs properly** — stride inference, `strref = -1`, the tautological
  round-trip check, and arbitrary locale selection. See
  `docs/findings/verified-format-offsets.md` §Known bugs.
- **Fix TLK string decoding** — `String.fromCharCodes` silently aliases latin1 and mangles every
  non-ASCII string. BG:EE `dialog.tlk` is **UTF-8** (verified 2026-08-07), so the fix is
  `utf8.decode` from `dart:convert`; there is **no cp1252 codec to write**. See
  `docs/findings/verified-format-offsets.md` §TLK.

**Gate:** spike behaviour reproduced by tests, all four bugs fixed, non-ASCII strings correct.

## Phase 1 — the writer · **deferred, deliberately**

Skipped for now because **nothing in Phase 2 needs it**: gold, XP, HP, THAC0 and
ability scores are all fixed-width, and the existing patch-a-copy writer already
handles them — proven in-game. It becomes unavoidable at Phase 4, when inventory and
spells start resizing sections. Two traps are recorded in
`docs/findings/verified-format-offsets.md`: `GamHeaderField` covers only five of the
GAM's nine offset fields, and "absent" is encoded three different ways in that one
header.

The hard phase. See `planning/architecture.md` §Offset recalculation.

- Layout pass: compute sizes, assign offsets, patch offset fields, emit.
- Original-byte retention and patching.
- `BackupService`: atomic write via temp+rename, `.bak` always.

**Gate: round-trip byte identity on every fixture.** No writer ships without it.

## Phase 2 — first useful app · **done 2026-08-07**

- ✅ Flutter shell: save browser → party. Both screens, `go_router`, full MVVM per
  `architecture.md`; D2 settled.
- ✅ Stats/gold/XP/HP editing: sealed edit commands, undo/redo, atomic write with a `.bak`.

Everything editable in this phase is **fixed-width**, so Phase 1's layout pass stays deferred —
the existing patch-a-copy writer already covers it, proven in-game.

**Gate: MET.** An edited `000000099-wandtest` loaded in BG:EE with Strength 19 and THAC0 15
applied and every other value intact. Measurements in `docs/findings/verified-format-offsets.md`
§Stored vs displayed.

## Phase 2.5 — the rules layer · **done 2026-08-08**

Derived values, shown beside stored ones. Prompted by finding that a savegame's numbers are not
the numbers the player sees: hit points and THAC0 are both *bases* the engine modifies.

**No KEY/BIFF reader needed, which is why this comes before Phase 3.** `../iesdp/files/2da/2da_bgee/`
holds 198 BG:EE 2DA files carrying real `2DA V1.0` payloads — `hpconbon` (Constitution → hit
points), `dexmod` (Dexterity → armour class), `strmod`/`strmodex`, `thac0`, `hpclass`.

- ✅ **Generated**, not hand-written — `tool/gen/generate_rules.dart`, run by hand, output
  committed and stamped with the IESDP commit.
- ✅ Class, race, gender and alignment names; Dexterity → armour class; Constitution → hit points.
- ⬅️ Still open, and now known to need **Phase 3's real tables**: the rules-based hit-point cap
  (IESDP ships no per-class dice tables), the warrior column (needs a Constitution 17+ character),
  the kit encoding, and the armour-class question left by the Phase 2 gate.

Haeravon's BG:EE walkthrough carries the same tables in prose and is useful as a **cross-check**,
not a source: its §6.3 independently gives Constitution 16 → +2 hit points per level, agreeing
with `hpconbon.2da` and with the game's own portrait overlay.

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
