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

part 'hit_die_tables.mapper.dart';

/// One level's worth of hit dice, exactly as the table stores it.
///
/// **Kept as the three raw columns rather than as a computed total**, because
/// the interpretation is not this data's business: the maximum is
/// `sides * rolls + modifier`, and showing a player "1d10" needs the parts
/// back. Reducing it here bakes one reading in and loses every other.
typedef HitDieRow = ({int sides, int rolls, int modifier});

/// How many hit points each class gains per level — **data, no behaviour**.
///
/// Two of the game's tables: `hpclass.2da` maps a class *or kit* to a hit-die
/// table, and each `hp…2da` gives `SIDES ROLLS MODIFIER` per level, to 40.
///
/// ⚠️ **This replaced a written-out map that was wrong.** It had every class
/// stop rolling after level 9; `hpwiz.2da` and `hprog.2da` roll through **11**,
/// so a Mage 12 was short 3 hit points and a Thief 12 short 4. No fixture is
/// above level 2, so nothing could have caught it.
///
/// ⚠️ **`hpclass.2da` covers kits individually and they do not follow their
/// class** — `DWARVEN_DEFENDER` maps to `HPBARB`, not to the Fighter's `HPWAR`.
/// Any rule that walked from a kit to its base class would get that wrong.
@MappableClass()
class HitDieTables with HitDieTablesMappable {
  /// Records what the tables said.
  const HitDieTables({
    this.tableByClass = const {},
    this.rowsByTable = const {},
  });

  /// Nothing read — no installation, or files that would not parse.
  static const HitDieTables empty = HitDieTables();

  /// `hpclass.2da`: a `CLASS.IDS` or `KIT.IDS` identifier to a table name.
  final Map<String, String> tableByClass;

  /// Each table's rows, level 1 first.
  ///
  /// ⚠️ **A character may out-level the table.** These stop at 40; the last row
  /// governs everything past it, which is what the engine does and what the
  /// rows themselves imply — the tail is a flat modifier repeated.
  final Map<String, List<HitDieRow>> rowsByTable;

  /// The rows for [classIdentifier], or `null` if nothing names it.
  List<HitDieRow>? rowsFor(String classIdentifier) {
    final table = tableByClass[classIdentifier];
    if (table == null) return null;
    final rows = rowsByTable[table];
    return rows == null || rows.isEmpty ? null : rows;
  }

  /// Whether anything at all was read.
  bool get isEmpty => tableByClass.isEmpty || rowsByTable.isEmpty;
}
