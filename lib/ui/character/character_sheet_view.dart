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
import 'package:wand_of_saves/ui/character/findings.dart';
import 'package:wand_of_saves/ui/character/pip_meter.dart';
import 'package:wand_of_saves/ui/character/sheet_view_model.dart';
import 'package:wand_of_saves/ui/character/value_readout.dart';
import 'package:wand_of_saves/ui/core/arithmetic_line.dart';
import 'package:wand_of_saves/ui/core/palette_finish.dart';
import 'package:wand_of_saves/ui/core/panel_card.dart';
import 'package:wand_of_saves/ui/core/screen_tone.dart';
import 'package:wand_of_saves/ui/core/tag.dart';

/// The whole record, one panel per group, stacked in one column.
///
/// **One sheet, two documents.** A savegame and an exported `.chr` wrap the
/// same `CRE V1.0` record, so a field means the same thing in either — which is
/// exactly what `CreatureDocument` exists to state. This takes the projected
/// [SheetCharacter] and knows nothing about which file it came out of.
class CharacterSheetView extends StatelessWidget {
  /// Draws [character] as a single column of panels.
  const CharacterSheetView({
    required this.character,
    required this.rulesBind,
    required this.onOpen,
    super.key,
  });

  /// The record being drawn.
  final SheetCharacter character;

  /// Whether a value past the rules is an error or a deliberate enhancement.
  final bool rulesBind;

  /// Called when a row or tile is opened for editing.
  final ValueChanged<Subject> onOpen;

  @override
  Widget build(BuildContext context) {
    final index = indexOf(character);
    final flagged = <String, Finding>{
      for (final finding in findingsFor(character))
        if (finding.subject case FieldSubject(:final entry)) entry.key: finding,
    };

    final built = <String, Widget>{};
    for (final section in character.sections) {
      if (section.title == 'Abilities') {
        built['Abilities'] = _Abilities(
          character: character,
          rulesBind: rulesBind,
          onOpen: onOpen,
        );
        continue;
      }
      for (final group in section.groups) {
        final rows = [
          for (final entry in index)
            if (entry.group == group) entry,
        ];
        if (rows.isEmpty) continue;
        built[group.title] = PanelCard(
          title: group.title,
          note: group.note,
          children: [
            for (final entry in rows) ...[
              if (entry != rows.first) const Divider(),
              _ValueRow(
                entry: entry,
                finding: flagged[entry.key],
                rulesBind: rulesBind,
                onTap: () => onOpen(FieldSubject(entry)),
              ),
            ],
          ],
        );
      }
    }
    if (character.proficiencies.isNotEmpty) {
      built['Proficiencies'] = _Proficiencies(
        character: character,
        onOpen: onOpen,
      );
    }

    // ⚠️ **Named, not inherited from the data's order**, because the order a
    // record happens to store its groups in is not the order a person reads a
    // character in. Anything the data holds that is not named here is appended
    // rather than dropped — a hard-coded order that silently loses a new group
    // is a defect waiting for the next character.
    const order = [
      'Character',
      'Abilities',
      'Skills',
      'Proficiencies',
      'Combat',
      'Resistances',
      'Condition',
    ];
    final panels = <Widget>[
      for (final title in order)
        if (built.remove(title) case final Widget panel) panel,
      ...built.values,
    ];

    // ⚠️ **Selection belongs here, not at the application root.** Every number
    // on this sheet is one somebody wants to quote — this project's own
    // workflow is comparing a value here against one the engine printed — and
    // until now nothing anywhere in the app could be copied at all.
    //
    // It must sit *below* the router's `Navigator`: `SelectableRegion` needs an
    // `Overlay` for its handles, and a `SelectionArea` in
    // `MaterialApp.router`'s `builder` throws "No Overlay widget found" on the
    // first frame. That failure is invisible to the suite — see `main.dart`.
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Identity(character: character),
          const SizedBox(height: 20),
          for (final panel in panels) ...[panel, const SizedBox(height: 20)],
        ],
      ),
    );
  }
}

/// Who this record is, above the numbers.
///
/// ⚠️ **The sheet has to name the person, and for one revision it did not.**
/// The app bar names the *document* — a savegame slot, or `Aard1.chr`, which
/// really can differ from the character inside it — so with no header the
/// character's own name appeared nowhere on screen at all.
///
/// The facts stay separate because the engine prints them on separate lines,
/// and one run-on sentence loses which of them is the class.
class _Identity extends StatelessWidget {
  const _Identity({required this.character});

