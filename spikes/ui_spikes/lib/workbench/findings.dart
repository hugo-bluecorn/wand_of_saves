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

/// What this application noticed about the record, and what each sentence is
/// actually *about*.
///
/// `DemoCharacter.anomalies` is three sentences and nothing else. Rather than
/// hard-code an index-to-field table — which would be a lie the moment the
/// data changed — a sentence is linked to its subject **by name**: it is
/// matched against every field label with any parenthetical stripped
/// (`Reputation (party)` → `Reputation`) and against every proficiency name,
/// and the longest match wins.
///
/// Severity is *derived*, never authored: a sentence whose subject is an
/// anomalous field is a conflict, and everything else is a notice. Any
/// anomalous field no sentence names is appended as its own finding, so the
/// list can never miss one.
library;

import 'package:flutter/foundation.dart';
import 'package:ui_spikes/demo/demo_character.dart';

/// How much a [Finding] matters.
enum Severity {
  /// The record holds something the rules do not allow. Drawn in the error
  /// role, and always with the word *conflict* beside it.
  conflict,

  /// Worth knowing, and not wrong. Drawn in the tertiary role.
  notice,
}

/// One field, together with where on the sheet it lives.
///
/// The pair matters: a label on its own does not identify a field. It used to
/// matter more — the sheet listed `Lore` **twice**, once as a stored value and
/// once under a *What the game shows* group — until every row learned to carry
/// stored beside in-game and that second group had nothing left to say.
@immutable
final class FieldEntry {
  /// Records [field] as living in [group] of [section].
  const FieldEntry(this.section, this.group, this.field);

  /// The section it was found in.
  final DemoSection section;

  /// The group within that section.
  final DemoGroup group;

  /// The field itself.
  final DemoField field;

  /// `Skills · Skills` — the subtitle
  /// every palette row carries, and what disambiguates the two `Lore`s.
  String get where => '${section.title} · ${group.title}';

  /// A key that is unique across the whole sheet, which the label is not.
  String get key => '$where · ${field.label}';
}

/// What a [Finding] is about.
sealed class Subject {
  /// Allows subclasses to be const.
  const Subject();

  /// What to call it on screen.
  String get title;
}

/// A finding about one field of the character sheet.
@immutable
final class FieldSubject extends Subject {
  /// Points at [entry].
  const FieldSubject(this.entry);

  /// The field, and where it lives.
  final FieldEntry entry;

  @override
  String get title => entry.field.label;
}

/// A finding about one weapon proficiency.
@immutable
final class ProficiencySubject extends Subject {
  /// Points at [proficiency].
  const ProficiencySubject(this.proficiency);

  /// The proficiency.
  final DemoProficiency proficiency;

  @override
  String get title => proficiency.name;
}

/// A finding about one item, in a slot or in the backpack.
@immutable
final class ItemSubject extends Subject {
  /// Points at [item].
  const ItemSubject(this.item);

  /// The item.
  final DemoItem item;

  @override
  String get title => item.name;
}

/// One sentence this application can say about the record, and the thing that
/// sentence is about.
@immutable
final class Finding {
  /// Creates a finding.
  const Finding({
    required this.severity,
    required this.sentence,
    this.subject,
  });

  /// How much it matters.
  final Severity severity;

  /// The whole sentence, shown wrapping and in full — never truncated.
  final String sentence;

  /// What it is about, when a subject could be resolved.
  final Subject? subject;
}

/// Flattens `section × group × field` into the corpus the palette searches.
List<FieldEntry> indexOf(DemoCharacter character) => [
  for (final section in character.sections)
    for (final group in section.groups)
      for (final field in group.fields) FieldEntry(section, group, field),
];

/// Every finding about [character], conflicts first.
List<Finding> findingsFor(DemoCharacter character) {
  final entries = indexOf(character);
  final findings = <Finding>[];

  for (final sentence in character.anomalies) {
    final subject = _subjectFor(sentence, entries, character.proficiencies);
    findings.add(
      Finding(
        severity: _severityOf(subject),
        sentence: sentence,
        subject: subject,
      ),
    );
  }

  // Anything the record flags that no sentence happened to name still has to
  // appear. The list is allowed to say too much; it is not allowed to miss.
  for (final entry in entries) {
    if (!entry.field.anomalous) continue;
    if (findings.any((finding) => _namesField(finding, entry))) continue;
    findings.add(
      Finding(
        severity: Severity.conflict,
        sentence:
            '${entry.field.label} holds ${entry.field.stored}, which '
            'this class cannot allocate.',
        subject: FieldSubject(entry),
      ),
    );
  }

  return [...findings]
    ..sort((a, b) => a.severity.index.compareTo(b.severity.index));
}

/// Findings built from the item flags themselves, so the inventory screen
/// invents no data of its own.
List<Finding> itemFindingsFor(DemoCharacter character) {
  final findings = <Finding>[];
  for (final item in [...character.equipped, ...character.backpack]) {
    if (!item.identified) {
      findings.add(
        Finding(
          severity: Severity.notice,
          sentence:
              '${item.name} has never been identified, so the game '
              'shows it under its plain name and says nothing about what it '
              'does.',
          subject: ItemSubject(item),
        ),
      );
    }
    if (item.stolen) {
      findings.add(
        Finding(
          severity: Severity.notice,
          sentence:
              '${item.name} is flagged stolen, and every shopkeeper '
              'in the game will refuse to buy it.',
          subject: ItemSubject(item),
        ),
      );
    }
    if (item.undroppable) {
      findings.add(
        Finding(
          severity: Severity.notice,
          sentence:
              '${item.name} cannot be removed in game — only from '
              'here.',
          subject: ItemSubject(item),
        ),
      );
    }
  }
  return findings;
}

bool _namesField(Finding finding, FieldEntry entry) {
  final subject = finding.subject;
  return subject is FieldSubject && subject.entry.key == entry.key;
}

Subject? _subjectFor(
  String sentence,
  List<FieldEntry> entries,
  List<DemoProficiency> proficiencies,
) {
  Subject? best;
  var longest = 0;
  for (final entry in entries) {
    final name = _bareLabel(entry.field.label);
    if (name.length > longest && sentence.contains(name)) {
      best = FieldSubject(entry);
      longest = name.length;
    }
  }
  for (final proficiency in proficiencies) {
    if (proficiency.name.length > longest &&
        sentence.contains(proficiency.name)) {
      best = ProficiencySubject(proficiency);
      longest = proficiency.name.length;
    }
  }
  return best;
}

/// `Reputation (party)` → `Reputation`. A sentence names the thing; the
/// parenthetical belongs to the sheet, which needs it to disambiguate.
String _bareLabel(String label) {
  final open = label.indexOf(' (');
  return open == -1 ? label : label.substring(0, open);
}

Severity _severityOf(Subject? subject) => switch (subject) {
  FieldSubject(:final entry) =>
    entry.field.anomalous ? Severity.conflict : Severity.notice,
  ProficiencySubject() => Severity.notice,
  ItemSubject() => Severity.notice,
  null => Severity.notice,
};
