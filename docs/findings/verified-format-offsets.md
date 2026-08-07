# Verified format offsets

**Status:** established 2026-08-07. **Source of record: IESDP** (`../iesdp`), the
Infinity Engine Structures Description Project. Every offset here was confirmed by parsing a real
BG1EE save. Do not re-derive these; do extend the file as new structures are verified.

> **Provenance (D1).** This project is Apache-2.0 and NearInfinity is LGPL-2.1, so codecs are an
> independent implementation: facts come from IESDP, behaviour is checked against NearInfinity run
> as a black-box oracle, and its Java is not read while writing codecs. Where a NearInfinity `file:line` appears
> below it is recorded as a **cross-check only** — the offsets were independently verified present
> in IESDP on 2026-08-07.

Fixture used for confirmation:
`~/.local/share/Baldur's Gate - Enhanced Edition/save/000000022-last/BALDUR.gam`
(GAME V2.0, 95,968 bytes, 1 party member, 33 globals, 8 journal entries).

## Save directory layout (BG:EE)

A save slot is a **directory**, not a file:

| File | What it is |
|---|---|
| `BALDUR.gam` | The savegame. **Uncompressed** — party, globals, journal all live here. |
| `BALDUR.SAV` | Archive of area files. Header `SAV V1.0`, then per-entry: name, uncompressed length, compressed length, **zlib** stream. |
| `BALDUR.bmp` | Save screenshot. |
| `PORTRT*.bmp` | Party portraits. |
| `*.tot` / `*.toh` | **Save-local string overrides.** Player-chosen character names live here, not in the CRE. |

**This is the single most important structural finding for scope:** on BG:EE, party editing needs
only `BALDUR.gam`. `BALDUR.SAV` matters solely for area-embedded creatures, so it can be deferred
past v1 entirely. Classic BG2 packed everything into the `.sav`; EE does not.

`dart:io`'s `ZLibCodec` handles the `.SAV` entries when the time comes — no package needed.

## GAM V2.0 header

Source: IESDP `file_formats/ie_formats/gam_v2.0.htm`. All little-endian.

| Offset | Size | Field |
|---|---|---|
| `0x00` | 4 | Signature `'GAME'` |
| `0x04` | 4 | Version `'V2.0'` |
| `0x08` | 4 | Game time (300 units == 1 hour) |
| `0x18` | 4 | Party gold |
| `0x20` | 4 | Offset to party NPC structs |
| `0x24` | 4 | Count of party NPC structs (includes protagonist) |
| `0x28` | 4 | Offset to party inventory |
| `0x2c` | 4 | Count of party inventory |
| `0x30` | 4 | Offset to non-party NPC structs |
| `0x34` | 4 | Count of non-party NPC structs |
| `0x38` | 4 | Offset to GLOBAL variables |
| `0x3c` | 4 | Count of GLOBAL variables |
| `0x40` | 8 | Main area (resref) |
| `0x4c` | 4 | Count of journal entries |
| `0x50` | 4 | Offset to journal entries |
| `0x54` | 4 | Party reputation (**×10** — `110` means 11.0) |
| `0x58` | 8 | Current area (resref) |

## GAM party NPC struct

Source: IESDP `file_formats/ie_formats/gam_v2.0.htm`, party NPC struct.
Cross-checked against NearInfinity `resource/gam/PartyNPC.java:236-281`.

| Offset | Size | Field |
|---|---|---|
| `+0` | 2 | Selection state |
| `+2` | 2 | Party position |
| `+4` | 4 | **Offset to embedded CRE** (absolute, from start of GAM) |
| `+8` | 4 | **Size of embedded CRE** |
| `+12` | 8 | Character resref |
| `+20` | 4 | Orientation |
| `+24` | 8 | Current area (resref) |
| `+32` / `+34` | 2 each | Location X / Y |
| `+192` | 32 | **Name** (plain text — this is where the displayed name comes from) |
| `+224` | 4 | Times talked to |

## CRE V1.0

Source: IESDP `file_formats/ie_formats/cre_v1.htm`.
Cross-checked against NearInfinity `resource/cre/CreResource.java:1613-1800`.

⚠️ **Two offset conventions — do not mix them.** IESDP quotes **absolute** offsets from the start
of the file; the table below is **relative to the CRE body**, i.e. `creStart + 8`, after
`'CRE '` + `'V1.0'`. The two differ by exactly 8: IESDP's `0x0238` Strength is `+560` here.
Prefer IESDP's absolute form in new code and convert once at the boundary.

