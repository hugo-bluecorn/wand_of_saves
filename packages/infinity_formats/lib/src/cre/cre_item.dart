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

import 'package:infinity_formats/src/spec/cre_v1_0.dart';

/// One thing a creature is carrying, as its record stores it.
///
/// **A class rather than a record**, unlike the homogeneous groups elsewhere in
/// `Cre`: those are several readings of one kind of thing — eleven resistances,
/// eight thief skills — where a record's field names carry all the meaning. An
/// item is one thing with fields of four different kinds, and it has behaviour
/// ([isIdentified], [start]) that a record cannot carry.
///
/// ⚠️ **This is what the record holds, not what the game shows.** Resolving
/// [resref] to a name needs the archives and the talk table, which is the app's
/// job — and which of the item's two names applies depends on [isIdentified].
class CreItem {
  /// Describes an item entry.
  const CreItem({
    required this.resref,
    required this.quantity,
    required this.flags,
    required this.start,
    this.quantity2 = 0,
    this.quantity3 = 0,
    this.expiration = 0,
  });

  /// Resref of the `ITM` resource, e.g. `BOOT01`.
  ///
  /// ⚠️ **The key, and the only one.** Four different items resolve to the name
  /// "The Paws of the Cheetah"; nothing but the resref tells them apart.
  final String resref;

  /// How many, or how many charges the first ability has left.
  ///
  /// The format does not distinguish a stack from a charge count — the `ITM`
  /// does, through its extended headers.
  final int quantity;

  /// Charges on the second ability.
  final int quantity2;

  /// Charges on the third ability.
  final int quantity3;

  /// Days until the engine replaces or removes it; `0` never expires.
  final int expiration;

  /// Identified, unstealable, stolen, undroppable.
  final Set<CreItemFlag> flags;

  /// Where this entry starts, relative to the creature record.
  ///
  /// Carried for the same reason `Proficiency.effectOffset` is: an edit names
  /// the bytes it patches by position, and finding them again by scanning would
  /// mean the command had to read the file it is about to change.
  final int start;

  /// Whether the player knows what it is.
  ///
  /// ⚠️ **Decides which of the item's two names the engine draws.** Clear, the
  /// game shows the plain one — "Belt", not "Belt of Antipode" — and a sheet
  /// that shows the identified name anyway is stating something the engine
  /// does not.
  bool get isIdentified => flags.contains(CreItemFlag.identified);

  /// Whether the player cannot drop it in game.
  bool get isUndroppable => flags.contains(CreItemFlag.undroppable);

  /// Whether it was stolen, so no shop will buy it.
  bool get isStolen => flags.contains(CreItemFlag.stolen);

  @override
  String toString() => 'CreItem($resref ×$quantity at $start)';
}
