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

import 'package:wand_of_saves/domain/rules/game_tables.dart';
import 'package:wand_of_saves/domain/rules/hit_die_tables.dart';
import 'package:wand_of_saves/domain/rules/identifiers.g.dart';
import 'package:wand_of_saves/domain/rules/modifiers.g.dart';
import 'package:wand_of_saves/domain/rules/name_tables.dart';
import 'package:wand_of_saves/domain/rules/rules_tables.dart';
import 'package:wand_of_saves/domain/rules/saving_throw_tables.dart';
import 'package:wand_of_saves/domain/rules/table_columns.dart';
import 'package:wand_of_saves/domain/saving_throws.dart';

/// What the game's own tables say.
///
/// A savegame stores numbers the engine modifies before showing them: hit
/// points and THAC0 are *bases*, and a class is a byte. This turns those into
/// what the player sees.
///
/// **An interface because the tables are a snapshot.** They are generated from
/// IESDP's copies of the shipped `2DA` and `IDS` files, which is right for an
/// unmodded install and wrong for a modded one. Phase 3's resource index can
/// implement this over the player's actual files with nothing above it
/// changing.
abstract interface class GameRules {
  /// The `CLASS.IDS` identifier for [id], e.g. `FIGHTER_MAGE`.
  String? classIdentifier(int id);

  /// The `RACE.IDS` identifier for [id], e.g. `ELF`.
  String? raceIdentifier(int id);

  /// The `CLASS.IDS` id for [identifier], e.g. `7` for `FIGHTER_MAGE`.
  ///
  /// The reverse of [classIdentifier], and it exists because the game's own
  /// rules tables are keyed by **name**: `clsrcreq.2da` labels its rows
  /// `FIGHTER_MAGE`, and storing a class needs the number.
  int? classIdFor(String identifier);

  /// The `RACE.IDS` id for [identifier], e.g. `2` for `ELF`.
  ///
  /// The reverse of [raceIdentifier]. ⚠️ **`clsrcreq.2da`'s columns use exactly
  /// this vocabulary** — including `HALFORC` with no underscore — where
  /// `racetext.2da` spells the same race `HALF_ORC`. That disagreement is why
  /// a race is matched here and joined to its text on the numeric id.
  int? raceIdFor(String identifier);

  /// The `ALIGNMEN.IDS` identifier for [id], e.g. `NEUTRAL_GOOD`.
  String? alignmentIdentifier(int id);

  /// The `GENDER.IDS` identifier for [id], e.g. `MALE`.
  String? genderIdentifier(int id);

  /// The `KIT.IDS` identifier for the dword [stored] at CRE `0x0244`.
  ///
  /// `null` when the character has no kit, which the engine writes two ways.
  String? kitIdentifier(int stored);

  /// [classIdentifier] as English, e.g. `Fighter / Mage`.
  String? className(int id);

  /// [raceIdentifier] as English, e.g. `Half-Elf`.
  String? raceName(int id);

  /// [alignmentIdentifier] as English, e.g. `Neutral Good`.
  String? alignmentName(int id);

  /// [genderIdentifier] as English, e.g. `Male`.
  String? genderName(int id);

  /// [kitIdentifier] as English, e.g. `Necromancer`, or `null` for no kit.
  String? kitName(int stored);

  /// The rules-table column that governs this character.
  ///
  /// `weapprof.2da` and `thiefscl.2da` are keyed by the same vocabulary —
  /// `CLASS.IDS` and kit identifiers — so one resolver serves both. This is a
  /// **lookup key, not a rendering**: `Fighter / Mage` finds nothing where
  /// `FIGHTER_MAGE` finds the column. `null` when the class cannot be named.
  String? classColumn({required int classId, required int kitId});

  /// Whether class [id] uses the warrior column of the hit-point table.
  bool isWarrior(int id);

  /// How many class-level slots class [id] actually uses, or `null` if the
  /// class is unknown.
  int? classCount(int id);

  /// The armour class modifier [dexterity] grants, or `null` off the table.
  ///
  /// Negative is better, as armour class runs downwards.
  int? armourClassFromDexterity(int dexterity);

  /// Hit points per level from [constitution], or `null` off the table.
  int? hitPointBonusPerLevel({
    required int constitution,
    required bool warrior,
  });

  /// The most hit points one class can have **rolled** by [level], before
  /// Constitution — or `null` for a class the tables do not name.
  ///
  /// [classIdentifier] is a single `CLASS.IDS` name such as `FIGHTER`, never a
  /// multi-class one: a `FIGHTER_MAGE` rolls its two halves separately, and
  /// composing them belongs to the caller.
  int? maximumRolledHitPoints(String classIdentifier, int level);

