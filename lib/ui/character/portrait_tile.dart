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
import 'package:wand_of_saves/ui/character/portrait_image.dart';

/// One party member's portrait, at the size the game writes it.
///
/// ⚠️ **Restored from `party_view.dart` after being lost, and the loss is the
/// point.** This was library-private, so deleting that file deleted it, and the
/// rail was rewritten with `PortraitImage(baseName: 'PORTRT$index')` — a
/// **filename where a resref belongs**. Nothing resolved and every destination
/// fell back to a generic icon. `Character.portraitBaseName` is the field whose
/// own dartdoc says it is what the sheet shows; `portraitPath` is the stale
/// `PORTRT<n>.bmp` snapshot kept only as an oracle.
class PortraitTile extends StatelessWidget {
  /// Draws the portrait named [baseName], framed as [selected] or not.
  const PortraitTile({
    required this.baseName,
    this.selected = false,
    super.key,
  });

  /// The width the game writes.
  static const double width = 54;

  /// The height the game writes.
  static const double height = 84;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(6));

  /// The portrait's base name, with no variant suffix.
  final String baseName;

  /// Whether this is the character on show.
  ///
  /// The rail's own M3 indicator is drawn *behind* the icon, and a portrait is
  /// opaque and fills that space exactly — so it hid the indicator completely
  /// and selection had no visible effect. The frame is drawn here instead.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'The portrait this character’s record names.',
      child: _frame(colors),
    );
  }

  Widget _frame(ColorScheme colors) {
    return Container(
      width: width,
      height: height,
      // Foreground, so the frame sits over the portrait rather than under it.
      // Both states carry a border of the same width, so nothing shifts when
      // the selection moves.
      foregroundDecoration: BoxDecoration(
        borderRadius: _radius,
        border: Border.all(
          color: selected ? colors.primary : colors.outlineVariant,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: PortraitImage(baseName: baseName, iconSize: 28),
      ),
    );
  }
}
