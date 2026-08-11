// Copyright 2026 hugo-bluecorn
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// Every `2DA` this application names, as a vocabulary rather than as strings.
///
/// ⚠️ **Why, and it is not tidiness.** Every rules lookup used to spell its
/// table with a bare string, and that shape has cost this project twice:
/// `thiefskl` was read where `thiefscl` was meant, and `profs` where `profsmax`
/// was meant — the second built a proficiency rule on the wrong table and
/// **shipped**. Both files exist, both parse, and both return a plausible
/// integer, so nothing failed. Naming them for **what they answer** rather than
/// for what they are called is what makes the pair unconfusable:
/// `proficiencySlots` and `proficiencyRankCap` cannot be mistyped for each
/// other the way `profs` and `profsmax` can.
///
/// This is D6's argument moved from binary layouts to game data — an enhanced
/// enum whose `values` turns an invariant into a test.
///
/// ⚠️ **The vocabulary is Dart's; the values stay the player's.** Nothing here
/// caches a number. D11 is why: IESDP's copies of these files are per-game.
/// Its `weapprof.2da` is the **BG2:EE** one, whose Two-Weapon Style strref
/// resolves against a BG:EE talk table to a paragraph about temples — and a
/// real installation carries columns IESDP's has never heard of (`SHAMAN`,
/// `OHTYR`, `OHTEMPUS`). `carriesStrrefs` makes that rule checkable instead of
/// a paragraph.
///
/// ⚠️ **Tables the *data* names are deliberately absent.** `hpclass.2da`'s
/// `TABLE` column holds resrefs — `HPWAR`, `HPWIZ`, `HPFMT` — so which hit-die
/// table a class uses is data, not vocabulary. Only tables *the code* names
/// belong here.
library;

/// A rules table in the player's installation, named for what it answers.
enum GameTable {
  /// `abclasrq` — the ability minima a class or **kit** demands.
  ///
  /// A kit raises the bar where it has a row: an Abjurer needs Wisdom 15 where
  /// a plain Mage needs nothing.
  classAbilityMinima('abclasrq'),

  /// `abracead` — what a race adds to or takes from each rolled ability.
  racialAbilityAdjustments('abracead'),

  /// `abracerq` — the floor and ceiling each race allows per ability.
  ///
  /// ⚠️ **Not the class's minima**, which is [classAbilityMinima]. The name is
  /// one letter from it and answers a different question.
  raceAbilityBounds('abracerq'),

  /// `alignmnt` — which alignments a class or kit permits, as ones and zeros.
  ///
  /// ⚠️ **A kit governs where it has a row, not its class**: a Fighter may be
  /// any alignment and a Kensai may not be chaotic.
  alignmentsByClass('alignmnt'),

  /// `clastext` — the class names and descriptions, as strrefs.
  ///
  /// ⚠️ **Its names are TEMPLATES.** `FIGHTER` resolves to `<FIGHTERTYPE>` and
  /// `CLERIC_MAGE` to `Cleric / <MAGESCHOOL>`; the engine substitutes the kit,
  /// or the base class where there is none. Substitute *in place* — falling
  /// back to a derived name throws away the separator the row exists to carry.
  ///
  /// ⚠️ **And its `DESCSTR` is a rules source.** The description states, in the
  /// engine's own words, things no numeric table holds: "May Turn Undead", the
  /// backstab progression, and "May only become Proficient (one slot) in any
  /// weapon class". It is prose — show it and cross-check against it, never
  /// parse it into a lookup.
  ///
  /// ⚠️ **Two rows can share a `CLASSID`.** `FALLEN_CLERIC` carries the same id
  /// and the same "no kit" marker as `CLERIC` and sits later in the file, so a
  /// last-wins map puts "Fallen Cleric" on screen. The `FALLEN` column tells
  /// them apart.
  classText('clastext', carriesStrrefs: true),

  /// `clsrcreq` — which classes and kits each race may take.
  ///
  /// Also what *forces* a specialisation: the `GNOME` column allows exactly one
  /// mage school, `ILLUSIONIST`, which is why a Gnome Cleric/Mage is written
  /// with that kit though the game never asks for it.
  classesByRace('clsrcreq'),

  /// `hpclass` — which hit-die table each class and kit uses.
  ///
  /// ⚠️ **Kits do not follow their class**: `DWARVEN_DEFENDER` uses `HPBARB`
  /// where its Fighter base uses `HPWAR`. The tables it names are data and are
  /// not values of this enum.
  hitDieTableByClass('hpclass'),

