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

import 'dart:convert';
import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';

/// Source of truth for the rules tables that live inside the game's archives.
///
/// **Why this exists when there is already a generated rules layer.** D9 reads
/// the game's `2DA` and `IDS` files from IESDP and commits the result, which
/// is right for tables of pure numbers and confirmed in game. It is not right
/// in general: IESDP ships the **BG2:EE** `weapprof.2da`, and its `NAME_REF`
/// column is a strref into a talk table that is per game. Generating
/// proficiency names from it ships tutorial prose as the name of Two-Weapon
/// Style. That is D11, and this is the reader it calls for.
///
/// Outputs **domain models**, per the repository charter — nothing above this
/// layer sees `Table2da`, `KeyIndex` or a BIFF.
///
/// **Concrete, unlike `StringRepository`, and with no "absent" sibling.** That
/// pairing exists there because `TlkStringRepository` holds an open file and
/// something has to stand in when there is none. Here the absent case is not a
/// different implementation, it is the same one finding no installation and
/// answering [ProficiencyCatalogue.empty] — a second class would have been the
/// same behaviour written twice. A test substitutes this the way Dart always
/// allows: `implements ResourceRepository`.
class ResourceRepository {
  /// Reads the installation [_profile] locates.
  ///
  /// Positional, unlike the other repositories: the field is private, and a
  /// named parameter cannot be an initialising formal for one.
  ResourceRepository(this._profile);

  /// Where the game is on this machine.
  ///
  /// Private so that `implements ResourceRepository` needs only the method —
  /// a test double has no installation to point at, and being made to invent
  /// one would be the interface leaking into its own substitutes.
  final GameProfileService _profile;

  ProficiencyCatalogue? _proficiencies;

  /// Every proficiency the player's `weapprof.2da` names.
  ///
  /// Names are left as strrefs: resolving them needs the talk table, which is
  /// a different repository, and repositories must never be aware of each
  /// other. The merge happens in the ViewModel, exactly as it does for the
  /// names companions do not carry in the savegame.
  ///
  /// Cached, because a rules table cannot change while the app is open.
  Future<ProficiencyCatalogue> proficiencies() async =>
      _proficiencies ??= proficienciesFrom(
        await _table(weaponProficiencyTable),
      );

  /// The `2DA` named [resref], or an empty table if it cannot be read.
  ///
  /// **Never throws.** A missing or unreadable installation is an ordinary
  /// state — the app opens saves on machines with no game on them — and the
  /// panel degrades to numbers without names rather than failing to draw.
  Future<Table2da> _table(String resref) async {
    final game = _profile.findGameDirectory();
    if (game == null) return Table2da.parse('');

    final separator = Platform.pathSeparator;
    try {
      final index = KeyIndex.parse(
        await File(
          '$game$separator${GameProfileService.gameMarker}',
        ).readAsBytes(),
        source: GameProfileService.gameMarker,
      );
      final where = index.locate(resref, ResourceType.table2da);
      if (where == null) return Table2da.parse('');

      // The key file writes archive paths in the engine's own notation, which
      // is Windows-separated whatever the host is.
      final archive = index.archives[where.archive].replaceAll(
        r'\',
        separator,
      );
      final bif = BifArchive.parse(
        await File('$game$separator$archive').readAsBytes(),
        source: archive,
      );
      return Table2da.parse(utf8.decode(bif.resource(where.file)));
    } on FileSystemException {
      return Table2da.parse('');
    } on InfinityFormatException {
      return Table2da.parse('');
    } on FormatException {
      // A 2DA that is not UTF-8. Every BG:EE table is, but a mod's need not
      // be, and a rules table is not worth failing an app launch over.
      return Table2da.parse('');
    }
  }
}

/// The resref of the weapon-proficiency table.
const String weaponProficiencyTable = 'weapprof';

/// The `weapprof.2da` column holding the number opcode 233 stores.
const String proficiencyIdColumn = 'ID';

/// The `weapprof.2da` column holding the strref of the displayed name.
const String proficiencyNameColumn = 'NAME_REF';

/// The `weapprof.2da` column holding the strref of the description.
///
/// Named only so [proficienciesFrom] can tell it apart from a class column;
/// nothing reads the descriptions yet.
const String proficiencyDescriptionColumn = 'DESC_REF';

/// The highest strref a talk table could hold.
///
/// The unused rows of `weapprof.2da` carry `4294967296` — two to the
/// thirty-second, one past the top of a dword. It is a filler value, not a
/// string reference, and passing it to a lookup would be asking for entry
/// number four billion.
const int maximumStrref = 0xFFFFFFFF;

/// [ProficiencyCatalogue] from a parsed `weapprof.2da`.
///
/// A free function so the parsing is testable without an installation, and
/// because it is pure — the same reason `charactersFrom` is one.
///
/// ⚠️ **Keyed on the `ID` column, never on the row label.** BG:EE labels two
/// rows `AXE` and two `SPEAR` — the obsolete BG1 proficiencies 6 and 3, then
/// the live 92 and 98 — so the label does not identify a proficiency. That is
/// also why this walks `allRows` rather than `rows`: the displaced half of
/// each pair is real data.
ProficiencyCatalogue proficienciesFrom(Table2da table) {
  final columns = table.columns;
  final idAt = columns.indexOf(proficiencyIdColumn);
  final nameAt = columns.indexOf(proficiencyNameColumn);
  if (idAt < 0) return ProficiencyCatalogue.empty;

  // Everything that is not the id or one of the two strrefs is a class or kit
  // column. Taken by exclusion rather than by a hardcoded list, because the
  // set of kits is what varies between installations — and a modded game
  // adding one is precisely the case the generated tables get wrong.
  final classColumns = [
    for (var i = 0; i < columns.length; i++)
      if (columns[i] != proficiencyIdColumn &&
          columns[i] != proficiencyNameColumn &&
          columns[i] != proficiencyDescriptionColumn)
        (name: columns[i], index: i),
  ];

  final entries = <int, ProficiencyEntry>{};
  for (final row in table.allRows) {
    // `columns` and `cells` both exclude the row label, so they line up
    // directly — this is `Table2da.cell` with the row already in hand. A row
    // too short for a column gets the file's declared default, which is what
    // the second line of a 2DA is for.
    String? cell(int column) {
      if (column < 0) return null;
      return column < row.cells.length ? row.cells[column] : table.defaultValue;
    }

    final id = int.tryParse(cell(idAt) ?? '');
    if (id == null) continue;

    final strref = int.tryParse(cell(nameAt) ?? '');
    entries[id] = ProficiencyEntry(
      id: id,
      identifier: row.label,
      nameStrref: strref != null && strref >= 0 && strref <= maximumStrref
          ? strref
          : null,
      maximumByColumn: {
        for (final column in classColumns)
          if (int.tryParse(cell(column.index) ?? '') case final int maximum)
            column.name: maximum,
      },
    );
  }
  return ProficiencyCatalogue(entries);
}