  /// The same for a whole character, composed across their classes.
  ///
  /// **Each class rolls its own die to its own level and the total is split
  /// between them**, rounded up. `null` when the tables cannot name a class or
  /// when the name and the level count disagree.
  int? maximumRolledHitPointsFor({
    required String classIdentifier,
    required List<int> levels,
  });

  /// Which saving-throw table one class uses, e.g. `savewiz` for a `MAGE`.
  ///
  /// [classIdentifier] is a single `CLASS.IDS` name. `null` when nothing names
  /// it.
  GameTable? savingThrowTableFor(String classIdentifier);

  /// The saving throws [classIdentifier] at [levels] should have.
  ///
  /// [levels] is one level per class, in the identifier's own order —
  /// `FIGHTER_MAGE` with `[3, 1]` is a Fighter 3 / Mage 1. `null` when the
  /// tables cannot answer, including when the two disagree about how many
  /// classes there are.
  ///
  /// ⚠️ **[raceIdentifier] and [constitution] are not decoration.** A dwarf,
  /// gnome or halfling takes a Constitution bonus of up to five on three of
  /// the five saves, so leaving them out is wrong rather than merely
  /// incomplete for three of the seven playable races.
  SavingThrows? savingThrowsFor({
    required String classIdentifier,
    required List<int> levels,
    String? raceIdentifier,
    int constitution = 0,
  });

  /// Which Constitution-bonus table a race uses, e.g. `savecng` for a gnome.
  ///
  /// `null` for the four races that take no such bonus.
  GameTable? racialSavingThrowTableFor(String raceIdentifier);

  /// The THAC0 [classIdentifier] at [levels] should have, or `null`.
  ///
  /// ⚠️ **A multi-class has a row of its own** — `thac0.2da` enumerates
  /// `FIGHTER_MAGE` and the rest — so nothing here is composed.
  int? thac0For({
    required String classIdentifier,
    required List<int> levels,
  });

  /// The Lore [classIdentifier] at [levels] should have, or `null`.
  ///
  /// `lore.2da` gives a rate per level for each single class.
  int? loreFor({required String classIdentifier, required List<int> levels});

  /// How many thief-skill points [classColumn] has to spend at first level.
  ///
  /// `null` for a class with no row, which is not the same as zero: a fighter
  /// is absent from the table because the question does not apply.
  int? thiefSkillPointsFor(String classColumn);

  /// What [ability] adds to Lore. `lorebon.2da`, consulted for Intelligence
  /// *and* Wisdom.
  int? loreBonusFor(int ability);

  /// What [dexterity] and [raceIdentifier] add to the thief skill [row].
  ///
  /// `skilldex.2da` and `skillrac.2da`. `null` when neither can answer, and a
  /// table that answers alone contributes on its own.
  int? thiefSkillBonusFor({
    required String row,
    required int dexterity,
    required String? raceIdentifier,
  });

  /// What [strength] takes off THAC0. `strmod.2da`, or `strmodex.2da` at 18.
  ///
  /// Positive is an improvement, because THAC0 runs downwards.
  int? strengthToHitFor({required int strength, required int percentile});

  /// The chance [intelligence] gives of learning a spell. `intmod.2da`.
  int? chanceToLearnSpellFor(int intelligence);

  /// The thief skills [classIdentifier] gets **without allocating them**.
  ///
  /// A ranger's stealth and a bard's pick pockets are fixed by level, not
  /// spent. Empty for every class that has neither.
  Map<String, int> fixedThiefSkillsFor({
    required String classIdentifier,
    required List<int> levels,
  });
}

/// [GameRules] backed by the tables generated from IESDP, plus whatever the
/// player's own installation could be read for.
///
/// ⚠️ **D13: a name comes from the game's table when there is one.** [tables]
/// carries `racetext`, `clastext` and `kitlist`; the derivations below are the
/// **fallback**, reachable only when nothing was read — which is a machine with
/// no game installed, where the app still has to open a savegame and name what
/// is in it.
class GeneratedGameRules implements GameRules {
  /// Creates the rules over the tables that could be read, each defaulting to
  /// nothing.
  const GeneratedGameRules({
    this.tables = NameTables.empty,
    this.hitDice = HitDieTables.empty,
    this.savingThrows = SavingThrowTables.empty,
    this.rulesTables = RulesTables.empty,
  });

