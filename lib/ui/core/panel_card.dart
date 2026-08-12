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

/// One titled region of a screen.
///
/// It is a plain [Card] and nothing else — the theme gives it its hairline,
/// its radius and its rung on the surface ladder, so no caller names a
/// colour. Regions *inside* a card carry no fill at all; they are separated
/// by a rule, because a fifth surface tone is where the placeholder-inside-a-
/// card defect came from.
class PanelCard extends StatelessWidget {
  /// Creates a card headed [title].
  const PanelCard({
    required this.title,
    required this.children,
    this.note,
    this.trailing,
    super.key,
  });

  /// The heading.
  final String title;

  /// The card's contents, laid out in a column.
  final List<Widget> children;

  /// A one-line qualifier under the heading, wrapping in full.
  final String? note;

  /// An action or a count, right-aligned on the heading row.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Heading(title: title, note: note, trailing: trailing),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.note, this.trailing});

  final String title;
  final String? note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final noteText = note;
    final action = trailing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: text.titleLarge)),
            ?action,
          ],
        ),
        if (noteText != null) ...[
          const SizedBox(height: 4),
          Text(
            noteText,
            style: text.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
