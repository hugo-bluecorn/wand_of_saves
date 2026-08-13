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

import 'package:flutter/material.dart';

/// An item in flight between one character's backpack and another's portrait.
///
/// **A named type rather than a record** so `Draggable<ItemDrag>` and
/// `DragTarget<ItemDrag>` name the same thing: a `DragTarget` accepts by type,
/// and two unrelated drags carrying `(int, int, String)` would be
/// indistinguishable to it.
class ItemDrag {
  /// Carries entry [itemIndex] of the character at party position [from].
  const ItemDrag({
    required this.from,
    required this.itemIndex,
    required this.resref,
  });

  /// Party position of the character it is leaving.
  ///
  /// ⚠️ **A position, not a creature offset** — the move shrinks the source
  /// record and shifts every record after it, so an offset captured when the
  /// drag began would be stale before the drop lands.
  final int from;

  /// Which entry of that character's items section this is.
  final int itemIndex;

  /// What the entry is expected to hold, carried so the command can check it.
  final String resref;
}

/// What the pointer carries while an item is being dragged.
///
/// Its own widget so the rail's drop targets and the tests can both name the
/// thing being dragged, rather than matching on whatever the chip happens to
/// contain.
class ItemDragFeedback extends StatelessWidget {
  /// Shows [resref] under the pointer.
  const ItemDragFeedback({required this.resref, super.key});

  /// The item being carried.
  final String resref;

  @override
  Widget build(BuildContext context) {
    final colours = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Chip(
        avatar: const Icon(Icons.inventory_2_outlined, size: 18),
        label: Text(resref),
        backgroundColor: colours.secondaryContainer,
      ),
    );
  }
}
