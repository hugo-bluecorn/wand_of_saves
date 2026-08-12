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

/// The static character every spike renders, and the shape it is rendered in.
///
/// ⚠️ **The numbers are the engine's own, not invented.** They are copied field
/// for field from `docs/findings/screens/level-up/03-record-after-level-2.png`
/// — a BG:EE record screen for Aard, a Fighter 2 / Mage 1. A spike fed tidy
/// made-up data does not reproduce the defects that have actually bitten this
/// project: 148 px truncated `Exceptional strength`, and 190 px truncated
/// `Paralysis / Poison / Death` to `Paralysis / Poison / De…`. Both strings are
/// in here deliberately, and any layout that cannot hold them has failed.
///
/// **Nothing here touches the disk.** No repositories, no providers, no game
/// installation — a spike must boot instantly on any machine and be about
/// layout rather than plumbing.
library;

import 'package:flutter/widgets.dart';

/// Who owns a field's value, which is D14's distinction.
enum FieldSource {
  /// The player wrote it and the engine leaves it alone. 67 fields.
  authored,

  /// The engine recomputes it, so editing is provisional. 6 fields.
  derived,
}

/// One editable or readable value on the character sheet.
@immutable
class DemoField {
  /// Creates a field.
  const DemoField(
    this.label,
    this.stored, {
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

  /// The largest value the game's own tables would ever produce here.
  ///
  /// ⚠️ **Not the same as [gameMaximum], and the gap is the whole point.** A
  /// THAC0 of 25 on a level-2 fighter is beyond anything the rules compute —
  /// and it was written into a real save, imported, played and kept, because
  /// the engine never recomputes that field. So "the rules would not produce
  /// this" and "the game will not accept this" are different questions, and
  /// only the second one is a hard limit.
  final int? rulesMaximum;

  /// The largest value the engine will accept without correcting or refusing.
  ///
  /// Above this the value is not a choice, it is a corruption.
  final int? gameMaximum;

  /// The stored value as a number, when it is one.
  int? get storedNumber => int.tryParse(stored);

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
class DemoGroup {
  /// Creates a group.
  const DemoGroup(this.title, this.fields, {this.note});

  /// The heading.
  final String title;

  /// Its fields, in the record's own order.
  final List<DemoField> fields;

  /// An optional one-line qualifier on the whole group.
  final String? note;
}

/// One category of the character sheet — a tab, a rail destination or a
/// document section, depending on which spike is drawing it.
@immutable
class DemoSection {
  /// Creates a section.
  const DemoSection(this.title, this.icon, this.groups);

  /// The category name.
  final String title;

  /// Its icon, for the spikes that use one.
  final IconData icon;

  /// Its groups, in order.
  final List<DemoGroup> groups;

  /// Every field in the section, flattened.
  List<DemoField> get fields => [for (final g in groups) ...g.fields];
}

/// A weapon proficiency, which on BG:EE is an effect rather than a header byte.
@immutable
class DemoProficiency {
  /// Creates a proficiency.
  const DemoProficiency(this.name, this.pips, this.maximum);

  /// Its display name — never the `2DA` row label. `FLAILMORNINGSTAR` shipped
  /// once and was a defect.
  final String name;

  /// Pips taken.
  final int pips;

  /// The ceiling: `min(profsmax.FIRST_LEVEL, weapprof[column])`.
  final int maximum;
}

/// One spell, in a book or in a memorisation slot.
@immutable
class DemoSpell {
  /// Creates a spell.
  const DemoSpell(this.name, this.level, {this.school, this.note});

  /// What the game calls it.
  final String name;

  /// Which spell level it occupies. Slots are counted per level, never in
  /// total, so this is not decoration.
  final int level;

  /// Its school, for arcane spells. Divine spells have none.
  ///
  /// ⚠️ **A specialist's forbidden school lives in each spell**, not in a
  /// table: exclusion flags at `0x1E` of the `SPL`, bit = the school's row + 5.
  /// So a Necromancer cannot learn an Illusion spell, and the rule is a
  /// property of the spell rather than of the character.
  final String? school;

  /// One line on what it does, for the picker.
  final String? note;
}

/// One caster class's spells. A character can have more than one.
///
/// ⚠️ **Arcane and divine are different shapes, and this application will meet
/// a character who is both.** A mage *learns* spells into a book, gated by the
/// chance to learn, and memorises from what is in it. A cleric has no book at
/// all — every spell of a level they can cast is available, and they memorise
/// straight from the full list. A Cleric / Mage needs both sets of rules at
/// once, which is why this hangs off the caster rather than off the character.
@immutable
class DemoSpellbook {
  /// Creates a caster's spells.
  const DemoSpellbook({
    required this.caster,
    required this.learnsIntoBook,
    required this.slotsPerLevel,
    required this.available,
    required this.memorised,
    this.known = const [],
    this.forbiddenSchool,
  });

  /// The class that casts them — `Mage`, `Cleric`.
  final String caster;

  /// Whether spells must be learned into a book before they can be memorised.
  /// True for arcane, false for divine.
  final bool learnsIntoBook;

  /// Memorisation slots, indexed by spell level minus one.
  final List<int> slotsPerLevel;

  /// Every spell this caster could have at their level.
  final List<DemoSpell> available;

  /// What is in the book. Empty for a divine caster, who needs no book.
  final List<DemoSpell> known;

  /// What is memorised and ready to cast.
  final List<DemoSpell> memorised;

  /// The school a specialist may never learn.
  final String? forbiddenSchool;

  /// What this caster may memorise from — the book for a mage, everything
  /// they can cast for a cleric.
  List<DemoSpell> get castable => learnsIntoBook ? known : available;

  /// How many slots this caster has at [level].
  int slotsAt(int level) =>
      level <= slotsPerLevel.length ? slotsPerLevel[level - 1] : 0;

  /// How many of those slots are filled.
  int filledAt(int level) =>
      memorised.where((spell) => spell.level == level).length;
}

/// One item, in a slot or in the backpack.
@immutable
class DemoItem {
  /// Creates an item.
  const DemoItem(
    this.name, {
    this.slot,
    this.quantity = 1,
    this.charges,
    this.identified = true,
    this.stolen = false,
    this.undroppable = false,
  });

  /// What the game calls it.
  final String name;

  /// The equipped slot's name, or null when it is loose in the backpack.
  final String? slot;

  /// Stack size.
  final int quantity;

  /// Remaining charges, for wands and the like.
  final int? charges;

  /// Whether the player has identified it.
  final bool identified;

  /// Whether it is flagged stolen.
  final bool stolen;

  /// Whether it can be removed.
  final bool undroppable;
}

/// One savegame in the lineup.
///
/// ⚠️ **These are the three real slots in the installation**, not invented
/// ones — including the fact that `Prologue Start` has **no `BALDUR.bmp`**.
/// That absence is the shape the real data has: a save written before the
/// engine had a screen worth keeping simply has no screenshot, and an app that
/// only ever sees tidy fixtures draws a broken-image icon over an ordinary
/// absence. It has been that defect once already.
@immutable
class DemoSave {
  /// Creates a save slot.
  const DemoSave({
    required this.slot,
    required this.label,
    required this.lead,
    required this.party,
    required this.location,
    required this.saved,
    this.screenshot,
  });

  /// The directory name, as the engine writes it: `000000020-Arduin Start`.
  final String slot;

  /// What a person calls it, with the numeric prefix taken off.
  final String label;

  /// The protagonist.
  final String lead;

  /// How many characters are in the party, the protagonist included.
  final int party;

  /// Where the party was standing.
  final String location;

  /// When the engine wrote it.
  final String saved;

  /// The base name of the screenshot in `SPIKE_ART`, or null when the slot
  /// genuinely has none. See the warning on this class.
  final String? screenshot;
}

/// The lineup of savegames, beside the characters.
const List<DemoSave> demoSaves = [
  DemoSave(
    slot: '000000020-Arduin Start',
    label: 'Arduin Start',
    lead: 'Arduin',
    party: 1,
    location: 'Candlekeep',
    saved: 'Today, 14:56',
    screenshot: 'save-arduin',
  ),
  DemoSave(
    slot: '000000007-Prologue Start',
    label: 'Prologue Start',
    lead: 'Arduin',
    party: 1,
    location: 'Candlekeep',
    saved: 'Today, 14:54',
  ),
  DemoSave(
    slot: '000000000-Auto-Save',
    label: 'Auto-Save',
    lead: 'Arduin',
    party: 1,
    location: 'Candlekeep',
    saved: 'Today, 14:54',
    screenshot: 'save-auto',
  ),
];

/// The whole character a spike draws.
@immutable
class DemoCharacter {
  /// Creates a character.
  const DemoCharacter({
    required this.name,
    required this.fileName,
    required this.levelLine,
    required this.identity,
    required this.experienceLine,
    required this.sections,
    required this.proficiencies,
    required this.equipped,
    required this.backpack,
    required this.anomalies,
    this.proficiencySlots = 0,
    this.spellbooks = const [],
  });

  /// The character's own name.
  final String name;

  /// The document it lives in.
  final String fileName;

  /// `Level 2/1`, as the engine writes it for a multi-class.
  final String levelLine;

  /// ⚠️ **Four facts, not one sentence.** The engine prints these on separate
  /// lines; this app concatenates them into
  /// `Level 1/1 · Male · Elf · Fighter / Mage · Neutral Good`. Each spike may
  /// do either, and the difference is worth seeing.
  final List<String> identity;

  /// What the record screen shows under the portrait.
  final String experienceLine;

  /// The sheet's categories.
  final List<DemoSection> sections;

  /// Its proficiencies — **all of them**, not only the ones with pips.
  ///
  /// A list showing only what is already taken cannot say what else is
  /// available, and choosing one is the whole interaction.
  final List<DemoProficiency> proficiencies;

  /// Every caster class this character has. Empty for a pure warrior or
  /// thief; two for a Cleric / Mage.
  final List<DemoSpellbook> spellbooks;

  /// How many pips the character has to spend in total.
  ///
  /// ⚠️ **A budget, not a per-row limit.** The engine grants slots by class
  /// and level — BG:EE's own creation screen prints `PROFICIENCY SLOTS 4` —
  /// and they are spent across every weapon. So a row can be at its own
  /// ceiling and still be unavailable because nothing is left, and freeing one
  /// pip anywhere makes every row available again.
  final int proficiencySlots;

  /// Items in slots.
  final List<DemoItem> equipped;

  /// Items loose in the backpack.
  final List<DemoItem> backpack;

  /// What this app knows is odd about the record. The Workbench spike makes
  /// this a first-class surface; the others need it to render an anomalous
  /// field honestly.
  final List<String> anomalies;

  /// Every field on the sheet, flattened.
  List<DemoField> get allFields => [
    for (final s in sections) ...s.fields,
  ];
}
