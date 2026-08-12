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
/// about.
///
/// **Every finding is derived from the record, never authored.** The spike this
/// came from carried hand-written sentences and matched each one back to its
/// field by longest-label-match — necessary there, because the demo character's
/// prose was written by hand. With a real character there is no prose to match:
/// an anomalous field *is* the finding, and its sentence is composed from the
/// field. That deletes the matching entirely, along with the class of bug where
/// a sentence silently stops naming the field it is about.
///
/// Severity is derived too. A field whose stored value its class cannot
/// allocate is a **conflict**; a proficiency above its ceiling is a conflict;
/// everything else is a **notice**.
library;

import 'package:flutter/foundation.dart';
import 'package:wand_of_saves/ui/character/sheet_view_model.dart';

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
/// The pair matters: **a label on its own does not identify a field.** It used
/// to matter more — the sheet listed `Lore` twice, once as a stored value and
/// once under a *What the game shows* group — until every row learned to carry
/// stored beside in-game and that second group had nothing left to say.
@immutable
final class FieldEntry {
  /// Records [field] as living in [group] of [section].
  const FieldEntry(this.section, this.group, this.field);

  /// The section it was found in.
  final SheetSection section;

  /// The group within that section.
  final SheetGroup group;

  /// The field itself.
  final SheetField field;

  /// `Skills · Skills` — the subtitle every row carries.
  String get where => '${section.title} · ${group.title}';

  /// A key unique across the whole sheet, which the label is not.
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
  final SheetProficiency proficiency;

  @override
  String get title => proficiency.name;
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

/// Flattens `section × group × field` into the corpus a search reads.
List<FieldEntry> indexOf(SheetCharacter character) => [
  for (final section in character.sections)
    for (final group in section.groups)
      for (final field in group.fields) FieldEntry(section, group, field),
];

/// Every finding about [character], conflicts first.
///
/// Two sources, both read off the record:
///
/// 1. **A field the class cannot allocate but the record holds anyway.** This
///    is the case the editor exists for — the value stays editable so it can be
///    corrected, and saying so is what stops it looking like a rendering bug.
/// 2. **A proficiency above the ceiling its own tables give it.** Measured in
///    game: BG:EE refuses a thief a second pip with a slot still unspent, so a
///    record holding two is beyond the rules however it got there.
///
/// ⚠️ **"Stored differs from in game" is NOT a finding, and briefly was.**
/// Every row already carries `stored 7` beside `in game 11`, so a sentence
/// saying so underneath restated the chips above it, doubled the height of half
/// the sheet, and drew a marker bar down rows where nothing is wrong. It made
/// the badge useless: a healthy first-level character read **13**, so a number
/// meant to mean *look at this* meant *this record has values in it*. Only
/// looking at a capture showed it — the logic was correct and the screen was
/// unreadable.
List<Finding> findingsFor(SheetCharacter character) {
  final findings = <Finding>[
    for (final entry in indexOf(character))
      if (entry.field.anomalous)
        Finding(
          severity: Severity.conflict,
          sentence:
              '${entry.field.label} holds ${entry.field.stored}, which this '
              'class cannot allocate.',
          subject: FieldSubject(entry),
        ),
    for (final proficiency in character.proficiencies)
      if (proficiency.over)
        Finding(
          severity: Severity.conflict,
          sentence:
              '${proficiency.name} holds ${proficiency.pips} pips, above the '
              '${proficiency.maximum} this character may have.',
          subject: ProficiencySubject(proficiency),
        ),
  ];

  return [...findings]
    ..sort((a, b) => a.severity.index.compareTo(b.severity.index));
}

/// How many of [findings] are conflicts.
int conflictCount(List<Finding> findings) =>
    findings.where((f) => f.severity == Severity.conflict).length;
