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
import 'package:wand_of_saves/data/party_projection.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
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

  /// Writes [gam] over the savegame in [slot], keeping a `.bak`.
  ///
  /// The write is atomic — temporary file, then rename — so a reader, the game
  /// included, sees either the whole old save or the whole new one. For a file
  /// holding tens of hours of play, that is the difference between "unchanged"
  /// and "destroyed".
  Future<void> write(SaveSlot slot, Gam gam);
}

/// Reads savegames from the local filesystem.
class FileSaveGameRepository implements SaveGameRepository {
  /// Creates a repository over [profile]'s view of this machine.
  const FileSaveGameRepository({required this.profile});

  /// Locates the save directory. Repositories own no discovery of their own.
  final GameProfileService profile;

  /// The screenshot the game writes beside each savegame.
  static const String screenshotName = 'BALDUR.bmp';

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
  Future<List<Character>> party(SaveSlot slot) async =>
      charactersFrom(await load(slot), slot);

  @override
  Future<void> write(SaveSlot slot, Gam gam) => writeFileAtomically(
    '${slot.path}${Platform.pathSeparator}${GameProfileService.saveMarker}',
    GamCodec.encode(gam),
  );

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
