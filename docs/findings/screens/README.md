# Screens the engine drew

BG:EE screenshots, captured by the user and recovered from an earlier session's paste cache. They
are the engine's own output, so they rank above IESDP and above any 2DA reading — see
`docs/findings/verified-format-offsets.md` §Oracles.

⚠️ **Gitignored.** These are BioWare's screen content; keeping them out of the repo's history is a
distribution decision, not a storage one. They are on disk and readable by any session.

## `char-create/` — one complete character generation, 34 screens

The making of **Aurel**: male elf Fighter/Mage, Neutral Good, Str 18/27 Dex 18 Con 17 Int 17 Wis 9
Cha 9. He is the character in the `000000101-Aurel Start` fixture, whose stored record reads
`str=18/27 con=17` — so this walkthrough and that savegame are a **matched pair**, the screen and
the bytes for the same character.

Numbered in the order the screens were visited. The flow is:

`00` main menu → `01` step list → `02` gender → `03` **portrait** → `04`–`06` race → `07`–`09`
class → `10`–`12` alignment → `13`–`15` abilities → `16`–`19` proficiencies → `20`–`24` mage book
and memorisation → `25`–`28` colours and voice → `29`–`32` name and summary → `33` difficulty.

Four things in here that the code should be checked against:

- ⚠️ **The portrait is chosen third, right after gender** — before race, class or anything else.
  The step list shows `APPEARANCE` seventh, but `APPEARANCE` is the *colour* step (`26`); the
  portrait is its own screen and it comes first. This app's creation flow already puts the portrait
  first, which turns out to match the engine.
- ⚠️ **`17` reads `PROFICIENCY SLOTS 4`** for a first-level Fighter/Mage. A note in
  `CLAUDE.md` says `profsmax.2da` gives every class `FIRST_LEVEL 2`. One of the two is wrong and it
  has not been chased.
- **Pips render as plus signs** — `War Hammer +`, `Two-Weapon Style ++` (`25`, `29`, `32`). That is
  the engine's own notation for what this app draws as a pip count.
- **`33` states the difficulty rules in the game's words**: on Normal, "Hit Point rolls are
  maximized". Several hit-point measurements rest on that and had only the walkthrough for it.

## `level-up/` — Aard's record, four screens

Not character creation. These are the level-up run: the record before (`01`), the level-up result
`Additional Hit Points Gained: 7` (`02`), the record after (`03`), and the same sheet under the
name `Draa` (`04`).

⚠️ **`03` is evidence in an open question.** Aard is Fighter **Level 2** and the sheet still prints
`Base THAC0: 15`, where `THAC0.2da` computes 19. That is the reading behind the unresolved "does
the engine recompute THAC0" entry in `CLAUDE.md` — and it cannot separate "never recomputes" from
"recomputes and keeps the better", because 15 beats 19 either way.
