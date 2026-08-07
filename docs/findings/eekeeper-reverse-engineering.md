# EE Keeper — reverse-engineering findings

**Status:** established 2026-08-07 from `../EEKeeper/EEKeeper.exe`.
This document exists to answer one question: **what does EE Keeper actually do?** It is the
feature checklist for this project. It is *not* a UI specification to copy — see D4.

## The binary

| Property | Value |
|---|---|
| Format | PE32 x86 GUI, 6 sections, ImageBase `0x400000` |
| Built | 2017-06-07, MSVC, LTCG + PGO |
| Framework | Statically-linked MFC (Feature Pack) |
| Packing | None — plaintext strings, intact `.reloc`, no obfuscation |
| Symbols | No PDB, but **RTTI fully intact**: 594 type descriptors, 541 vtables |

Self-identifying copyright string:

```
EE Keeper Copyright (C) 2012-2017 Troodon80, Shadow Keeper Copyright (C) 2000 Aaron.
```

EE Keeper descends from **Shadow Keeper** (Aaron O'Neil, 2000), whose source is public at
`github.com/devurandom/shadowkeeper`. **That source is off-limits to this project** — see D1.

## How the findings were obtained

Pure-Python PE parsers (no Ghidra/radare2 needed for this depth). The technique, if it needs
repeating: MFC message maps (`AFX_MSGMAP`, 24-byte zero-terminated entries in `.rdata`) bind a
control ID to a handler function address; dialog resource templates bind the same control ID to a
caption. Correlating the two names the handlers. Classes are matched to their message map through
the vtable's `GetMessageMap` thunk, which PGO reduces to `mov eax, imm32; ret`.

Control-ID overlap between message maps and dialog templates matched **7/7** and **14/14** on the
tabs checked, so the correlation is sound rather than approximate.

Extracted output: **`eekeeper-ui-spec.json`** in this directory — 72 dialog templates with every
control (class, ID, caption, geometry) and 173 classes with their message-map entries and resolved
handler addresses. Use it as a completeness checklist.

⚠️ **Deliberately redacted.** EE Keeper is proprietary with no redistribution grant, so that file
carries **structure only**. The 767-entry string table and 13 captions longer than 60 characters
were removed before the first commit: those are authored prose, and republishing them would
redistribute part of a copyrighted work. Short functional labels ("Set Qty", "ID All") are kept —
words and short phrases are not copyrightable. **Do not re-add the removed content.** If a session
needs the prose, read it from a local copy of the binary; it does not belong in this repository.

## Feature set

### Character editing — 12 tabs

Recovered as `CTab*Dlg` classes, each with its own dialog template and message map:

| Tab | Class | Notes |
|---|---|---|
| Abilities | `CTabAbilitiesDlg` | 78 controls. STR/DEX/CON/INT/WIS/CHA, HP, AC, THAC0, reputation, gold, XP, levels, morale, "Re-roll" |
| Characteristics | `CTabCharacteristicsDlg` | class, kit, race, alignment, gender |
| Appearance | `CTabAppearanceDlg` | portraits, colours, animation |
| Inventory | `CTabInvDlg` | "Clear Item", "Set Qty", "All Max Qty", "Change Item", "ID All", "Set Item Flags" |
| Spells | `CTabSpellsDlg` | known spells |
| Memorised spells | `CTabMemSpellsDlg` | per-level memorisation + flags |
| Proficiencies | `CTabProfsDlg` | |
| Effects | `CTabEffectsDlg` | opcode-driven effect editor |
| Journal | `CTabJournalDlg` | |
| Global variables | `CTabGlobalVarsDlg` | |
| Local variables | `CTabLocalVarsDlg` | |
| Miscellaneous | `CTabMiscellaneousDlg` | |

Handler binding works, e.g. `CTabInvDlg`:

```
ON_COMMAND/BN_CLICKED  ID 1048  handler=0x00443529  [BUTTON "Set Qty"]
ON_COMMAND/BN_CLICKED  ID 1051  handler=0x00443c15  [BUTTON "ID All"]
```

Disassembling `0x443529` shows `imul ebx,ebx,0x14` indexing an array at `[edi+0xc8]` — inventory
slot records are **20 bytes**, held at offset `0xC8` in `CTabInvDlg`.

### Browsers

`CCreatureBrowser*`, `CItemBrowser*`, `CSpellBrowser*`, `CCharacterBrowser*` — each a
Doc/Frame/View triad plus a filter dialog (`CItemFilterDlg` alone has **51 controls**).

### Supporting dialogs

Installation directory / game profile / language, open saved game (single-player, multiplayer,
Black Pits, additional campaigns), resource indexing progress, portrait picker, set quantity,
spell settings, edit effects + effect data, set value, edit global variable, name/dialog reference
numbers, edit inventory item flags, edit memorisation flags, innate abilities, export resource,
save character (`.CHR`), save creature (`.CRE`), editor settings, colour selection, changes-made
warning, check for updates.

### Derived behaviours — no oracle but EE Keeper itself

"Recalculate Stats", "Update Bonus Stats", "ID All", "Re-roll", "All Max Qty". These compute values
from game rules (2DA tables) rather than reading them from the file. **NearInfinity has no
equivalent and cannot answer what they should produce.** If parity with these is wanted, EE Keeper
under Wine is the only reference.

## Object sizes (from `CRuntimeClass`)

Useful as a sanity check on how much state each screen carries:

| Class | `sizeof` |
|---|---|
| `CMainFrame` | 16,616 |
| `CEEKeeperView` | 14,049 |
| `CEEKeeperDoc` | 11,848 |

`CEEKeeperDoc` being an 11.8 KB mutable blob that the tabs poke directly is exactly the design this
project replaces with an immutable model plus edit commands.

## Formats EE Keeper touches

Recovered from the `CRes` class hierarchy (`CResCRE`, `CResItem`, `CResSpell`, `CResText`,
`CResBitmap`, `CResCHR`, `CResCell`) plus `CInfTlk`, `CTlkFileOverride`, `CProfData`, `CZipFile`:

KEY/BIFF, SAV, GAM, CRE, CHR, ITM, SPL, TLK (+ override), 2DA, IDS, BAM, MOS, BMP, EFF v1/v2.

## The effects database

EE Keeper ships `bgEEEffects.dat` — **plaintext CSV**, one row per opcode, with parameter names and
prose descriptions. It is visibly derived from IESDP: opcode 0 matches
`iesdp/_opcodes/op000.html` field for field, including the description text.

**Do not port an opcode table by hand.** Generate it from `iesdp/_opcodes/` (911 files, YAML
front-matter: `n`, `opname`, `param1`, `param2`, and per-game applicability flags
`bg1`/`bg2`/`bgee`/`iwd1`/`iwd2`/`pst`/`pstee`). For comparison, NearInfinity encodes the same
information as 442 Java classes totalling 24,909 lines — a data-driven approach avoids all of it.
