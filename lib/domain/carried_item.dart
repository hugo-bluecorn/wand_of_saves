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

part 'carried_item.mapper.dart';

/// One thing a character is carrying, as the record stores it.
///
/// **The domain mirror of `CreItem`**, exactly as `Proficiency` mirrors an
/// opcode 233 effect: the format type stays in `infinity_formats` and the model
/// the UI reads is plain. Nothing here knows about bytes.
@MappableClass()
class CarriedItem with CarriedItemMappable {
  /// Records [resref] in the slot at [slotIndex].
  const CarriedItem({
    required this.resref,
    required this.index,
    required this.slotIndex,
    this.quantity = 1,
    this.isIdentified = true,
  });

  /// The `ITM` resource, e.g. `BOOT01`.
  ///
  /// ⚠️ **The key.** Four items resolve to the name "The Paws of the Cheetah";
  /// nothing but the resref tells them apart.
  final String resref;

  /// Which entry of the record's items section this is.
  ///
  /// ⚠️ **Positional and shifting** — removing an earlier item renumbers it,
  /// which is why a command that removes carries the resref as a check field.
  final int index;

  /// Which slot holds it, as `CreItemSlot.index` numbers them.
  ///
  /// `-1` when no slot points at it. ⚠️ **That is possible and observed**:
  /// 220 of BioWare's own shipped creature records carry items no slot
  /// references. No record the *engine* writes does, but the reader must not
  /// assume it.
  final int slotIndex;

  /// How many, or how many charges.
  final int quantity;

  /// Whether the player knows what it is.
  ///
  /// ⚠️ **Decides which of the item's two names the game draws.** Clear, the
  /// engine shows the plain one — "Belt", not "Belt of Antipode" — so a screen
  /// that resolves the identified name regardless states something the engine
  /// does not.
  final bool isIdentified;

  /// Whether any slot points at this item.
  bool get isInASlot => slotIndex >= 0;
}