  /// What the player's installation calls things. Data, separate from this.
  final NameTables tables;

  /// How many hit points each class gains per level. Data, separate from this.
  final HitDieTables hitDice;

  /// The five saving-throw progressions. Data, separate from this.
  final SavingThrowTables savingThrows;

  /// The game's other numeric tables — THAC0, Lore, skill points and the two
  /// fixed skill progressions. Data, separate from this.
  final RulesTables rulesTables;

  /// Class identifiers whose hit points come from the warrior column.
  ///
  /// From the ability chapter of Haeravon's walkthrough: the warrior bonus is
  /// for *"Fighters, Paladins, Rangers, and their kits"*. Matched by name
  /// rather than by number so the rule reads in the engine's own vocabulary,
  /// and by *containment* so every multi-class with a fighter in it — CLASS.IDS
  /// spells them `FIGHTER_MAGE`, `FIGHTER_THIEF` and so on — is covered too.
  ///
  /// **Verified in game 2026-08-08, and it was the last unmeasured rule here.**
  /// `hpconbon.2da`'s two columns are identical up to Constitution 16, so for
  /// a year of fixtures nothing could tell a warrior from anyone else. Raised
  /// to 18, a `FIGHTER_MAGE` made the engine print
  /// `Bonus Hit Points/Level: **+4**` — the warrior row. The other column
  /// reads 2 there, so the reading is unambiguous.
  ///
  /// It also confirms the *containment* rule rather than just the roots: Aard
  /// is half mage and still draws on the warrior column.
  ///
  /// ⚠️ **D13 — a rule, and here is why no table answers.** `hpconbon.2da` has
  /// the `WARRIOR` column but **nothing in the installation maps a class to
  /// it**; `hpclass.2da` maps classes to *hit-die* tables, which is a different
  /// question. Checked and rejected: `hpclass`, `hpconbon`, `clsrcreq`,
  /// `profs`. The rule stands because it is **measured** rather than reasoned.
  ///
  /// ⚠️ And it is known to be wrong in one direction that has not bitten yet:
  /// containment says a kit follows its class, and `hpclass` shows
  /// `DWARVEN_DEFENDER` breaking exactly that pattern for hit dice. If this is
  /// ever asked about a kit, measure first.
  static const Set<String> warriorRoots = {'FIGHTER', 'PALADIN', 'RANGER'};

  @override
  String? classIdentifier(int id) => classIdentifiers[id];

  @override
  String? raceIdentifier(int id) => raceIdentifiers[id];

  /// `CLASS.IDS` reversed. **Lowest id wins on a repeat**, which keeps the
  /// playable classes (1–21) ahead of the monster entries that start at 101.
  static final Map<String, int> _classIdsByName = _reverse(classIdentifiers);

  /// `RACE.IDS` reversed, on the same rule.
  static final Map<String, int> _raceIdsByName = _reverse(raceIdentifiers);

  static Map<String, int> _reverse(Map<int, String> byId) {
    final out = <String, int>{};
    for (final id in byId.keys.toList()..sort()) {
      out.putIfAbsent(byId[id]!, () => id);
    }
    return out;
  }

  @override
  int? classIdFor(String identifier) => _classIdsByName[identifier];

  @override
  int? raceIdFor(String identifier) => _raceIdsByName[identifier];

  @override
  String? alignmentIdentifier(int id) => alignmentIdentifiers[id];

  @override
  String? genderIdentifier(int id) => genderIdentifiers[id];

  /// The `KIT.IDS` name for a character with no kit at all.
  ///
  /// `KIT.IDS` numbers it `0x4000`, and numbers `MAGESCHOOL_GENERALIST` the
  /// same. `IdsMap.shadowed` keeps that second name rather than letting it
  /// displace this one, which is what it used to do.
  static const String noKitIdentifier = 'TRUECLASS';

  /// Where the `KIT.IDS` key sits inside the stored dword.
  ///
  /// Measured, not assumed: Xzar stores `0x10000000` and is a Necromancer,
  /// whose key is `0x1000`.
  static const int kitKeyShift = 16;

  /// Mage schools are stored under a prefixed name the game does not use.
  ///
  /// `MAGESCHOOL_NECROMANCER` is shown as `Necromancer`.
  static const String schoolPrefix = 'MAGESCHOOL_';

  @override
  String? kitIdentifier(int stored) => kitIdentifiers[stored >>> kitKeyShift];

