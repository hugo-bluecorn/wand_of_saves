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

#### ✅ The index mapping — SETTLED 2026-08-08 by a four-member party

`000000100-Party` carries Aard, Imoen, Montaron and Xzar, and the overlay is the proof. Each
portrait's hit points match exactly one member's **stored** hit points plus **that member's own**
Constitution bonus, and no two of the numbers are the same:

| file | overlay | member | stored | Con | `hpconbon` | stored + bonus |
|---|---|---|---|---|---|---|
| `PORTRT0` | 39/42 | party[0] Aard | 37/40 | 16 | +2 | 39/42 ✓ |
| `PORTRT1` | 8/8 | party[1] Imoen | 6/6 | 16 | +2 | 8/8 ✓ |
| `PORTRT2` | 9/9 | party[2] Montaron | 8/8 | 15 | +1 | 9/9 ✓ |
| `PORTRT3` | 4/4 | party[3] Xzar | 4/4 | 10 | +0 | 4/4 ✓ |

**`PORTRT<n>` is the n-th party slot**, and there are exactly `partyNpcCount` of them. The reading
the app already had is correct.

One detail this save cannot show, recorded rather than guessed: **`partyOrder` equals the array
index for all four**, and all 33 non-party structs hold `0xFFFF`, so the two candidate readings —
"n-th in the array" and "the member whose party order is n" — agree and cannot be told apart here.
A save where a reorder made them diverge would separate them. It is not worth chasing: an absent
file is `null` rather than an error, so the worst a wrong reading could cost is a picture.

⚠️ **The BMPs declare `biClrUsed = 0x01000000`**, which is meaningless at 24bpp and makes strict
decoders refuse the file — ImageMagick reports `insufficient image data`. `BALDUR.bmp` carries it
too. `dart:ui` ignores it, as any decoder should above 8bpp, so nothing in the app is affected;
this is here because external tooling pointed at these files will fail in a way that looks like
file corruption and is not.

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

### `000000100-Party` — the first fixture with a real party, added 2026-08-08

| Field | Value |
|---|---|
| `partyOffset` / `partyCount` | 180 / **4** |
| `nonPartyOffset` / `nonPartyCount` | — / **33** |
| Members, in array order | Aard `*HARBASE`, Imoen `*MOEN1`, Montaron `*ONTAR`, Xzar `*ZAR` |
| Party orders | 0, 1, 2, 3 — **equal to the array index** |
| Classes | `FIGHTER_MAGE`, `THIEF`, `FIGHTER_THIEF`, `MAGE` |

It closes the blind spot named directly above: the party array now has a real stride to test, and
four members made four separate findings visible at once — the portrait mapping, the kit encoding,
the level slots and the `*` resref, each recorded in its own section below. `test/gam/
party_fixture_test.dart` asserts them.

⚠️ **It is a copy of a live save the app itself edits**, so its ability scores are a moving target
— Constitution has already been rewritten from 16/16/15/10 to 18 across the board to arm an
in-game run. A test over this fixture may assert structure and identity, never a field
`CharacterStat` can change.

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

Extended 2026-08-08, a second run at different values: stored **20 / 40** showed as **22 / 42**,
with the same "Bonus Hit Points/Level: +2". Two points on the line make the hit-point arithmetic
arithmetic rather than a coincidence. Both runs were still **level 1**, so whether a multi-class
character multiplies the bonus by the highest class level or averages it is *still* untested — and
a third data set on 2026-08-08, four characters at three Constitutions, is still level 1 too. It
did settle that the bonus is **not divided among a multi-class character's classes**; see
§Hit points are stored WITHOUT the Constitution bonus.

**The Constitution finding is now confirmed by the engine in its own words.** The inventory screen
prints `Class Hit Points/Level: +7` and `Bonus Hit Points/Level: **+2**`, and shows `9/9` from a
stored maximum of `7`. That is the third independent agreement, after the portrait overlay and
`hpconbon.2da`.

#### Armour class — SETTLED 2026-08-08: the engine reads `0x48`, the **effective** field

The first run was ambiguous: the game showed a base of **10**, which was both the untouched
effective field's value *and* the unarmoured default. Two hypotheses fit — the engine reads
`0x48`, or it recomputes and ignores both stored fields.

A second run wrote **6** into `0x48`, a value that cannot arise unarmoured, and left `0x46` at the
`8` the first run had put there. The result is decisive:

| Run | `0x46` natural | `0x48` effective | Game showed |
|---|---|---|---|
| 1 | **8** (edited) | 10 | `Armor Class: 10` → AC 7 |
| 2 | 8 | **6** (edited) | `Armor Class: 6` → AC 3 |

**`0x48` is the field. `0x46` moved nothing in either run**, including the run where it was the
only one edited. It stays editable — the field is real and may matter to the engine somewhere the
character sheet does not show — but it is not what sets armour class.

This **reverses the reasoning that chose it.** The plan argued for editing the "authored input"
and letting the engine derive the output, on the strength of IESDP's Natural/Effective naming.
The engine does not work that way, and only the measurement showed it.

⚠️ **Consequence for a future inventory editor:** since the engine reads a stored effective armour
class rather than recomputing it from what is worn, equipping an item in this editor will *not*
update armour class on its own. That is EE Keeper's "Recalculate Stats", and it is now known to be
required rather than optional.

#### The rules tables, and what they still cannot say — 2026-08-08

`../iesdp/files/2da/2da_bgee/` (198 files) and `../iesdp/files/ids/bgee/` carry the game's own
tables as plain data, so **the rules layer needs no KEY/BIFF reader**. Five lookups were checked
against the screenshots from the run above and all five matched:

| Source | Reads | Game showed |
|---|---|---|
| `CLASS.IDS` 7 | `FIGHTER_MAGE` | Fighter / Mage |
| `RACE.IDS` 2 | `ELF` | Elf |
| `ALIGNMEN.IDS` 0x21 | `NEUTRAL_GOOD` | Neutral Good |
| `GENDER.IDS` 1 | `MALE` | Male |
| `dexmod.2da` row 17 | `AC −3` | "Dexterity: −3" |
| `hpconbon.2da` row 16 | `+2` | "Bonus Hit Points/Level: +2" |

**Three things they still cannot answer, each recorded rather than guessed:**

