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
import 'package:wand_of_saves/ui/core/arithmetic_line.dart';
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

  /// Called when a row is opened for editing.
  final ValueChanged<Subject> onOpen;

  /// Whether this document can take a proficiency it does not already hold.
  ///
  /// ⚠️ **A property of the document, not of the character.** Raising a
  /// proficiency from zero appends a 264-byte opcode 233 effect, which moves
  /// **one** pointer in a `.chr` and **forty-three** inside a savegame. So a
  /// character file passes `true` and a savegame `false` — and the sheet itself
  /// does not know which it is looking at, which is why this is a parameter
  /// rather than something it works out.
  @override
  Widget build(BuildContext context) {
    final panels = sheetPanelsOf(
      character: character,
      rulesBind: rulesBind,
      onOpen: onOpen,
    );

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
          SheetIdentity(character: character),
          const SizedBox(height: 20),
          for (final panel in panels.values) ...[
            panel,
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

/// The order the panels are read in, whatever order the record stores them.
///
/// ⚠️ **Named, not inherited from the data's order**, because the order a
/// record happens to store its groups in is not the order a person reads a
/// character in. Anything the data holds that is not named here is appended
/// rather than dropped — a hard-coded order that silently loses a new group is
/// a defect waiting for the next character.
const List<String> sheetPanelOrder = [
  'Character',
  'Abilities',
  'Skills',
  'Proficiencies',
  'Combat',
  'Resistances',
  'Condition',
];

/// Every panel of [character]'s record, keyed by its heading and in
/// [sheetPanelOrder].
///
/// **Extracted so more than one arrangement can place the same panels.** The
/// single column above draws them in order; a grid puts named panels in named
/// cells. Building them twice would be two answers to "what is on this sheet",
/// which is this project's most expensive recurring bug.
///
/// [inlineEditor] is asked about every row as it is built, and whatever it
/// returns is drawn directly beneath that row. `null` — the single column's
/// answer, and the default — draws nothing extra, so the sheet is unchanged.
///
/// [foldInto] names groups that should not get a panel of their own, mapping
/// each to the panel its rows join instead — `{'Condition': 'Character'}` puts
/// fatigue and intoxication at the end of the Character panel and leaves no
/// Condition panel at all. Empty by default, so the sheet is unchanged.
Map<String, Widget> sheetPanelsOf({
  required SheetCharacter character,
  required bool rulesBind,
  required ValueChanged<Subject> onOpen,
  Widget? Function(Subject subject)? inlineEditor,
  Map<String, String> foldInto = const {},
}) {
  final index = indexOf(character);
  final flagged = <String, Finding>{
    for (final finding in findingsFor(character))
      if (finding.subject case FieldSubject(:final entry)) entry.key: finding,
  };

  final built = <String, Widget>{};
  // ⚠️ Rows are collected before any panel is built, because folding means one
  // panel can draw more than one group's worth of them.
  final gathered = <String, List<FieldEntry>>{};
  final notes = <String, String?>{};
  for (final section in character.sections) {
    if (section.title == 'Abilities') {
      built['Abilities'] = _Abilities(
        character: character,
        rulesBind: rulesBind,
        onOpen: onOpen,
        flagged: flagged,
        inlineEditor: inlineEditor,
      );
      continue;
    }
    for (final group in section.groups) {
      final rows = [
        for (final entry in index)
          if (entry.group == group) entry,
      ];
      if (rows.isEmpty) continue;
      final panel = foldInto[group.title] ?? group.title;
      (gathered[panel] ??= []).addAll(rows);
      notes[panel] ??= group.note;
    }
  }
  for (final MapEntry(key: title, value: rows) in gathered.entries) {
    built[title] = PanelCard(
      title: title,
      note: notes[title],
      children: [
        for (final entry in rows) ...[
          if (entry != rows.first) const Divider(),
          _ValueRow(
            entry: entry,
            finding: flagged[entry.key],
            rulesBind: rulesBind,
            onTap: () => onOpen(FieldSubject(entry)),
          ),
          ?inlineEditor?.call(FieldSubject(entry)),
        ],
      ],
    );
  }
  if (character.proficiencies.isNotEmpty) {
    built['Proficiencies'] = _Proficiencies(
      character: character,
      onOpen: onOpen,
      inlineEditor: inlineEditor,
    );
  }

  final ordered = <String, Widget>{};
  for (final title in sheetPanelOrder) {
    if (built.remove(title) case final Widget panel) ordered[title] = panel;
  }
  return ordered..addAll(built);
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
class SheetIdentity extends StatelessWidget {
  /// Names [character] above their numbers.
  const SheetIdentity({required this.character, super.key});

  /// Whose record this is.
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

    final field = entry.field;
    final unit = field.unit ?? '';
    final inGame = field.inGame;
    final state = stateTagFor(field, rulesBind: rulesBind);
    final limits = rulesBind ? null : _limits(field);

    // ⚠️ **Two lines, and the second one carries the sum.** The label and the
    // number the file holds; then, underneath, the modification *with its
    // amount* and the number the engine draws. The single-line arrangement this
    // replaces put `stored 3` beside `in game 23` with a helper line reading
    // `stored 3, + Intelligence + Wisdom` — which names the terms and never
    // says `+20`, so the one line that answers *why* raised the question
    // instead. A row with no modification stays one line, which makes the
    // taller row the interesting one.
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(field.label, style: text.bodyLarge)),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${field.stored}$unit',
                    style: text.titleMedium,
                    textAlign: TextAlign.end,
                  ),
                  // ⚠️ **What the rules say, when the file disagrees.** Stored
                  // and base are not always the same number: a stored maximum
                  // of 45 arrived in a new game as 12, recomputed. Saying so
                  // here is the distinction made per row rather than left to a
                  // sentence underneath.
                  if (field.divergesFromRules)
                    Tag(
                      '${field.derived}',
                      caption: 'rules say',
                      tone: TagTone.enhanced,
                    ),
                  ?state,
                  if (field.caveat case final String note) _Caveat(note),
                ],
              ),
            ],
          ),
          if (field.valueMeanings != null && inGame != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ArithmeticLine(
                    'the game draws this as $inGame — open it to see what '
                    'every value means',
                  ),
                ),
                const SizedBox(width: 12),
                Tag('$inGame$unit', caption: 'in game', tone: TagTone.inGame),
              ],
            ),
          ] else if (arithmetic != null && inGame != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: ArithmeticLine(arithmetic)),
                const SizedBox(width: 12),
                Tag('$inGame$unit', caption: 'in game', tone: TagTone.inGame),
              ],
            ),
          ] else if (arithmetic != null) ...[
            const SizedBox(height: 6),
            ArithmeticLine(arithmetic),
          ],
          // ⚠️ **The range, and only with the check off.** On, the app refuses
          // what the rules refuse and the bound is implicit. Off, the player is
          // deliberately going past it and needs to know where the two limits
          // are — the rules' and the engine's, which D16 keeps apart because
          // one is a choice and the other is a corrupt byte.
          if (limits != null) ...[
            const SizedBox(height: 6),
            Text(
              limits,
              style: text.bodySmall?.copyWith(color: colors.secondary),
            ),
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

/// What the two limits are, or `null` when neither is known.
///
/// ⚠️ **Two numbers, never one range, and that is D16 rather than pedantry.**
/// `18` and `25` answer different questions — *the rules stop here* and *the
/// engine stops here* — and a THAC0 of 25 at level 2 was written, imported,
/// played and kept, so the gap between them is a real place a save editor lets
/// you stand. Collapsing them to `1–25` throws that away.
///
/// ⚠️ **A `null` rules ceiling is "nobody looked it up", not "anything goes".**
/// Strength has no rules ceiling here because `CharacterSheet` does not expose
/// the 18 that creation enforces from `abracerq.2da`, so this says only what
/// the engine will take rather than implying the rules permit it. See
/// `docs/findings/known-defects.md`.
String? _limits(SheetField field) {
  final rules = field.rulesMaximum;
  final game = field.gameMaximum;
  return switch ((rules, game)) {
    (final int r, final int g) =>
      'the rules reach ${_grouped(r)} · '
          'the game takes up to ${_grouped(g)}',
    (final int r, null) => 'the rules reach ${_grouped(r)}',
    (null, final int g) => 'the game takes up to ${_grouped(g)}',
    (null, null) => null,
  };
}

/// `4294967295` as `4,294,967,295`.
///
/// ⚠️ **Hand-rolled because `intl` is not a dependency**, and a field's own
/// width is where this earns its place: experience is a dword, so its engine
/// limit really is ten digits, and ten ungrouped digits read as noise rather
/// than as a number. Not localised — a separator that varied by locale would be
/// a reason to take the dependency, and nothing else here needs one.
String _grouped(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// The ⓘ: one short line, on hover, never a paragraph on the surface.
class _Caveat extends StatelessWidget {
  const _Caveat(this.note);

  final String note;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: note,
      waitDuration: const Duration(milliseconds: 500),
      child: Icon(
        Icons.info_outline,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// The seven ability scores, in the same rows as everything else.
///
/// ⚠️ **They used to be bordered tiles with their own value readout, and that
/// was a second rendering of one thing.** It cost twice: the sheet showed
/// `stored 18` on Strength and a bare `7` on the row above it, and every rule
/// added to the sheet had to be wired to two widgets — which is exactly how the
/// rules check came to reach the value rows and go silent on the ability tiles,
/// the field people most often open a save editor to change. One row widget
/// makes that class of bug unavailable rather than merely fixed.
class _Abilities extends StatelessWidget {
  const _Abilities({
    required this.character,
    required this.rulesBind,
    required this.onOpen,
    required this.flagged,
    this.inlineEditor,
  });

  final SheetCharacter character;
  final bool rulesBind;
  final ValueChanged<Subject> onOpen;

  /// What this application noticed, by field key.
  final Map<String, Finding> flagged;

  /// What to draw beneath a row, when an arrangement edits in place.
  final Widget? Function(Subject subject)? inlineEditor;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final entry in indexOf(character))
        if (entry.section.title == 'Abilities') entry,
    ];
    return PanelCard(
      title: 'Abilities',
      children: [
        for (final entry in rows) ...[
          if (entry != rows.first) const Divider(),
          _ValueRow(
            entry: entry,
            finding: flagged[entry.key],
            rulesBind: rulesBind,
            onTap: () => onOpen(FieldSubject(entry)),
          ),
          ?inlineEditor?.call(FieldSubject(entry)),
        ],
      ],
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
  const _Proficiencies({
    required this.character,
    required this.onOpen,
    this.inlineEditor,
  });

  final SheetCharacter character;
  final ValueChanged<Subject> onOpen;

  /// What to draw beneath a row, when an arrangement edits in place.
  final Widget? Function(Subject subject)? inlineEditor;

  /// Whether a proficiency the record does not hold can be taken up.
  @override
  Widget build(BuildContext context) {
    final total = character.proficiencies.length;
    return PanelCard(
      title: 'Proficiencies',
      // ⚠️ **The note is about the DOCUMENT and was shown against both.** In a
      // `.chr` every row is editable, so saying otherwise was not merely noise:
      // it explained a restriction that did not apply, while the rows really
      // were inert — which is how "I deselected all proficiencies but I cannot
      // add pip to other proficiencies" happened.
      // ⚠️ **A note used to live here saying a savegame could not grant a
      // proficiency, and the GAM relocation made that false.** Both documents
      // now take a resizing edit, so there is nothing to explain away — and a
      // note explaining a restriction that no longer applies is exactly the
      // defect this panel was fixed for once already.
      trailing: Tag('$total', caption: 'all editable'),
      children: [
        for (final proficiency in character.proficiencies) ...[
          PipMeter(
            proficiency: proficiency,
            // Every proficiency is open now: the record either holds the
            // effect already or grows one, and both documents can grow.
            onTap: () => onOpen(ProficiencySubject(proficiency)),
          ),
          ?inlineEditor?.call(ProficiencySubject(proficiency)),
        ],
      ],
    );
  }
}