  final SheetCharacter character;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(character.name, style: text.headlineSmall),
        const SizedBox(height: 4),
        Text(
          [character.levelLine, ...character.identity].join('  ·  '),
          style: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          character.experienceLine,
          style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.entry,
    required this.onTap,
    this.finding,
    this.rulesBind = true,
  });

  final FieldEntry entry;
  final VoidCallback onTap;

  /// What this application noticed about this field, marked in place rather
  /// than listed somewhere else. A separate list said the same thing twice and
  /// put it where the field was not.
  final Finding? finding;

  /// Whether a value past the rules reads as a fault or as a choice.
  final bool rulesBind;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final arithmetic = entry.field.arithmetic;
    final live = entry.field.enabledUnder(rulesBind: rulesBind);
    final mark = finding;
    final marked = mark != null;
    final tone = mark?.severity == Severity.conflict
        ? colors.error
        : colors.tertiary;
    // One sentence for a screen reader, covering the verdict too — a label
    // that only knew the value would go silent on the state that matters.
    final spoken = StringBuffer(
      '${entry.field.label}, stored ${entry.field.stored}',
    );
    if (mark != null) spoken.write('. ${mark.sentence}');

    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Text(entry.field.label, style: text.bodyLarge),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: ValueReadout(
                  field: entry.field,
                  rulesBind: rulesBind,
                ),
              ),
            ],
          ),
          if (arithmetic != null) ...[
            const SizedBox(height: 8),
            ArithmeticLine(arithmetic),
          ],
          // The sentence sits under the value it is about. It used to live in
          // a column on the right, which said the field's name a second time
          // to explain where to look.
          if (marked) ...[
            const SizedBox(height: 8),
            Text(
              mark.sentence,
              style: text.bodyMedium?.copyWith(color: tone),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: true,
      label: spoken.toString(),
      child: InkWell(
        // Readable either way — you can always open it to read the caveat —
        // but the surface says whether it may be *changed*, which is what the
        // mode governs. Behaviour that changes while appearance does not is a
        // mode nobody can see.
        onTap: onTap,
        child: Container(
          decoration: marked
              ? BoxDecoration(
                  border: Border(left: BorderSide(color: tone, width: 3)),
                )
              : null,
          padding: EdgeInsets.only(left: marked ? 12 : 0),
          child: live ? body : ScreenTone(child: body),
        ),
      ),
    );
  }
}

/// The seven ability scores, each carrying its arithmetic in full.
///
/// ⚠️ **Abilities are where a save editor is actually used**, so the verdict
/// has to reach these tiles and not only the rows. A rule wired to one surface
/// and not the other is a rule that goes quiet on exactly the field someone
/// opened the application to change.
class _Abilities extends StatelessWidget {
  const _Abilities({
    required this.character,
    required this.rulesBind,
    required this.onOpen,
  });

  final SheetCharacter character;
  final bool rulesBind;
  final ValueChanged<Subject> onOpen;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      for (final entry in indexOf(character))
        if (entry.section.title == 'Abilities') entry,
    ];
    return PanelCard(
      title: 'Abilities',
      children: [
        for (final entry in tiles) ...[
          _AbilityTile(entry: entry, rulesBind: rulesBind, onOpen: onOpen),
          if (entry != tiles.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AbilityTile extends StatelessWidget {
  const _AbilityTile({
    required this.entry,
    required this.onOpen,
    this.rulesBind = true,
  });

  final FieldEntry entry;
  final ValueChanged<Subject> onOpen;
  final bool rulesBind;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final field = entry.field;
    final arithmetic = field.arithmetic;
    final live = field.enabledUnder(rulesBind: rulesBind);

    // ⚠️ No fill. An inset region inside a card is separated by a hairline,
    // never by a fifth surface tone — that collision is what made the previous
    // application's placeholders invisible inside the cards holding them.
    final tile = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.label, style: text.bodyLarge),
                if (arithmetic != null) ...[
                  const SizedBox(height: 8),
                  ArithmeticLine(arithmetic),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: ValueReadout(field: field, rulesBind: rulesBind),
          ),
        ],
      ),
    );

    // Asked for, not stated — the palette decides how hard an edge is. See
    // [PaletteFinish].
    final corner = PaletteFinish.of(context).radiusOf(12);

    return Semantics(
      button: live,
      label: '${field.label}, stored ${field.stored}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: corner,
          border: Border.all(color: colors.outline),
        ),
        child: InkWell(
          onTap: live ? () => onOpen(FieldSubject(entry)) : null,
          borderRadius: corner,
          child: live ? tile : ScreenTone(child: tile),
        ),
      ),
    );
  }
}

/// Every proficiency the tables know, not only the ones with pips.
///
/// A list showing only what is taken cannot say what else is available, and
/// choosing one is the whole interaction.
///
/// ⚠️ **The per-row ceiling is what binds here, not a slot budget.** The engine
/// also grants a *total* number of slots by class and level, and this panel
/// does not count them — a savegame cannot take a proficiency the record has no
/// effect for anyway, because granting one resizes the record.
class _Proficiencies extends StatelessWidget {
  const _Proficiencies({required this.character, required this.onOpen});

  final SheetCharacter character;
  final ValueChanged<Subject> onOpen;

  @override
  Widget build(BuildContext context) {
    final grantable = [
      for (final proficiency in character.proficiencies)
        if (proficiency.effectOffset != null) proficiency,
    ];
    return PanelCard(
      title: 'Proficiencies',
      note: grantable.length == character.proficiencies.length
          ? null
          : 'Only the proficiencies this character already has can be changed '
                'in a savegame. Adding one resizes the record; export the '
                'character to do that.',
      trailing: Tag(
        '${grantable.length}/${character.proficiencies.length}',
        caption: 'editable',
      ),
      children: [
        for (final proficiency in character.proficiencies)
          PipMeter(
            proficiency: proficiency,
            onTap: proficiency.effectOffset == null
                ? null
                : () => onOpen(ProficiencySubject(proficiency)),
          ),
      ],
    );
  }
}
