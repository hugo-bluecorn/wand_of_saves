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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/edit_command.dart';
import 'package:wand_of_saves/domain/rules/character_sheet.dart';
import 'package:wand_of_saves/ui/character/character_file_viewmodel.dart';
import 'package:wand_of_saves/ui/character/character_sheet_view.dart';
import 'package:wand_of_saves/ui/character/findings.dart';
import 'package:wand_of_saves/ui/character/findings_badge.dart';
import 'package:wand_of_saves/ui/character/rules_toggle.dart';
import 'package:wand_of_saves/ui/character/sheet_projection.dart';
import 'package:wand_of_saves/ui/character/sheet_view_model.dart';
import 'package:wand_of_saves/ui/character/side_sheet.dart';
import 'package:wand_of_saves/ui/inventory/inventory_screen.dart';

/// The editor for one exported character.
///
/// Paired 1:1 with [CharacterFileViewModel]. **The same sheet the savegame
/// editor shows** — [CharacterSheetView] takes a projected record and does not
/// know which document it came out of, which is `CreatureDocument`'s promise
/// made good in the UI. Two things are missing because a `.chr` does not have
/// them: the portrait rail, since there is one character and nothing to rail
/// between, and the party's reputation, which no exported character has.
///
/// ⚠️ **A `.chr` is the document that can grow.** Adding a proficiency moves
/// one pointer here against thirty-nine inside a savegame, so this is the
/// screen where resizing edits are safe — the reason export is a primary path
/// and not a convenience.
class CharacterFileView extends ConsumerStatefulWidget {
  /// Opens the character file called [fileName].
  const CharacterFileView({required this.fileName, super.key});

  /// The character file the route named.
  final String fileName;

  @override
  ConsumerState<CharacterFileView> createState() => _CharacterFileViewState();
}

class _CharacterFileViewState extends ConsumerState<CharacterFileView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scroll = ScrollController();

  /// Whether the rules bind, or merely advise. On by default — D16.
  bool _rulesBind = true;

  Subject? _subject;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _open(Subject subject) {
    setState(() => _subject = subject);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openEndDrawer();
    });
  }

  void _closeSheet() {
    _scaffoldKey.currentState?.closeEndDrawer();
    setState(() => _subject = null);
  }

  CharacterFileViewModel get _notifier =>
      ref.read(characterFileProvider(widget.fileName).notifier);

  void _applyField(FieldEntry entry, String value) {
    final stat = entry.field.stat;
    final number = int.tryParse(value);
    final creOffset = _creOffset;
    if (stat == null || number == null || creOffset == null) return;
    _notifier.edit(
      SetCharacterStat(creOffset: creOffset, stat: stat, value: number),
    );
  }

  void _applyPips(SheetProficiency proficiency, int pips) {
    final effectOffset = proficiency.effectOffset;
    final creOffset = _creOffset;
    if (creOffset == null) return;

    // ⚠️ **A `.chr` is the document that can grow, so this is where granting
    // belongs.** Raising a proficiency from zero appends a 264-byte opcode 233
    // effect: **one** pointer here, the length in its 100-byte header, against
    // **thirty-nine** inside a savegame. An earlier version of this method
    // refused it anyway, with a comment saying it was safe, which made every
    // proficiency the record did not already hold inert on the one screen where
    // it is safe to add one.
    _notifier.edit(
      effectOffset == null
          ? GrantProficiency(
              creOffset: creOffset,
              proficiencyId: proficiency.id,
              pips: pips,
            )
          : SetProficiency(
              creOffset: creOffset,
              effectOffset: effectOffset,
              proficiencyId: proficiency.id,
              pips: pips,
            ),
    );
  }

  int? get _creOffset => ref
      .read(characterFileProvider(widget.fileName))
      .value
      ?.character
      .creOffset;

  @override
  Widget build(BuildContext context) {
    final file = ref.watch(characterFileProvider(widget.fileName));
    final state = file.value;
    final notifier = _notifier;
    final sheet = state == null
        ? null
        : sheetCharacterFrom(
            character: state.character,
            sheet: CharacterSheet(
              character: state.character,
              rules: ref.watch(gameRulesProvider),
              proficiencies: state.proficiencies,
              skills: state.skills,
            ),
            fileName: state.file.fileName,
          );
    final subject = _subject;

    return PopScope(
      // Leaving with unsaved edits would discard them silently. The same guard
      // the savegame editor has, for the same reason: this is somebody's
      // character.
      canPop: !(state?.isDirty ?? false),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard(context);
        if (leave && context.mounted) context.pop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        endDrawerEnableOpenDragGesture: false,
        endDrawer: subject == null || sheet == null
            ? null
            : SideSheet(
                key: ValueKey<String>(
                  '${subject.runtimeType}:${subject.title}',
                ),
                subject: subject,
                character: sheet,
                rulesBind: _rulesBind,
                onApplyField: _applyField,
                onApplyPips: _applyPips,
                onClose: _closeSheet,
              ),
        appBar: AppBar(
          // ⚠️ **The file, not the character.** The savegame editor's bar names
          // the save while the sheet below names the character, and this is the
          // same division: the sheet already says "Aurel" in headline type, so
          // repeating it here says nothing and loses the one fact the bar can
          // add. The two really are different — `Aard1.chr` holds a character
          // called `Aard`, and a player with two exports of one character has
          // only the file name to tell them apart.
          title: Text(
            '${state?.file.fileName ?? widget.fileName}'
            '${(state?.isDirty ?? false) ? ' •' : ''}',
          ),
          actions: [
            if (sheet != null)
              FindingsBadge(findings: findingsFor(sheet), onPressed: null),
            const SizedBox(width: 8),
            // ⚠️ **D16 reaches this screen too.** A rules check present on the
            // savegame editor and absent here would be the same rule wired to
            // one surface of two — which this project has shipped twice.
            RulesToggle(
              binding: _rulesBind,
              onChanged: (value) => setState(() => _rulesBind = value),
            ),
            const SizedBox(width: 8),
            // ⚠️ **The same icon the savegame editor has.** Both documents take
            // the same edits; a `.chr` being the less capable surface would
            // invert every other feature in this application.
            if (state?.character case final Character character)
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => InventoryScreen(
                      character: () =>
                          ref
                              .watch(characterFileProvider(widget.fileName))
                              .value
                              ?.character ??
                          character,
                      onAdd: (resref, slot) => notifier.edit(
                        AddItem(
                          creOffset: character.creOffset,
                          resref: resref,
                          slot: slot,
                        ),
                      ),
                    ),
                  ),
                ),
                icon: const Icon(Icons.backpack_outlined),
                tooltip: 'Inventory',
              ),
            IconButton(
              onPressed: (state?.canUndo ?? false) ? notifier.undo : null,
              icon: const Icon(Icons.undo),
              tooltip: 'Undo',
            ),
            IconButton(
              onPressed: (state?.canRedo ?? false) ? notifier.redo : null,
              icon: const Icon(Icons.redo),
              tooltip: 'Redo',
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: (state?.isDirty ?? false) ? notifier.save : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: file.when(
          data: (_) => sheet == null
              ? const SizedBox.shrink()
              : Scrollbar(
                  controller: _scroll,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: CharacterSheetView(
                          character: sheet,
                          rulesBind: _rulesBind,
                          onOpen: _open,
                        ),
                      ),
                    ),
                  ),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _LoadFailed(error: error),
        ),
      ),
    );
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave without saving?'),
        content: const Text(
          'This character has changes that are not written to disk yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard changes'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colors.error),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