  /// `intmod` — what Intelligence is worth, including the chance to learn a
  /// spell.
  intelligenceModifiers('intmod'),

  /// `kitlist` — every kit, with its name and description strrefs.
  kits('kitlist', carriesStrrefs: true),

  /// `lore` — Lore gained per level, per single class.
  ///
  /// ⚠️ **It has nine rows and not one of them is a kit**, so the walkthrough's
  /// claim that a Blade gets half Lore per level is stated by no table. Left
  /// open rather than written into code.
  ///
  /// A multi-class takes the **highest** of its classes, not the sum — settled
  /// 2026-08-11 by a Gnome Cleric/Illusionist the engine itself made.
  loreRate('lore'),

  /// `lorebon` — what an ability adds to Lore at display. Consulted twice, once
  /// for Intelligence and once for Wisdom.
  loreBonus('lorebon'),

  /// `mschool` — the magic schools.
  ///
  /// ⚠️ **The row's position IS the school number**; no column carries it.
  /// `None` is row 0 and `ABJURER` is 1, and a spell's `SPL` header stores
  /// exactly these numbers. Its one column is the strref of the message shown
  /// when magic of that school is dispelled.
  magicSchools('mschool', carriesStrrefs: true),

  /// `mxsplbrd` — a bard's memorisable spells per level.
  ///
  /// ⚠️ **It has no row 1**: a bard casts nothing at first level, and the
  /// absence is the answer rather than a gap.
  bardMemorisation('mxsplbrd'),

  /// `mxsplsrc` — a sorcerer's memorisable spells per level.
  sorcererMemorisation('mxsplsrc'),

  /// `mxsplwiz` — a wizard's memorisable spells per level.
  wizardMemorisation('mxsplwiz'),

  /// `profs` — how many proficiency pips a class has **to spend**.
  ///
  /// ⚠️ **Not [proficiencyRankCap].** This is the number of slots; that is how
  /// many may go into any one proficiency. Reading the wrong one of the two is
  /// a bug this project has already shipped. `FIRST_LEVEL` is 4 for a fighter
  /// and 1 for a mage, and `RATE` gives a slot every so many levels after.
  proficiencySlots('profs'),

  /// `profsmax` — the most pips one proficiency may hold, **by level**.
  ///
  /// ⚠️ **Not [proficiencySlots]**, and ⚠️ **not the whole cap either.** Its
  /// `FIRST_LEVEL` is `2` for every row in the file; the cap the engine applies
  /// is the *lower* of that and [weaponProficiencies]' class column, which
  /// gives a cleric or a thief **1**. Measured in game: a thief was refused a
  /// second pip with a slot still unspent.
  proficiencyRankCap('profsmax'),

  /// `racetext` — the race names, as strrefs.
  raceText('racetext', carriesStrrefs: true),

  /// `savecndh` — the Constitution bonus to saving throws for **dwarves and
  /// halflings**.
  ///
  /// Columned by Constitution rather than by level, 1 to 25, giving 0 up to 5,
  /// and improving death, wands and spells. ⚠️ **Not
  /// [savesConstitutionGnome]**,
  /// whose death row is all zeros — that difference is the only reason these
  /// are two files rather than one.
  savesConstitutionDwarfHalfling('savecndh'),

  /// `savecng` — the Constitution bonus to saving throws for **gnomes**.
  ///
  /// ⚠️ **Its `DEATH` row is all zeros.** A gnome's Constitution improves wands
  /// and spells only.
  savesConstitutionGnome('savecng'),

  /// `savemonk` — saving throws for a Monk.
  savesMonk('savemonk'),

  /// `saveprs` — saving throws for a Cleric or Druid.
  savesPriest('saveprs'),

  /// `saverog` — saving throws for a Thief or Bard.
  savesRogue('saverog'),

  /// `savewar` — saving throws for a Fighter, Paladin or Ranger.
  savesWarrior('savewar'),

  /// `savewiz` — saving throws for a Mage or Sorcerer.
  savesWizard('savewiz'),

  /// `skillbrd` — the Pick Pockets a bard gets without allocating it.
  bardSkills('skillbrd'),

  /// `skilldex` — what Dexterity adds to each thief skill at display.
  dexteritySkillBonus('skilldex'),

