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

part 'proficiency_catalogue.mapper.dart';

/// What the game's own `weapprof.2da` says about one proficiency.
///
/// Two things a savegame cannot supply: what to call it, and how many pips
/// this character is allowed. Both come from the **player's installation**
/// rather than from IESDP — see D11, and see [nameStrref] for the specific
/// way that goes wrong.
@MappableClass()
class ProficiencyEntry with ProficiencyEntryMappable {
  /// Describes proficiency [id].
  const ProficiencyEntry({
    required this.id,
    required this.identifier,
    required this.maximumByColumn,
    this.nameStrref,
    this.name,
  });

  /// The number opcode 233 stores in parameter 2 — the table's `ID` column.
  ///
  /// **Not the row label.** BG:EE's file labels two rows `AXE` and two
  /// `SPEAR`, one obsolete and one live, so the label does not identify a
  /// proficiency and the `ID` column does.
  final int id;

  /// The table's row label, e.g. `2WEAPON`. Shown when there is no [name].
  final String identifier;

  /// The largest number of pips each class or kit column permits.
  ///
  /// Keyed by the column header, which is a `CLASS.IDS` identifier
  /// (`FIGHTER_MAGE`) or a kit's (`NECROMANCER`). This is the **only** source
  /// for a pip ceiling: IESDP states no range for opcode 233's Amount.
  final Map<String, int> maximumByColumn;

  /// Strref of the name in the player's talk table, or `null` if unusable.
  ///
  /// ⚠️ **This is D11's whole point.** IESDP ships the BG2:EE `weapprof.2da`,
  /// whose strref for Two-Weapon Style is 31138 — which in a BG:EE talk table
  /// reads *"While in temples, talk to the priests as you would an
  /// innkeeper…"*. The player's own file says 25023, which reads
  /// "Two-Weapon Style". Both files parse and both give a plausible integer,
  /// so only resolving the strref shows which one is wrong.
  final int? nameStrref;

  /// The resolved name, once the talk table has been consulted.
  ///
  /// `null` until then, and `null` for good on a machine with no game
  /// installed — which is an ordinary state, not a failure.
  final String? name;

  /// The most pips [column] permits, or `null` when the table cannot say.
  ///
  /// **`null`, never `0`, for an unknown column.** A kit missing from the
  /// player's file must not silently cap every proficiency at zero and refuse
  /// edits that are perfectly legal.
  int? maximumFor(String? column) =>
      column == null ? null : maximumByColumn[column];
}

/// Every proficiency the player's `weapprof.2da` names.
///
/// A domain model, so nothing above the data layer needs `Table2da`. Empty is
/// an ordinary state: the app opens saves on machines with no game installed,
/// and the panel then shows pip counts without names or ceilings.
@MappableClass()
class ProficiencyCatalogue with ProficiencyCatalogueMappable {
  /// Wraps [entries], keyed by proficiency id.
  const ProficiencyCatalogue(this.entries);

  /// Nothing known — no installation, or a file that would not parse.
  static const ProficiencyCatalogue empty = ProficiencyCatalogue({});

  /// Every proficiency, by the id opcode 233 stores.
  final Map<int, ProficiencyEntry> entries;

  /// The entry for [id], or `null`.
  ProficiencyEntry? operator [](int id) => entries[id];

  /// This catalogue with names filled in from [byStrref].
  ///
  /// The merge of two repositories, and it happens above both of them: the
  /// table comes from the resource index and the text from the talk table,
  /// and a repository reaching sideways for the other is what the layering
  /// forbids.
  ProficiencyCatalogue withNames(Map<int, String> byStrref) =>
      ProficiencyCatalogue({
        for (final entry in entries.entries)
          entry.key: entry.value.copyWith(
            name: byStrref[entry.value.nameStrref],
          ),
      });
}
