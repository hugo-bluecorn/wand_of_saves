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

/// ⚠️ **THROWAWAY** — see `grid_spike_host.dart`.
///
/// **G2's one search box, and the deepest thing these spikes settle.** G1 keeps
/// two finds — Ctrl+K over the record, a search over the catalogue. G2 commits
/// to the opposite: one box, both corpora, results labelled by kind. Whether
/// that saves a decision or costs one is what looking at it answers, and the
/// question the study could not settle on paper is **result mixing** — typing
/// `strength` matches a field called Strength *and* items whose descriptions
/// mention it.
///
/// ⚠️ **It composes the two searches rather than replacing them.**
/// [subjectsMatching] is the palette's own matcher and `ItemCatalogue.search`
/// is the inventory's own, tiers and withheld count included. Nothing here
/// decides what matches; it decides only how the two lists are shown together.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/item_catalogue.dart';
import 'package:wand_of_saves/ui/character/command_palette.dart';
import 'package:wand_of_saves/ui/character/findings.dart';
import 'package:wand_of_saves/ui/character/sheet_view_model.dart';
import 'package:wand_of_saves/ui/core/tag.dart';

/// One box over the record and the catalogue at once.
class UnifiedFind extends ConsumerWidget {
  /// Searches [character]'s record and the installation's items together.
  const UnifiedFind({
    required this.controller,
    required this.character,
    required this.onSubject,
    required this.onItem,
    required this.onQuery,
    required this.canAdd,
    super.key,
  });

  /// Held by the screen so it can be opened by Ctrl+K.
  final SearchController controller;

  /// The record being searched.
  final SheetCharacter character;

  /// Called with a field or proficiency that was chosen.
  final ValueChanged<Subject> onSubject;

  /// Called with an item that was chosen, to be added to the backpack.
  final ValueChanged<ItemEntry> onItem;

  /// Called with the query that was standing when something was chosen, so the
  /// results cell beside this box keeps showing the same search.
  final ValueChanged<String> onQuery;

  /// Whether there is a free backpack slot to add an item into.
  final bool canAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue =
        ref.watch(itemCatalogueProvider).value ?? ItemCatalogue.empty;
    const hint = 'Find a field, a proficiency or an item…';

    return SearchAnchor(
      searchController: controller,
      isFullScreen: false,
      viewHintText: hint,
      builder: (context, anchor) => SearchBar(
        controller: anchor,
        hintText: hint,
        leading: const Icon(Icons.search),
        trailing: const [
          Padding(
            padding: EdgeInsets.only(right: 4),
            child: Tag('Ctrl K', tone: TagTone.muted),
          ),
        ],
        onTap: anchor.openView,
        onChanged: (_) => anchor.openView(),
      ),
      suggestionsBuilder: (context, anchor) =>
          _suggestions(context, anchor, catalogue),
    );
  }

  Iterable<Widget> _suggestions(
    BuildContext context,
    SearchController anchor,
    ItemCatalogue catalogue,
  ) {
    final query = anchor.text.trim().toLowerCase();
    if (query.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Text(
            'Type to search this character’s record and every item the game '
            'ships, at once.',
          ),
        ),
      ];
    }

    final subjects = subjectsMatching(character, query);
    final items = catalogue.search(query);

    if (subjects.isEmpty && items.results.isEmpty) {
      return [
        const PaletteEmpty(),
        if (items.withheld > 0) _Withheld(count: items.withheld),
      ];
    }

    return [
      // ⚠️ **Both kinds are always headed, even when only one has results.**
      // A list that drops its heading when it is the only one leaves the reader
      // unable to tell which corpus answered — which is the confusion this
      // whole arrangement is on trial for.
      _Kind(
        label: 'On this record',
        count: subjects.length,
        icon: Icons.person_outline,
      ),
      if (subjects.isEmpty)
        const _NothingOfThatKind('No field or proficiency answers to that.'),
      for (final subject in subjects)
        PaletteRow(
          subject: subject,
          onTap: canOpenSubject(subject)
              ? () {
                  anchor.closeView(subject.title);
                  onSubject(subject);
                }
              : null,
        ),
      _Kind(
        label: 'In the item catalogue',
        count: items.results.length,
        icon: Icons.inventory_2_outlined,
      ),
      if (items.results.isEmpty)
        const _NothingOfThatKind('No item answers to that.'),
      for (final result in items.results)
        _ItemRow(
          entry: result.entry,
          how: result.how,
          onTap: canAdd
              ? () {
                  // ⚠️ **Closes on the QUERY, not on the item's name.** Adding
                  // one thing is rarely the whole errand, and rewriting the box
                  // with what was just taken loses the search that found it —
                  // along with the results the column beside it is showing.
                  anchor.closeView(anchor.text);
                  onQuery(anchor.text);
                  onItem(result.entry);
                }
              : null,
        ),
      if (items.withheld > 0) _Withheld(count: items.withheld),
    ];
  }
}

/// Which corpus the rows beneath it came out of.
class _Kind extends StatelessWidget {
  const _Kind({required this.label, required this.count, required this.icon});

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Tag('$count'),
        ],
      ),
    );
  }
}

class _NothingOfThatKind extends StatelessWidget {
  const _NothingOfThatKind(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One item, in the same row shape the record's results use.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.entry, required this.how, this.onTap});

  final ItemEntry entry;
  final ItemMatch how;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: const Icon(Icons.inventory_2_outlined, size: 18),
      title: Text(entry.label),
      subtitle: Text(
        // ⚠️ **Why the row appeared, said on the row.** "Boots of Speed"
        // matches no item name in BG:EE and three descriptions; a reader who
        // cannot see which of the two matched cannot tell a near miss from a
        // hit.
        switch (how) {
          ItemMatch.resref => entry.resref,
          ItemMatch.name => '${entry.resref} · by name',
          ItemMatch.description => '${entry.resref} · only in the description',
        },
        style: theme.textTheme.bodySmall,
      ),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (entry.isCursed) const Tag('cursed', tone: TagTone.muted),
          if (onTap == null)
            const Tag('no room', tone: TagTone.muted)
          else
            const Tag('Add', tone: TagTone.enhanced),
        ],
      ),
    );
  }
}

/// What the catalogue refused to offer, counted rather than shown.
class _Withheld extends StatelessWidget {
  const _Withheld({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Text(
        '$count more ${count == 1 ? "match was" : "matches were"} withheld: '
        'the game will not let ${count == 1 ? "it" : "them"} be moved or '
        'equipped.',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}
