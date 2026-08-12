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

/// Spells, on their own screen beside the inventory.
///
/// ## Why here rather than a panel on the sheet
///
/// A spellbook has the **same shape as the inventory** — a catalogue you pick
/// from, a set of slots you fill, and a picker between them. Memorisation slots
/// are the paper doll; the book is the backpack. A level-9 mage carries nine
/// spell levels of both, which is not a panel.
///
/// ## Arcane and divine are different, and a character can be both
///
/// ⚠️ **A cleric has no spellbook.** Every spell of a level they can cast is
/// available to them, and they memorise straight from that list. A mage must
/// *learn* a spell into the book first — gated by the chance to learn, which
/// sits on the character sheet's Abilities panel — and may only memorise what
/// the book holds. A **Cleric / Mage** needs both sets of rules at once, so
/// this screen draws one section per caster rather than one per character.
///
/// ## What the rules check has to say here
///
/// Three things, and none of them is a range:
///
/// - **Slots are per spell level**, never a total. Four first-level slots do
///   not help a second-level spell.
/// - **A specialist may not learn their forbidden school.** That flag lives in
///   each spell rather than in a table.
/// - **A mage cannot memorise what is not in the book**, which is the one rule
///   with no equivalent on the divine side.
library;

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/workbench/panel_card.dart';
import 'package:ui_spikes/workbench/tag.dart';

/// The spells of every caster class this character has.
class SpellsScreen extends StatefulWidget {
  /// Opens [character]'s spells.
  const SpellsScreen({
    required this.character,
    required this.rulesBind,
    super.key,
  });

  /// The record being worked on.
  final DemoCharacter character;

  /// Whether the rules bind — slots, the book, and the forbidden school.
  final bool rulesBind;

  @override
  State<SpellsScreen> createState() => _SpellsScreenState();
}

class _SpellsScreenState extends State<SpellsScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final books = widget.character.spellbooks;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.character.name} · Spells')),
      body: books.isEmpty
          ? const _NoCaster()
          : Scrollbar(
              controller: _scroll,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final book in books) ...[
                          _Caster(book: book, rulesBind: widget.rulesBind),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _NoCaster extends StatelessWidget {
  const _NoCaster();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Text(
          'This character casts nothing. A fighter or a thief has no spells '
          'at all — which is an ordinary state and not an empty list.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// One caster class: what is memorised, then what may be memorised from.
class _Caster extends StatelessWidget {
  const _Caster({required this.book, required this.rulesBind});

  final DemoSpellbook book;
  final bool rulesBind;

  @override
  Widget build(BuildContext context) {
    final levels = [
      for (var level = 1; level <= book.slotsPerLevel.length; level++) level,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final level in levels) ...[
          _MemorisedLevel(book: book, level: level, rulesBind: rulesBind),
          const SizedBox(height: 20),
        ],
        _Castable(book: book, rulesBind: rulesBind),
      ],
    );
  }
}

/// The slots at one spell level, filled and empty.
class _MemorisedLevel extends StatelessWidget {
  const _MemorisedLevel({
    required this.book,
    required this.level,
    required this.rulesBind,
  });

  final DemoSpellbook book;
  final int level;
  final bool rulesBind;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final slots = book.slotsAt(level);
    final filled = book.filledAt(level);
    final ready = book.memorised.where((s) => s.level == level).toList();
    final full = rulesBind && filled >= slots;

    return PanelCard(
      title: '${book.caster} · level $level memorised',
      note: rulesBind
          ? full
                ? 'Every slot at this level is taken. Slots are counted per '
                      'level, so a spare elsewhere does not help here.'
                : '${slots - filled} of $slots still open at this level.'
          : 'Slots are not being counted.',
      trailing: Tag(
        '$filled/$slots',
        tone: full ? TagTone.conflict : TagTone.neutral,
      ),
      children: [
        for (final spell in ready)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_awesome),
            title: Text(spell.name, style: text.bodyLarge),
            subtitle: spell.note == null ? null : Text(spell.note!),
            trailing: IconButton(
              onPressed: () {},
              tooltip: 'Forget ${spell.name}',
              icon: const Icon(Icons.close),
            ),
          ),
        for (var i = filled; i < slots; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.add_circle_outline,
              color: colors.onSurfaceVariant,
            ),
            title: Text(
              'Empty slot',
              style: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// What this caster may memorise from — the book, or everything they can cast.
class _Castable extends StatelessWidget {
  const _Castable({required this.book, required this.rulesBind});

  final DemoSpellbook book;
  final bool rulesBind;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final known = {for (final spell in book.known) spell.name};

    return PanelCard(
      title: book.learnsIntoBook
          ? '${book.caster} · spellbook'
          : '${book.caster} · available',
      note: book.learnsIntoBook
          ? 'A mage may only memorise what the book holds. Learning a spell '
                'into it is a separate act, and it can fail.'
          : 'A cleric keeps no book — every spell of a level they can cast is '
                'available to them.',
      children: [
        for (final spell in book.available)
          Builder(
            builder: (context) {
              final inBook = !book.learnsIntoBook || known.contains(spell.name);
              final forbidden =
                  book.forbiddenSchool != null &&
                  spell.school == book.forbiddenSchool;
              // While the rules bind, a mage cannot reach past the book and a
              // specialist cannot reach their forbidden school at all. With
              // the check off both open — which is the same bargain the rest
              // of the application makes.
              final live = !rulesBind || (inBook && !forbidden);
              return Opacity(
                opacity: live ? 1 : 0.45,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    inBook ? Icons.menu_book : Icons.menu_book_outlined,
                    color: inBook ? null : colors.onSurfaceVariant,
                  ),
                  title: Row(
                    children: [
                      Flexible(child: Text(spell.name, style: text.bodyLarge)),
                      const SizedBox(width: 8),
                      if (forbidden)
                        const Tag('forbidden school', tone: TagTone.conflict)
                      else if (!inBook)
                        Tag(
                          rulesBind ? 'not in the book' : 'beyond the book',
                          tone: rulesBind ? TagTone.muted : TagTone.enhanced,
                        ),
                    ],
                  ),
                  subtitle: Text(
                    spell.school == null
                        ? spell.note ?? ''
                        : '${spell.school} · ${spell.note ?? ''}',
                  ),
                  trailing: live
                      ? TextButton(
                          onPressed: () {},
                          child: const Text('Memorise'),
                        )
                      : null,
                ),
              );
            },
          ),
      ],
    );
  }
}
