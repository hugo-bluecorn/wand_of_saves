# Seed — inventory: find an item, add it to a character

**Written 2026-08-12 as input to a plan, not as a plan.** Everything numbered here was measured
against the player's own installation and the gitignored fixtures on this machine; nothing is
quoted from recall. Where a source is silent, this document says so rather than filling the gap.

The ask, verbatim:

> *"a basic inventory control system where I can add an item that was arrived by some kind of
> search… eg if i search for Boots of Speed or by their item number BOOT001 then I can add that
> item to iventory in a saved game or a characther that is saved/exported."*

Four requirements fall out: **search by name**, **search by resref**, **add to a savegame**, **add
to a `.chr`**. Three of the four are cheap. One is not, and it is the reason this document leads
with it.

---

## 1 ⚠️ The ask needs the GAM relocation, and that job is bigger than the record says

**Adding an item appends a 20-byte record to the CRE's items table.** That is a *resizing* edit.
Through a `.chr` it costs one dword. Inside a savegame `Gam.withCreature` throws
`UnsupportedError` — `known-defects.md` entry 3, open since the project began.

**So "add that item to inventory in a saved game" cannot ship without building it.** There is no
way around this: the items table holds exactly `itemsCount` entries with no spare capacity, so an
add always grows the record. Replacing an item already present is fixed-width and would work
today, but that is EE Keeper's *Change Item*, not an add.

### The recorded cost is a floor. Measured on `000000022-last`:

```
      180  party NPC structs
     7312  non-party NPC structs
    92700  GLOBALs
    95472  journal
    95568  familiar info            ⚠️ UNMODELLED
    95968  stored locations         ⚠️ UNMODELLED  (== EOF, count 0)
    95968  pocket plane             ⚠️ UNMODELLED  (== EOF, count 0)
    95968  (EOF)
```

The protagonist's CRE sits at **532** and runs **6,780** bytes. Growing it by 20 must patch:

| what | count |
|---|---|
| `creOffset` in each later NPC struct | 36 |
| GAM header section offsets after it | **6** |
| `creLength` in the protagonist's own struct | 1 |
| **total** | **43** |

⚠️ **`docs/findings/verified-format-offsets.md:838` records 3 header offsets and 39 pointers.
That counts only the offsets `GamHeaderField` *models*.** Three live fields sit past the party CRE
and are invisible to the codec. `0x68` in particular holds real data — file size − 400 in all
eleven fixtures — and a relocation that skips it corrupts the save silently, which is precisely
the failure this project's warning about the 36 non-party structs was written for.

### The four unmodelled fields, read off IESDP's GAM V2.0 page today

`GamHeaderField` stops at `0x58`. These are the missing four, and they are **named nowhere in this
repository** — the "five of nine" claim in `CLAUDE.md:459` and `roadmap.md:84` cites
`verified-format-offsets.md`, which does not contain it.

| field | offset | what all 11 fixtures hold |
|---|---|---|
| Offset to Familiar Extra | `0x48` | `0xFFFFFFFF` |
| Offset to familiar info | `0x68` | **live** — file size − 400 |
| Offset to stored locations | `0x6c` | == EOF, count 0 |
| Offset to pocket plane locations | `0x78` | == EOF, count 0 |

**All three encodings of "absent" appear in one real save**, which is what makes `offset != 0`
insufficient here. And `0x6c`/`0x78` pose a question no source answers: an empty section pinned to
EOF either moves with EOF or is a sentinel that must not be touched. **Not guessable.**

**Consequence for planning:** `Gam.withCreature` is not the mechanical job the roadmap implies. It
needs a spec pass first — name the four fields, decide the EOF semantics — and a synthetic-GAM
builder that actually writes non-party structs. `test/support/synthetic_gam.dart` declares
`nonPartyNpcCount = 36` and writes **zero** structs, so `nonPartyMembers` throws on it; the
36-pointer patch has nothing to test against but real fixtures that skip on a fresh clone.

---

## 2 What the installation actually contains

Measured through the project's own `KeyIndex` / `BifArchive` / `Tlk`.

| | |
|---|---|
| ITM resources indexed | **1,530** across 7 archives (1,282 in `data/ITEMS.BIF`) |
| Read 1,530 headers | **28 ms** |
| Resolve 3,060 name strrefs | **69 ms** |
| Whole catalogue, names only | **119 ms** including parsing `chitin.key` |
| With descriptions too | **130 ms**, 619 KB of text |

⚠️ **The catalogue is cheap.** `planning/ui-review.md:5` calls this "a picker over 37,000 indexed
resources" and the concern shaped the whole UI review; the real number is 1,530 items and a tenth
of a second. **No paging, no debounce and no background isolate are needed for search.** The
expensive thing in this app remains the first BIFF parse, which is already cached.