- **What maximum hit points *should* be.** `hpclass.2da` only names the per-class dice tables
  (`HPWAR`, `HPWIZ`, …); IESDP ships **none of them**, just a template page (`hpx.2da`, shown as
  `hpmonk.2da`). So the rules-based cap is not computable from IESDP. Phase 3, reading the player's
  own installation, is where it becomes possible.
- ~~**The warrior column.**~~ **SETTLED 2026-08-08 — see below.** It was the last unmeasured rule
  in the file, and the measurement agreed with the walkthrough.
- ~~**The kit encoding.**~~ **SETTLED 2026-08-08 — see below. The claim recorded here was wrong,
  and it was wrong about our own parser rather than about the game.**

⚠️ **`2DA V1.0` is not always spelled that way.** 17 of the 194 BG:EE tables pad the signature —
`hpclass.2da` writes `2DA        V1.0`. A parser matching the literal string produces a silently
**empty** table for every one of them, which is the worst way for a rules table to be wrong.

#### ✅ The warrior column — SETTLED 2026-08-08, at Constitution 18

`hpconbon.2da`'s two columns are identical from 1 to 16 and diverge only from 17 up, so no save
this project has ever held could tell them apart. The party's Constitution was raised to 18 in the
app, the save loaded, and the engine printed its own breakdown:

```
Class Hit Points/Level: +7
Bonus Hit Points/Level: +4      <- the WARRIOR row; OTHER reads 2 at 18
```

with the hit-point globe reading **41 / 44** against a stored **37 / 40**.

| Hypothesis | Bonus | Predicted | Observed |
|---|---|---|---|
| `WARRIOR` column | +4 | 41 / 44 | **✓ 41 / 44** |
| `OTHER` column | +2 | 39 / 42 | ✗ |

**Three things fall out, and the second is the one that was actually in doubt.**

1. `GeneratedGameRules.warriorRoots` — `{FIGHTER, PALADIN, RANGER}`, taken from a walkthrough
   rather than from the game — is **right**. No code changed; the guess held.
2. **A multi-class draws the warrior bonus on the strength of one of its classes.** Aard is half
   mage and still took the warrior row. The rule is *containment*, not "the class is a warrior".
3. **The bonus is not halved for a multi-class.** A divided reading of the warrior row gives 2 and
   predicts 39/42, which is also what the other column predicts — so this run separated three
   hypotheses, not two.

⚠️ **It could easily have been a wasted run, for the reason §Oracles warns about.** `39 / 42` is
what the *portrait* still shows, baked in when the save was written at Constitution 16. Had the
answer been the other column, a fresh portrait would have been pixel-identical to the stale one
and "the engine uses `OTHER`" would have been indistinguishable from "you forgot to re-save". The
printed `+N` is the reading that cannot be confused; take the record or inventory screen, not the
picture.

Still level 1, so **whether the bonus multiplies by the highest class level or averages across
them is untouched** — every reading gives ×1 here.

⚠️ **Do not answer that one by editing a level (D10).** A level is not a field: hit dice, THAC0,
saving throws, proficiency slots and spell slots are all granted on level-up, and the "Next Level"
counter runs against a per-class experience threshold the stored total would no longer match. It
is the recalculation layer, brought forward for one display number.

It is also unnecessary. The game printed the protagonist's own thresholds — Fighter level 2 at
**2000** per class, Mage at **2500**, against a stored total of 364 split evenly — so between a
**total of 4000 and 5000 experience** he is **Fighter 2 / Mage 1**. At Constitution 18 and the
warrior +4, the three readings predict stored **+8**, **+6** and **+4**: three different numbers
on one screen. `000000100-Party` also carries Yeslick at `FIGHTER_CLERIC` **2/3**, which
discriminates the same way if he is recruited first.

#### Everything else that run re-confirmed

Free checks that came with the same two screenshots, all agreeing with what is recorded above:
`Base THAC0: 15` (a stored base, not recomputed), `Armor Class: 6` with `Dexterity: -3` giving 3
(the **effective** field `0x48`, and `0x46` still moving nothing at its edited `8`),
`Reputation: Average (11)` from the GAM's `110`, and party gold `12455`.

⚠️ **The game shows *two* THAC0s and we only hold one.** Its record screen prints `Base THAC0` and
then a modified figure: Imoen reads `Base THAC0: 20` / `THAC0: 18`, Aard `Base THAC0: 15` /
`Main Hand THAC0: 12` / `Off-hand THAC0: 14` from `Strength Modification: -3` and
`Proficiencies: +2`. The stored byte is the **base**, so an editor showing `20` beside a game
showing `18` reads as a bug the way `6/7` against `8/9` did. The field is therefore labelled
**"THAC0 (base)"** and says why. Computing the modified value needs proficiency data, which is
Phase 3 territory — the same place the hit-point cap waits.

One number is new. **Multi-class experience splits exactly**, at a second data point: the CRE holds
**364** and the record screen shows `Fighter: Experience 182` and `Mage: Experience 182`. The
earlier run's 325 showed 162 apiece, losing one to rounding, so the engine floors — 364 divides
evenly and loses nothing.

#### ✅ The kit encoding — SETTLED 2026-08-08, and the blocker was our own parser

**`0x0244 >> 16` is the `KIT.IDS` key.** The shift is measured, not assumed: Xzar stores
`0x10000000`, which shifted right 16 is `0x1000` — `MAGESCHOOL_NECROMANCER` — and Xzar is a
Necromancer.

| Member | Class | Stored | `>> 16` | `KIT.IDS` |
|---|---|---|---|---|
| Aard | `FIGHTER_MAGE` | `0x40000000` | `0x4000` | `TRUECLASS` — no kit |
| Imoen | `THIEF` | `0x00000000` | `0x0000` | *(absent)* — no kit |
| Montaron | `FIGHTER_THIEF` | `0x40000000` | `0x4000` | `TRUECLASS` — no kit |
| Xzar | `MAGE` | `0x10000000` | `0x1000` | `MAGESCHOOL_NECROMANCER` |

**"No kit" has two encodings**, `0x00000000` and `0x40000000`, and both must render as nothing.

⚠️ **A kit REPLACES the class name; it does not qualify it.** BG:EE's record screen for Xzar:

