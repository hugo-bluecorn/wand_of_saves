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

part 'rules_tables.mapper.dart';

/// The game's numeric rules tables — **data, no behaviour**.
///
/// **One type for many tables, deliberately.** `thac0`, `lore`, `thiefskl`,
/// `skilldex`, `skillrac`, `lorebon`, `strmod` and `intmod` are all the same
/// shape: a row label, a column name, and a number where they meet. What
/// differs is only *which* row and column to ask for, and that is a rule rather
/// than data — it lives in `GameRules`, which is where every other rule this
/// project has measured lives.
///
/// ⚠️ **Not the saving-throw tables, which stay their own type.** Those need a
/// composition across several tables at once and a per-race bonus subtracted
/// from the result; folding them in here would put that rule somewhere it could
/// not be read.
///
/// Every lookup answers `null` rather than a default. A machine with no game
/// installed reads nothing, and a sheet that shows nothing is honest where one
/// showing a zero is not.
@MappableClass()
class RulesTables with RulesTablesMappable {
  /// Records what was read, keyed by the table's resref, uppercased.
  const RulesTables({this.byName = const {}});

  /// Nothing read — no installation, or files that would not parse.
  static const RulesTables empty = RulesTables();

  /// Table name to row label to column name to value.
  final Map<String, Map<String, Map<String, int>>> byName;

  /// The number [table] holds where [row] meets [column], or `null`.
  ///
  /// Row labels and table names are matched uppercased, because a resref's
  /// case is an accident of where it was written down. Column names are not:
  /// the tables spell them `START_POINTS` and `PICK_POCKETS` consistently, and
  /// case-folding a column would hide a typo rather than tolerate one.
  int? at({
    required String table,
    required String row,
    required String column,
  }) => byName[table.toUpperCase()]?[row.toUpperCase()]?[column];

  /// Every row label [table] carries, or empty when it was not read.
  Iterable<String> rowsOf(String table) =>
      byName[table.toUpperCase()]?.keys ?? const [];

  /// Whether anything at all was read.
  bool get isEmpty => byName.isEmpty;
}
