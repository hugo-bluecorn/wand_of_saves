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
| `PORTRT<n>.bmp` | Party portraits, one per party slot. **54×84, 24-bit, `BI_RGB`** — measured 2026-08-07. |
| `*.tot` / `*.toh` | **Save-local string overrides.** Player-chosen character names live here, not in the CRE. |

### `PORTRT<n>.bmp` — measured 2026-08-07, and IESDP does not document it

Header on all four fixture slots: width `0x36` (54), height `0x54` (84), 1 plane, `0x18` bpp,
compression `0`. File size 13,830 = 54-byte header + 84 rows × 164 bytes (54 × 3 padded to a
4-byte boundary). `dart:ui` decodes it with no decoder of our own, exactly as it already does for
`BALDUR.bmp` — so **the party rail shows the player's real portraits without the BIFF index
(Phase 3) or the BAM decoder (Phase 5)**.

⚠️ **The index mapping is UNVERIFIED.** Every fixture on this machine holds a *one-character*
party, where party order and array index are both `0` and therefore indistinguishable — the same
blind spot that hid the spike's stride of −180. The app keys on **party order** and treats a
missing file as "no portrait" rather than an error, so a wrong reading costs a picture and nothing
else. Settling it needs a save with 2+ party members.

### The portraits are a second oracle, and nobody had noticed

`PORTRT<n>.bmp` is not a clean portrait: **the game bakes its own HUD overlay into it**, including
the character's hit points in green. That makes each save carry a picture of what the engine
believed at the moment it wrote the file — an oracle sitting inside the fixture, free, needing no
emulator and no NearInfinity. It is what falsified our hit-point reading below. See §Oracles.

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
| `+228` | 116 | Character stats sub-struct |
| `+344` | 8 | Voice set — **the last field** |

### Struct size: **352 bytes.** Verified 2026-08-07, three independent ways

This is the fact whose absence caused the stride bug. **Read it; never infer it.**

1. **IESDP** — the last field is Voice Set at `0x0158` (= 344), 8 bytes wide. 344 + 8 = **352**.
2. **The party array** — `partyOffset` is 180 and there is 1 member; 180 + 1 × 352 = **532**, which
   is exactly where the embedded party CRE begins (`0x214`).
3. **The non-party array** — `nonPartyOffset` 7312 with 36 structs; 7312 + 36 × 352 = **19,984**,
   exactly where the first non-party CRE begins. Read at that stride, all 36 CRE blobs chain
   perfectly (`offset[i] + size[i] == offset[i+1]`) and carry recognisable BG1 companions
   (`*KHALID`, `*JAHEIRA`, `*MINSC`, `*VICONIA`, `*IMOEN`). A wrong stride breaks that 36-link
   chain immediately.

The same struct serves both party and non-party NPCs.

### Fixture composition — this shapes the test strategy

Measured across all three saves (`000000020-start`, `000000021-basic_weapon`, `000000022-last`),
which are **identical** in these values:

| Field | Value |
|---|---|
| `partyOffset` / `partyCount` | 180 / **1** |
| `partyInventoryOffset` / `partyInventoryCount` | **0 / 0 — the section is absent** |
| `nonPartyOffset` / `nonPartyCount` | 7192, 7272, 7312 (per save) / **36** |

Two consequences for `GamCodec`'s tests:

- **A stride bug is invisible in the party array** — every fixture has exactly one member, so any
  stride produces correct output. Testing the party stride needs a *synthetic* multi-member GAM.
- **The non-party array is the real-data stride test.** 36 structs of identical layout, with the
  contiguity property above as a strong invariant.

Layout of `000000022-last`, for orientation: header → party structs (180) → party CRE (532) →
non-party structs (7312) → non-party CREs (19,984 onward).

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

### Stored vs displayed — measured in game 2026-08-07

Four fields were edited on `000000099-wandtest`, the save written, and the result loaded in BG:EE.
**The save loaded and every unedited value was intact** — Dex 17, Con 16, Int 18, Wis 9, Cha 9,
reputation 11, Fighter/Mage, party gold 12345. That is the Phase 2 gate.

| Edit | Result | What it settles |
|---|---|---|
| Strength 18 → **19** | **Holds.** Record screen reads 19. | Ability scores are stored and authoritative. |
| THAC0 20 → **15** | **Holds.** "Base THAC0: **15**". | THAC0 is *not* recomputed from class and level. It is a **base**, like hit points: the game showed `15` − 3 (Strength) + 2 (Proficiencies) → 12 main hand / 14 off hand. |
| Armour class **natural** (`0x46`) 10 → **8** | **No visible effect.** Game showed base armour class 10. | Writing `0x46` alone does not move what the game displays. |
| Current hit points 6 → **20** | Clamped. Game showed **9/9**. | Current hit points are clamped to maximum on load. |