```
Necromancer: Level 1        <- not "Mage"
Next Level: 2500            <- but still the mage progression
Male / Human / Necromancer / Chaotic Evil
```

The word "Mage" appears nowhere on the screen, while the class byte underneath is still `1`. A
first pass here rendered `Mage (Necromancer)`, which was ours and not the game's; the screenshot
that was asked for to confirm the *spelling* corrected the *form* instead. Measured on a mage
school, the only kit any fixture carries — BG:EE names the other kits the same way, a kitted
fighter reading `Berserker`, but that part is convention until one turns up.

**Why the earlier note said `KIT.IDS` has no `TRUECLASS` row.** It has one. `KIT.IDS` numbers
`0x4000` **twice** — `TRUECLASS` first, `MAGESCHOOL_GENERALIST` fourteen rows later — and
`IdsMap.parse` was last-wins, so the row meaning "no kit" was silently dropped and the surviving
name put a mage school on every character without one. The parser is now first-wins and keeps the
displaced rows in `IdsMap.shadowed`, which the generator prints into `identifiers.g.dart`.

Montaron settles it from the data alone, with no appeal to which row comes first: a Fighter/Thief
has no mage component, so his `0x4000` cannot possibly be a mage school.

⚠️ **`CLASS.IDS` collides the same way at 202** — `LONG_BOW` and `MAGE_ALL`, which IESDP's own page
explains in prose. Unreachable from a CRE class byte, so it changes nothing; it is here because it
proves duplicate keys are a property of the format rather than one bad row in one file.

#### Two more facts nobody was looking for

- **Multi-class experience is split per class on display.** The record screen showed
  `Fighter: Experience 162` and `Mage: Experience 162` against a stored `0x18` of **325**. The CRE
  holds the total; the engine divides it. (325 ÷ 2 = 162 each, losing one point to rounding.)
- **Carried gold and the party purse are genuinely different numbers**, as `0x1c`'s
  documentation implies: the creature record read `0` while the game showed **12345**, which is
  the GAM header's `partyGold` from the earlier write-path proof.

#### Identity fields, added 2026-08-08

| Offset | Size | Field |
|---|---|---|
| `0x0234` | 1 | Level, first class |
| `0x0235` | 1 | Level, second class — **junk unless the class uses it** |
| `0x0236` | 1 | Level, third class — **junk unless the class uses it** |
| `0x0244` | 4 | Kit — the `KIT.IDS` key in the **high word**; see above |
| `0x0272` | 1 | Race (`RACE.IDS`) |
| `0x0273` | 1 | Class (`CLASS.IDS`) |
| `0x0275` | 1 | Gender (`GENDER.IDS`) |
| `0x027b` | 1 | Alignment (`ALIGNMEN.IDS`), whose table is written in **hex** |

#### ⚠️ Unused class-level slots are NOT zeroed — 2026-08-08

Only the *player's own* record zeroes the slot it does not use. Every shipped NPC record leaves a
`1` there:

| Member | Class | `0x0234`–`0x0236` | Slots that mean anything | Game shows |
|---|---|---|---|---|
| Aard | `FIGHTER_MAGE` | `01 01 00` | 2 | `Multi-Class` · `Fighter: Level 1` · `Mage: Level 1` |
| Imoen | `THIEF` | `01 01 01` | **1** | `Thief: Level 1` |
| Montaron | `FIGHTER_THIEF` | `01 01 01` | **2** | — |
| Xzar | `MAGE` | `01 01 01` | **1** | `Necromancer: Level 1` |

The right-hand column is the engine's own record screen, read 2026-08-08. Imoen and Xzar store
three levels apiece and the game prints **one line each**; Aard stores two and gets a `Multi-Class`
heading with a block per class. Nothing in the bytes distinguishes Imoen from Montaron — they are
byte-identical here — so the class is the only thing that can.

**How many slots are meaningful comes from `CLASS.IDS`, never from the bytes.** Every playable
class name spells its classes out, so `FIGHTER_MAGE_THIEF` is three and `THIEF` is one; splitting
the identifier on `_` and counting is the rule. Reading it off the bytes instead put
**"Level 1/1/1" on a plain Thief** in the character panel, and the defect survived review because
every one-character fixture was the player's own record, where the two rules agree.

#### The rest of the character sheet — added 2026-08-08

Everything the record screen shows and the app did not, all **fixed-width header bytes**, so the
patch-a-copy writer covers them:

| Block | Offsets |
|---|---|
| Saving throws ×5 | `0x54`–`0x58` — death, wands, polymorph, breath, spells |
| Resistances ×11 | `0x59`–`0x63` — fire … missile |
| Thief skills ×8 | `0x45` hide, then `0x64`–`0x6a` — detect illusion, set traps, **lore**, locks, move silently, find traps, pick pockets |
| Attacks per round | `0x53` |
| Armour class modifiers ×4 | `0x4a`–`0x50`, **signed** — crushing, missile, piercing, slashing |
| Fatigue, intoxication, luck | `0x6b`–`0x6d` |
| Morale break, racial enemy, recovery | `0x240`, `0x241`, `0x242` |
| Turn undead, tracking | `0x82`, `0x83` |

**Saving throws are stored exactly as displayed** — the one block in this format that is not a
base. Xzar holds `14/11/13/15/12` and his record screen printed Paralysis/Poison/Death **14**,
Rod/Staff/Wand **11**, Petrification/Polymorph **13**, Breath **15**, Spell **12**.

⚠️ **Thief skills and Lore are not.** They are the points *allocated*; the engine adds class, race
and Dexterity bonuses before display. Imoen stores Move Silently **15** and the game shows **35**;
she stores Lore **3** and shows **10**; Xzar stores Lore **3** and shows **15**. Same hazard as hit
points and THAC0 — label them, and do not invent a derived figure until the tables are in.

### ⚠️ Proficiencies are effects, not header bytes — 2026-08-08

IESDP documents BG1 weapon proficiencies at `0x6e`–`0x81`. **Those bytes are zero on all four
party members** of a save where the game plainly shows pips, so they are deliberately absent from
`CreHeaderField` rather than recorded as meaningful zeroes.

They are stored as **opcode 233 effects** in the creature's own effects section, with the pip
count in *parameter 1* and a `STATS.IDS` index in *parameter 2* — 89–108 the weapons, 111–115 the
fighting styles.

