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

/// The Ledger's row grammar, and the merge that is this spike's whole argument.
///
/// ## The duplication being collapsed
///
/// A capture of the current application's Skills tab prints the **same eight
/// labels twice on one screen** — `Lore`, `Open Locks`, `Find Traps`,
/// `Pick Pockets`, `Move Silently`, `Hide in Shadows`, `Detect Illusion`,
/// `Set Traps` — once under *Points allocated* and again under *What the game
/// shows*, with the helper text `allocated, + Dexterity + race` repeated
/// verbatim seven times. Nothing there is wrong; it is what happens when the
/// distinction between a stored value and a drawn one is expressed as **two
/// tables** instead of as **two columns**.
///
/// [ledgerBlocks] is the alternative. It merges a section's display-only group
/// into the authored rows it restates, so `Lore` appears once carrying both
/// numbers, and drops that group's heading — the `IN GAME` and `OWNER` columns
/// now make the distinction the heading used to. Skills goes from thirteen
/// fields to **eleven rows**, and `Chance to learn a spell`, which has no
/// authored counterpart, survives as a `derived` row in the same table rather
/// than needing a table of its own.
///
/// The rule is general, not a special case for one tab: `Combat` keeps both of
/// its headings and `Character` keeps both of its, because in each of those
/// both groups are authored and there is nothing to collapse.
library;

import 'package:flutter/foundation.dart';
import 'package:ui_spikes/demo/demo_character.dart';

/// One line of a ledger table.
///
/// Sealed so the table's cell logic is an exhaustive switch: adding a fourth
/// kind of row cannot silently fall through to a default that draws it wrong.
sealed class LedgerRow {
  /// Creates a row identified by [id].
  const LedgerRow({required this.id});

  /// Stable across rebuilds, and unique across the whole character — an edit,
  /// a selection and an undo entry are all keyed by it.
  ///
  /// ⚠️ The section title is part of it on purpose. `Lore` is one label in two
  /// groups of the Skills section, and `Armour class` prefixes four rows in
  /// Combat; a bare label is not a key.
  final String id;

  /// What the row is called, which is the leftmost cell.
  String get label;
}

/// A character field: the ordinary row, and about fifty of the sixty on screen.
final class FieldRow extends LedgerRow {
  /// Wraps [field], with whatever its display-only twin contributed.
  const FieldRow({
    required super.id,
    required this.field,
    this.inGame,
    this.arithmetic,
    this.caveat,
  });

  /// The authored field — or, for a display-only field with no authored
  /// counterpart, that field itself. Everything not merged is read through it:
  /// `stored`, `source`, `unit`, `available`, `anomalous`, `enabled`.
  final DemoField field;

  /// What the engine draws, merged from the display-only twin where the
  /// authored field did not already say.
  final String? inGame;

  /// The sum, always visible and never ellipsised.
  ///
  /// ⚠️ The application's own helper line truncates — a capture shows
  /// `stored 12, +4/level from Constit…`. An arithmetic line that cannot be
  /// read is worse than none, because it looks like it has been provided.
  final String? arithmetic;

  /// The one thing no number can say, shown behind the row's ⓘ.
  final String? caveat;

  @override
  String get label => field.label;

  /// Whether the engine will draw something other than what is stored.
  ///
  /// Not [DemoField.differsInGame]: that one cannot see the merge, so it says
  /// `false` for every row whose in-game value arrived from a twin.
  bool get differsInGame => inGame != null && inGame != field.stored;
}

/// A weapon proficiency, whose value is a run of pips against a ceiling.
final class PipRow extends LedgerRow {
  /// Wraps [proficiency].
  const PipRow({required super.id, required this.proficiency});

  /// The proficiency, its pips and its ceiling.
  final DemoProficiency proficiency;

  @override
  String get label => proficiency.name;
}

/// An item, equipped or in the backpack.
final class ItemRow extends LedgerRow {
  /// Wraps [item].
  const ItemRow({required super.id, required this.item});

  /// The item.
  final DemoItem item;

  @override
  String get label => item.name;
}

/// A titled run of rows — what a [DemoGroup] becomes once merged.
@immutable
class LedgerBlock {
  /// Creates a block.
  const LedgerBlock(this.title, this.rows, {this.note});

  /// The heading.
  final String title;

  /// Its rows, in the record's own order.
  final List<LedgerRow> rows;

  /// An optional one-line qualifier on the whole block.
  final String? note;
}

