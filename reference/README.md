# Reference material

**Everything listed here is READ-ONLY.** Never modify, never `git pull`/`checkout`/`commit` inside
these trees, never write to the game install or anyone's saves. None of it is committed to this
repository — these are pointers to material you supply locally.

## Conventions

Paths are expressed two ways, and neither hardcodes a machine:

- **Reference repositories** are expected as **siblings of this repository**, so `../NearInfinity`
  from the repo root. Override with an environment variable if you keep them elsewhere.
- **Game data** cannot be relative — it lives wherever the game was installed. Resolution order
  everywhere in this project is **argument → environment variable → well-known locations**.

| Variable | What | Default |
|---|---|---|
| `IESDP_DIR` | IESDP checkout | `../iesdp` |
| `NI_DIR` | NearInfinity source (oracle builds only) | `../NearInfinity` |
| `EEKEEPER_DIR` | EE Keeper binary (reverse-engineering reference) | `../EEKeeper` |
| `BGEE_GAME_DIR` | Game installation — the directory holding `chitin.key` | auto-discovered |
| `BGEE_SAVE_DIR` | Save root, or a single save slot | auto-discovered |

Auto-discovery covers Steam (Linux/macOS/Windows), GOG and Beamdog layouts. See
`defaultGameRoots` / `defaultSaveRoots` in `lib/data/services/game_profile_service.dart` for the
current list; extend it rather than hardcoding a path.

## Source references

| Sibling | What it is | Standing |
|---|---|---|
| `../iesdp` | [Gibberlings3/iesdp](https://github.com/Gibberlings3/iesdp) — the Infinity Engine Structures Description Project. | **Primary specification source.** Everything is written from this. |
| `../NearInfinity` | [Argent77/NearInfinity](https://github.com/Argent77/NearInfinity), branch `devel`. Java/Swing IE browser+editor, **LGPL-2.1**, ~297k LOC. | **Black-box oracle only.** Its Java is not read while writing codecs — see `planning/using-nearinfinity.md`. |
| `../EEKeeper` | EE Keeper 1.0.4.0 binary + `bgEEEffects.dat` + `lang/*.dll`. Proprietary, © 2012–2017 Troodon80. | The feature target. Reverse-engineered — see `docs/findings/`. Also the only oracle for its derived behaviours, via Wine. |
| Haeravon's *BG:EE FAQ/Walkthrough* (GameFAQs, plain text) | A player's guide carrying the AD&D 2e rules tables in prose — abilities, hit points, THAC0 and armour class by class and level. Copyright its author. | **Cross-check only, never a source.** Facts may be taken from it and expression may not (D1): the numbers are TSR's rules, not the author's writing. Where it and a 2DA disagree, the 2DA wins — it is the game's own data. |

Get them with:

```bash
cd ..                                                        # alongside this repo
git clone --depth 1 https://github.com/Gibberlings3/iesdp.git iesdp
git clone --depth 1 -b devel https://github.com/Argent77/NearInfinity.git NearInfinity
```

### Useful paths inside IESDP

- `file_formats/ie_formats/gam_v2.0.htm`, `cre_v1.htm` — HTML tables, regular enough to script
  (`<td>offset</td><td>size (type)</td><td>desc</td>`). ⚠️ IESDP quotes **absolute** offsets;
  `docs/findings/verified-format-offsets.md` uses CRE-**body**-relative ones. They differ by 8.
- `_data/file_formats/{eff_v1,eff_v2,itm_v1,spl_v1,sto_v1}/*.yml` — **machine-readable** field
  definitions (`offset`, `type`, `length`, `desc`). GAM and CRE are HTML only.
- `_opcodes/*.html` — 911 files with YAML front-matter (`n`, `opname`, `param1`, `param2`, per-game
  applicability). Source for the effects database (Phase 6).
- **`files/2da/2da_bgee/` — 198 BG:EE 2DA files carrying real `2DA V1.0` payloads**, not
  descriptions of them: `hpconbon` (Constitution → hit points), `dexmod` (Dexterity → armour
  class), `strmod` / `strmodex`, `thac0`, `hpclass`. Found 2026-08-07, and it moves work earlier
  than planned: **the game-rules tables need no KEY/BIFF reader**, so derived values do not wait
  for Phase 3. Generate from these; do not transcribe.

## Game data

Supply your own — a legitimately owned copy of Baldur's Gate: Enhanced Edition.

| What | Contains |
|---|---|
| Game installation | `chitin.key`, `override/`, `lang/<locale>/dialog.tlk`, `data/` BIFFs |
| Save directory | numbered slot folders, each with `BALDUR.gam`, `BALDUR.SAV`, portraits |

**Copy saves into a fixtures directory before testing. Never open the originals for writing** —
they are someone's real game. `.gitignore` refuses game data and fixtures; keep it that way, as
that content is BioWare's copyright and must never enter this repository.

The reference fixture used to verify the format offsets was a BG1EE slot with: `GAME V2.0`,
95,968 bytes, 1 party member, 33 globals, 8 journal entries, 161 gold, reputation 11.0, area
`AR2600`. Development so far has been against BG1EE via Steam on Linux, ~37,815 indexed resources.

## Prior work

`../near_infinity_flutter` — a stalled experiment porting NearInfinity wholesale to Flutter.
**Not a dependency.** Its `context/` canon was carried over here; its scope, contract and audit are
not applicable. Two measured findings worth keeping:

- NearInfinity **cannot run headless** — `AppOption.java:369` calls `Toolkit.getScreenSize()` from
  a static initialiser. It works under a display (Xvfb) with `new BrowserMenuBar()` constructed
  first; BG1EE then opens with 37,815 resources in 122 ms. Relevant to building the oracle harness.
- Keeping the data layer in a Flutter-free package makes the rule mechanical rather than
  aspirational — see `planning/architecture.md`.