Two facts about the record, each of which cost a wrong guess:

- **Effects here are v2 at 264 bytes, not the 48 of a v1 record.** `effectVersion == 1` means v2.
  Confirmed by the section chain dividing exactly: Aard's effects run 1340 → 6884, and
  5544 = 21 × 264.
- ⚠️ **An embedded effect is the EFF *body alone*, so IESDP's body offsets are eight bytes too
  high.** IESDP numbers the body from `0x08`; what it calls body `0x08` is byte 0 of the stored
  record. Reading with IESDP's numbers puts the opcode eight bytes early and returns **zero for
  every effect in the file** — which looks like "this creature has no effects" rather than like a
  bug. `EffectV2Field` carries the corrected table.

**It cross-validates four ways, which is what makes it a measurement.** Every member is proficient
in the weapon actually in their hand:

| Member | Proficiencies | Carrying |
|---|---|---|
| Aard | Two-Weapon Style 2, Flail/Morning Star 2 | Battle Axe + `BLUN03` **Flail +1** off-hand, "Attacks per Round: 2", separate off-hand THAC0 |
| Imoen | Short Sword 1, Shortbow 1 | `BOW05` Shortbow and 37 arrows |
| Montaron | Short Sword 2, Sling 2 | `SW1H07` Short Sword |
| Xzar | Dagger 1 | `DAGG01`, and his record screen reads "Proficiencies: Dagger +" |

A wrong offset or stride gives every character the same answer, usually an empty one.

**Raising a pip is a fixed-width edit** — parameter 1 is a dword already in the record, so 2 → 3
changes *one byte* of the 101,352-byte save. Only **granting** a proficiency a character lacks adds
an effect, and that resizes.

### Inventory — read cleanly 2026-08-08, and mostly editable without a layout pass

Item records are **20 bytes** (`0x00` resref, `0x08` expiration, `0x0a`/`0x0c`/`0x0e` quantities,
`0x10` flags). The slot table is **fixed at 80 bytes** — 40 words, each `0xFFFF` or an index into
the items table, in the BG order: helmet, armour, shield, gloves, two rings, amulet, belt, boots,
four weapons, four quivers, cloak, three quick items, sixteen pack slots, magic weapon, then
"selected weapon" and "selected weapon ability".

**Because the slot table is fixed, quantities, charges and the identified/stolen/undroppable flags
are all fixed-width edits.** Only adding or removing an item resizes the items table — and removing
also shifts every slot index above the one removed.

No item record in the fixture is unreferenced by a slot, so the engine keeps the table tight;
writing an orphan would be novel behaviour rather than something it already tolerates.

### ⚠️ The first byte of a CRE resref is overwritten with `*` — 2026-08-08

`CHARBASE` → `*HARBASE`, `IMOEN1` → `*MOEN1`, `XZAR` → `*ZAR`. **Replacement, not a prefix**:
`*ZAR` occupies four bytes where a prefix would need five, and `*HARBASE` is eight where a prefix
would have pushed the `E` out. It is on the non-party structs too, not just recruited members.

**Consequence: the resref is not a usable identity key** — one character of it is simply gone.

⚠️ **And it is worse than that: it is not unique either.** Aard and Aurel are different characters
in different campaigns and **both** are `*HARBASE`, because both are the player's own character
built from the same `CHARBASE` template. Corrected 2026-08-09.

⚠️ **`dialogFile` is not the answer on its own either.** An earlier revision of this note said
`dialogFile` at `0x02cc` "survives intact (`IMOEN2`, `MONTAJ`, `XZARJ`) and is what to key on".
That is true of **companions** and false of **the protagonist**, whose copy is eight zero bytes —
checked 2026-08-09 across all three saves, on Aard twice and Aurel once. The two are
**complementary**, and together they are an identity:

| | GAM `displayName` | CRE `dialogFile` | CRE `longNameStrref` |
|---|---|---|---|
| protagonist | `Aard`, `Aurel` | empty | `-1` |
| companion | empty | `IMOEN2`, `MONTAJ`, `XZARJ` | names them in the talk table |

So the key is **`displayName` if it is non-empty, otherwise `dialogFile`** — the same shape as the
name resolution the app already does, and for the same reason.

#### Recruiting moves the struct between arrays — 2026-08-08

Not a flag. The one-character saves hold party 1 / non-party 36; `000000100-Party` holds 4 / 33,
and the three resrefs missing from the non-party array are exactly the three that joined. **Both
arrays resize**, which is another entry on Phase 1's list.

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

**Extended 2026-08-08 from one character to four, at three different Constitutions.** The
four-member party's portraits (see §`PORTRT<n>.bmp`) each carry the same arithmetic with a
*different* bonus, which is what turns it from a pattern into a rule:

| Member | Class | Con | `hpconbon` | Stored max | Rendered |
|---|---|---|---|---|---|
| Aard | `FIGHTER_MAGE` | 16 | +2 | 40 | **42** |
| Imoen | `THIEF` | 16 | +2 | 6 | **8** |
| Montaron | `FIGHTER_THIEF` | 15 | +1 | 8 | **9** |
| Xzar | `MAGE` | 10 | +0 | 4 | **4** |

Two things fall out that a single character could not show. The bonus applies to **non-warrior
classes on the same table** — Imoen is a Thief and takes the same +2 as Aard, exactly as
`hpconbon.2da` says it should below 17. And the bonus is **not divided among the classes of a
multi-class character**: Aard takes the full +2 and Montaron the full +1, not half of each.

**A fourth run the same day pushed the bonus itself.** Aard at Constitution **18** rendered
**41 / 44** from a stored 37 / 40, with the engine printing `Bonus Hit Points/Level: +4` — the
warrior row, undivided. Varying the *modifier* rather than only the base is what makes this
arithmetic rather than a fixed offset that happens to fit. See §The warrior column.

Still level 1 everywhere, so **whether the bonus multiplies by the highest class level or averages
across them remains untested** — every reading gives the same answer at level 1.

