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

  /// [classIdentifier] as English, e.g. `Fighter / Mage`.
  String? className(int id);

  /// [raceIdentifier] as English, e.g. `Half-Elf`.
  String? raceName(int id);

  /// [alignmentIdentifier] as English, e.g. `Neutral Good`.
  String? alignmentName(int id);

  /// [genderIdentifier] as English, e.g. `Male`.
  String? genderName(int id);

  /// Whether class [id] uses the warrior column of the hit-point table.
  bool isWarrior(int id);

  /// The armour class modifier [dexterity] grants, or `null` off the table.
  ///
  /// Negative is better, as armour class runs downwards.
  int? armourClassFromDexterity(int dexterity);

  /// Hit points per level from [constitution], or `null` off the table.
  int? hitPointBonusPerLevel({
    required int constitution,
    required bool warrior,
  });
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
  /// **Unverified.** `hpconbon.2da`'s two columns are identical up to
  /// Constitution 16 and the only fixture has 16, so no save on this machine
  /// can tell a warrior from anyone else. A character with 17 or more would
  /// settle it.
  static const Set<String> warriorRoots = {'FIGHTER', 'PALADIN', 'RANGER'};

  @override
  String? classIdentifier(int id) => classIdentifiers[id];

  @override
  String? raceIdentifier(int id) => raceIdentifiers[id];

  @override
  String? alignmentIdentifier(int id) => alignmentIdentifiers[id];

  @override
  String? genderIdentifier(int id) => genderIdentifiers[id];

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