  @override
  String? kitName(int stored) {
    // Two encodings mean the same thing. Aard and Montaron store 0x40000000,
    // Imoen stores 0, and the game shows no kit for any of the three.
    final bare = _kitColumn(stored);
    if (bare == null) return null;

    // ⚠️ **D13, and here the derivation is not merely clumsy but wrong.**
    // `kitlist.2da` names the Ranger's first kit `FERALAN`; the game draws
    // *Archer*. No amount of title-casing an identifier reaches that.
    return tables.kitNames[bare] ?? _words(bare).join(' ');
  }

  /// The kit identifier as `weapprof.2da` spells it, or `null` for no kit.
  ///
  /// The same `MAGESCHOOL_` strip [kitName] does, because the table's column
  /// is `NECROMANCER` where `KIT.IDS` says `MAGESCHOOL_NECROMANCER`.
  String? _kitColumn(int stored) {
    final identifier = kitIdentifier(stored);
    // Both encodings of "no kit" — TRUECLASS and plain zero — must fall
    // through to the class. Reading either as a column looks up a heading no
    // table has and caps every proficiency at nothing.
    if (identifier == null || identifier == noKitIdentifier) return null;
    return identifier.startsWith(schoolPrefix)
        ? identifier.substring(schoolPrefix.length)
        : identifier;
  }

  /// The kit's column if there is one, otherwise the class's.
  ///
  /// **A kit replaces the class here exactly as it replaces the name.** That
  /// is what kits are for in these tables: a Shadowdancer is a thief who
  /// cannot set traps and a Blade picks pockets at half a bard's rate, and
  /// neither is derivable from the base class.
  @override
  String? classColumn({required int classId, required int kitId}) =>
      _kitColumn(kitId) ?? classIdentifier(classId);

  @override
  int? classCount(int id) {
    // The bytes cannot answer this: a savegame leaves the unused level slots
    // holding 1 in every shipped NPC record and 0 in the player's own, so a
    // single-class Thief reads 1/1/1. Every playable CLASS.IDS name spells
    // its classes out -- FIGHTER_MAGE_THIEF is three -- so the name can.
    //
    // ⚠️ D13 — a rule, and no table answers it. Checked: `clsrcreq`, `profs`,
    // `hpclass`, `clastext`, `dualclas`. Each is *keyed* by the multi-class
    // name and none of them counts it. The identifier is the only source.
    final identifier = classIdentifier(id);
    return identifier?.split('_').length;
  }

  /// What the engine substitutes into `clastext.2da`'s own names.
  ///
  /// ⚠️ **The table's names are TEMPLATES, not names.** Resolved against the
  /// player's talk table, `FIGHTER` reads `<FIGHTERTYPE>` and `CLERIC_MAGE`
  /// reads `Cleric / <MAGESCHOOL>` — the engine fills each token with the
  /// character's kit, or with the base class where there is none. Ours had
  /// been drawing the tokens on the class-selection screen.
  ///
  /// Each token maps to a `CLASS.IDS` identifier rather than to a literal, so
  /// the word comes from the same derivation every other class name uses.
  static const Map<String, String> classNameTokens = {
    '<FIGHTERTYPE>': 'FIGHTER',
    '<MAGESCHOOL>': 'MAGE',
  };

  /// Whether [name] still holds a token nothing could fill in.
  static bool _hasToken(String name) => name.contains('<');

  @override
  String? className(int id) {
    final identifier = classIdentifier(id);
    // A multi-class is one identifier with underscores, and the game renders
    // it with slashes: FIGHTER_MAGE is "Fighter / Mage".
    final derived = identifier == null ? null : _words(identifier).join(' / ');

    // ⚠️ **D13: `clastext.2da`'s MIXED column already says it** — separator,
    // capitalisation and ordering included, in the player's language. The
    // derivation above is the no-installation fallback.
    final fromTable = tables.classNames[id];
    if (fromTable == null) return derived;

    // ⚠️ **Substituted in place, never swapped wholesale.** `Cleric /
    // <MAGESCHOOL>` has one real word in it, and the separator and ordering
    // are the table's — which is the whole reason to read it rather than
    // derive one. Falling back on any token would throw both away.
    var name = fromTable;
    for (final MapEntry(key: token, value: root) in classNameTokens.entries) {
      if (!name.contains(token)) continue;
      final word = _words(root).join();
      name = name.replaceAll(token, word);
    }

    // A token nothing filled in is one the engine knows and we do not. Drawing
    // it is worse than the derived name, which at least reads as English.
    return _hasToken(name) ? derived : name;
  }