**Consequences.** The offsets and IESDP's names (`0x0024` "Current Hit Points", `0x0026` "Maximum
Hit Points") are correct and are not the problem; an editor should read and write exactly these
fields. But a screen showing `6 / 7` beside a game showing `8 / 9` reads as a bug, so the UI
labels it **"Hit points (base)"** and says why. Computing the displayed value needs `HPCONBON.2DA`
out of the BIFF archives (Phase 3) plus the class rules, which is the same territory as EE
Keeper's deferred "Update Bonus Stats".

~~**Suspect the same of every other derived stat** — armour class and THAC0 are the obvious
candidates, and both are unchecked.~~ **Both were checked on 2026-08-07/08 and both are settled
above:** THAC0 is a stored base the engine does not recompute, and armour class is read from the
effective field `0x48`. The portrait overlay only reports hit points, so those two needed the game.

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

## CHR V2.0 — exported characters, and what import does to them

Measured 2026-08-09 against `characters/aurel.chr`, `aard.chr` and `Aard1.chr`, each paired with
the savegame it came from.

### Layout: a 100-byte header, then a plain CRE

`CHR ` / `V2.0`, a 32-byte name at `0x08`, the CRE offset at `0x28`, its length at `0x2c`. On every
file measured the offset is **100** and `100 + creLength == fileLength` exactly.

⚠️ **IESDP's CHR V2.0 page says the embedded file is a "CRE v2.0". On BG:EE it is `CRE V1.0`** —
the record `CreCodec` already reads. Dispatch on the **embedded signature**, never on the CHR
version.

⚠️ **`dialogFile` is eight zero bytes in a `.chr`**, and `longNameStrref` is `-1`. The 32-byte
header name is where the character's name lives — the protagonist's shape, which is what an
exported character always is.

### Export copies the record verbatim; import rebuilds part of it

**Export runs from a saved game** — the Record screen's EXPORT button — and copies the party
member's CRE byte for byte. Three matched pairs:

| `.chr` | matches | CRE bytes |
|---|---|---|
| `aurel.chr` | `000000101-Aurel Start` | 6,924 |
| `aard.chr` | `000000020-start` | 6,660 |
| `Aard1.chr` | Aard immediately after his level-up | 6,884 |

**Import is the character-creation screen's IMPORT button, and it starts a *new game*.** It carries
more than expected and silently rebuilds two things:

| | carried | rebuilt |
|---|---|---|
| experience, class levels | ✅ 4000, Fighter 2 / Mage 1 | |
| THAC0, ability scores, proficiencies, Lore, AI script, effects | ✅ **including values this app had edited** | |
| **hit points** | | ⚠️ stored **45 → 12** |
| **percentile strength** | | ⚠️ **19/100 → 19/0** |

⚠️ **Editing hit points and exporting is pointless** — the engine discards the stored maximum and
recomputes it from class and level. Strength 19 and THAC0 15, both written by this app in earlier
sessions, survived into the new game untouched. So *some* edits cross the import boundary and
others do not, and which is which is not guessable.

⚠️ **The percentile is normalised.** Only a Strength of exactly 18 has one; the engine zeroes it
otherwise. A stored `19/100` is junk, and this app was faithfully displaying it.

### How hit points are actually built — 2026-08-09

Draa, imported at Fighter 2 / Mage 1, arrived with a stored maximum of **12**:

    2 × (d10 ÷ 2)  +  1 × (d4 ÷ 2)  =  10 + 2  =  12

