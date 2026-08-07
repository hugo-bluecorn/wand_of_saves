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

/// Turns savegame bytes into the party the UI reads.
///
/// A free function rather than a repository method because it is **pure** and
/// wanted in two places: the repository projects a savegame it has just read
/// from disk, and an editor projects one it has just patched in memory. Both
/// must produce the same characters from the same bytes, so there is one
/// implementation.
library;

import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/domain/ability_scores.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/save_slot.dart';

/// Prefix of the party portraits the game writes beside each savegame.
///
/// One per party slot — `PORTRT0.bmp` … `PORTRT5.bmp`, 54×84 and 24-bit.
/// **Not documented by IESDP**; established by inspecting real save
/// directories, which is why a missing file degrades to no portrait rather
/// than being treated as an error.
const String portraitPrefix = 'PORTRT';

/// Suffix of the party portraits. `dart:ui` decodes BMP natively, so these
/// need no decoder of their own.
const String portraitSuffix = '.bmp';

/// The party in [gam], in array order, as domain models.
///
/// [Character.name] comes back **possibly empty** — the savegame carries a
/// name only for characters who have joined. Resolving the rest needs the talk
/// table, which is a different repository, and repositories must never be
/// aware of each other; that merge belongs upstream.
///
/// Throws [InfinityFormatException] if any creature record will not parse.
List<Character> charactersFrom(Gam gam, SaveSlot slot) => [
  for (final npc in gam.partyMembers) _characterFrom(npc, slot),
];

Character _characterFrom(GamNpc npc, SaveSlot slot) {
  final cre = CreCodec.decode(npc.creBytes, source: npc.creResref);
  final (first, second, third) = cre.levels;

  return Character(
    name: npc.displayName,
    nameStrref: cre.longNameStrref,
    creResref: npc.creResref,
    partyOrder: npc.partyOrder,
    structOffset: npc.structOffset,
    creOffset: npc.creOffset,
    creLength: npc.creLength,
    currentHitPoints: cre.currentHitPoints,
    maximumHitPoints: cre.maximumHitPoints,
    experience: cre.experience,
    gold: cre.gold,
    thac0: cre.thac0,
    armorClass: cre.armorClass,
    armorClassNatural: cre.armorClassNatural,
    levelFirstClass: first,
    levelSecondClass: second,
    levelThirdClass: third,
    reputation: cre.reputation,
    abilities: AbilityScores(
      strength: cre.strength,
      strengthBonus: cre.strengthBonus,
      dexterity: cre.dexterity,
      constitution: cre.constitution,
      intelligence: cre.intelligence,
      wisdom: cre.wisdom,
      charisma: cre.charisma,
    ),
    portraitPath: _portraitFor(npc.partyOrder, slot),
  );
}

/// The portrait file for the character in party slot [partyOrder].
///
/// **The index mapping is unverified.** Every save on the developer's machine
/// holds a one-character party, where party order and array index are both `0`
/// and therefore indistinguishable — the same blind spot that hid the spike's
/// stride of −180. Party order is the reading that matches what the files are
/// for; a save that disagrees loses a picture and nothing more, because an
/// absent file is `null` rather than an error.
String? _portraitFor(int partyOrder, SaveSlot slot) {
  if (partyOrder == Character.notInParty) return null;
  final file = File(
    '${slot.path}${Platform.pathSeparator}'
    '$portraitPrefix$partyOrder$portraitSuffix',
  );
  return file.existsSync() ? file.path : null;
}
