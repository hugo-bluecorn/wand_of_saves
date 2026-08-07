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

import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/ability_scores.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/save_slot.dart';

/// Source of truth for savegames.
///
/// An interface so `ProviderScope(overrides:)` can substitute a fake — which
/// is why ViewModels talk to this and never to `infinity_formats` directly.
abstract interface class SaveGameRepository {
  /// Every readable save slot, newest first.
  Future<List<SaveSlot>> listSlots();

  /// The slot whose directory is named [directoryName], or `null`.
  ///
  /// The route carries a directory name rather than a `SaveSlot`, so that a
  /// reload resolves to the same save instead of losing it.
  Future<SaveSlot?> slotNamed(String directoryName);

  /// Loads the full savegame behind [slot].
  ///
  /// Separate from [listSlots] because the browser only needs a summary, and
  /// reading every 96 KB savegame to draw a grid of cards would be wasteful.
  ///
  /// Throws [InfinityFormatException] if the file will not parse — unlike
  /// listing, a save the user explicitly chose should fail loudly.
  Future<Gam> load(SaveSlot slot);

  /// The party in [slot], in array order, as domain models.
  ///
  /// Returning [Character] rather than the codec's own types is what keeps
  /// `infinity_formats` out of the UI layer: a ViewModel talks to this and
  /// never to a `Gam`.
  ///
  /// [Character.name] comes back **possibly empty** — the savegame carries a
  /// name only for characters who have joined. Resolving the rest needs the
  /// talk table, which is a different repository, and repositories must never
  /// be aware of each other; that merge belongs upstream.
  ///
  /// Throws [InfinityFormatException] if the savegame or any of its creature
  /// records will not parse.
  Future<List<Character>> party(SaveSlot slot);
}

/// Reads savegames from the local filesystem.
class FileSaveGameRepository implements SaveGameRepository {
  /// Creates a repository over [profile]'s view of this machine.
  const FileSaveGameRepository({required this.profile});

  /// Locates the save directory. Repositories own no discovery of their own.
  final GameProfileService profile;

  /// The screenshot the game writes beside each savegame.
  static const String screenshotName = 'BALDUR.bmp';

  /// Prefix of the party portraits the game writes beside each savegame.
  ///
  /// One per party slot — `PORTRT0.bmp` … `PORTRT5.bmp`, 54×84 and 24-bit.
  /// **This is not documented by IESDP**; it was established by inspecting
  /// real save directories, which is why a missing file degrades to no
  /// portrait rather than being treated as an error.
  static const String portraitPrefix = 'PORTRT';

  /// Suffix of the party portraits. `dart:ui` decodes BMP natively, so these
  /// need no decoder of their own.
  static const String portraitSuffix = '.bmp';

  @override
  Future<List<SaveSlot>> listSlots() async {
    final root = profile.findSaveRoot();
    if (root == null) return const [];

    final slots = <SaveSlot>[];
    for (final directory in profile.slotsIn(root)) {
      final slot = await _readSlot(directory);
      // A slot that will not parse is skipped rather than failing the whole
      // listing: one damaged save should not hide the others.
      if (slot != null) slots.add(slot);
    }
    slots.sort((a, b) => b.modified.compareTo(a.modified));
    return slots;
  }

  @override
  Future<SaveSlot?> slotNamed(String directoryName) async {
    final root = profile.findSaveRoot();
    if (root == null) return null;

    final directory = profile
        .slotsIn(root)
        .where(
          (d) => d.path.split(Platform.pathSeparator).last == directoryName,
        )
        .firstOrNull;
    return directory == null ? null : _readSlot(directory);
  }

  @override
  Future<Gam> load(SaveSlot slot) async {
    final path =
        '${slot.path}${Platform.pathSeparator}${GameProfileService.saveMarker}';
    return GamCodec.decode(await File(path).readAsBytes(), source: path);
  }

  @override
  Future<List<Character>> party(SaveSlot slot) async {
    final gam = await load(slot);
    return [
      for (final npc in gam.partyMembers) _characterFrom(npc, slot),
    ];
  }

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
  /// **The index mapping is unverified.** Every save on the developer's
  /// machine holds a one-character party, where party order and array index
  /// are both `0` and therefore indistinguishable — the same blind spot that
  /// hid the spike's stride of −180. Party order is the reading that matches
  /// what the files are for; a save that disagrees loses a picture and nothing
  /// more, because an absent file is `null` rather than an error.
  String? _portraitFor(int partyOrder, SaveSlot slot) {
    if (partyOrder == Character.notInParty) return null;
    final file = File(
      '${slot.path}${Platform.pathSeparator}'
      '$portraitPrefix$partyOrder$portraitSuffix',
    );
    return file.existsSync() ? file.path : null;
  }

  Future<SaveSlot?> _readSlot(Directory directory) async {
    final separator = Platform.pathSeparator;
    final name = directory.path.split(separator).last;
    final gamFile = File(
      '${directory.path}$separator${GameProfileService.saveMarker}',
    );

    try {
      final gam = GamCodec.decode(
        await gamFile.readAsBytes(),
        source: gamFile.path,
      );
      final screenshot = File('${directory.path}$separator$screenshotName');

      return SaveSlot(
        directoryName: name,
        path: directory.path,
        area: gam.currentArea,
        gameTime: gam.gameTime,
        partySize: gam.partyNpcCount,
        gold: gam.partyGold,
        modified: gamFile.lastModifiedSync(),
        screenshotPath: screenshot.existsSync() ? screenshot.path : null,
      );
    } on InfinityFormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }
}