### The data is dirtier than a picker can ignore

| | count | consequence |
|---|---|---|
| No usable name at either strref | **107** | `ACIDMIST`, `ANKHEG1`, `GHOST`, `DEMOGORG` — monster innate attacks, not items. Must not be offered. |
| Negative name strref | 195 | `-1` is "no string", exactly as `Spl.nameStrref` already models it |
| Distinct resref lengths | 3–8 chars | `resrefsOf` returns them upper-cased |

The filter is the one `wizardSpells` already uses: **the header names a string**. `key_index.dart`
records the same fact for spells — *"Most are not spells anyone learns… the engine keeps its own
plumbing here too."*

---

## 3 ⚠️ The user's own example finds nothing, and that is the design problem

Searching all 1,530 items for **"Boots of Speed"** returns **zero** name matches. BG:EE does not
use that name.

| resref | unidentified | identified |
|---|---|---|
| `BOOT01` | Boots | **The Paws of the Cheetah** |
| `BOOTDRIZ` | Boots | The Paws of the Cheetah |
| `DASBOOT` | Boots | The Paws of the Cheetah |
| `TROLLBOO` | Boots | The Paws of the Cheetah |

Three things follow, and each is a design decision rather than a bug:

1. **Search must cover both names.** Ten of the fourteen "boot" items are called just `Boots`
   unidentified. A player who has not identified an item knows it by the plain name.
2. **A name is not a key.** Four resrefs share one identified name — the fifth time this project
   has hit that shape, after `KIT.IDS`, two `AXE` rows in `weapprof.2da`, `FALLEN_CLERIC` in
   `clastext`, and the `weapprof` padding band. **The resref is the key.**
3. ⚠️ **Descriptions find what names cannot.** "Boots of Speed" matches **3 descriptions** — the
   item's own in-game text uses the phrase. But searching descriptions for "speed" alone returns
   **238** matches. So description search has to exist and must not be the default.

**Recommendation.** One search field, three tiers, labelled: exact resref match first, then name
substring, then a collapsed *"3 more match their description"* group. That is EE Keeper's *Match
Name / Match Description / Match Resource* (dialog 158, 51 controls) collapsed into one live-filtered
list, which is exactly what **D4** already committed to.

### And identification changes what the game draws

`Aard1.chr` carries `BELT16` with flags `0x0` — **not identified**. The engine draws **"Belt"**.
A panel that shows "Belt of Antipode" there is inventing what the engine draws, which is this
project's sharpest recurring fault. **The row must follow the stored flag, not the catalogue.**

---

## 4 What a character's inventory really looks like

Verified end to end against the fixtures — read the CRE, resolve every resref through the archives
and the talk table:

```
===== Aard1.chr =====   itemSlotsOffset=1040  itemsOffset=1120  itemsCount=11
  item  0  BLUN03  q=1/0/0 flags=0x1 identified   Flail +1
  item  1  BOOT01  q=0/0/0 flags=0x1 identified   The Paws of the Cheetah
  item  4  BELT16  q=0/0/0 flags=0x0              Belt of Antipode      ← unidentified
  item  7  SCRL3Z  q=0/0/0 flags=0x3 identified   Gorion's Scroll       ← + unstealable
  ...
  slot  2 Shield        -> item 0     slot 21 Pack 1 -> item 3
  slot  8 Boots         -> item 1     slot 22 Pack 2 -> item 4
  slot  9 Weapon 1      -> item 2     ...  slot 27 Pack 7 -> item 9
                                      slot 29 Pack 9 -> item 10
  items referenced by a slot: 11/11
```

**The slot table is 40 words. Only 0–37 are item indices**; 38 is *selected weapon* and 39 is
*selected weapon ability*. A model that maps all forty to items corrupts the selection pair.

| indices | slots |
|---|---|
| 0–8 | Helmet, Armor, Shield, Gloves, L.Ring, R.Ring, Amulet, Belt, Boots |
| 9–12 | Weapon 1–4 |
| 13–16 | Quiver 1–4 — ⚠️ **four**, and quiver 4 is unreachable in the game's own GUI |
| 17–20 | Cloak, Quick 1–3 |
| **21–36** | **Pack 1–16 — the backpack** |
| 37 | Magic weapon |
| 38, 39 | *(selection state, not items)* |

Three observations the plan needs:

- ⚠️ **Holes are legal.** Aard uses packs 1–7 and 9; pack 8 is empty. "The first free slot" must
  scan, not count.
- **Every item is referenced by a slot** in every fixture, confirming the findings' caution that an
  orphan would be novel behaviour. **An add must write a slot word**, or the item exists in the
  file and nowhere in the game.
- **A created character has no items section at all.** `WANDMAX.chr` stores
  `itemsOffset == itemSlotsOffset == 2168` with count 0. `withEntryInserted` already creates an
  absent section, and this is the path every created character takes.

