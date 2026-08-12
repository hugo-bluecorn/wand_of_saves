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

/// What the Workbench screens render.
///
/// **A presentation model, not a domain model.** Every value here is already a
/// string, already labelled and already carries its own verdict, because the
/// widgets that draw a character sheet should not be reaching back into
/// `CharacterSheet` and the rules tables to find out whether a number is
/// allowed. `sheet_projection.dart` is the one place that translation happens.
///
/// The shape came from the spike that chose this UI (D15) and is kept
/// deliberately: it was designed against three different renderings of the same
/// character, which is what makes it a fit for more than one of them.
library;

import 'package:flutter/widgets.dart';
import 'package:wand_of_saves/domain/character_stat.dart';

/// Who owns a field's value, which is D14's distinction.
enum FieldSource {
  /// The player wrote it and the engine leaves it alone. Sixty-seven fields.
  authored,

  /// The engine recomputes it on load, so editing is provisional. Six fields.
  derived,
}

/// One editable or readable value on the character sheet.
@immutable
class SheetField {
  /// Creates a field.
  const SheetField(
    this.label,
    this.stored, {
    this.stat,
    this.derived,
    this.inGame,
    this.arithmetic,
    this.caveat,
    this.editable = true,
    this.available = true,
    this.anomalous = false,
    this.source = FieldSource.authored,
    this.unit,
    this.rulesMaximum,
    this.gameMaximum,
  });

  /// What the sheet calls it.
  final String label;

  /// Which stat this row edits, when it edits one.
  ///
  /// ⚠️ **An edit needs an identity, and a label is not one.**
  /// `SetCharacterStat` takes a [CharacterStat]; matching back from the
  /// displayed label would put a string comparison between a keystroke and a
  /// byte, and the sheet has already shown two rows with the same label once.
  /// `null` marks a row displaying something the edit commands do not reach.
  final CharacterStat? stat;

  /// What the file holds. A savegame stores *base* values.
  final String stored;

  /// What the engine draws, when that differs from [stored].
  final String? inGame;

  /// The sum, for the always-visible helper line — never hidden behind a hint.
  final String? arithmetic;

  /// The one thing no number can say. Behind an ⓘ, one short line, and never a
  /// restatement of something already on screen.
  final String? caveat;

  /// Whether this value can be written at all.
  final bool editable;

  /// Whether the class may have it. `false` greys the field — but see
  /// [anomalous]: a stored value overrides this, because a field you cannot
  /// touch is one you cannot correct.
  final bool available;

  /// The record holds a value the class cannot have. Stays editable.
  final bool anomalous;

  /// Who owns it.
  final FieldSource source;

  /// A trailing unit, where one reads better than putting it in the label.
  final String? unit;

  /// What the game's own tables say this value **should** be, or `null` when
  /// they cannot say.
  ///
  /// ⚠️ **Not the same as [stored], and not the same as [inGame].** Three
  /// numbers, and each answers a different question: the file holds [stored],
  /// the rules produce this, and the engine draws [inGame]. Most of the time
  /// the first two agree — but a THAC0 of 25 at level 2 was written, imported,
  /// played and kept against a computed 20, because the engine never recomputes
  /// that field. So "a savegame stores base values" is a rule with exceptions,
  /// and this is how a row can say which it is.
  final int? derived;

  /// The largest value the game's own tables would ever produce here.
  ///
  /// ⚠️ **Not the same as [gameMaximum], and the gap is the whole point.** A
  /// THAC0 of 25 on a level-2 fighter is beyond anything the rules compute —
  /// and it was written into a real save, imported, played and kept, because
  /// the engine never recomputes that field. So "the rules would not produce
  /// this" and "the game will not accept this" are different questions, and
  /// only the second one is a hard limit. That is D16.
  final int? rulesMaximum;

  /// The largest value the engine will accept without correcting or refusing.
  ///
  /// Above this the value is not a choice, it is a corruption.
  final int? gameMaximum;

  /// The stored value as a number, when it is one.
  int? get storedNumber => int.tryParse(stored);

  /// Whether the file holds something other than what the rules produce.
  ///
  /// `false` when the tables cannot say — an unanswered rule is not a
  /// disagreement.
  bool get divergesFromRules {
    final rules = derived;
    final held = storedNumber;
    return rules != null && held != null && rules != held;
  }

  /// Whether [value] is beyond what the rules produce but still playable —
  /// the state a save editor exists to make possible.
  bool beyondRules(String value) {
    final number = int.tryParse(value);
    final limit = rulesMaximum;
    if (number == null || limit == null) return false;
    return number > limit && !impossible(value);
  }

