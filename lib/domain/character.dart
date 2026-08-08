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

import 'package:dart_mappable/dart_mappable.dart';
import 'package:wand_of_saves/domain/ability_scores.dart';

part 'character.mapper.dart';

/// One member of the party, as the UI sees them.
///
/// The domain projection of a GAM NPC struct plus its embedded CRE, built by
/// `SaveGameRepository` so no `infinity_formats` type reaches the UI layer.
///
/// Immutable, with `copyWith`, `==` and `hashCode` from `dart_mappable` (D9).
/// The edit commands that arrive with stat editing rebuild a character rather
/// than mutating one, and a field forgotten in a hand-written `copyWith` is
/// exactly how a save ends up silently wrong.
///
/// **It carries its position in the file** — see [structOffset] and
/// [creOffset]. A character is addressed by where they are, not by their name:
/// two party members may legitimately share one.
@MappableClass()
class Character with CharacterMappable {
  /// Creates a character.
  const Character({
    required this.name,
    required this.nameStrref,
    required this.creResref,
    required this.partyOrder,
    required this.structOffset,
    required this.creOffset,
    required this.creLength,
    required this.currentHitPoints,
    required this.maximumHitPoints,
    required this.experience,
    required this.gold,
    required this.thac0,
    required this.armorClass,
    required this.armorClassNatural,
    required this.levelFirstClass,
    required this.levelSecondClass,
    required this.levelThirdClass,
    required this.reputation,
    required this.classId,
    required this.raceId,
    required this.alignmentId,
    required this.genderId,
    required this.kitId,
    required this.abilities,
    this.portraitPath,
  });

  /// The party order value meaning "not in the party".
  static const int notInParty = 0xFFFF;

  /// The player-visible name.
  ///
  /// **May be empty as the repository builds it.** The GAM struct carries the
  /// name for characters who have joined the party; the 36 companions waiting
  /// to be recruited carry an empty one, and their name has to be resolved
  /// from [nameStrref]. Filling that in needs the talk table, which is a
  /// different repository — so the merge happens above this layer.
  final String name;

  /// Strref of this character's name in `dialog.tlk`, or `-1` if there is none.
  ///
  /// `-1` for the protagonist: their name was typed by the player and cannot
  /// be in a file shipped with the game.
  final int nameStrref;

  /// Resref of the creature record, e.g. `*HARBASE`.
  ///
  /// The last-resort name. It is not a name, but it is information, which
  /// beats inventing placeholder text.
  final String creResref;

  /// Position in the party, or [notInParty].
  final int partyOrder;

  /// Byte offset of this character's GAM NPC struct from the start of the save.
  final int structOffset;

  /// Byte offset of this character's embedded CRE from the start of the save.
  final int creOffset;

  /// Size in bytes of the embedded CRE.
  final int creLength;

  /// Current hit points.
  final int currentHitPoints;

  /// Maximum hit points.
  final int maximumHitPoints;

  /// Experience points.
  final int experience;

  /// Gold this character carries personally, not the shared party purse.
  final int gold;

  /// THAC0 — "to hit armour class 0". Lower is better.
  final int thac0;

  /// Effective armour class — what they actually defend at, equipment
  /// included. Lower is better, and it goes negative.
  ///
  /// **The engine's to compute, not ours to set.** Equipping armour changes
  /// it, so it is shown and never edited; [armorClassNatural] is the authored
  /// half.
  final int armorClass;

  /// Natural armour class — the character's own, before anything is worn.
  final int armorClassNatural;

  /// Level in the first class slot.
  final int levelFirstClass;

  /// Level in the second class slot; `0` when single-classed.
  final int levelSecondClass;

  /// Level in the third class slot.
  final int levelThirdClass;

  /// Reputation as displayed, e.g. `11.0`. Stored in the file times ten.
  final double reputation;

  /// Class, as a `CLASS.IDS` number. `7` is `FIGHTER_MAGE`.
  ///
  /// The number rather than the name: naming it takes the game's own
  /// identifier tables, which is the rules layer's job, not the model's.
  final int classId;

  /// Race, as a `RACE.IDS` number. `2` is `ELF`.
  final int raceId;

  /// Alignment, as an `ALIGNMEN.IDS` number. `0x21` is `NEUTRAL_GOOD`.
  final int alignmentId;

  /// Gender, as a `GENDER.IDS` number. `1` is `MALE`.
  final int genderId;

  /// Kit, as the dword the creature record stores — **not** a `KIT.IDS` key.
  ///
  /// Carried raw because the relationship between the two is not understood:
  /// a character with no kit stores `0x40000000`, and shifting that right by
  /// 16 lands on `KIT.IDS`'s first entry rather than on any "no kit" row. Kept
  /// so the question can be answered later without another format change.
  final int kitId;

  /// The six ability scores.
  final AbilityScores abilities;

  /// Path to this character's portrait, or `null` if the save has none.
  final String? portraitPath;

  /// Whether this character is in the party.
  bool get isInParty => partyOrder != notInParty;

  /// Levels in every class this character has, in slot order.
  ///
  /// A multi-classed character carries a level in more than one slot; unused
  /// slots hold `0` and are dropped here rather than shown as "level 0".
  List<int> get levels => [
    levelFirstClass,
    levelSecondClass,
    levelThirdClass,
  ].where((level) => level > 0).toList();

  /// Levels as the game writes them — `1` single-classed, `1/1` multi-classed.
  String get levelLabel => levels.isEmpty ? '—' : levels.join('/');
}
