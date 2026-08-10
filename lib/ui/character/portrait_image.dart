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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wand_of_saves/config/providers.dart';

/// The portrait a character record names.
///
/// `Image.memory` rather than `Image.file`: these come out of a BIFF archive,
/// and `dart:ui` decodes BMP natively, so no decoder is involved.
///
/// Four states — loading, present, absent, unreadable — and all four degrade to
/// the same placeholder rather than to an error, because a card without a
/// picture is a far better outcome than a screen that fails to draw.
class PortraitImage extends ConsumerWidget {
  /// Draws the portrait called [baseName].
  const PortraitImage({required this.baseName, this.iconSize = 48, super.key});

  /// The portrait's base name, with no variant suffix.
  final String baseName;

  /// How large the placeholder icon is drawn.
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (baseName.isEmpty) return _NoPortrait(iconSize: iconSize);

    return ref
        .watch(portraitProvider(baseName))
        .maybeWhen(
          data: (bytes) => bytes == null
              ? _NoPortrait(iconSize: iconSize)
              : Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) =>
                      _NoPortrait(iconSize: iconSize),
                ),
          orElse: () => _NoPortrait(iconSize: iconSize),
        );
  }
}

/// Where a portrait goes when there is none to draw.
class _NoPortrait extends StatelessWidget {
  const _NoPortrait({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Icon(
        Icons.person_outline,
        color: colors.outline,
        size: iconSize,
      ),
    );
  }
}