  @override
  String? raceName(int id) {
    // ⚠️ **D13: `racetext.2da`'s UPPERCASE column holds `Half-Orc` outright.**
    // The map below existed because a word-splitter cannot reach that string;
    // keeping it as a fallback is only for a machine with no game installed.
    final fromTable = tables.raceNames[id];
    if (fromTable != null) return fromTable;

    final identifier = raceIdentifier(id);
    if (identifier == null) return null;
    return const {'HALF_ELF': 'Half-Elf', 'HALFORC': 'Half-Orc'}[identifier] ??
        _words(identifier).join(' ');
  }

  /// ⚠️ **D13 — derived, and no table was found.** `alignmnt.2da` is 1/0
  /// permissions with no names in it, and no `align*`-shaped table carries
  /// display strings. The alignment screen's own prose lives in the talk table
  /// with nothing tying a strref to an `ALIGNMEN.IDS` number. Unlike races and
  /// classes, this stays derived — and it will read only in English.
  @override
  String? alignmentName(int id) {
    final identifier = alignmentIdentifier(id);
    return identifier == null ? null : _words(identifier).join(' ');
  }

  /// ⚠️ **D13 — derived, and no table was found**, on the same search as
  /// [alignmentName]. `GENDER.IDS` has the two words and nothing names them.
  @override
  String? genderName(int id) {
    final identifier = genderIdentifier(id);
    return identifier == null ? null : _words(identifier).join(' ');
  }

  @override
  bool isWarrior(int id) {
    final identifier = classIdentifier(id);
    if (identifier == null) return false;
    return identifier.split('_').any(warriorRoots.contains);
  }

  @override
  int? armourClassFromDexterity(int dexterity) =>
      dexterityArmourClass[dexterity];

  @override
  int? hitPointBonusPerLevel({
    required int constitution,
    required bool warrior,
  }) => warrior
      ? constitutionHitPointsWarrior[constitution]
      : constitutionHitPointsOther[constitution];

  /// The die each class rolls, and what it gets instead once rolling stops.
  ///
  /// **Transcribed from the player's own installation, 2026-08-09**, because
  /// IESDP ships `hpclass.2da` but none of the per-class dice tables it points
  /// at — a gap the roadmap already recorded. `HPCLASS.2DA` maps every class
  /// to a table; each table gives `SIDES ROLLS MODIFIER` per level, rolling
  /// once through level 9 and granting a flat modifier from 10 on:
  ///
  /// | table | classes | die | from level 10 |
  /// |---|---|---|---|
  /// | `HPWAR` | Fighter, Ranger, Paladin | d10 | +3 |
  /// | `HPPRS` | Cleric, Druid, Monk | d8 | +2 |
  /// | `HPROG` | Thief, Bard | d6 | +2 |
  /// | `HPWIZ` | Mage, Sorcerer | d4 | +1 |
  /// | `HPBARB` | Barbarian | d12 | +3 |
  ///
  /// ⚠️ **`HPFM` and its multi-class siblings are deliberately absent.** The
  /// game maps `FIGHTER_MAGE` to `HPFM`, a pre-averaged `1d7`, and the engine
  /// measurably does not use it: an imported Fighter 2 / Mage 1 arrived with
  /// **12**, which is `HPWAR`×2 and `HPWIZ`×1 each halved, and a Fighter 1→2
  /// level-up stored **+5**, which is `HPWAR` halved. What `HPFM` is for is an
  /// open question in the findings.
  /// ⚠️ **The fallback, and it is measurably wrong past level 9.** It has every
  /// class stop rolling at 9; `hpwiz.2da` and `hprog.2da` roll through **11**,
  /// so a Mage 12 comes out 3 short and a Thief 12 four short. Kept only for a
  /// machine with no game installed, where a character sheet still has to draw
  /// and every fixture is level 1 or 2 anyway. **`hitDice` supersedes it.**
  static const Map<String, (int die, int afterNine)> classHitDice = {
    'FIGHTER': (10, 3),
    'RANGER': (10, 3),
    'PALADIN': (10, 3),
    'CLERIC': (8, 2),
    'DRUID': (8, 2),
    'MONK': (8, 2),
    'THIEF': (6, 2),
    'BARD': (6, 2),
    'MAGE': (4, 1),
    'SORCERER': (4, 1),
    'BARBARIAN': (12, 3),
  };

  /// The last level at which a class rolls a die rather than taking a flat
  /// modifier. Every table in the installation turns over at the same place.
  static const int lastRollingLevel = 9;