**The Constitution finding is now confirmed by the engine in its own words.** The inventory screen
prints `Class Hit Points/Level: +7` and `Bonus Hit Points/Level: **+2**`, and shows `9/9` from a
stored maximum of `7`. That is the third independent agreement, after the portrait overlay and
`hpconbon.2da`.

#### Armour class is not settled, and the observed value is ambiguous

The game showed a base armour class of **10** with `Dexterity: −3` → 7. But `10` is *both* the
value the untouched **effective** field (`0x48`) already held *and* the unarmoured default, so two
hypotheses fit equally: the engine reads `0x48`, or the engine recomputes armour class from
equipment and ignores both stored fields.

**Writing a value that cannot arise naturally separates them.** Set `0x48` to something like `6`
with nothing worn: if the game shows a base of 6, it reads the field; if it shows 10, it
recomputes. Both armour-class fields are editable meanwhile — a field is not withheld on a guess
about behaviour there is an oracle for.

#### Two more facts nobody was looking for

- **Multi-class experience is split per class on display.** The record screen showed
  `Fighter: Experience 162` and `Mage: Experience 162` against a stored `0x18` of **325**. The CRE
  holds the total; the engine divides it. (325 ÷ 2 = 162 each, losing one point to rounding.)
- **Carried gold and the party purse are genuinely different numbers**, as `0x1c`'s
  documentation implies: the creature record read `0` while the game showed **12345**, which is
  the GAM header's `partyGold` from the earlier write-path proof.

### ⚠️ Hit points are stored WITHOUT the Constitution bonus. Verified 2026-08-07

**The savegame's hit-point fields are not the numbers the player sees.** Falsified by the game's
own portrait overlay (see §Save directory layout), which renders the engine's view of the same
moment:

| Save | Stored `+28`/`+30` | Game renders | Constitution |
|---|---|---|---|
| `000000020-start` | 7 / 7 | **9 / 9** | 16 |
| `000000022-last` | 6 / 7 | **8 / 9** | 16 |

A constant **+2** on both current and maximum, at a constant Constitution of 16 — which is the
warrior Constitution-16 bonus of +2 HP per level, at level 1. The engine stores the base and adds
the modifier when it displays.

**Consequences.** The offsets and IESDP's names (`0x0024` "Current Hit Points", `0x0026` "Maximum
Hit Points") are correct and are not the problem; an editor should read and write exactly these
fields. But a screen showing `6 / 7` beside a game showing `8 / 9` reads as a bug, so the UI
labels it **"Hit points (base)"** and says why. Computing the displayed value needs `HPCONBON.2DA`
out of the BIFF archives (Phase 3) plus the class rules, which is the same territory as EE
Keeper's deferred "Update Bonus Stats".

**Suspect the same of every other derived stat** — armour class and THAC0 are the obvious
candidates, and both are unchecked. The portrait overlay only reports hit points.

### Signedness — two fields corrected 2026-08-07

IESDP's type column distinguishes signed from unsigned, and it matters:

| Field | IESDP type | Why it matters |
|---|---|---|
| `0x0046` / `0x0048` Armour class | **2 (signed word)** | Plate and shield reaches AC −2, which an unsigned read renders as **65534**. |
| `0x0052` THAC0 | 1 (byte), range 1-25 | Genuinely unsigned — checked rather than assumed, since the AC fields two rows above are not. |
| `0x0008` Long name | strref | Read **signed**, so the engine's "no string" sentinel arrives as `-1` rather than `4294967295`. `Tlk.get` documents its contract in terms of a negative strref, so the unsigned reading satisfied it only by accident of the bounds check. |

**No fixture catches the armour-class case**: all 37 creatures in the save sit at AC 10, where
signed and unsigned agree. It is covered by a synthetic test instead
(`test/cre/cre_codec_test.dart`, group `signedness`).

`0x0044` Reputation is listed by IESDP as a **signed** byte, but it is stored ×10 over a 0-20
range, so real values reach **200** and only an *unsigned* read produces them. Read unsigned; the
annotation and the documented range cannot both be right.

### Where a displayed name comes from — both legs occur in real data

Dumped from `000000022-last` on 2026-08-07:

| | GAM struct `0xc0` display name | CRE `0x0008` name strref |
|---|---|---|
| Party member (protagonist) | `"Aard"` | **−1** |
| All 36 non-party companions | **empty** | valid (`*INSC` → 9501, `*ORDAI` → 10733, …) |

So the resolution order is **GAM display name if non-empty → `dialog.tlk` by strref → the CRE
resref**. Neither leg alone is sufficient, and each is the *only* source for one of the two
groups. This is the proper fix for the display half of spike bug #2; name *editing* still needs
the `.tot`/`.toh` pair.

### Header size and sections — verified 2026-08-07 against all 37 creatures in a save

**The fixed header is 724 bytes** (`0x2cc` + 8, the dialogue resref being the last field).
Confirmed from data, not transcription: on every creature, the first *present* section begins
exactly at 724.

| Section | Offset | Count | Entry |
|---|---|---|---|
| Known spells | `0x2a0` | `0x2a4` | 12 |
| Spell memorisation info | `0x2a8` | `0x2ac` | 16 |
| Memorised spells | `0x2b0` | `0x2b4` | 12 |
| Item slots | `0x2b8` | **none** | **80, fixed** |
| Items | `0x2bc` | `0x2c0` | 20 |
| Effects | `0x2c4` | `0x2c8` | 48 or 264 — see below |

Item slots is the **only** section with no count field; its table is a fixed 80 bytes. Every entry
size is confirmed twice: from IESDP's sub-tables, and from the chain arithmetic below. The 20-byte
item entry additionally matches EE Keeper's disassembled `imul ebx,ebx,0x14`
(`eekeeper-reverse-engineering.md`).

**Effect structure version flag: `0x33`.** `0` selects 48-byte effects, `1` selects 264-byte. Not
cosmetic — on the fixture only the 264-byte reading makes the layout close on the file's declared
length; the 48-byte reading ends 4,536 bytes short.

### ⚠️ An offset of `0` means the section is ABSENT

The rule already recorded for the GAM's party inventory **generalises to CRE sections**. Measured:
two of the 37 creatures carry `knownSpellsOffset = 0`, and several carry `itemsOffset = 0`. They do
not have a section at position zero; they have no section.

Any code that treats such an offset as a position, or does arithmetic with it, is wrong. Prefer an
explicit `hasSection`-style predicate over comparing an offset to zero.

### The section chain closes — the strongest check available on a CRE

Summing the layout reproduces the record's declared size exactly. For the protagonist:

```
header 724 → +2 spells×12 → 748 → +16 memo×16 → 1004 → +1 memorised×12 → 1016
           → +80 slots     → 1096 → +7 items×20 → 1236 → +21 effects×264 → 6780 ✓
```

One comparison reconciles all six section pointers, every entry size, and the version flag — and it
holds on all 37 creatures, over data nobody authored for the purpose.

**This is also the arithmetic the Phase 1 writer must reproduce.** Every section is
variable-length, so adding one item moves everything after it inside the CRE, then the CRE's size in
the GAM NPC struct, then every GAM offset past that.

### `0x18` is dual-purpose

IESDP: *"Creature Power Level (for summoning spells) / XP of the creature (for party members)"*.
Measured: 325 for the protagonist, 36,293 for Minsc, 42 for Khalid — party-joinable characters carry
experience here. `0x14` ("XP for killing this creature") is 0 for companions.

### ⚠️ Reading IESDP's CRE page

It **interleaves game variants in one column**. At `0x0084` a *"BG1, BG2 and BGEE"* row (Tracking
target, 32 bytes) competes with a run of PSTEE-only rows; walking the table in order produces a
**backwards offset jump**. On the BGEE branch, `0x0084 + 32` lands exactly on `0x00a4`, the next
shared field. With PSTEE excluded and array notation (`4*100`) handled, the BGEE header is 126
fields with no gaps ending at 724.

`lib/src/spec/cre_v1_0.dart` therefore records a **verified subset** rather than all 126 fields, and
takes its assurance from the chain check above instead of an exact-fit invariant. That is a
deliberate departure from `GamNpcField`, whose table is mechanical enough to transcribe wholesale.

## TLK (`dialog.tlk`)

Source: IESDP `file_formats/ie_formats/tlk_v1.htm`. ⚠️ That page's *Applies to* list covers the
classic games and **omits the EEs entirely** — it documents the classic-era format. That is why the
cp1252 assumption previously recorded here was reasonable, and why it is nonetheless wrong.

Located at `<game>/lang/<locale>/dialog.tlk`. On this install: 15 locales, **34,000 strings** each;
`en_US` is 4,739,485 bytes, `ru_RU` 8,004,361.

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