| Offset | Size | Field |
|---|---|---|
| `+0` | 4 | Name (strref) |
| `+16` | 4 | Experience |
| `+20` | 4 | Gold |
| `+28` | 2 | Current HP |
| `+30` | 2 | Maximum HP |
| `+60` | 1 | Reputation |
| `+74` | 1 | THAC0 |
| `+556` | 1 | Level, first class |
| `+557` | 1 | Level, second class |
| `+558` | 1 | Level, third class |
| `+559` | 1 | Sex (`GENDER.IDS`) |
| `+560` | 1 | **Strength** (IESDP `0x0238`, "Strength (1-25)") |
| `+561` | 1 | Strength bonus (percentile) |
| `+562` | 1 | Intelligence |
| `+563` | 1 | Wisdom |
| `+564` | 1 | Dexterity |
| `+565` | 1 | Constitution |
| `+566` | 1 | Charisma |
| `+567` | 1 | Morale |

Confirmed live: `STR 18(100) INT 18 WIS 9 DEX 17 CON 16 CHA 9`, XP 325, HP 6/7, THAC0 20 —
plausible BG1 level-1 protagonist values.

Still to verify: the offset+count table (known spells, memorisation info, memorised spells, item
slots, items, effects) and the EFF-structure-version flag that selects effect v1 (48 bytes) vs
v2 (264 bytes).

## TLK (`dialog.tlk`)

Located at `<game>/lang/<locale>/dialog.tlk` — for this install, `lang/en_US/dialog.tlk`,
**34,000 strings**.

| Offset | Size | Field |
|---|---|---|
| `0x00` | 4 | Signature `'TLK '` |
| `0x04` | 4 | Version `'V1  '` |
| `0x08` | 2 | Language ID |
| `0x0a` | 4 | Number of entries |
| `0x0e` | 4 | Offset to string data |
| `0x12` | — | Entry array begins, **26 bytes each** |

Entry: flags (2), sound resref (8), volume variance (4), pitch variance (4), **string offset (4,
relative to string-data offset)**, **string length (4)**.

`dialog.tlk` is tens of MB. Dart has no mmap — use `RandomAccessFile`, seek per lookup, and put an
LRU in front. Do **not** load all strings.

⚠️ **Encoding:** see `context/java-semantics-notes.md` entry 3. Dart has no built-in cp1252 codec
and `latin1` is *not* equivalent for `0x80–0x9F`. The spike uses `String.fromCharCodes`, which is
wrong for any non-ASCII string and must be fixed in Phase 0.

## Known bugs in the spike

`tool/spike/gam_cre_tlk_spike.dart` works but is **not** correct. Three defects, deliberately left
in place so Phase 0 fixes them properly:

1. **Stride computation is wrong.** It derives the NPC struct size from
   `partyInventoryOffset - partyOffset`, which yields **-180** on the fixture because the inventory
   block precedes the party block. It produced correct output only because there is one party
   member. Use the documented struct size; never infer sizes from offset arithmetic.
2. **`strref = -1` is unhandled.** The protagonist's CRE name strref is `0xFFFFFFFF`. The displayed
   name comes from the GAM NPC struct `+192` (`"Aard"` on the fixture) or from the save-local
   `.tot`/`.toh` pair. Name *editing* will need the `.tot`/`.toh` path.
3. **The round-trip check is tautological.** It re-reads the file and compares it to the buffer it
   already read. A real round-trip requires a writer; it arrives in Phase 1.

Additionally: CRE `+60` reads **110** where the GAM party reputation is 11.0, suggesting CRE
reputation is also stored ×10. **Unverified** — confirm against the oracle before relying on it.

## Oracles

Prefer verification over reasoning from a spec. Three are available, with different standing:

1. **NearInfinity, run as a black-box oracle.** Open the same file, compare field values. Running
   it creates no derivative work, so this is available regardless of how D1 lands. Note from the
   previous project's measurement: NI **cannot run headless** — `AppOption.java:369` calls
   `Toolkit.getScreenSize()` from a static initialiser — but works under a display with
   `new BrowserMenuBar()` constructed first. BG1EE opens with 37,815 resources in 122 ms.
2. **EE Keeper under Wine.** The *only* oracle for its derived behaviours — "Recalculate Stats",
   "Update Bonus Stats", "ID All", "Re-roll", "All Max Qty". NearInfinity has no such features and
   cannot answer these questions.
3. **The game itself.** Final authority: load the edited save and see. Slow, but the only test that
   matters for "did we corrupt it".
