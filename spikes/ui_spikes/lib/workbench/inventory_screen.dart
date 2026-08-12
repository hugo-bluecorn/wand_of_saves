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
import 'package:flutter/services.dart';
import 'package:ui_spikes/demo/boot.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/workbench/command_palette.dart';
import 'package:ui_spikes/workbench/findings.dart';
import 'package:ui_spikes/workbench/findings_badge.dart';
import 'package:ui_spikes/workbench/panel_card.dart';
import 'package:ui_spikes/workbench/side_sheet.dart';
import 'package:ui_spikes/workbench/tag.dart';

/// The inventory: a list you can read, and a picker that is one text field.
///
/// The findings card here is built from the item flags themselves rather than
/// from anything authored — unidentified, stolen, undroppable are all facts
/// the record already carries, so the screen can say them without inventing
/// data.
///
/// Opening a slot opens the picker. The application this replaces used a
/// modal dialog with fifty-one controls for the same job; here it is the
/// side sheet, one filter field and the backpack.
class InventoryScreen extends StatefulWidget {
  /// Opens [character]'s inventory.
  const InventoryScreen({required this.character, super.key});

  /// The record being worked on.
  final DemoCharacter character;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SearchController _palette = SearchController();
  final ScrollController _scroll = ScrollController();
  final Map<String, String> _replacements = <String, String>{};
  Subject? _subject;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _palette.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _boot() {
    if (!mounted) return;
    switch (requestedTab) {
      case 1:
        _palette
          ..text = 'pot'
          ..openView();
      case 2:
        _open(_slotNamed('Main hand'));
    }
  }

  Subject? _slotNamed(String slot) {
    for (final item in widget.character.equipped) {
      if (item.slot == slot) return ItemSubject(item);
    }
    return null;
  }

  void _open(Subject? subject) {
    if (subject == null || !mounted) return;
    setState(() => _subject = subject);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openEndDrawer();
    });
  }

  void _closeSheet() {
    _scaffoldKey.currentState?.closeEndDrawer();
    setState(() => _subject = null);
  }

  void _stageItem(DemoItem item, DemoItem? replacement, int quantity) {
    setState(() {
      final slot = item.slot ?? item.name;
      if (replacement == null) {
        _replacements.remove(slot);
      } else {
        _replacements[slot] = replacement.name;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final character = widget.character;
    final subject = _subject;
    final findings = itemFindingsFor(character);

    return Scaffold(
      key: _scaffoldKey,
      endDrawerEnableOpenDragGesture: false,
      endDrawer: subject == null
          ? null
          : SideSheet(
              key: ValueKey<String>('item:${subject.title}'),
              subject: subject,
              character: character,
              // No field is editable from here — the sheet opens on items —
              // so there is nothing for the check to bind. The parameter is
              // required rather than defaulted so a field added later cannot
              // slip past it unnoticed.
              rulesBind: true,
              // No proficiency is reachable from the inventory sheet either,
              // so no slot can be spent here.
              slotsLeft: 0,
              onApplyField: (_, _) => _closeSheet(),
              onApplyPips: (_, _) => _closeSheet(),
              onApplyItem: _stageItem,
              onClose: _closeSheet,
            ),
      appBar: AppBar(
        title: Text('${character.name} · Inventory'),
        actions: [
          // The count travels; the panel does not. Tapping goes back to
          // the screen that owns the list rather than growing a second one.
          FindingsBadge(
            findings: findingsFor(character),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
          if (_replacements.isNotEmpty)
            Tag(
              _replacements.length == 1
                  ? '1 change'
                  : '${_replacements.length} changes',
              caption: 'not written yet',
              tone: TagTone.inGame,
            ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _replacements.isEmpty ? null : () {},
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyK, control: true):
              _palette.openView,
        },
        child: Focus(
          autofocus: true,
          child: Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${character.equipped.length} equipped · '
                        '${character.backpack.length} in the backpack',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      CommandPalette(
                        controller: _palette,
                        character: character,
                        onSelected: _open,
                        itemsOnly: true,
                      ),
                      const SizedBox(height: 24),
                      if (findings.isNotEmpty) ...[
                        _ItemFindings(
                          findings: findings,
                          onOpen: _open,
                        ),
                        const SizedBox(height: 20),
                      ],
                      PanelCard(
                        title: 'Equipped',
                        note:
                            'A slot opens its picker. Nothing is written '
                            'until you save.',
                        children: [
                          for (final item in character.equipped)
                            _SlotRow(
                              item: item,
                              pending: _replacements[item.slot],
                              onTap: () => _open(ItemSubject(item)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      PanelCard(
                        title: 'Backpack',
                        children: [
                          for (final item in character.backpack)
                            _BackpackRow(
                              item: item,
                              onTap: () => _open(ItemSubject(item)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemFindings extends StatelessWidget {
  const _ItemFindings({required this.findings, required this.onOpen});

  final List<Finding> findings;
  final ValueChanged<Subject> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PanelCard(
      title: 'What this app noticed',
      note: 'Read off the items themselves — nothing here is authored.',
      children: [
        for (final finding in findings)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 10),
                  child: SizedBox(
                    width: 8,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(finding.sentence, style: text.bodyLarge),
                ),
                const SizedBox(width: 8),
                if (finding.subject case final subject?)
                  TextButton(
                    onPressed: () => onOpen(subject),
                    child: const Text('Open'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.item, required this.onTap, this.pending});

  final DemoItem item;
  final VoidCallback onTap;
  final String? pending;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final replacement = pending;
    return Semantics(
      button: true,
      label: '${item.slot}, ${item.name}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  item.slot ?? '',
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: Text(
                  replacement == null
                      ? item.name
                      : '${item.name} → $replacement',
                  style: text.bodyLarge,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: _ItemTags(item: item, pending: replacement != null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackpackRow extends StatelessWidget {
  const _BackpackRow({required this.item, required this.onTap});

  final DemoItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.name,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Text(
                  item.name,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: _ItemTags(item: item, pending: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemTags extends StatelessWidget {
  const _ItemTags({required this.item, required this.pending});

  final DemoItem item;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (pending) const Tag('not written yet', tone: TagTone.muted),
        if (item.quantity > 1) Tag('${item.quantity}', caption: 'quantity'),
        if (item.charges case final charges?)
          Tag('$charges', caption: 'charges'),
        if (!item.identified) const Tag('unidentified', tone: TagTone.muted),
        if (item.stolen) const Tag('stolen', tone: TagTone.conflict),
        if (item.undroppable)
          const Tag('cannot be dropped', tone: TagTone.muted),
      ],
    );
  }
}