The entry array start is **hardcoded to byte 18** by the format, not derived from the header.

Use `RandomAccessFile`, seek per lookup, and put an LRU in front. Dart has no mmap, and the largest
single string measured is 15,111 bytes. Do **not** load all strings.

### Encoding — UTF-8. Verified 2026-08-07

**BG:EE `dialog.tlk` is UTF-8.** This supersedes the cp1252 claim previously recorded here, which
came from `context/java-semantics-notes.md` entry 3 and is true only of the *classic* engine — out
of scope under D3.

| Evidence | Result |
|---|---|
| `en_US` em dash | `e2 80 94` → `—`. cp1252 encodes it as the single byte `0x97`. |
| `pt_BR` / `de_DE` | `c3 a3` → `ã`, `c3 bc` → `ü` — not `0xE3` / `0xFC`. |
| `ru_RU` | `d0 9d d1 83` → `Ну`. **Decisive: cp1252 cannot represent Cyrillic at all.** |
| Full scan, `en_US` + `ru_RU` | **34,000 / 34,000 strings each decode as strict UTF-8. Zero failures.** |

The fix is therefore `utf8.decode` from `dart:convert`. **There is no cp1252 codec to write.** The
spike's `String.fromCharCodes` is still wrong — it silently aliases latin1 and renders
`My name is Viconia. Iâ I'm not from around here` — but the remedy is not the one previously
recorded here.

⚠️ IESDP describes this section as *"composed of ASCII strings"*. Measurably untrue for the EEs,
and untrue for any non-English classic install either.

### Further measured properties

- **NUL termination — IESDP and the data disagree.** IESDP: *"some strings are NULL terminated,
  others are not, hence a combination of NULL terminators and the string length should be used to
  find the true string length."* Measured on BG:EE: **zero NULs across 68,000 strings**
  (`en_US` + `ru_RU`). Resolution adopted: **trim at the first NUL if one is present** — a no-op on
  EE data, correct for classic files, and safe because `0x00` in UTF-8 only ever means U+0000.
- **Language ID is `0` in every locale**, `ru_RU` and `ja_JP` included. The header field therefore
  cannot select an encoding even in principle. Do not dispatch on it.
- **`strBase` is observed to equal `18 + count × 26`** — 884,018 in every locale, because the entry
  table is a shared index and only the string bodies differ. That is an *observation, not an
  invariant*: the format carries an explicit field precisely so it need not hold. **Read the field,
  never compute it.** Same class of error as the party-stride bug below.
- **String data is tightly packed.** `strBase + max(offset + length)` lands exactly on EOF in both
  files scanned. No slack, no padding.
- **Entry flags observed: `{0, 1, 2, 3, 5, 7}`**, fully explained by three independent bits
  (`1` = text, `2` = sound, `4` = token). Not needed yet; preserve them.
- **`dialogF.tlk`** — the female-variant string table — is present in 9 gendered locales (`de_DE`,
  `es_ES`, `fr_FR`, `it_IT`, `ja_JP`, `pl_PL`, `pt_BR`, `ru_RU`, `uk_UA`) and **absent for
  `en_US`**. It is spelled with a **capital `F`** on disk — a live instance of the DOS-casing hazard
  in `context/java-semantics-notes.md` entry 7. Out of scope for v1; recorded so it is not
  rediscovered.

## Known bugs in the spike

`tool/spike/gam_cre_tlk_spike.dart` works but is **not** correct. Four defects, deliberately left
in place so Phase 0 fixes them properly:

