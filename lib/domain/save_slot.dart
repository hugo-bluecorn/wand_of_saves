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

part 'save_slot.mapper.dart';

/// A savegame on disk, summarised for the browser.
///
/// Immutable, with value equality from `dart_mappable` (D9) — the viewmodel
/// holds a list of these, and identity equality would make every refresh look
/// like a change and rebuild the whole grid.
///
/// The screenshot is a **path, not bytes**: `Image.file` then gets Flutter's
/// image cache for free, and a 130 KB bitmap per slot never sits in the model.
@MappableClass()
class SaveSlot with SaveSlotMappable {
  /// Creates a summary of one save slot.
  const SaveSlot({
    required this.directoryName,
    required this.path,
    required this.area,
    required this.gameTime,
    required this.partySize,
    required this.gold,
    required this.modified,
    this.screenshotPath,
  });

  /// The slot directory's name, e.g. `000000022-last`.
  final String directoryName;

  /// Absolute path to the slot directory.
  final String path;

  /// Resref of the area the party is in, e.g. `AR2600`.
  final String area;

  /// Elapsed game time in engine units; 300 is one in-game hour.
  final int gameTime;

  /// Number of characters in the party.
  final int partySize;

  /// Shared party gold.
  final int gold;

  /// When the savegame was last written.
  final DateTime modified;

  /// Path to `BALDUR.bmp`, the screenshot taken when the game was saved.
  ///
  /// `null` if the slot has none — old or hand-made saves sometimes do not.
  final String? screenshotPath;

  /// The human-chosen part of [directoryName], e.g. `last`.
  ///
  /// BG:EE names slots `<nine digits>-<label>`. The digits are an index the
  /// player never sees, so showing them would be showing plumbing.
  String get label => labelOf(directoryName);

  /// The human-chosen part of [directoryName], without needing a loaded slot.
  ///
  /// ⚠️ **A static because the rule is needed before there is anything to
  /// load.** The party shell titles itself from the route parameter while the
  /// savegame is being read, and that parameter is the raw directory name — so
  /// opening a save flashed `000000022-last` for a frame before settling on
  /// `last`. The rule above says the digits are plumbing; the loading state has
  /// to obey it too.
  static String labelOf(String directoryName) {
    final dash = directoryName.indexOf('-');
    return dash == -1 ? directoryName : directoryName.substring(dash + 1);
  }

  /// Elapsed in-game time in hours.
  double get hoursPlayed => gameTime / 300;
}
