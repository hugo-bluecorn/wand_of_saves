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

/// Repository doubles substituted through `ProviderScope(overrides:)`.
///
/// That override is the testing seam the architecture exists to provide, and
/// it is why repositories are interfaces: a ViewModel test never touches the
/// filesystem or `infinity_formats`.
library;

import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/party_projection.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/repositories/save_game_repository.dart';
import 'package:wand_of_saves/data/repositories/string_repository.dart';
import 'package:wand_of_saves/domain/ability_scores.dart';
import 'package:wand_of_saves/domain/armor_class_modifiers.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/proficiency.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/domain/resistances.dart';
import 'package:wand_of_saves/domain/save_slot.dart';
import 'package:wand_of_saves/domain/saving_throws.dart';
import 'package:wand_of_saves/domain/thief_skills.dart';

/// A savegame repository answering from memory.
class FakeSaveGameRepository implements SaveGameRepository {
  /// Creates a repository over [slots], whose parties come from [parties].
  FakeSaveGameRepository({
    this.slots = const [],
    this.parties = const {},
    this.gam,
    this.failure,
  });

  /// The slots this repository reports, in the order given.
  List<SaveSlot> slots;

  /// Party members per slot directory name.
  ///
  /// Ignored when [gam] is set.
  Map<String, List<Character>> parties;

  /// A savegame to project the party from, instead of [parties].
  ///
  /// Set this when a test edits: the projection is the **real** one, so a
  /// patched savegame shows changed values. A canned list of characters could
  /// not, since nothing would connect an edit to what comes back.
  Gam? gam;

  /// Thrown by every method when set, so failure paths can be exercised.
  Exception? failure;

  /// How many times [listSlots] has been called.
  int listCalls = 0;

  @override
  Future<List<SaveSlot>> listSlots() async {
    listCalls++;
    if (failure != null) throw failure!;
    return slots;
  }

  @override
  Future<SaveSlot?> slotNamed(String directoryName) async {
    if (failure != null) throw failure!;
    return slots.where((s) => s.directoryName == directoryName).firstOrNull;
  }

  @override
  Future<List<Character>> party(SaveSlot slot) async {
    if (failure != null) throw failure!;
    final source = gam;
    if (source != null) return charactersFrom(source, slot);
    return parties[slot.directoryName] ?? const [];
  }

  @override
  Future<Gam> load(SaveSlot slot) async {
    if (failure != null) throw failure!;
    final source = gam;
    if (source == null) {
      throw StateError('this fake was not given a savegame to load');
    }
    return source;
  }

  /// Savegames handed to [write], newest last — so a test can assert what was
  /// saved without touching a filesystem.
  final List<Gam> written = [];

  @override
  Future<void> write(SaveSlot slot, Gam gam) async {
    if (failure != null) throw failure!;
    written.add(gam);
  }
}

/// A talk table answering from a map.
class FakeStringRepository implements StringRepository {
  /// Creates a repository over [strings], keyed by strref.
  FakeStringRepository([this.strings = const {}]);

  /// The strings this table holds.
  final Map<int, String> strings;

  /// Every strref looked up, in order — so a test can assert that a name
  /// already present in the savegame was *not* looked up.
  final List<int> lookups = [];

  @override
  Future<String?> lookup(int strref) async {
    lookups.add(strref);
    return strings[strref];
  }

  @override
  Future<void> close() async {}
}

/// A resource repository answering with a canned catalogue.
class FakeResourceRepository implements ResourceRepository {
  /// Creates a repository answering [catalogue].
  const FakeResourceRepository(this.catalogue);

  /// What every call returns.
  final ProficiencyCatalogue catalogue;

  @override
  Future<ProficiencyCatalogue> proficiencies() async => catalogue;
}

/// A save slot summary, with the fixture's values as defaults.
SaveSlot fakeSlot(String label) => SaveSlot(
  directoryName: '000000022-$label',
  path: '/tmp/$label',
  area: 'AR2600',
  gameTime: 4791,
  partySize: 1,
  gold: 161,
  modified: DateTime(2026),
);

/// A party member, with the fixture protagonist's values as defaults.
///
/// **Every default is Aard's, read off `000000100-Party` rather than chosen.**
/// That matters most for the parts a test is not looking at: a helper that
/// filled the saving throws or the proficiencies with plausible zeroes would
/// be asserting a shape no savegame has, under a doc comment claiming
/// otherwise.
Character fakeCharacter({
  String name = 'Aard',
  int nameStrref = -1,
  String creResref = '*HARBASE',
  int partyOrder = 0,
  int levelFirstClass = 1,
  int levelSecondClass = 1,
  int levelThirdClass = 0,
  int strength = 18,
  int strengthBonus = 100,
  int classId = 7,
  int kitId = 0x40000000,
  List<Proficiency> proficiencies = const [
    // Two-Weapon Style and Flail/Morning Star, at the offsets the fixture
    // holds them: Aard dual-wields a Battle Axe and a Flail +1.
    Proficiency(id: 114, pips: 2, effectOffset: 1340),
    Proficiency(id: 100, pips: 2, effectOffset: 1604),
  ],
  String? portraitPath,
}) => Character(
  name: name,
  nameStrref: nameStrref,
  creResref: creResref,
  partyOrder: partyOrder,
  structOffset: 180 + partyOrder * 352,
  creOffset: 532,
  creLength: 6780,
  currentHitPoints: 6,
  maximumHitPoints: 7,
  experience: 325,
  gold: 0,
  thac0: 20,
  armorClass: 10,
  armorClassNatural: 10,
  levelFirstClass: levelFirstClass,
  levelSecondClass: levelSecondClass,
  levelThirdClass: levelThirdClass,
  reputation: 11,
  classId: classId,
  raceId: 2,
  alignmentId: 0x21,
  genderId: 1,
  kitId: kitId,
  abilities: AbilityScores(
    strength: strength,
    strengthBonus: strengthBonus,
    dexterity: 17,
    constitution: 16,
    intelligence: 18,
    wisdom: 9,
    charisma: 9,
  ),
  // The same five the game printed on the record screen, and the one block of
  // the sheet the engine does not modify before showing it.
  savingThrows: const SavingThrows(
    death: 14,
    wands: 11,
    polymorph: 13,
    breath: 15,
    spells: 12,
  ),
  resistances: Resistances.none,
  // A Fighter/Mage has no thief skills; Lore every class has.
  thiefSkills: const ThiefSkills(
    hideInShadows: 0,
    detectIllusion: 0,
    setTraps: 0,
    lore: 3,
    lockpicking: 0,
    moveSilently: 0,
    findTraps: 0,
    pickPockets: 0,
  ),
  armorClassModifiers: ArmorClassModifiers.none,
  numberOfAttacks: 1,
  morale: 10,
  // 0 here and 1 for recovery is the *protagonist's* shape; every recruited
  // companion in the same save stores 4 or 5 and 60.
  moraleBreak: 0,
  luck: 0,
  fatigue: 3,
  intoxication: 0,
  turnUndeadLevel: 0,
  trackingSkill: 0,
  proficiencies: proficiencies,
  portraitPath: portraitPath,
);