on Normal difficulty, where hit-point rolls are maximised (stated by the difficulty screen and
independently by Haeravon's walkthrough). So hit points are computed **per class** — each class
contributes half its own die per *its own* level.

⚠️ **This contradicts `HPFM.2da`, and the engine wins.** That table gives a Fighter/Mage
`SIDES 7, ROLLS 1, MODIFIER 0` — a single pre-averaged `1d7`, which is `(10+4)/2`. Were it the die
in use, Aard's Fighter 1→2 would have stored **+7**; it stored **+5**, which is `d10 ÷ 2`. **What
`HPFM` is for is open.**

**The level-up screen's figure includes Constitution; the stored bytes do not.** BG:EE announced
`Additional Hit Points Gained: 7` while the stored maximum went 40 → **45**. The missing 2 is the
Constitution bonus for an 18 (+4, warrior column) **halved for a two-class character**.

### ✅ The multi-class Constitution multiplier — SETTLED 2026-08-09, closing D10

Draa, imported at Fighter 2 / Mage 1 with Constitution 18, stores a maximum of **12** and the game
draws **18 / 18** into `PORTRT0.bmp`. Bonus = **6**.

⚠️ **The bonus multiplies by the MEAN of the class levels, not the highest.** `4 × 1.5 = 6`, where
highest would give `4 × 2 = 8` and show 20.

The two competing readings were never rivals: `bonus × Σlevels ÷ nClasses` **is**
`bonus × mean(levels)`, identically. And **for a single-class character mean and highest are the
same number** — which is why every earlier run agreed and this stayed open.

**Residual unknown:** the rounding when the mean is not exact. Constitution 17 (+3) at 2/1 gives
4.5. Not guessed at in code.

⚠️ **The oracle was on disk the whole time.** No screenshot was needed — the engine bakes the hit
points into the portrait it saves beside every game. This file says so under §Oracles; it went
unused for two days while runs were requested instead.

### The engine does not level a character on load — 2026-08-09

Setting experience to 4000 on a Fighter/Mage produced `Ready to Level Up` on the Record screen and
**nothing else**. Levels, hit points, THAC0 and saving throws were all unchanged until LEVEL UP was
pressed. **An experience edit on its own changes nothing derived.**

The experience split is even and confirmed on screen: 4000 → 2000 Fighter / 2000 Mage, against
thresholds of 2000 and 2500, giving Fighter 2 / Mage 1.

**Levelling does not resize the record** — 6,884 bytes before it, after it, and in the new game.

### ⚠️ THAC0 survives a level-up, and why is OPEN

`THAC0.2da` gives a Fighter 20/19/18/… by level and a Mage 20/20/20/19/…, and a multi-class takes
the **better** row — so Aard at Fighter 2 computes to **19**. His record holds **15**, written by
this app, and the Record screen still printed 15 after the level-up.

Two readings fit, and 15 being *better* than 19 is exactly why they cannot be told apart:

- the engine never recomputes THAC0 from class and level, or
- it recomputes and keeps whichever is better — the same rule the walkthrough states for choosing
  between a multi-class character's two classes.

⚠️ **The experiment that separates them:** store a THAC0 *worse* than the computed value — 25 on
this character — and look. `19` means it recalculates; `25` means the stored byte is taken as-is.

`CLASTHAC.2da`, the per-class THAC0 bonus, is **all zeros** on BG:EE.

### Proficiency slots are granted slowly — 2026-08-09

`profsmax.2da` gives every class `FIRST_LEVEL 2`. Aard's Fighter 1→2 level-up screen showed
`PROFICIENCY SLOTS 0`, with every `+` greyed. **The game bounds how many proficiencies a character
may have long before the file format does.**

#### What adding a proficiency actually costs

Proficiencies are opcode 233 effects, so granting one the character lacks appends a 264-byte
record. Measured on both saves:

| | in a savegame | in a `.chr` |
|---|---|---|
| GAM header offsets | 3 | — |
| later party `creOffset`s | 0–3 | — |
| **non-party `creOffset`s** | **33–36** | — |
| CHR header length field | — | 1 |
| **total pointers to patch** | **39** | **1** |
| bytes shifted | 81–93 KB | 0 |

⚠️ **36 of those 39 are the `creOffset` embedded in each non-party NPC struct.** No earlier note
mentioned them; a layout pass that patches only the GAM header corrupts the save silently.

**The engine performs this resize constantly.** Aurel's record was **1,908 bytes** at
`000000007-Prologue Start` and **6,924** by `000000101-Aurel Start`: the prologue attached 19
opcode 187 (`Script: Store Local Variable`) effects, exactly 19 × 264 = 5,016 bytes. Of his 22
effects only **3** are proficiencies.

## Portraits, and the resources a character names — measured 2026-08-09

### The CRE names two portraits, and IESDP's names for them are misleading

| offset | IESDP calls it | actually holds |
|---|---|---|
| `0x0034` | "Small Portrait" | the **`…M`** resref — `BDTMIM`, `IMOENM`, `MONTARM`, `XZARM` |
| `0x003c` | "Large Portrait" | the **`…L`** resref — `BDTMIL`, `IMOENL`, `MONTARL`, `XZARL` |

Verified on six records: all four members of `000000100-Party`, plus `aurel.chr` and `Aard1.chr`.
⚠️ **Name these fields for what they hold.** A field called `smallPortrait` returning `BDTMIM` is a
trap for the next reader. The two exactly fill the gap this spec leaves between `effectVersion`
(`0x33`) and `reputation` (`0x44`), and neither is in `CreHeaderField` yet.

⚠️ **The `…S` variant is not referenced by a CRE at all.** 54×84 is what the game bakes into
`PORTRT<n>.bmp` beside a save — a different picture for a different purpose, and the one this
project uses as an oracle.

### The format, measured across all 210 in `data/PORTRAIT.BIF`

**24-bit uncompressed BMP**, in `L`/`M`/`S` triples off a base name of at most seven characters so
the suffix fits an 8-byte resref — `AJANTISL`, `AJANTISM`, `AJANTISS`.

| variant | size | count |
|---|---|---|
| `L` | 210×330 | 67 |
| `M` | 169×266 | 67 |
| `S` | 54×84 | 65 |

The remainder are older or odd — 38×60, 54×85, 110×170, 172×266, one 1×1 and one 32-bit — so **the
engine tolerates variation** and a strict size check would be stricter than the game.

`dart:ui` decodes BMP natively, already proven by the save browser, so **portraits need no BAM
decoder and none of Phase 5**.

### Custom portraits are loose files that shadow the packed ones

`<user data>/portraits/` sits beside `save/` and `characters/` — present and empty on this machine.
The engine looks there before the archives, and a portrait is named by resref either way, so
**the same two CRE fields serve a built-in and a custom one**. There is no separate mechanism to
build, only a different place to look first.

### ⚠️ `CHARBASE` is in the archives, and it is the seed the engine uses

The key file indexes **2,253 creatures**, `CHARBASE` among them. That is the template every
protagonist is built from — which is *why* the resref of the player's own character always reads
`*HARBASE`, and why Aard and Aurel, different characters in different campaigns, are **both** it.

**Consequence: creating a character never means synthesising a CRE.** Load the engine's own
template out of the player's installation and edit it.

### ⚠️ `ResourceType.creature` is wrong — `0x03f9`, and CRE is `0x03f1`

Confirmed against IESDP's own type table (`file_formats/general.htm`) and against the data: 2,253
resources of type `0x03f1` including `CHARBASE`, and none at `0x03f9`. **Never fired**, because
`KeyIndex.locate` is only ever called for `table2da` today. It would fire the first time anything
asked for a creature.

## Rules tables read from the player's installation — 2026-08-09

⚠️ **IESDP ships `hpclass.2da` and none of the per-class tables it points at**, so these came from
the installation. All are pure numbers, so D11's strref rule does not apply — but the *engine*
outranks them, and in one case measurably does.

### Hit dice — `HPCLASS.2DA` maps a class to its table

| table | classes | die | from level 10 |
|---|---|---|---|
| `HPWAR` | Fighter, Ranger, Paladin | d10 | +3 |
| `HPPRS` | Cleric, Druid, Monk | d8 | +2 |
| `HPROG` | Thief, Bard | d6 | +2 |
| `HPWIZ` | Mage, Sorcerer | d4 | +1 |
| `HPBARB` | Barbarian | d12 | +3 |

Each table rolls once per level through 9 and grants a flat modifier from 10 on.

⚠️ **`HPCLASS` maps `FIGHTER_MAGE` to `HPFM`, a pre-averaged `1d7`, and the engine does not use
it.** Measured twice: an imported Fighter 2 / Mage 1 arrived at **12**, which is `HPWAR`×2 and
`HPWIZ`×1 each halved, and a Fighter 1→2 level-up stored **+5**, which is `HPWAR` halved. **What
`HPFM` is for is open.**

### Ability ranges — three tables, and the combination is derived exactly

- `ABRACERQ.2da` — per race, `MIN_`/`MAX_` for all six abilities. Elf: `MIN_DEX 6, MAX_DEX 18`.
- `ABRACEAD.2da` — racial adjustment. Elf: `MOD_DEX +1`, `MOD_CON −1`.
- `ABCLASRQ.2da` — per class minimums only. Mage: `MIN_INT 9`. Fighter: `MIN_STR 9`.

**6 to 18, plus 1, is 7 to 19 — exactly what BG:EE printed on Aurel's ABILITIES screen** for an
Elf's Dexterity. Each table is measured; ⚠️ **flooring the racial minimum with the class one is an
inference** until a case distinguishes it.

### Proficiency slots — `profsmax.2da`

Every class row gives `FIRST_LEVEL 2`, and **a multi-class sums its halves**: Aurel, a level-1
Fighter/Mage, was offered **4** slots at creation and spent exactly four — War Hammer 1,
Flail 1, Two-Weapon Style 2.

⚠️ **The progression past level 1 does not parse cleanly.** The remaining columns read
`OTHER_LEVELS 5` and then three headed `3 6 9` holding `3 4 5`. All that is measured is that a
Fighter 1→2 level-up grants **none** — the screen read `PROFICIENCY SLOTS 0`.

### Thief skill points — `thiefskl.2da`

`START_POINTS` and `LEVEL_POINTS`: a Thief gets **40** then **25** a level, a Shadowdancer 30 then
20, an Assassin 40 then 15. This bounds the *total* a character may have allocated, where
`thiefscl.2da` only says *which* skills a class may have at all.

⚠️ **`thiefskl` is not `thiefscl`.** The near-identical names have misled this project once
already.

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

**The spike was deleted on 2026-08-08**, once all four defects below were answered and every part
of what it did was living in tested code. Keeping a second, buggier reader around invites someone
copying from it — bug #1 was still in it, verbatim, on the day it went. It remains in git history
if the original is ever wanted.

The four defects, and where each ended up:

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

   ✅ **RESOLVED 2026-08-08 by deletion.** `Gam` reads the documented 352-byte stride and the
   layout invariant makes the table self-checking, so the shipped reader never had this bug. The
   spike itself still computed `(invOff - partyOff) ~/ partyCnt` right up until it was removed.
2. **`strref = -1` is unhandled.** The protagonist's CRE name strref is `0xFFFFFFFF`. The displayed
   name comes from the GAM NPC struct `+192` (`"Aard"` on the fixture) or from the save-local
   `.tot`/`.toh` pair. Name *editing* will need the `.tot`/`.toh` path.

   ✅ **Display half FIXED 2026-08-07.** `Cre.longNameStrref` now reads **signed**, so the sentinel
   arrives as `-1`; the app resolves names GAM → TLK → resref (see §Where a displayed name comes
   from). Name *editing* remains open and still needs `.tot`/`.toh`.
3. **The round-trip check is tautological.** It re-reads the file and compares it to the buffer it
   already read. A real round-trip requires a writer; it arrives in Phase 1.

   ✅ **RESOLVED 2026-08-07.** The writer arrived early, and with the assertion that actually
   constrains one: edit a single field on the real 95,968-byte fixture and prove **exactly** the
   bytes backing it differ. Byte identity on an unedited file is still recorded as proving nothing,
   since `return input` passes it — see `test/gam/gam_edit_test.dart`.
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

### Extended 2026-08-08 — a field inside an *effect*, and it is read by the engine

The third and hardest of the fixed-width claims: a value that is not in any header at all, but
inside one 264-byte effect record in a creature's effects section. Two edits went in one save and
one load — a plain header byte and a patched effect, so a single record screen answers both.

**On disk**, diffing against the `.bak`: the file is the same 101,352 bytes and **exactly two
bytes differ**.

| Offset | Change | What |
|---|---|---|
| `0xb84` | `2` → `3` | Aard, CRE `+0x550` — the effect at 1340, plus `EffectV2Field.parameter1` at `+0x14` |
| `0x3a34` | `12` → `5` | Xzar, CRE `+0x58` — `saveVersusSpells` |

**In game**, BG:EE agreed with both:

- Xzar's record screen prints **`Spell: 5`**, with the other four saving throws still
  `14 / 11 / 13 / 15`. Those four are the immediate byte neighbours of the one written, which is
  what makes this a check on the *write* and not just on the read.
- Aard's combat screen prints **`Two-Weapon Style +++`** — three pips, from the patched effect.

⚠️ **And the engine did not merely display it, it applied it.** Aard's off-hand THAC0 breakdown
itemises `Two-Weapon Style: +2`. The game's own `stylbonu.2da` gives `THAC0_LEFT` as **4** for
`TWOWEAPON-2` and **2** for `TWOWEAPON-3`, so `+2` is reachable only from three pips.
`THAC0_RIGHT` is `0` in both rows, and the main hand correctly did not move — it read 12 before
and 12 after.

**The before-state was already in this document**, which is what makes the off-hand a measured
pair rather than a prediction. §Stored vs displayed records the 2026-08-07 run on the same
character reading *"12 main hand / **14** off hand"* at two pips. At three it is **12 / 12**. Two
pips of difference, exactly what the table predicts, on a screen nobody was looking at the
off-hand for at the time.

⚠️ Caveat, since it costs one sentence: the 14 was read on `000000099-wandtest` and the 12 on
`000000100-Party` — the same character with the same weapons and the same stored THAC0 of 15, but
not literally the same file. The main hand agreeing at 12 across both is the check that they are
comparable.

Two more of that screen's lines are confirmations of things nothing had checked:

- `Proficiencies: -1` on the off-hand is `wspecial.2da` row **2** (`HIT 1`) — so the engine still
  reads Flail/Morning Star at exactly 2 pips. The *other* effect, one 264-byte stride away, was
  untouched. Patching the wrong one is the failure a single-proficiency character could not show.
- `Proficiencies: +2` on the **main** hand is the unproficient-weapon penalty: Aard wields a
  Battle Axe and has no axe proficiency at all. It is not a two-weapon number, which is why it
  does not move with the pips.

**Base THAC0 is the stored byte, confirmed at last.** The record screen labels it `Base THAC0` and
prints **15** for Aard, whose record stores 15; and **20** for Xzar, whose record stores 20. Xzar's
second line reads `THAC0: 20` as well — a mage with no proficiency and no Strength bonus has
nothing applied, which is exactly what the panel's own note predicted.

### ⚠️ The creature's reputation copy is stale, and the engine ignores it — 2026-08-08

Found by cross-checking Xzar's record screen against his bytes, and it falsified a claim this
project had written into the UI.

| Where | Value |
|---|---|
| GAM header `reputation` (`0x54`, ×10) | **110** → 11.0 |
| Aard's CRE `0x44` | 110 → 11.0 |
| Imoen's, Montaron's, **Xzar's** CRE `0x44` | **100** → 10.0 |
| What BG:EE prints on Xzar's record screen | **`Reputation: Average (11)`** |

So the number the engine shows is the **party's**, and three of the four creature copies disagree
with it. Only the protagonist's agreed — the same asymmetry as the class-level slots and the
morale break point, and the same trap: a one-character party cannot show it, because there the two
always match.

The panel had been showing the *creature's* copy under a tooltip asserting that it "matches the
party's". It read 10.0 on a screen where the game says 11. It now shows the party's value and says
what the stale copy is.

⚠️ **The general lesson, which has now cost three findings: a value duplicated between the GAM and
a CRE is not necessarily maintained in both.** Prefer the one the engine is known to read, and
find out which that is by looking rather than by reasoning.

## `chitin.key` and the BIFF archives — measured 2026-08-08

The resource index turned out to be one of the cheapest things in this project, not one of the
most expensive. Phase 3's difficulty is icons and pickers, not this.

| Fact | Value |
|---|---|
| Header | 24 bytes: signature, version, archive count, resource count, two table offsets |
| Archive entry | 12 bytes: length, name offset, name length, location |
| Resource entry | **14 bytes**: 8 resref, 2 type, 4 locator |
| BG:EE install | **83 archives, 37,342 resources**, 1,530 of them items |
| Locator packing | archive `>> 20 & 0xFFF`, tileset `>> 14 & 0x3F`, file `& 0x3FFF` |
| Cost | ~22 ms to index every resource |

**The resource table closes exactly at the file length** — 2405 + 37,342 × 14 = 525,193 — the same
kind of invariant that gives confidence in the GAM layout, and it is asserted.

**All 83 archives are plain uncompressed `BIFFV1  `.** No decompressor is needed for this game;
the compressed variants belong to titles D3 puts out of scope. A test walks all 83 and says so, so
an install carrying `BIFC` fails by name rather than deeper down.

### ⚠️ IESDP's 2DA copies are per-game, and the strref ones are wrong here

**This is the trap.** IESDP ships the **BG2:EE** `weapprof.2da`. Its `NAME_REF` column points into
BG2's talk table, so generating proficiency names from it produces *tutorial prose*: IESDP gives
strref 31138 for what should be "Two-Weapon Style", and 31138 in this game reads *"While in
temples, talk to the priests as you would an innkeeper…"*.

The player's own `weapprof.2da` gives **25023**, which reads **"Two-Weapon Style"**.

The lesson is narrower than "IESDP is unreliable", and worth stating precisely:

- **Tables of pure numbers survived**, and are confirmed in game — `dexmod` row 17 → −3 and
  `hpconbon` 16 → +2 and 18 → +4 were all read off the record screen.
- **Anything carrying a strref must come from the installation.** A strref is an index into a talk
  table, and the talk table is per-game.

That is why the app reads `chitin.key` at all, and it is recorded as **D11**.

### `thiefscl.2da` — which classes may allocate which skills, read 2026-08-08

The table that says a Fighter/Mage has no thief skills, found while fixing a panel that offered
him all seven. A row per skill, a column per class **or kit**, and the cell is the percentage of
skill points that class may put into it — so `0` is the answer to "does this class have this skill
at all".

**Its columns are the same vocabulary as `weapprof.2da`**, which is what makes it cheap: the
kit-then-class resolver written for proficiency ceilings is the lookup key here unchanged.

| Column | What it allows |
|---|---|
| `THIEF` | 100 on all seven |
| `FIGHTER_MAGE` | **0 on all seven** |
| `BARD` | Pick Pockets only |
| `RANGER` | Move Silently and Hide in Shadows only |
| `BLADE` | Pick Pockets at **50**, where a Bard is 100 |
| `SKALD` | Pick Pockets at **25** |
| `SHADOWDANCER` | a thief, except Set Traps at 0 |

⚠️ **A kit does not follow its class**, as those last three show. Nothing derived from the base
class would get a Blade or a Shadowdancer right.

**Lore is deliberately not in this table**, because every class has it — confirmed in game, where
a Necromancer's record screen prints `Lore: 15`. It stays universally editable.

Three near-misses in the same neighbourhood, recorded so nobody loses the time twice:

- **`thiefskl.2da`** is the *number of points per level* (a Thief starts with 40 and gets 25), not
  who may spend them.
- **`tracking.2da`** is, despite the name, a list of per-area strings. It says nothing about who
  may track.
- **`profsmax.2da`** is proficiency *slots* per level, not which proficiencies exist. The per-class
  ceiling is `weapprof.2da`'s own class columns, where `0` again means "not this class".

**So Turn Undead and Tracking have no governing table**, and are left editable rather than given
an invented class rule. Open question, not a guess.

## Oracles

Prefer verification over reasoning from a spec. Four are available, with different standing:

0. **The save's own `PORTRT<n>.bmp`.** Cheapest of the four and the only one needing nothing but
   the fixture: the game bakes its HUD overlay into the portrait, so every save ships a picture of
   what the engine believed when it wrote the file. It cost one `PIL` resize to read and it
   immediately falsified our hit-point reading (§Hit points are stored WITHOUT the Constitution
   bonus) — a discrepancy no amount of reading IESDP would have surfaced, because the offsets were
   never wrong. Limited to what the HUD draws, which today means hit points.

   **On a multi-member party it becomes an identity oracle too**, which is how the portrait
   mapping was settled: four members with different Constitutions produce four different overlay
   numbers, and each one matches exactly one member's stored value plus that member's own bonus.
   *Design a party that way if you can* — had all four had the same hit points, the picture would
   have proved nothing, the same trap as the first armour-class run.

   ⚠️ Read them with your own loader. The files declare `biClrUsed = 0x01000000`, which is
   meaningless at 24bpp, and strict decoders reject them outright — the 54-byte header, 84 rows of
   164 bytes, BGR bottom-up, is quicker than arguing with ImageMagick.
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
