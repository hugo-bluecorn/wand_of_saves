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

import 'package:wand_of_saves/domain/rules/identifiers.g.dart';
import 'package:wand_of_saves/domain/rules/modifiers.g.dart';

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
}

/// [GameRules] backed by the tables generated from IESDP.
class GeneratedGameRules implements GameRules {
  /// Creates the rules.
  const GeneratedGameRules();

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
  static const Set<String> warriorRoots = {'FIGHTER', 'PALADIN', 'RANGER'};

  @override
  String? classIdentifier(int id) => classIdentifiers[id];

  @override
  String? raceIdentifier(int id) => raceIdentifiers[id];

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
    return bare == null ? null : _words(bare).join(' ');
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
    final identifier = classIdentifier(id);
    return identifier?.split('_').length;
  }

  @override
  String? className(int id) {
    final identifier = classIdentifier(id);
    // A multi-class is one identifier with underscores, and the game renders
    // it with slashes: FIGHTER_MAGE is "Fighter / Mage".
    return identifier == null ? null : _words(identifier).join(' / ');
  }

  @override
  String? raceName(int id) {
    final identifier = raceIdentifier(id);
    if (identifier == null) return null;
    // Races hyphenate where classes separate, and HALFORC has no underscore
    // to work from at all — so the two that need it are named outright rather
    // than guessed at by a rule that would get one of them wrong.
    return const {'HALF_ELF': 'Half-Elf', 'HALFORC': 'Half-Orc'}[identifier] ??
        _words(identifier).join(' ');
  }

  @override
  String? alignmentName(int id) {
    final identifier = alignmentIdentifier(id);
    return identifier == null ? null : _words(identifier).join(' ');
  }

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
    final entry = classHitDice[classIdentifier];
    if (entry == null || level < 1) return null;
    final (die, afterNine) = entry;
    final rolled = level < lastRollingLevel ? level : lastRollingLevel;
    return die * rolled + afterNine * (level - rolled);
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
