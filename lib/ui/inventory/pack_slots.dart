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

/// Where the next item can go, asked once.
///
/// ⚠️ **Three surfaces ask this and they must not each answer it.** The
/// inventory needs the slot to put an item in; the party rail and any other
/// arrangement of the party need to know whether a portrait may accept a drop.
/// A rail that lights up for a character the inventory considers full is
/// exactly the class of defect this project keeps paying for — a rule with two
/// copies, and the second one wrong.
library;

import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/domain/carried_item.dart';

/// The first backpack slot nothing in [items] points at, or `null` when the
/// backpack is full.
///
/// ⚠️ **Scans rather than counts.** Holes are legal — a real character fills
/// packs 1–7 and 9, leaving 8 empty — so the item count is not the index of the
/// next free slot, and using it would overwrite what is already there.
CreItemSlot? firstFreePackSlot(List<CarriedItem> items) {
  final taken = {
    for (final item in items)
      if (item.isInASlot) item.slotIndex,
  };
  for (final slot in CreItemSlot.pack) {
    if (!taken.contains(slot.index)) return slot;
  }
  return null;
}

/// Whether a character carrying [items] has room for one more.
bool hasPackRoom(List<CarriedItem> items) => firstFreePackSlot(items) != null;
