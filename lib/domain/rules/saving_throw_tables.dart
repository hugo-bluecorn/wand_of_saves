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
import 'package:wand_of_saves/domain/saving_throws.dart';

part 'saving_throw_tables.mapper.dart';

/// The game's saving-throw progressions — **data, no behaviour**.
///
/// Five tables in the installation, one per class group: `savewar`, `savewiz`,
/// `saveprs`, `saverog` and `savemonk`. Each is five rows — `DEATH`, `WANDS`,
/// `POLY`, `BREATH`, `SPELL` — by forty level columns.
///
/// ⚠️ **Nothing in the installation maps a class to its table**, unlike
/// `hpclass.2da` for hit dice. That mapping is a written rule; see
/// `GeneratedGameRules.savingThrowTableFor` for what was checked.
///
/// ⚠️ **And there is no written-out fallback for a machine with no game.** That
/// is a deliberate difference from `HitDieTables`: five tables of forty levels
/// copied by hand is exactly the shape of transcription that goes stale, and
/// D14 makes these fields authored — a wrong value here would be written into a
/// character and kept by the engine for the whole game.
@MappableClass()
class SavingThrowTables with SavingThrowTablesMappable {
  /// Records what the tables said.
  const SavingThrowTables({this.rowsByTable = const {}});

  /// Nothing read — no installation, or files that would not parse.
  static const SavingThrowTables empty = SavingThrowTables();

  /// Table name to category to values, level 1 first.
  ///
  /// Keyed as the tables name themselves, uppercased: `SAVEWAR`, `DEATH`.
  final Map<String, Map<String, List<int>>> rowsByTable;

  /// The `DEATH` row's label in every one of these tables.
  static const String deathRow = 'DEATH';

  /// The `WANDS` row's label.
  static const String wandsRow = 'WANDS';

  /// The polymorph row's label. ⚠️ **`POLY`, not `POLYMORPH`.**
  static const String polymorphRow = 'POLY';

  /// The breath-weapon row's label.
  static const String breathRow = 'BREATH';

  /// The spell row's label. ⚠️ **`SPELL` singular.**
  static const String spellsRow = 'SPELL';

  /// Every row this reads, in the order the tables list them.
  static const List<String> rows = [
    deathRow,
    wandsRow,
    polymorphRow,
    breathRow,
    spellsRow,
  ];

  /// What [table] gives at [level], or `null` when it cannot say.
  ///
  /// **The last row governs every level past the end**, which is what the
  /// tables themselves imply: their tails are a repeated constant. A level
  /// below 1 is not a level, and answers nothing.
  SavingThrows? at({required String table, required int level}) =>
      _column(table: table, at: level);

  /// The racial bonus [table] grants at [constitution], or `null`.
  ///
  /// The same lookup as [at] against a different kind of table: `savecndh` and
  /// `savecng` are columned by Constitution rather than by level. Named apart
  /// so a call site cannot read as though a Constitution were a level.
  ///
  /// ⚠️ **The values are a bonus to subtract, not a saving throw.** Lower is
  /// better, so a `3` here improves a save by three.
  SavingThrows? bonusAt({required String table, required int constitution}) =>
      _column(table: table, at: constitution);

  SavingThrows? _column({required String table, required int at}) {
    if (at < 1) return null;
    final rows = rowsByTable[table.toUpperCase()];
    if (rows == null) return null;

    int? value(String row) {
      final values = rows[row];
      if (values == null || values.isEmpty) return null;
      return values[at <= values.length ? at - 1 : values.length - 1];
    }

    final death = value(deathRow);
    final wands = value(wandsRow);
    final polymorph = value(polymorphRow);
    final breath = value(breathRow);
    final spells = value(spellsRow);
    if (death == null ||
        wands == null ||
        polymorph == null ||
        breath == null ||
        spells == null) {
      return null;
    }
    return SavingThrows(
      death: death,
      wands: wands,
      polymorph: polymorph,
      breath: breath,
      spells: spells,
    );
  }

  /// Whether anything at all was read.
  bool get isEmpty => rowsByTable.isEmpty;
}