  /// Whether [value] is past what the engine will take at all.
  bool impossible(String value) {
    final number = int.tryParse(value);
    final limit = gameMaximum;
    if (number == null || limit == null) return false;
    return number > limit;
  }

  /// Whether the field accepts input, which is not the same as [available].
  ///
  /// ⚠️ **This depends on the mode, and the exception is the important part.**
  ///
  /// - A value the engine owns is never editable, in either mode.
  /// - **A corrupt value is always editable**, in either mode. A record that
  ///   holds a skill its class cannot allocate can only be repaired by someone
  ///   allowed to touch it, so the rules check must never lock the one field it
  ///   is complaining about. An anomaly you cannot touch is one you cannot
  ///   correct.
  /// - Otherwise the class restriction binds only while the rules do. Turning
  ///   the check off is what lets a Fighter / Mage be given thief skills at
  ///   all — which is the entire reason a save editor exists.
  bool enabledUnder({required bool rulesBind}) {
    if (!editable) return false;
    if (anomalous) return true;
    if (!rulesBind) return true;
    return available;
  }

  /// Whether the field accepts input while the rules bind.
  bool get enabled => enabledUnder(rulesBind: true);

  /// Whether the engine will draw something other than what is stored.
  bool get differsInGame => inGame != null && inGame != stored;
}

/// A titled run of fields.
@immutable
class SheetGroup {
  /// Creates a group.
  const SheetGroup(this.title, this.fields, {this.note});

  /// The heading.
  final String title;

  /// Its fields, in the record's own order.
  final List<SheetField> fields;

  /// An optional one-line qualifier on the whole group.
  final String? note;
}

/// One category of the character sheet — a rail destination.
@immutable
class SheetSection {
  /// Creates a section.
  const SheetSection(this.title, this.icon, this.groups);

  /// The category name.
  final String title;

  /// Its icon.
  final IconData icon;

  /// Its groups, in order.
  final List<SheetGroup> groups;

  /// Every field in the section, flattened.
  List<SheetField> get fields => [for (final g in groups) ...g.fields];
}

/// A weapon proficiency, which on BG:EE is an effect rather than a header byte.
@immutable
class SheetProficiency {
  /// Creates a proficiency.
  const SheetProficiency(
    this.id,
    this.name,
    this.pips,
    this.maximum, {
    this.effectOffset,
  });

  /// Its `weapprof.2da` `ID`, which is the key an edit needs.
  ///
  /// ⚠️ **Not the row label.** BG:EE labels two rows `AXE` and two `SPEAR`.
  final int id;

  /// Its display name — never the `2DA` row label. `FLAILMORNINGSTAR` shipped
  /// once and was a defect.
  final String name;

  /// Pips taken.
  final int pips;

  /// The ceiling the character's own tables allow.
  final int maximum;

  /// Where the opcode 233 effect holding it starts, or `null` when the
  /// character has no effect for this proficiency yet.
  ///
  /// `null` means raising it from zero would **append** an effect, which
  /// resizes the record — so a savegame cannot take it and a `.chr` can.
  final int? effectOffset;

  /// Whether the pips taken exceed what the tables allow.
  bool get over => pips > maximum;
}

/// A character as the Workbench draws them.
@immutable
class SheetCharacter {
  /// Creates a character.
  const SheetCharacter({
    required this.name,
    required this.fileName,
    required this.levelLine,
    required this.identity,
    required this.experienceLine,
    required this.sections,
    required this.proficiencies,
    required this.creOffset,
  });

  /// The character's own name.
  final String name;

  /// The document it lives in.
  final String fileName;

  /// `Level 2/1`, as the engine writes it for a multi-class.
  final String levelLine;

  /// ⚠️ **Four facts, not one sentence.** The engine prints these on separate
  /// lines rather than as `Male · Elf · Fighter / Mage · Neutral Good`.
  final List<String> identity;

  /// What the record screen shows under the portrait.
  final String experienceLine;

  /// The sheet's categories.
  final List<SheetSection> sections;

  /// Its proficiencies — **all of them**, not only the ones with pips.
  ///
  /// A list showing only what is already taken cannot say what else is
  /// available, and choosing one is the whole interaction.
  final List<SheetProficiency> proficiencies;

  /// Where this character's record starts in its document.
  final int creOffset;

  /// Every field on the sheet, flattened.
  List<SheetField> get fields => [for (final s in sections) ...s.fields];

  /// The fields whose stored value the character's class cannot have.
  List<SheetField> get anomalies => [
    for (final field in fields)
      if (field.anomalous) field,
  ];
}