1. **Stride computation is wrong.** It derives the NPC struct size from
   `partyInventoryOffset - partyOffset`, which yields **-180**. It produced correct output only
   because there is one party member, so the stride is never actually applied.
   Use the documented struct size (**352** — see §GAM party NPC struct); never infer sizes from
   offset arithmetic.

   ⚠️ **Corrected 2026-08-07.** This entry previously said the `-180` arose "because the inventory
   block precedes the party block". That is **wrong**, and so is the general claim it was cited to
   support. All three saves carry `partyInventoryOffset = 0, partyInventoryCount = 0` — the section
   is **absent**, not misordered — and the real layout is strictly ordered. The rule ("never infer
   a size from the difference between two offsets") stands; the actual hazard is sharper: **an
   offset field of `0` means the section is absent, so arithmetic on it is meaningless.**
2. **`strref = -1` is unhandled.** The protagonist's CRE name strref is `0xFFFFFFFF`. The displayed
   name comes from the GAM NPC struct `+192` (`"Aard"` on the fixture) or from the save-local
   `.tot`/`.toh` pair. Name *editing* will need the `.tot`/`.toh` path.

   ✅ **Display half FIXED 2026-08-07.** `Cre.longNameStrref` now reads **signed**, so the sentinel
   arrives as `-1`; the app resolves names GAM → TLK → resref (see §Where a displayed name comes
   from). Name *editing* remains open and still needs `.tot`/`.toh`.
3. **The round-trip check is tautological.** It re-reads the file and compares it to the buffer it
   already read. A real round-trip requires a writer; it arrives in Phase 1.
4. **Locale selection is arbitrary.** It takes the first `lang/*` directory `listSync()` happens to
   return — **`pt_BR`** on this install — while `Baldur.lua` records
   `SetPrivateProfileString('Language','Text','en_US')`. Currently invisible only because the one
   strref it looks up is `-1` and never resolves. Structural fix: `Tlk.open` takes a path and
   performs no discovery; locale resolution belongs to `GameProfileService` in the app layer, not
   to `infinity_formats` — "where is the game installed" is a fact about this machine, not about a
   file format.

   ✅ **FIXED 2026-08-07**, structurally as described. `GameProfileService.findLanguage()` reads
   `Baldur.lua` — which lives in the **user data directory beside `save/`**, not in the
   installation — and `findDialogTlk()` resolves `<game>/lang/<code>/dialog.tlk`, falling back to
   `en_US`. The language value is validated against `^[a-z]{2}_[A-Z]{2}$` before it becomes a path
   segment. A test that runs against the real installation covers the defaults, which no injected
   fixture would.

Additionally: CRE `+60` (IESDP `0x44`) reads **110** where the GAM party reputation is 11.0.
**CONFIRMED 2026-08-07 — CRE reputation is stored ×10.** BG1 reputation ranges 0–20, so 110 cannot
be a raw value. Divide by ten for display.

## Write path — confirmed in-game 2026-08-07

**The game loads a patched save.** The first end-to-end proof that this project can edit a real
savegame without corrupting it.

What was done: a copy of `000000022-last` had **four bytes at `0x18` rewritten** (party gold,
161 → 12345) by patching a copy of the original buffer, written via temp-file + rename with a
`.bak`, and installed as a new slot `000000099-wandtest`. Nothing else in the file was touched, and
none of the existing saves were opened for writing.

| Check | Result |
|---|---|
| Bytes differing from the source (`cmp -l`) | **2**, at `0x18` and `0x19` — both inside the gold field. The field's upper two bytes were `00` before and after. |
| File length | Unchanged, 95,968 |
| `.bak` | Byte-identical to the pre-edit file |
| Existing saves `000000020`–`22` | Byte-identical to copies taken beforehand |
| **In game** | **Loads. Party gold reads 12345.** |

### What this proves, and what it does not

**Proved:** GAM V2.0 carries no checksum or integrity field that patching invalidates; the engine
accepts a file edited in place; retaining the original buffer and patching a copy of it produces
something the game treats as a valid save; and temp-file + rename + `.bak` works as a write
mechanism.

**Not proved — and this is the important half.** Party gold is a **fixed-width field in the
header**, so nothing moved. Offset recalculation — the thing that actually causes save corruption,
where a resized section shifts every offset after it — was never exercised. This de-risks the
*mechanism*, not the *algorithm*. The writer is not done.

### Extended 2026-08-07 — a field *inside* an embedded creature record

The gate above only ever patched the GAM header, at a fixed offset. Editing a character means
writing inside a CRE located through the party array, which is the harder claim. Now covered both
ways:

- **In test:** `Gam.withCreatureField` on the real 95,968-byte fixture changes **exactly one
  byte**, at `creOffset + field.offset`, with all 95,967 others provably identical
  (`test/gam/gam_edit_test.dart`).
- **In game:** Strength and THAC0 written through that path both survive a load, with nothing
  else disturbed. See §Stored vs displayed.

Still fixed-width, so still no layout pass. Phase 1 remains the untouched half.

## Oracles

Prefer verification over reasoning from a spec. Four are available, with different standing:

0. **The save's own `PORTRT<n>.bmp`.** Cheapest of the four and the only one needing nothing but
   the fixture: the game bakes its HUD overlay into the portrait, so every save ships a picture of
   what the engine believed when it wrote the file. It cost one `PIL` resize to read and it
   immediately falsified our hit-point reading (§Hit points are stored WITHOUT the Constitution
   bonus) — a discrepancy no amount of reading IESDP would have surfaced, because the offsets were
   never wrong. Limited to what the HUD draws, which today means hit points.
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
