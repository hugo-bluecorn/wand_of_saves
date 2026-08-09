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

/// Turns savegame and character-file bytes into the characters the UI reads.
///
/// Free functions rather than repository methods because they are **pure** and
/// wanted in several places: the savegame repository projects a file it has
/// just read from disk, an editor projects one it has just patched in memory,
/// and the character-file repository projects a record with no savegame around
/// it at all. All must produce the same character from the same record, so
/// there is one implementation — [characterFrom] — and everything else feeds
/// it.
library;

import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/domain/ability_scores.dart';
import 'package:wand_of_saves/domain/armor_class_modifiers.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/proficiency.dart';
import 'package:wand_of_saves/domain/resistances.dart';
import 'package:wand_of_saves/domain/save_slot.dart';
import 'package:wand_of_saves/domain/saving_throws.dart';
import 'package:wand_of_saves/domain/thief_skills.dart';

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

Character _characterFrom(GamNpc npc, SaveSlot slot) => characterFrom(
  CreCodec.decode(npc.creBytes, source: npc.creResref),
  name: npc.displayName,
  creResref: npc.creResref,
  partyOrder: npc.partyOrder,
  structOffset: npc.structOffset,
  creOffset: npc.creOffset,
  creLength: npc.creLength,
  portraitPath: _portraitFor(npc.partyOrder, slot),
);

/// One creature record as the UI reads it, wherever it came from.
///
/// **The projection, with the savegame's contribution passed in rather than
/// looked up.** A `Gam` supplies a display name, a party order, two offsets
/// and a portrait sidecar; a `.chr` supplies none of those, and the record
/// itself is identical either way. Splitting it here is what lets one
/// character sheet serve both documents.
///
/// The savegame-shaped parameters all default to the "no savegame" answer, and
/// each is worth stating because a wrong default is silent:
///
/// - [partyOrder] defaults to [Character.notInParty]. Defaulting it to `0`
///   would make a lone exported character look like the protagonist of a save.
/// - [structOffset] defaults to `0`, which is not a position — an exported
///   character has no GAM NPC struct to have an offset into.
/// - [creOffset] is where the record sits **in the file it came from**: an
///   absolute position in a savegame, and the CHR header's own offset in a
///   `.chr`. Edits are addressed by it, so it is required, never defaulted.
/// - [portraitPath] defaults to `null`. A `.chr` has no `PORTRT<n>.bmp` beside
///   it; its picture comes from the resrefs the record names.
///
/// [name] comes back **possibly empty** for a savegame — see [charactersFrom].
/// For a `.chr` it is the CHR header's own 32-byte name, which is the only name
/// an exported character has.
Character characterFrom(
  Cre cre, {
  required String name,
  required String creResref,
  required int creOffset,
  required int creLength,
  int partyOrder = Character.notInParty,
  int structOffset = 0,
  String? portraitPath,
}) {
  final (first, second, third) = cre.levels;
  final saves = cre.savingThrows;
  final resists = cre.resistances;
  final skills = cre.thiefSkills;
  final modifiers = cre.armorClassModifiers;

  return Character(
    name: name,
    nameStrref: cre.longNameStrref,
    creResref: creResref,
    partyOrder: partyOrder,
    structOffset: structOffset,
    creOffset: creOffset,
    creLength: creLength,
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
    classId: cre.classId,
    raceId: cre.raceId,
    alignmentId: cre.alignmentId,
    genderId: cre.genderId,
    kitId: cre.kitId,
    abilities: AbilityScores(
      strength: cre.strength,
      strengthBonus: cre.strengthBonus,
      dexterity: cre.dexterity,
      constitution: cre.constitution,
      intelligence: cre.intelligence,
      wisdom: cre.wisdom,
      charisma: cre.charisma,
    ),
    savingThrows: SavingThrows(
      death: saves.death,
      wands: saves.wands,
      polymorph: saves.polymorph,
      breath: saves.breath,
      spells: saves.spells,
    ),
    resistances: Resistances(
      fire: resists.fire,
      cold: resists.cold,
      electricity: resists.electricity,
      acid: resists.acid,
      magic: resists.magic,
      magicFire: resists.magicFire,
      magicCold: resists.magicCold,
      slashing: resists.slashing,
      crushing: resists.crushing,
      piercing: resists.piercing,
      missile: resists.missile,
    ),
    thiefSkills: ThiefSkills(
      hideInShadows: skills.hideInShadows,
      detectIllusion: skills.detectIllusion,
      setTraps: skills.setTraps,
      lore: skills.lore,
      lockpicking: skills.lockpicking,
      moveSilently: skills.moveSilently,
      findTraps: skills.findTraps,
      pickPockets: skills.pickPockets,
    ),
    armorClassModifiers: ArmorClassModifiers(
      crushing: modifiers.crushing,
      missile: modifiers.missile,
      piercing: modifiers.piercing,
      slashing: modifiers.slashing,
    ),
    numberOfAttacks: cre.numberOfAttacks,
    morale: cre.morale,
    moraleBreak: cre.moraleBreak,
    luck: cre.luck,
    fatigue: cre.fatigue,
    intoxication: cre.intoxication,
    turnUndeadLevel: cre.turnUndeadLevel,
    trackingSkill: cre.trackingSkill,
    proficiencies: [
      for (final effect in cre.effects)
        if (effect.isProficiency)
          Proficiency(
            id: effect.parameter2,
            pips: effect.parameter1,
            effectOffset: effect.start,
          ),
    ],
    portraitPath: portraitPath,
    portraitBaseName: _baseNameOf(cre.portraitMedium),
  );
}

/// A portrait resref with its variant letter removed.
///
/// `BDTMIM` gives `BDTMI`. ⚠️ **Only when the record actually names one**: an
/// empty resref stays empty rather than becoming a stray letter, and a resref
/// that does not end in a variant letter is left alone — six of the game's own
/// 210 portraits are not part of an `L`/`M`/`S` triple at all.
String _baseNameOf(String resref) {
  if (resref.isEmpty) return '';
  final last = resref[resref.length - 1].toUpperCase();
  return last == 'M' || last == 'L' || last == 'S'
      ? resref.substring(0, resref.length - 1)
      : resref;
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