  @override
  int? maximumRolledHitPoints(String classIdentifier, int level) {
    if (level < 1) return null;

    // ⚠️ **D13: `hpclass.2da` names the table and `hp…2da` holds the rows.**
    // The written-out dice below are the no-installation fallback, and they are
    // known to be slightly wrong past level 9 — see [classHitDice].
    final rows = hitDice.rowsFor(classIdentifier);
    if (rows != null) {
      var total = 0;
      for (var each = 1; each <= level; each++) {
        // The last row governs every level past the end of the table.
        final row = rows[each <= rows.length ? each - 1 : rows.length - 1];
        total += row.sides * row.rolls + row.modifier;
      }
      return total;
    }

    final entry = classHitDice[classIdentifier];
    if (entry == null) return null;
    final (die, afterNine) = entry;
    final rolled = level < lastRollingLevel ? level : lastRollingLevel;
    return die * rolled + afterNine * (level - rolled);
  }

  @override
  int? maximumRolledHitPointsFor({
    required String classIdentifier,
    required List<int> levels,
  }) {
    final classes = classIdentifier.split('_');
    // A name and a slot count that disagree mean one of them is junk, and
    // inventing a ceiling from junk is worse than having none.
    if (classes.length != levels.length || classes.isEmpty) return null;

    var total = 0;
    for (var i = 0; i < classes.length; i++) {
      final own = maximumRolledHitPoints(classes[i], levels[i]);
      if (own == null) return null;
      total += own;
    }
    // **Rounded up.** A ceiling a point low refuses a value the game would
    // happily produce; a ceiling a point high merely fails to catch one
    // absurd value.
    return (total + classes.length - 1) ~/ classes.length;
  }

  /// Which saving-throw table each single class uses.
  ///
  /// ⚠️ **D13 — a written rule, and here is why no table answers.** `hpclass`
  /// does exactly this job for hit dice and `thac0.2da` enumerates the
  /// multi-classes outright, so a table was the first thing looked for.
  /// Checked and rejected: `hpclass`, `clsrcreq`, `profs`, `clastext`,
  /// `clasthac`, `classcat` — none names a `save…` file, and ⚠️ `savename.2da`
  /// is savegame *slot* names, a near name with nothing to do with saves. What
  /// states it is IESDP's prose on `savexxx.2da`, which lists the five tables
  /// and the classes each serves. Confirmed at level 1 against BG:EE's own
  /// Aurel, a `FIGHTER_MAGE`, whose five are `savewiz` verbatim.
  static const Map<String, GameTable> savingThrowTables = {
    'FIGHTER': GameTable.savesWarrior,
    'PALADIN': GameTable.savesWarrior,
    'RANGER': GameTable.savesWarrior,
    'MAGE': GameTable.savesWizard,
    'SORCERER': GameTable.savesWizard,
    'CLERIC': GameTable.savesPriest,
    'DRUID': GameTable.savesPriest,
    'THIEF': GameTable.savesRogue,
    'BARD': GameTable.savesRogue,
    'MONK': GameTable.savesMonk,
  };

  @override
  GameTable? savingThrowTableFor(String classIdentifier) =>
      savingThrowTables[classIdentifier];

  /// Which Constitution-bonus table each race uses.
  ///
  /// ⚠️ **D13 — a written rule, and the table names are what state it.**
  /// `savecndh` is Constitution / Dwarf-Halfling and `savecng` is
  /// Constitution / Gnome; there are exactly two such files in the
  /// installation and `racetext.2da` has no column naming either. **Measured,
  /// not read off the names**: KAGAIN (dwarf, Constitution 20) stores
  /// 9/11/15/17/12 where the class tables alone give 14/16/15/17/17, and ALORA
  /// (halfling, 12) and QUAYLE and TIAX (gnomes, 11 and 16) each land exactly
  /// on their table's row.
  ///
  /// The four races with no entry take nothing, which is why an elf, a human,
  /// a half-elf and a half-orc agree with the class tables untouched.
  static const Map<String, GameTable> racialSavingThrowTables = {
    'DWARF': GameTable.savesConstitutionDwarfHalfling,
    'HALFLING': GameTable.savesConstitutionDwarfHalfling,
    'GNOME': GameTable.savesConstitutionGnome,
  };

  @override
  GameTable? racialSavingThrowTableFor(String raceIdentifier) =>
      racialSavingThrowTables[raceIdentifier];

