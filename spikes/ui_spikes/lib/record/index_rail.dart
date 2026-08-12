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

/// The document's index: where you are, and how to get somewhere else.
///
/// **No icons.** A book's index is type, and seven words are quicker to read
/// than seven pictograms whose meanings have to be learnt first. The entry the
/// reader is currently inside is marked by a rule and a weight change rather
/// than by a filled shape, because nothing here is being selected — the reader
/// is simply somewhere.
library;

import 'package:flutter/material.dart';
import 'package:ui_spikes/record/theme.dart';

/// The index rail, tracking the reader's position in the document.
class IndexRail extends StatelessWidget {
  /// Creates a rail listing [titles], with [activeIndex] currently under the
  /// reader.
  const IndexRail({
    required this.titles,
    required this.activeIndex,
    required this.onSelected,
    required this.width,
    super.key,
  });

  /// The chapter names, in the document's own order.
  final List<String> titles;

  /// Which of them the reader is inside.
  final int activeIndex;

  /// Called with the index of a chapter the reader wants to go to.
  final ValueChanged<int> onSelected;

  /// How wide to draw it. The document narrows the rail before it narrows the
  /// reading measure.
  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    return SizedBox(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: 30, bottom: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text('SECTIONS', style: tokens.chapterHead),
                    ),
                    for (var i = 0; i < titles.length; i++)
                      _RailEntry(
                        title: titles[i],
                        active: i == activeIndex,
                        onTap: () => onSelected(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const VerticalDivider(),
        ],
      ),
    );
  }
}

class _RailEntry extends StatefulWidget {
  const _RailEntry({
    required this.title,
    required this.active,
    required this.onTap,
  });

  final String title;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_RailEntry> createState() => _RailEntryState();
}

class _RailEntryState extends State<_RailEntry> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    return Semantics(
      button: true,
      selected: widget.active,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              // Material 3's own hover state opacity.
              color: _hovering
                  ? tokens.changeInk.withValues(alpha: 0.08)
                  : null,
              border: Border(
                left: BorderSide(
                  color: widget.active ? tokens.changeInk : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
              child: Text(
                widget.title,
                style: widget.active
                    ? tokens.railEntryActive
                    : tokens.railEntry,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
