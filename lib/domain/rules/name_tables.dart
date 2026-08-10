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

part 'name_tables.mapper.dart';

/// What the player's installation calls things — **data, with no behaviour**.
///
/// **This exists because of D13.** These names used to be *derived* inside
/// `GameRules`: an identifier split on underscores, title-cased and joined,
/// plus a hand-maintained map for the two races that rule got wrong. The game
/// ships all of it as tables — `racetext.2da`, `clastext.2da`, `kitlist.2da` —
/// already spelled, already punctuated, and already translated into whichever
/// language the player installed.
///
/// Keeping it as a separate value rather than as fields on the rules object is
/// the point: **the data is one thing and reading it is another.** A second
/// source — a modded installation, a different game — replaces this and touches
/// no logic.
///
/// Every map may be empty, and empty is an ordinary state: it is what a machine
/// with no game installed has. `GameRules` falls back to deriving from the IDS
/// identifiers there, which is the only thing left to do.
@MappableClass()
class NameTables with NameTablesMappable {
  /// Records what the tables said.
  const NameTables({
    this.raceNames = const {},
    this.classNames = const {},
    this.kitNames = const {},
  });

  /// Nothing read — no installation, or files that would not parse.
  static const NameTables empty = NameTables();

  /// Display name by `RACE.IDS` id, from `racetext.2da`'s `UPPERCASE` column.
  ///
  /// ⚠️ **Joined on that table's `ID` column, never on its row label** — it
  /// spells the seventh race `HALF_ORC` where `RACE.IDS` says `HALFORC`.
  final Map<int, String> raceNames;

  /// Display name by `CLASS.IDS` id, from `clastext.2da`'s `MIXED` column.
  ///
  /// ⚠️ **These carry substitution tokens.** `FIGHTER_MAGE` reads
  /// `<FIGHTERTYPE> / <MAGESCHOOL>`, and those tokens are *why* a kit replaces
  /// the class name on screen — the engine puts `Necromancer` where
  /// `<MAGESCHOOL>` is. That behaviour was found by staring at the game and
  /// written up as a rule; the table states it outright.
  final Map<int, String> classNames;

  /// Display name by `KIT.IDS` identifier, from `kitlist.2da`'s `MIXED` column.
  ///
  /// ⚠️ **The identifier is never the name.** The Ranger's first kit is
  /// `FERALAN` and the game draws *Archer*. Only the talk table says so.
  final Map<String, String> kitNames;

  /// Whether anything at all was read.
  bool get isEmpty =>
      raceNames.isEmpty && classNames.isEmpty && kitNames.isEmpty;
}