  @override
  SavingThrows? savingThrowsFor({
    required String classIdentifier,
    required List<int> levels,
    String? raceIdentifier,
    int constitution = 0,
  }) {
    final classes = classIdentifier.split('_');
    // The same refusal maximumRolledHitPoints makes: a name and a slot count
    // that disagree mean one of them is junk, and composing from junk is worse
    // than answering nothing.
    if (classes.length != levels.length) return null;

    final rows = <SavingThrows>[];
    for (var i = 0; i < classes.length; i++) {
      final table = savingThrowTableFor(classes[i]);
      if (table == null) return null;
      final row = savingThrows.at(table: table, level: levels[i]);
      if (row == null) return null;
      rows.add(row);
    }
    if (rows.isEmpty) return null;

    // ⚠️ **The best of each column, and each class read at its OWN level.**
    // Lower is better, so this is a minimum. **Measured**, not reasoned — see
    // `saving_throw_oracle_test.dart`. Aurel could not separate this from "the
    // caster's table wins", because at level 1 `savewar` is worse in all five
    // and a fighter multi-class gives the other table's row under either rule.
    // QUAYLE settles it: a Cleric/Mage 2/2, he stores the priest's death save
    // *and* the wizard's other four, which is a row neither table holds.
    final table = raceIdentifier == null
        ? null
        : racialSavingThrowTableFor(raceIdentifier);
    final bonus = table == null
        ? null
        : savingThrows.bonusAt(table: table, constitution: constitution);

    int best(int Function(SavingThrows) of) =>
        rows.map(of).reduce(_better) - (bonus == null ? 0 : of(bonus));

    return SavingThrows(
      death: best((r) => r.death),
      wands: best((r) => r.wands),
      polymorph: best((r) => r.polymorph),
      breath: best((r) => r.breath),
      spells: best((r) => r.spells),
    );
  }

  /// The better of two saving throws, which is the **lower**.
  static int _better(int a, int b) => a < b ? a : b;

  @override
  int? loreBonusFor(int ability) => rulesTables.at(
    table: GameTable.loreBonus,
    row: '$ability',
    column: TableColumn.value.header,
  );

  @override
  int? thiefSkillBonusFor({
    required String row,
    required int dexterity,
    required String? raceIdentifier,
  }) {
    final fromDexterity = rulesTables.at(
      table: GameTable.dexteritySkillBonus,
      row: '$dexterity',
      column: row,
    );
    final fromRace = raceIdentifier == null
        ? null
        : rulesTables.at(
            table: GameTable.racialSkillBonus,
            row: raceIdentifier,
            column: row,
          );
    // ⚠️ `null` only when *neither* answered. A machine with one table read
    // and not the other still has something true to say.
    if (fromDexterity == null && fromRace == null) return null;
    return (fromDexterity ?? 0) + (fromRace ?? 0);
  }

  @override
  int? strengthToHitFor({required int strength, required int percentile}) {
    // ⚠️ **Only a Strength of exactly 18 has a percentile.** The engine
    // consults `strmodex.2da` nowhere else, and a percentile stored beside a
    // 17 is a leftover rather than a modifier.
    if (strength == 18 && percentile > 0) {
      final exceptional = rulesTables.at(
        table: GameTable.exceptionalStrengthModifiers,
        row: '$percentile',
        column: TableColumn.toHit.header,
      );
      if (exceptional != null) return exceptional;
    }
    return rulesTables.at(
      table: GameTable.strengthModifiers,
      row: '$strength',
      column: TableColumn.toHit.header,
    );
  }

  @override
  int? chanceToLearnSpellFor(int intelligence) => rulesTables.at(
    table: GameTable.intelligenceModifiers,
    row: '$intelligence',
    column: TableColumn.learnSpell.header,
  );

  /// The value a table holds at the character's own level, with the last
  /// column governing anything past the end.
  ///
  /// The tables run to 40 and repeat their tails, exactly as the saving-throw
  /// and hit-die tables do, so out-levelling one is not a reason to answer
  /// nothing.
  int? _atLevel({
    required GameTable table,
    required String row,
    required int level,
  }) {
    if (level < 1) return null;
    for (var each = level; each >= 1; each--) {
      final value = rulesTables.at(
        table: table,
        row: row,
        column: '$each',
      );
      if (value != null) return value;
    }
    return null;
  }