/// What a ledger table's three trailing columns mean.
///
/// The row grammar — gutter, label, three cells, ⓘ — is one widget serving
/// both the character sheet and the backpack. Only the headings differ, so
/// only the headings are a parameter.
enum LedgerColumns {
  /// A character field: what the file holds, what the engine draws, who owns
  /// it.
  fields('STORED', 'IN GAME', 'OWNER'),

  /// An item: how many, how many charges left, and what is flagged about it.
  items('QTY', 'CHARGES', 'FLAGS');

  const LedgerColumns(this.first, this.second, this.third);

  /// The first trailing column's heading.
  final String first;

  /// The second trailing column's heading.
  final String second;

  /// The third trailing column's heading.
  final String third;
}

/// The blocks the Ledger draws for [section], with any display-only group
/// merged into the rows it restates.
///
/// [proficiencies] are appended as a final block when given. They belong to
/// whichever section is about allocated points — pips *are* allocated points —
/// and the caller decides which that is, because nothing in [DemoSection] says.
List<LedgerBlock> ledgerBlocks(
  DemoSection section, {
  List<DemoProficiency> proficiencies = const [],
}) {
  // Two passes, not one. A single forward pass would emit a display-only field
  // as its own row whenever its group came *before* the authored group that
  // claims it, which is an ordering the data is free to have.
  final drawn = <String, DemoField>{};
  final authored = <String>{};
  for (final group in section.groups) {
    final isDisplayOnly = _isDisplayOnly(group);
    for (final field in group.fields) {
      if (isDisplayOnly) {
        drawn[field.label] = field;
      } else {
        authored.add(field.label);
      }
    }
  }

  final drafts = <_Draft>[];
  for (final group in section.groups) {
    if (!_isDisplayOnly(group)) {
      drafts.add(
        _Draft(group.title, group.note)
          ..rows.addAll([
            for (final field in group.fields)
              _rowFor(section, field, drawn[field.label]),
          ]),
      );
      continue;
    }
    // Anything an authored row already claimed has been merged into that row.
    final survivors = [
      for (final field in group.fields)
        if (!authored.contains(field.label)) _rowFor(section, field, null),
    ];
    if (survivors.isEmpty) continue;
    if (drafts.isEmpty) {
      drafts.add(_Draft(group.title, group.note)..rows.addAll(survivors));
      continue;
    }
    drafts.last
      ..rows.addAll(survivors)
      ..absorbed = true;
  }

  return [
    for (final draft in drafts)
      LedgerBlock(draft.heading, draft.rows, note: draft.note),
    if (proficiencies.isNotEmpty)
      LedgerBlock('Weapon proficiencies', [
        for (final proficiency in proficiencies)
          PipRow(
            id: '${section.title}/pips/${proficiency.name}',
            proficiency: proficiency,
          ),
      ]),
  ];
}

/// Whether a group exists only to restate what the engine draws — every field
/// in it derived and none of them writable.
bool _isDisplayOnly(DemoGroup group) =>
    group.fields.isNotEmpty &&
    group.fields.every(
      (field) => field.source == FieldSource.derived && !field.editable,
    );

/// One merged row. The authored field supplies everything structural; its
/// display-only twin supplies the in-game value, and the arithmetic or caveat
/// only where the authored field has none of its own.
FieldRow _rowFor(DemoSection section, DemoField field, DemoField? twin) {
  return FieldRow(
    id: '${section.title}/${field.label}',
    field: field,
    // A twin *is* what the game shows, so its own stored value is this row's
    // in-game one unless it carries an explicit override.
    inGame: field.inGame ?? twin?.inGame ?? twin?.stored,
    arithmetic: field.arithmetic ?? twin?.arithmetic,
    caveat: field.caveat ?? twin?.caveat,
  );
}

/// A block under construction, which needs to be mutable for exactly as long
/// as it takes to discover whether a display-only group folds into it.
class _Draft {
  _Draft(this.title, this.note);

  final String title;
  final String? note;
  final List<LedgerRow> rows = [];

  /// Set when a display-only group's survivors were folded in here.
  bool absorbed = false;

  /// The heading as drawn.
  ///
  /// A group that absorbed one loses its qualifying clause: the data's own
  /// title is `Points allocated, not what the game shows`, and once the table
  /// shows both numbers that heading contradicts the columns beneath it.
  /// Everything up to the first comma is the part that is still true.
  String get heading => absorbed ? title.split(',').first : title;
}
