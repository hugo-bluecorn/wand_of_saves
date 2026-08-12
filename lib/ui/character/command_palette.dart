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
import 'package:wand_of_saves/ui/character/sheet_view_model.dart';
import 'package:wand_of_saves/ui/character/value_readout.dart';
import 'package:wand_of_saves/ui/core/arithmetic_line.dart';
import 'package:wand_of_saves/ui/core/screen_tone.dart';
import 'package:wand_of_saves/ui/core/tag.dart';

/// The one control that reaches every field and proficiency on the
/// record. It was once the *only* way to reach forty of the fifty-three
/// fields; now the sheet draws them all and this is the fast way rather
/// than the only way.
///
/// It is a [SearchAnchor] rather than a bare [SearchBar] because this really
/// is a suggestion-and-selection route: it pushes, it filters, it returns a
/// selection, and the selection opens something.
///
/// Three things the rows do that a list of labels cannot:
///
/// * **Every row carries `section · group`.** Aard's sheet lists `Lore`
///   twice; a palette that showed only labels would be ambiguous exactly
///   where it needs to be precise.
/// * **Every row carries its stored and in-game values and its arithmetic**,
///   wrapping, in full. Choosing is often all you came to do.
/// * **A row the class cannot have is dimmed and inert; a row the record
///   holds anyway is dimmed and live**, in the error role, with the word
///   *conflict* on it. Two different states, never both just grey.
///
/// Matching is by label substring, by the label's acronym (`ac` finds
/// `Armour class`), and by a word of the section or group. The acronym rule
/// is why two keystrokes reach anything.
class CommandPalette extends StatelessWidget {
  /// Creates the palette over [character].
  const CommandPalette({
    required this.controller,
    required this.character,
    required this.onSelected,
    super.key,
  });

  /// Held by the screen so it can be opened by Ctrl+K.
  final SearchController controller;

  /// The record being searched.
  final SheetCharacter character;

  /// Called with whatever the player picked.
  final ValueChanged<Subject> onSelected;

  @override
  Widget build(BuildContext context) {
    const hint = 'Find a field or a proficiency…';
    return SearchAnchor(
      searchController: controller,
      isFullScreen: false,
      viewHintText: hint,
      builder: (context, anchor) => SearchBar(
        controller: anchor,
        hintText: hint,
        leading: const Icon(Icons.search),
        trailing: const [_ShortcutHint()],
        onTap: anchor.openView,
        onChanged: (_) => anchor.openView(),
      ),
      suggestionsBuilder: _suggestionsFor,
    );
  }

  Iterable<Widget> _suggestionsFor(
    BuildContext context,
    SearchController anchor,
  ) {
    final query = anchor.text.trim().toLowerCase();
    final subjects = query.isEmpty ? _startHere() : _matches(query);
    if (subjects.isEmpty) {
      return const [_PaletteEmpty()];
    }
    return [
      for (final subject in subjects)
        _PaletteRow(
          subject: subject,
          onTap: _canOpen(subject)
              ? () {
                  anchor.closeView(subject.title);
                  onSelected(subject);
                }
              : null,
        ),
    ];
  }

  /// What the palette offers **before** a single keystroke: everything this
  /// application has flagged, then the handful of fields somebody actually
  /// opened the record to change.
  List<Subject> _startHere() {
    final flagged = <String, Subject>{};
    for (final finding in findingsFor(character)) {
      if (finding.subject case final subject?) {
        flagged[subject.title] = subject;
      }
    }
    const usual = [
      'Maximum hit points',
      'Strength',
      'THAC0 (base)',
      'Experience',
      'Gold (carried)',
      'Armour class (effective)',
    ];
    final rest = [
      for (final entry in indexOf(character))
        if (usual.contains(entry.field.label) &&
            !flagged.containsKey(entry.field.label))
          FieldSubject(entry),
    ];
    return [...flagged.values, ...rest];
  }

  List<Subject> _matches(String query) {
    final corpus = <Subject>[
      for (final entry in indexOf(character)) FieldSubject(entry),
      for (final proficiency in character.proficiencies)
        ProficiencySubject(proficiency),
    ];
    return [
      for (final subject in corpus)
        if (_matchesQuery(subject, query)) subject,
    ];
  }
}

bool _matchesQuery(Subject subject, String query) {
  final title = subject.title.toLowerCase();
  if (title.contains(query)) return true;
  if (_acronymOf(title).startsWith(query)) return true;
  final where = switch (subject) {
    FieldSubject(:final entry) => entry.where,
    ProficiencySubject() => 'Proficiencies',
  };
  for (final word in where.toLowerCase().split(RegExp('[^a-z0-9]+'))) {
    if (word.isNotEmpty && word.startsWith(query)) return true;
  }
  return false;
}

/// `armour class (effective)` → `ace`, which is what makes `ac` reach all six
/// armour classes in two keystrokes.
String _acronymOf(String title) {
  final initials = StringBuffer();
  for (final word in title.split(RegExp('[^a-z0-9]+'))) {
    if (word.isNotEmpty) initials.write(word[0]);
  }
  return initials.toString();
}

/// A field the class cannot have and the record does not hold is inert. One
/// the record holds anyway stays open, because a value you cannot reach is a
/// value you cannot correct.
bool _canOpen(Subject subject) => switch (subject) {
  FieldSubject(:final entry) => entry.field.available || entry.field.anomalous,
  ProficiencySubject() => true,
};

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({required this.subject, this.onTap});

  final Subject subject;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final dimmed = switch (subject) {
      FieldSubject(:final entry) => !entry.field.available,
      ProficiencySubject() => false,
    };
    final (IconData icon, String where) = switch (subject) {
      FieldSubject(:final entry) => (entry.section.icon, entry.where),
      ProficiencySubject() => (
        Icons.military_tech_outlined,
        'Proficiencies',
      ),
    };

    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject.title, style: text.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  where,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                _RowValues(subject: subject),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      label: '${subject.title}, $where',
      child: InkWell(
        onTap: onTap,
        child: dimmed ? ScreenTone(child: body) : body,
      ),
    );
  }
}

class _RowValues extends StatelessWidget {
  const _RowValues({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    switch (subject) {
      case FieldSubject(:final entry):
        final arithmetic = entry.field.arithmetic;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueReadout(field: entry.field),
            if (arithmetic != null) ...[
              const SizedBox(height: 6),
              ArithmeticLine(arithmetic),
            ],
          ],
        );
      case ProficiencySubject(:final proficiency):
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Tag('${proficiency.pips}/${proficiency.maximum}', caption: 'pips'),
            if (proficiency.pips >= proficiency.maximum)
              const Tag('at ceiling', tone: TagTone.muted),
          ],
        );
    }
  }
}

class _PaletteEmpty extends StatelessWidget {
  const _PaletteEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Row(
        children: [
          const Icon(Icons.search_off_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nothing on this record answers to that.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutHint extends StatelessWidget {
  const _ShortcutHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(right: 4),
      child: Tag('Ctrl K', tone: TagTone.muted),
    );
  }
}