  @override
  int? thac0For({
    required String classIdentifier,
    required List<int> levels,
  }) {
    if (levels.isEmpty) return null;
    // ⚠️ **The highest level, and it is NOT separated.** Every multi-class NPC
    // in the game is equal-levelled — Coran 3/3, Tiax 2/2, Quayle 2/2 — so
    // nothing measured says whether a Fighter 3 / Mage 1 reads column 3 or
    // column 1. The highest is what a single class reduces to, and it is the
    // reading that cannot make a character worse than one of their halves.
    final level = levels.reduce((a, b) => a > b ? a : b);
    return _atLevel(
      table: GameTable.thac0ByClass,
      row: classIdentifier,
      level: level,
    );
  }

  @override
  int? loreFor({required String classIdentifier, required List<int> levels}) {
    final classes = classIdentifier.split('_');
    if (classes.length != levels.length) return null;

    int? best;
    for (var i = 0; i < classes.length; i++) {
      final rate = rulesTables.at(
        table: GameTable.loreRate,
        row: classes[i],
        column: TableColumn.rate.header,
      );
      if (rate == null) continue;
      final own = rate * levels[i];
      if (best == null || own > best) best = own;
    }
    // ⚠️ **The highest, and the two candidate rules disagree.** The engine's
    // own recomputation stored **3** for a Fighter/Mage/Thief at 1/1/1, where
    // a sum gives 7 — so the engine says highest. The shipped NPC records read
    // like sums (Coran 12, Tiax 8, Quayle 8), and cannot referee it: the same
    // files hold a Fighter 1 with Lore 4 and a Mage 1 with Lore 0, which no
    // rule produces. Engine outranks table outranks file, so this follows the
    // engine and the disagreement is recorded in the findings.
    return best;
  }

  @override
  int? thiefSkillPointsFor(String classColumn) => rulesTables.at(
    table: GameTable.thiefSkillPoints,
    row: classColumn,
    column: TableColumn.startPoints.header,
  );

  /// The one column `skillrng.2da` has, and the second skill it also fills.
  ///
  /// ⚠️ **A ranger's stealth is one number written twice.** The table gives
  /// only `MOVE_SILENTLY`, and the records hold the same value in Hide in
  /// Shadows — Minsc at level 1 is 15/15 and Kivan at 2 is 21/21. Reading the
  /// table alone would leave every created ranger half-stealthy.
  static const String moveSilentlyColumn = 'MOVE_SILENTLY';

  /// The skill a ranger's `MOVE_SILENTLY` value is copied into.
  static const String hideInShadowsColumn = 'HIDE_IN_SHADOWS';

  /// The column `skillbrd.2da` has.
  static const String pickPocketsColumn = 'PICK_POCKETS';

  /// ⚠️ **These two tables are the other way up**: the level is the *row* and
  /// the skill is the column, where `thac0.2da` puts the level in the column.
  /// Reading one like the other silently answers nothing.
  int? _byLevelRow({
    required GameTable table,
    required int level,
    required String column,
  }) {
    if (level < 1) return null;
    for (var each = level; each >= 1; each--) {
      final value = rulesTables.at(
        table: table,
        row: '$each',
        column: column,
      );
      if (value != null) return value;
    }
    return null;
  }

  @override
  Map<String, int> fixedThiefSkillsFor({
    required String classIdentifier,
    required List<int> levels,
  }) {
    final classes = classIdentifier.split('_');
    if (classes.length != levels.length) return const {};

    final skills = <String, int>{};
    for (var i = 0; i < classes.length; i++) {
      // ⚠️ Each read at its OWN class's level: a Fighter 3 / Ranger 1 is a
      // level-1 ranger however good a fighter they are.
      switch (classes[i]) {
        case 'RANGER':
          final stealth = _byLevelRow(
            table: GameTable.rangerSkills,
            level: levels[i],
            column: moveSilentlyColumn,
          );
          if (stealth != null) {
            skills[moveSilentlyColumn] = stealth;
            skills[hideInShadowsColumn] = stealth;
          }
        case 'BARD':
          final pockets = _byLevelRow(
            table: GameTable.bardSkills,
            level: levels[i],
            column: pickPocketsColumn,
          );
          if (pockets != null) skills[pickPocketsColumn] = pockets;
      }
    }
    return skills;
  }

  /// `FIGHTER_MAGE` → `['Fighter', 'Mage']`.
  ///
  /// The identifiers are data; this rendering is ours, so it is convention
  /// rather than measurement — except where a screenshot confirms it, which
  /// covers `Fighter / Mage`, `Elf` and `Neutral Good`.
  static List<String> _words(String identifier) => [
    for (final part in identifier.split('_'))
      if (part.isNotEmpty)
        part[0].toUpperCase() + part.substring(1).toLowerCase(),
  ];
}
