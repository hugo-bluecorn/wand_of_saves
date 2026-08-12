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

/// The proficiency run, which the engine prints as a heading inside the combat
/// list rather than on a screen of its own.
///
/// The dots draw the ceiling as well as the pips taken, so a record that holds
/// more than its class may hold draws honestly rather than silently clipping.
/// The numeral beside them always carries the meaning; the dots are decoration
/// as far as a screen reader is concerned.
library;

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/record/theme.dart';

/// Every proficiency the character holds, with its pips and its ceiling.
class ProficiencyList extends StatelessWidget {
  /// Creates the run.
  const ProficiencyList({
    required this.proficiencies,
    required this.pips,
    required this.onChanged,
    super.key,
  });

  /// What the record holds.
  final List<DemoProficiency> proficiencies;

  /// Edits made since the record was opened, keyed by proficiency name.
  final Map<String, int> pips;

  /// Called with a name and the newly chosen number of pips.
  final void Function(String name, int pips) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final proficiency in proficiencies)
          _ProficiencyRow(
            proficiency: proficiency,
            pips: pips[proficiency.name] ?? proficiency.pips,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _ProficiencyRow extends StatelessWidget {
  const _ProficiencyRow({
    required this.proficiency,
    required this.pips,
    required this.onChanged,
  });

  final DemoProficiency proficiency;
  final int pips;
  final void Function(String name, int pips) onChanged;

  /// Tapping the last taken pip gives it back, which is the only way down to
  /// none. A pip past the ceiling can be reduced but never chosen.
  void _select(int target) {
    final wanted = target == pips ? target - 1 : target;
    if (wanted <= proficiency.maximum || wanted <= pips) {
      onChanged(proficiency.name, wanted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    final overCap = pips > proficiency.maximum;
    final caption = overCap
        ? 'above the ceiling this class allows'
        : (pips == proficiency.maximum && pips > 0 ? 'at its limit' : null);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.rowGap / 2),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: tokens.gutter,
              child: overCap
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: SizedBox(
                          width: 2,
                          height: 17,
                          child: ColoredBox(color: tokens.anomalyInk),
                        ),
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2, right: 8),
                          child: Text(
                            proficiency.name,
                            style: tokens.fieldLabel,
                          ),
                        ),
                      ),
                      // Matches the reserved ⓘ column of an ordinary row, so
                      // the numerals line up down the whole document.
                      const SizedBox(width: 32),
                      SizedBox(
                        width: tokens.valueColumn,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ExcludeSemantics(
                              child: _Pips(
                                pips: pips,
                                maximum: proficiency.maximum,
                                onSelected: _select,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$pips/${proficiency.maximum}',
                              style: overCap
                                  ? tokens.storedValue.copyWith(
                                      color: tokens.anomalyInk,
                                    )
                                  : tokens.storedValue,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (caption != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 1),
                      child: Text(
                        caption,
                        style: overCap
                            ? tokens.caption.copyWith(color: tokens.anomalyInk)
                            : tokens.caption,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pips extends StatelessWidget {
  const _Pips({
    required this.pips,
    required this.maximum,
    required this.onSelected,
  });

  final int pips;
  final int maximum;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final count = pips > maximum ? pips : maximum;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= count; i++) ...[
          if (i == maximum + 1) const _CapMarker(),
          _Pip(
            filled: i <= pips,
            beyondCap: i > maximum,
            onTap: () => onSelected(i),
          ),
        ],
      ],
    );
  }
}

class _Pip extends StatelessWidget {
  const _Pip({
    required this.filled,
    required this.beyondCap,
    required this.onTap,
  });

  final bool filled;
  final bool beyondCap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    final ink = beyondCap ? tokens.anomalyInk : tokens.pipInk;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: 16,
          height: 22,
          child: Center(
            child: SizedBox(
              width: 10,
              height: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? ink : Colors.transparent,
                  border: Border.all(
                    color: filled ? ink : tokens.pipEmptyInk,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the class stops. Only drawn when the record runs past it.
class _CapMarker extends StatelessWidget {
  const _CapMarker();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 7,
      height: 22,
      child: Center(
        child: SizedBox(
          width: 1,
          height: 12,
          child: ColoredBox(color: context.recordTokens.anomalyInk),
        ),
      ),
    );
  }
}