  /// `skillrac` — what a race adds to each thief skill at display.
  ///
  /// ⚠️ **This is the mechanism behind the "base scores" a class description
  /// claims.** The Thief's description lists 15% Pick Pockets, 10% Open Locks,
  /// 5% Find Traps, 10% Move Silently, 5% Hide in Shadows — which is this
  /// table's `HUMAN` row exactly. The prose is written for a human; nothing is
  /// stored until it is spent.
  racialSkillBonus('skillrac'),

  /// `skillrng` — the stealth a ranger gets without allocating it.
  ///
  /// ⚠️ **One number written twice.** The table gives only `MOVE_SILENTLY`, and
  /// the records hold the same value in Hide in Shadows.
  rangerSkills('skillrng'),

  /// `splsrckn` — how many spells a sorcerer knows per level.
  sorcererSpellsKnown('splsrckn'),

  /// `strmod` — what Strength is worth, to hit and to damage.
  strengthModifiers('strmod'),

  /// `strmodex` — the percentile rows, reached only at Strength **exactly 18**.
  ///
  /// A percentile stored beside a 17 is a leftover, not a modifier.
  exceptionalStrengthModifiers('strmodex'),

  /// `thac0` — the THAC0 progression, every class, levels 1 to 40.
  ///
  /// ⚠️ **A multi-class has a row of its own** — `FIGHTER_MAGE`, `CLERIC_MAGE`
  /// and the rest are all present — so nothing is composed from this table.
  thac0ByClass('thac0'),

  /// `thiefscl` — which thief skills a class or **kit** may allocate to.
  ///
  /// ⚠️ **Not [thiefSkillPoints]**, one letter away. This says a Fighter/Mage
  /// has none and that a Blade picks pockets at 50 where a Bard is 100.
  thiefSkillsByClass('thiefscl'),

  /// `thiefskl` — how many thief-skill points a class starts with, and gains.
  ///
  /// ⚠️ **Not [thiefSkillsByClass]**, one letter away. Reading either alone
  /// gives a Thief 40 points and nowhere to put them, or seven skills and
  /// nothing to spend.
  thiefSkillPoints('thiefskl'),

  /// `weapprof` — every weapon proficiency and fighting style, with the most
  /// pips each class or kit column permits.
  ///
  /// ⚠️ **D11's own example.** IESDP ships BG2:EE's copy, whose strref for
  /// Two-Weapon Style reads as tutorial prose in a BG:EE talk table. Read the
  /// player's.
  ///
  /// ⚠️ **The `ID` column is the key, not the row label** — BG:EE labels two
  /// rows `AXE` and two `SPEAR`, one obsolete and one live.
  ///
  /// ⚠️ **The class column is a cap and `0` means "not this class".** A kit's
  /// column governs when the kit *is* the whole class — `SWASHBUCKLER` is 2
  /// where `THIEF` is 1 — but a multi-class uses its class column:
  /// `ILLUSIONIST` is 0 for War Hammer where `CLERIC_MAGE` is 1, and the engine
  /// gives a Gnome Cleric/Illusionist the hammer.
  weaponProficiencies('weapprof', carriesStrrefs: true),

  /// `dexmod` — Dexterity to armour class. **Generated from IESDP.**
  dexterityArmourClass('dexmod'),

  /// `hpconbon` — Constitution to hit points per level. **Generated from
  /// IESDP.**
  ///
  /// ⚠️ Its `WARRIOR` column is reached by **containment**, not by exact class:
  /// half a fighter is a warrior, confirmed by the engine printing
  /// `Bonus Hit Points/Level: +4` for a Fighter/Mage at Constitution 18.
  constitutionHitPoints('hpconbon');

  const GameTable(this.resref, {this.carriesStrrefs = false});

  /// The file name, without extension, as `chitin.key` indexes it.
  final String resref;

  /// Whether any column of this table holds a **strref** rather than a number.
  ///
  /// ⚠️ **D11, made checkable.** A number means the same thing in every game;
  /// a strref indexes a particular talk table and means nothing in another. So
  /// a table may be baked from IESDP, or it may carry strrefs, and never both —
  /// which is exactly what `game_tables_test.dart` asserts over
  /// [generatedFromIesdp].
  final bool carriesStrrefs;

  /// The two tables `tool/gen/generate_rules.dart` transcribes from IESDP.
  ///
  /// Both are pure numbers, which is the only reason baking them is safe. Every
  /// other table here is read from the player's own installation at run time.
  static const List<GameTable> generatedFromIesdp = [
    dexterityArmourClass,
    constitutionHitPoints,
  ];
}