---

## 5 What exists, and what has to be built

### Already shipped, reusable unchanged

| | where |
|---|---|
| `ResourceType.item(0x03ed)` and `resrefsOf` / `locate` | `key_index.dart:31, 198, 210` |
| `CreSection.items`, 20-byte stride | `cre_section.dart:56` |
| `Cre.withEntryInserted` — splices, creates an absent section, shifts siblings, **relocates the slot table** | `cre.dart:519-571` |
| `Chr.withCreature` — the one-dword resize | `chr.dart:113-124` |
| Atomic write + `.bak` | `atomic_file.dart:48` |
| `EditSession` undo/redo over immutable snapshots | `ui/edit_session.dart` |
| The whole catalogue → strref → talk-table pattern | `ProficiencyCatalogue` + `loadRulesCatalogues` |

### Missing — the format layer

1. **`ItmHeaderField`** — a verified subset, mirroring `SplHeaderField`. The layout below is
   derived from IESDP's own width rules and **checked against `BOOT01`'s real bytes**: header 114 +
   2 feature blocks × 48 = **210**, the file's exact length.

   | offset | field | | offset | field |
   |---|---|---|---|---|
   | `0x08` | unidentified name (strref) | | `0x38` | stack amount |
   | `0x0c` | identified name (strref) | | `0x3a` | inventory icon (resref) |
   | `0x18` | flags (dword) | | `0x42` | lore to ID |
   | `0x1c` | item type (word) | | `0x4c` | weight |
   | `0x1e` | usability bitmask (**4 bytes, not a dword**) | | `0x50`/`0x54` | descriptions (strref) |
   | `0x34` | price | | `0x64`/`0x68` | extended headers offset/count |

   ⚠️ **`0x6a` is a dword at a non-4-aligned offset**, and the min-stat bytes at `0x28`–`0x31` are
   interleaved with the kit-usability bytes. ⚠️ **IESDP states no signedness for any ITM field.**
   `Spl` marks its name strref signed because `-1` means "no name" — measured. The same must be
   *measured* for ITM, not inherited: 195 items carry a negative name strref, which is the evidence.

2. **`CreItemField`** — the 20-byte record: `0x00` resref, `0x08` expiration (days, *not* an unknown),
   `0x0a`/`0x0c`/`0x0e` quantities, `0x10` flags. It fits `structSize: 20` with no gaps, so the
   existing `layoutProblems` gate passes cleanly.
3. **`itemEntry(...)` builder**, beside `spell_entry.dart`.
4. **`Cre.items` accessor** — the parallel of `knownSpells` / `memorizedSpells`, which do not exist
   for items.
5. **A slot-table reader and writer.** Nothing in the package can write those 80 bytes. This is the
   piece that makes an added item visible in game.
6. ⚠️ **Slot-index renumbering.** `withEntryInserted` relocates the table but never renumbers its
   contents. Inserting mid-array invalidates every index at or above it — the same hazard `cre.dart:486`
   documents for memorisation windows, undocumented for items. **Appending is the safe operation.**

### Missing — the app layer

- `ItemCatalogue` + `ItemEntry` domain models, `GameTable`/`TableColumn` entries if any 2DA is read.
- `ResourceRepository.items()` returning names as **strrefs** (repositories never know about each other).
- A use-case `loadItemCatalogue({resources, strings})` beside `loadRulesCatalogues` — `architecture.md:38`
  already predicts the promotion happens "at the item and spell pickers".
- `AddItem` / `RemoveItem` edit commands in the sealed hierarchy.
- An Inventory panel. `character_sheet_view.dart:114` orders panels by a named list and **appends
  anything unnamed**, so this is two lines plus the widget.

### The Riverpod shape — house style and the docs agree

Checked against the pinned 3.4.2 clone, which matches `pubspec.lock` exactly.

- **Catalogue: a plain `FutureProvider`, keep-alive.** Hand-declared providers are keep-alive by
  default; `isAutoDispose: true` is the opt-in. Pass `retry: neverRetry` on the provider itself, not
  only the scope.
- **Query string: widget-local, in the `SearchController`.** `do_dont.mdx:58-91` classifies this as
  ephemeral state and says keep it out of providers — and `command_palette.dart` already does exactly
  that. **Not** a family keyed on free text.
- **Filter: synchronous, in the suggestions builder.** No debounce; Riverpod's debounce recipe is for
  network requests and requires provider disposal between keystrokes, which this shape never produces.
- **After a write:** invalidate exactly the query that changed.
- **`Mutation` stays declined** — still flagged experimental in 3.4.2.

⚠️ **One correction found.** `providers.dart:181` says `.autoDispose` "is codegen-only, which D2
forbids." That is false — the docs' own non-codegen snippets use it. **The decision is right and the
stated reason is wrong**: the real justification is that the builder classes behind `.autoDispose` are
`@internal`, while `isAutoDispose:` is what the docs prescribe by name. Worth fixing, since D2's
credibility rests on checkable citations.

---

## 6 Decisions for you — the plan-mode agenda

**These are the ones where the answers lead to materially different work.** Everything else in this
document I will decide and state.

1. **Does v1 add to a savegame, or only to a `.chr` first?**
   Your ask says both. The savegame half needs the 43-pointer relocation plus a spec pass — call it a
   slice of its own, ahead of any inventory UI. The `.chr` half works today.
   *My recommendation: build the relocation, because it is the last structural gap in the project and
   it unblocks spells too. But it is a real slice and it is your call whether inventory waits for it.*

2. **Backpack only, or equipping too?**
   Pack slots 21–36 sidestep two problems: the item-type → legal-slot rule (`ITEMTYPE.2DA`, whose
   `SLOT = -1` convention IESDP never explains), and ⚠️ **"Recalculate Stats"** — the engine reads a
   *stored* effective armour class, so equipping armour in this editor changes nothing the game
   shows. That is recorded as **required, not optional**, and the roadmap still files it as deferred.
   *My recommendation: backpack for v1. "Add to inventory" is what you asked for, and it is the half
   that is honest without a recalculation pass.*

3. **How much of the item record does the panel edit?**
   Reading is free. Quantities, charges and the four flags are all fixed-width and work in a savegame
   **today**, with no relocation. EE Keeper exposes all of them (Set Qty with *In-Game Max* / *Max
   Possible* — the same distinction as D16's two ceilings). ⚠️ EE Keeper models **four** flags —
   Identified, **Given**, Stolen, Undroppable — where this project models three; `Given` is
   unmodelled everywhere and IESDP calls bit 1 *Unstealable*.

4. **Does search reach descriptions?** Your own example only works if it does. See §3.

---

## 7 Traps, each already paid for once

- ⚠️ **An item with no slot word is invisible in game.** Every fixture keeps the table tight.
- ⚠️ **Slot 38/39 are not items.**
- ⚠️ **Never show the identified name for an unidentified item.**
- ⚠️ **Filter the 107 nameless items**, or the picker offers `GHOST` and `DEMOGORG`.
- ⚠️ **`0x1e` is four independent bytes.** Read as a little-endian dword the class restrictions scramble.
- ⚠️ **No `override/` folder support anywhere in this project.** A modded install shadows archived
  items with loose files and the picker would silently show stale data. Vanilla-only today; worth a
  deliberate decision before shipping a browser.
- ⚠️ **D17 forbids a second staging buffer** beside `EditSession`, and forbids a destination that can
  never enable — that is *why* the spike's inventory screen was deleted. The new one must actually work.
- ⚠️ **`flutter test` cannot see this panel's layout.** Capture a real window after any panel change.
- ⚠️ Fixtures must carry the installation's shape: **a name always arrives with the strref it came
  from**, and an unidentified item must be in the fixture set or the flag rule goes untested.

## 8 Open, and not to be guessed at

| question | state |
|---|---|
| Do `0x6c`/`0x78` (EOF, count 0) move with EOF, or are they sentinels? | **Open.** No source answers it. Blocks the relocation. |
| Is `creLength` inside the 39, or additional? | **Open.** `gam.dart:189` records this count being wrong once already. |
| ITM field signedness | **Open.** IESDP is silent; must be measured, as SPL's was. |
| `ITEMTYPE.2DA`'s `SLOT = -1` | **Open.** IESDP never explains it. Irrelevant while v1 is backpack-only. |
| EE Keeper's fourth flag, "Given" | **Open.** IESDP calls bit 1 *Unstealable*. |
| Does the engine tolerate an orphan item? | **Open**, and deliberately untested — no fixture has one. |

## Sources

IESDP `itm_v1.htm` + `_data/file_formats/itm_v1/header.yml`, `cre_v1.htm:1211-1305`,
`gam_v2.0.htm`, `general.htm:246`; the player's installation via `dump_table.dart` and four
scratch probes; the gitignored fixtures; `verified-format-offsets.md:515-528, 645-700, 836-846`;
`known-defects.md:56-69`; `decisions.md` D4, D9, D11, D13, D14, D16, D17; the pinned
`rrousselGit/riverpod` @ 3.4.2 `website/docs`; EE Keeper's `eekeeper-ui-spec.json` dialogs 147,
148, 150, 158, 186; the deleted spike at `e5d0c93:spikes/ui_spikes/lib/workbench/`.

**No NearInfinity source was read.** Independent implementation from IESDP, verified against the
game's own bytes.
