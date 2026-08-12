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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ui_spikes/demo/boot.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/workbench/arithmetic_line.dart';
import 'package:ui_spikes/workbench/command_palette.dart';
import 'package:ui_spikes/workbench/findings.dart';
import 'package:ui_spikes/workbench/findings_badge.dart';
import 'package:ui_spikes/workbench/inventory_screen.dart';
import 'package:ui_spikes/workbench/palette_finish.dart';
import 'package:ui_spikes/workbench/panel_card.dart';
import 'package:ui_spikes/workbench/pip_meter.dart';
import 'package:ui_spikes/workbench/screen_tone.dart';
import 'package:ui_spikes/workbench/side_sheet.dart';
import 'package:ui_spikes/workbench/spells_screen.dart';
import 'package:ui_spikes/workbench/tag.dart';
import 'package:ui_spikes/workbench/value_readout.dart';

/// The workbench: the whole record, with what is wrong with it marked in
/// place.
///
/// **No tabs and no rail** — one sheet, panels balanced across two columns,
/// with a command palette for reaching a field by name rather than by
/// scrolling to it.
///
/// ⚠️ **Two things here used to be different and the reasons are worth
/// keeping**, because both were changed after looking rather than after
/// arguing:
///
/// - It drew **thirteen of fifty-three** values and kept the rest behind the
///   palette. That lost twice over: this is an *editor*, and a reader who
///   opens a record wants the record; and findings are marked in place, so a
///   hidden field is a mark nobody can see.
/// - Findings were a **column on the right**. That made them second on a wide
///   window and dropped them below every value panel on a narrow one — the
///   opposite of what they are for. They are now marked on the field itself,
///   and the sentence sits under the value it is about rather than repeating
///   the field's name to say where to look.
///
/// What survives from that column is the behaviour: stage an edit that answers
/// a finding and the mark says *will be corrected* instead of continuing to
/// accuse.
class CharacterScreen extends StatefulWidget {
  /// Opens [character] on the workbench.
  const CharacterScreen({required this.character, super.key});

  /// The record being worked on.
  final DemoCharacter character;

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SearchController _palette = SearchController();
  // ⚠️ Explicit, and shared with the scroll view. `thumbVisibility` asserts a
  // controller with an attached position, and desktop has no
  // `PrimaryScrollController` to fall back on.
  final ScrollController _scroll = ScrollController();
  /// Whether the rules bind, or merely advise. On by default.
  ///
  /// ⚠️ **It never blocks a keystroke.** This project's own rule is that an
  /// anomaly you cannot touch is one you cannot correct, so the field always
  /// accepts input; what the check governs is whether Save is allowed.
  bool _rulesBind = true;
  final Map<String, String> _pendingFields = <String, String>{};
  final Map<String, int> _pendingPips = <String, int>{};
  Subject? _subject;

  @override
  void initState() {
    super.initState();
    // ⚠️ Nothing on this machine can drive the pointer, so the boot state is
    // the screenshot. `openView()` asserts the anchor is attached, which it
    // only is once the first frame has laid the bar out — hence the callback.
    // Setting the text *before* opening means the view builds its filtered
    // suggestions on the opening frame rather than an empty list.
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
    if (requestedScroll > 0 && _scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent * requestedScroll);
    }
    switch (requestedTab) {
      case 1:
        _palette
          ..text = 'ac'
          ..openView();
      case 2:
        _open(_fieldNamed('Reputation (party)'));
      case 3:
        _open(_fieldNamed('Tracking'));
      case 4:
        _palette.openView();
      // 5 and 6 are the same edit under the two modes: Strength 22, which the
      // rules never reach (18 is the ceiling at creation) and the engine takes
      // without complaint (it draws and applies up to 25). Nothing here can
      // drive the pointer, so the mode has to be booted into.
      case 5:
        _stageNamed('Strength', '22');
      case 6:
        setState(() => _rulesBind = false);
        _stageNamed('Strength', '22');
      // 7 is the same 22 seen from inside the sheet: the input carries the
      // error, not just the button.
      case 7:
        _stageNamed('Strength', '22');
        _open(_fieldNamed('Strength'));
      // 8 is the thief skills with the rules off: what a Fighter / Mage cannot
      // allocate becomes editable, because that is what the mode is for. The
      // same screen at 0 shows them held back.
      case 8:
        setState(() => _rulesBind = false);
    }
  }

  void _stageNamed(String label, String value) {
    for (final entry in indexOf(widget.character)) {
      if (entry.field.label == label) {
        _stageField(entry, value);
        return;
      }
    }
  }

  Subject? _fieldNamed(String label) {
    for (final entry in indexOf(widget.character)) {
      if (entry.field.label == label) return FieldSubject(entry);
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

  /// Enumerates what needs attention, without rebuilding a list.
  ///
  /// ⚠️ **There is no findings panel any more.** Every flagged field is marked
  /// where it lives — and is *promoted onto the sheet* so the mark can be seen
  /// at all. What the badge is still for is the case a mark cannot answer:
  /// how many are there, and are they all above the fold. So it opens the
  /// palette, which already lists and reaches everything.
  void _showFindings() {
    _palette
      ..text = ''
      ..openView();
  }

  /// Edits *made in this session* that the rules would not produce.
  ///
  /// ⚠️ **Inherited faults are excluded on purpose.** Aard already stores
  /// `Tracking 25`. If the check blocked on every violation, a record that
  /// arrived broken could never be saved at all — you would come to change
  /// gold and be held by a fault you did not cause. So the sheet flags what it
  /// inherited and blocks only on what you introduced, which is how a linter
  /// treats code it did not write.
  List<FieldEntry> get _introducedViolations => [
    for (final entry in indexOf(widget.character))
      if (_pendingFields[entry.key] case final String staged)
        if (entry.field.beyondRules(staged) || entry.field.impossible(staged))
          entry,
  ];

  /// Proficiency slots not yet spent, counting staged edits.
  int get _slotsLeft {
    var spent = 0;
    for (final proficiency in widget.character.proficiencies) {
      spent += _pendingPips[proficiency.name] ?? proficiency.pips;
    }
    return widget.character.proficiencySlots - spent;
  }

  void _stageField(FieldEntry entry, String value) {
    setState(() {
      if (value == entry.field.stored || value.isEmpty) {
        _pendingFields.remove(entry.key);
      } else {
        _pendingFields[entry.key] = value;
      }
    });
  }

  void _stagePips(DemoProficiency proficiency, int pips) {
    setState(() {
      if (pips == proficiency.pips) {
        _pendingPips.remove(proficiency.name);
      } else {
        _pendingPips[proficiency.name] = pips;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final character = widget.character;
    final subject = _subject;
    final pending = _pendingFields.length + _pendingPips.length;
    final introduced = _introducedViolations;
    final blocked = _rulesBind && introduced.isNotEmpty;

    return Scaffold(
      key: _scaffoldKey,
      endDrawerEnableOpenDragGesture: false,
      endDrawer: subject == null
          ? null
          : SideSheet(
              key: ValueKey<String>('${subject.runtimeType}:${subject.title}'),
              subject: subject,
              character: character,
              pendingText: subject is FieldSubject
                  ? _pendingFields[subject.entry.key]
                  : null,
              pendingPips: subject is ProficiencySubject
                  ? _pendingPips[subject.proficiency.name]
                  : null,
              rulesBind: _rulesBind,
              slotsLeft: _slotsLeft,
              onApplyField: _stageField,
              onApplyPips: _stagePips,
              // An item opened from *here* is opened to be read: the picker
              // belongs to the inventory screen, which owns the slots.
              onApplyItem: (_, _, _) {},
              onClose: _closeSheet,
            ),
      appBar: AppBar(
        title: Text(character.name),
        actions: [
          FindingsBadge(
            findings: findingsFor(character),
            onPressed: _showFindings,
          ),
          const SizedBox(width: 8),
          // ⚠️ The only route to the inventory used to hang off a panel that
          // said "13 of 53 values". The panel went when the sheet became
          // complete; the route had to land somewhere rather than go with it.
          _RulesToggle(
            binding: _rulesBind,
            onChanged: (value) => setState(() => _rulesBind = value),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => InventoryScreen(character: character),
                ),
              ),
            ),
            tooltip: 'Inventory',
            icon: const Icon(Icons.backpack_outlined),
          ),
          if (character.spellbooks.isNotEmpty)
            IconButton(
              onPressed: () => unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SpellsScreen(
                      character: character,
                      rulesBind: _rulesBind,
                    ),
                  ),
                ),
              ),
              tooltip: 'Spells',
              icon: const Icon(Icons.auto_awesome_outlined),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: pending > 0 ? () {} : null,
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
          ),
          const IconButton(
            onPressed: null,
            tooltip: 'Redo',
            icon: Icon(Icons.redo),
          ),
          const SizedBox(width: 8),
          if (pending > 0)
            Tag(
              pending == 1 ? '1 change' : '$pending changes',
              caption: 'not written yet',
              tone: TagTone.inGame,
            ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: pending > 0 && !blocked ? () {} : null,
            icon: Icon(blocked ? Icons.error_outline : Icons.save_outlined),
            label: Text(blocked ? 'Fix it first' : 'Save'),
          ),
          const SizedBox(width: 8),
          _OverflowMenu(fileName: character.fileName),
          const SizedBox(width: 8),
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
                      CommandPalette(
                        controller: _palette,
                        character: character,
                        onSelected: _open,
                      ),
                      const SizedBox(height: 24),
                      _Sheet(
                        character: character,
                        pendingFields: _pendingFields,
                        pendingPips: _pendingPips,
                        rulesBind: _rulesBind,
                        onOpen: _open,
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

/// The whole record, one panel per group, balanced across columns.
///
/// ⚠️ **This used to draw six values of fifty-three.** The curation was the
/// spike's original argument — *show what matters, keep the rest a keystroke
/// away* — and it lost. Two things killed it. The first is that this is an
/// **editor**: a reader who opens a record wants to see the record, and a
/// curated view makes them ask what is being kept from them. The second is
/// that findings are marked **in place**, so a hidden field is a mark nobody
/// can see; the curated sheet had to promote flagged fields onto itself just
/// to stay honest, which is the design admitting it wanted to be complete.
///
/// The palette did not go away. It stopped being the only way to reach a
/// field and went back to being the fast way.
class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.character,
    required this.pendingFields,
    required this.pendingPips,
    required this.rulesBind,
    required this.onOpen,
  });

  final DemoCharacter character;
  final Map<String, String> pendingFields;
  final Map<String, int> pendingPips;

  /// Whether a value past the rules is an error or a deliberate enhancement.
  final bool rulesBind;

  final ValueChanged<Subject> onOpen;

  @override
  Widget build(BuildContext context) {
    final index = indexOf(character);
    final flagged = <String, Finding>{
      for (final finding in findingsFor(character))
        if (finding.subject case FieldSubject(:final entry)) entry.key: finding,
    };

    // (weight, panel), keyed by the group's own title. The weight is a row
    // count rather than a measurement — enough to balance two columns, and it
    // costs no layout pass to compute.
    final built = <String, (int, Widget)>{};
    for (final section in character.sections) {
      if (section.title == 'Abilities') {
        built['Abilities'] = (
          8,
          _Abilities(
            character: character,
            pending: pendingFields,
            rulesBind: rulesBind,
            onOpen: onOpen,
          ),
        );
        continue;
      }
      for (final group in section.groups) {
        final rows = [
          for (final entry in index)
            if (entry.group == group) entry,
        ];
        if (rows.isEmpty) continue;
        built[group.title] = (
          rows.length,
          PanelCard(
            title: group.title,
            note: group.note,
            children: [
              for (final entry in rows) ...[
                if (entry != rows.first) const Divider(),
                _ValueRow(
                  entry: entry,
                  pending: pendingFields[entry.key],
                  finding: flagged[entry.key],
                  resolved:
                      pendingFields[entry.key] != null &&
                      pendingFields[entry.key] != entry.field.stored,
                  rulesBind: rulesBind,
                  onTap: () => onOpen(FieldSubject(entry)),
                ),
              ],
            ],
          ),
        );
      }
    }
    built['Proficiencies'] = (
      character.proficiencies.length,
      _Proficiencies(
        character: character,
        pending: pendingPips,
        rulesBind: rulesBind,
        onOpen: onOpen,
      ),
    );

    // ⚠️ **Named, not inherited from the data's order**, because the order a
    // record happens to store its groups in is not the order a person reads a
    // character in. Anything the data holds that is not named here is appended
    // rather than dropped — a hard-coded order that silently loses a new group
    // is a defect waiting for the next character.
    const order = [
      'Character',
      'Abilities',
      'Skills',
      'Proficiencies',
      'Combat',
      'Resistances',
      'Condition',
    ];
    final panels = <(int, Widget)>[
      for (final title in order)
        if (built.remove(title) case final (int, Widget) panel) panel,
      ...built.values,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (_, panel) in panels) ...[
                panel,
                const SizedBox(height: 20),
              ],
            ],
          );
        }
        // Greedy balance: each panel joins whichever column is shorter so far.
        // Hand-assigning them would look tidy for Aard and lopsided for the
        // next character, whose Combat panel is a different length.
        final columns = <List<Widget>>[[], []];
        final heights = <int>[0, 0];
        for (final (weight, panel) in panels) {
          final target = heights[0] <= heights[1] ? 0 : 1;
          columns[target].add(panel);
          columns[target].add(const SizedBox(height: 20));
          heights[target] += weight;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: columns[0],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: columns[1],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.entry,
    required this.onTap,
    this.pending,
    this.finding,
    this.resolved = false,
    this.rulesBind = true,
  });

  final FieldEntry entry;
  final VoidCallback onTap;
  final String? pending;

  /// What this application noticed about this field, marked in place rather
  /// than listed somewhere else. A separate list said the same thing twice
  /// and put it where the field was not.
  final Finding? finding;

  /// Whether a staged edit already answers [finding]. A mark that keeps
  /// accusing after you have fixed the thing is a mark you stop reading.
  final bool resolved;

  /// Whether a value past the rules reads as a fault or as a choice.
  final bool rulesBind;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final arithmetic = entry.field.arithmetic;
    final live = entry.field.enabledUnder(rulesBind: rulesBind);
    final staged = pending;
    // Three verdicts, because this application knows three different kinds of
    // wrong: the bytes cannot hold it, the engine will not produce it, or the
    // engine simply owns it. Only the first is ever a hard stop.
    final impossible = staged != null && entry.field.impossible(staged);
    final beyond = staged != null && entry.field.beyondRules(staged);
    final mark = finding;
    final marked = mark != null || impossible || beyond;
    final tone = impossible || (beyond && rulesBind)
        ? colors.error
        : beyond
        ? colors.secondary
        : resolved
        ? colors.primary
        : mark?.severity == Severity.conflict
        ? colors.error
        : colors.tertiary;
    // One sentence for a screen reader, covering every verdict — a label that
    // only knew about findings would go silent on the two states the rules
    // check introduced.
    final spoken = StringBuffer(
      '${entry.field.label}, stored ${entry.field.stored}',
    );
    if (impossible) {
      spoken.write('. Beyond what the game will take.');
    } else if (beyond) {
      spoken.write(
        rulesBind
            ? '. Beyond what the rules produce.'
            : '. Enhanced, beyond what the rules produce.',
      );
    } else if (resolved) {
      spoken.write('. Will be corrected.');
    } else if (mark != null) {
      spoken.write('. ${mark.sentence}');
    }

    final body = Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(entry.field.label, style: text.bodyLarge),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: ValueReadout(
                      field: entry.field,
                      pending: pending,
                      rulesBind: rulesBind,
                    ),
                  ),
                ],
              ),
              if (arithmetic != null) ...[
                const SizedBox(height: 8),
                ArithmeticLine(arithmetic),
              ],
              // The sentence sits under the value it is about. It used to live
              // in a column on the right, which said the field's name a second
              // time to explain where to look.
              if (marked) ...[
                const SizedBox(height: 8),
                Text(
                  impossible
                      ? 'The game will not take a value above '
                            '${entry.field.gameMaximum}.'
                      : beyond
                      ? rulesBind
                            ? 'Beyond anything the rules produce — the '
                                  'highest they reach is '
                                  '${entry.field.rulesMaximum}.'
                            : 'Enhanced. The game will accept it; the rules '
                                  'would never produce it.'
                      : resolved
                      ? 'Will be corrected.'
                      : mark!.sentence,
                  style: text.bodyMedium?.copyWith(color: tone),
                ),
              ],
            ],
          ),
        );

    return Semantics(
      button: true,
      label: spoken.toString(),
      child: InkWell(
        // Readable either way — you can always open it to read the caveat —
        // but the surface says whether it may be *changed*, which is what the
        // mode governs. Behaviour that changes while appearance does not is a
        // mode nobody can see.
        onTap: onTap,
        child: Container(
          decoration: marked
              ? BoxDecoration(
                  border: Border(left: BorderSide(color: tone, width: 3)),
                )
              : null,
          padding: EdgeInsets.only(left: marked ? 12 : 0),
          child: live ? body : ScreenTone(child: body),
        ),
      ),
    );
  }
}

/// Seven tiles, each at least 260 px wide, each carrying its arithmetic in
/// full.
///
/// This is where the *greyed but not anomalous* state appears on the main
/// surface: `Exceptional strength` is held back by [ScreenTone], wears `not
/// for this class`, and is inert. Compare it with `Tracking` in the right-hand
/// column — held back the same way, wearing **conflict** in the error role,
/// and live. What "held back" looks like is the palette's decision, not this
/// widget's: a fade under two of them, a halftone plate under the third.
class _Abilities extends StatelessWidget {
  const _Abilities({
    required this.character,
    required this.pending,
    required this.rulesBind,
    required this.onOpen,
  });

  final DemoCharacter character;
  final Map<String, String> pending;
  final bool rulesBind;
  final ValueChanged<Subject> onOpen;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      for (final entry in indexOf(character))
        if (entry.section.title == 'Abilities') entry,
    ];
    return PanelCard(
      title: 'Abilities',
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 2 : 1;
            final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final entry in tiles)
                  SizedBox(
                    width: width,
                    child: _AbilityTile(
                      entry: entry,
                      pending: pending[entry.key],
                      rulesBind: rulesBind,
                      onOpen: onOpen,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AbilityTile extends StatelessWidget {
  const _AbilityTile({
    required this.entry,
    required this.onOpen,
    this.pending,
    this.rulesBind = true,
  });

  final FieldEntry entry;
  final ValueChanged<Subject> onOpen;
  final String? pending;

  /// ⚠️ **Abilities are where a save editor is actually used.** A verdict that
  /// reached the rows and not these tiles would go quiet on exactly the field
  /// someone opened the application to change.
  final bool rulesBind;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final field = entry.field;
    final arithmetic = field.arithmetic;
    final live = field.enabledUnder(rulesBind: rulesBind);
    final staged = pending;
    final impossible = staged != null && field.impossible(staged);
    final beyond = staged != null && field.beyondRules(staged);
    final verdict = impossible
        ? 'The game will not take a value above ${field.gameMaximum}.'
        : beyond
        ? rulesBind
              ? 'Beyond the rules — they reach ${field.rulesMaximum}.'
              : 'Enhanced. The game accepts it.'
        : null;
    final verdictTone = impossible || (beyond && rulesBind)
        ? colors.error
        : colors.secondary;

    // ⚠️ No fill. An inset region inside a card is separated by a hairline,
    // never by a fifth surface tone — that collision is what made the current
    // application's placeholders invisible inside the cards holding them.
    final tile = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.label, style: text.bodyLarge),
          const SizedBox(height: 8),
          ValueReadout(field: field, pending: pending),
          if (verdict != null) ...[
            const SizedBox(height: 8),
            Text(
              verdict,
              style: text.bodyMedium?.copyWith(color: verdictTone),
            ),
          ],
          if (arithmetic != null) ...[
            const SizedBox(height: 8),
            ArithmeticLine(arithmetic),
          ],
        ],
      ),
    );

    // Asked for, not stated — the palette decides how hard an edge is. See
    // [PaletteFinish].
    final corner = PaletteFinish.of(context).radiusOf(12);

    return Semantics(
      button: live,
      label: '${field.label}, stored ${field.stored}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: corner,
          border: Border.all(color: colors.outline),
        ),
        child: InkWell(
          onTap: live ? () => onOpen(FieldSubject(entry)) : null,
          borderRadius: corner,
          child: live ? tile : ScreenTone(child: tile),
        ),
      ),
    );
  }
}

/// Every proficiency, against a budget of slots rather than a per-row limit.
///
/// ⚠️ **Two limits, and they fail differently.** A row has its own ceiling —
/// the lower of what the class allows and what the weapon allows — and the
/// character has a *total* number of slots to spend across all of them. So a
/// row can be nowhere near its ceiling and still be unavailable because nothing
/// is left, and freeing one pip anywhere makes every row available again. A
/// panel that showed only the taken proficiencies could not express either.
class _Proficiencies extends StatelessWidget {
  const _Proficiencies({
    required this.character,
    required this.pending,
    required this.rulesBind,
    required this.onOpen,
  });

  final DemoCharacter character;
  final Map<String, int> pending;

  /// Whether the slots bind. Off, the budget stops applying — the same rule
  /// the fields follow, because a mode that constrained one and not the other
  /// would be two modes wearing one label.
  final bool rulesBind;

  final ValueChanged<Subject> onOpen;

  @override
  Widget build(BuildContext context) {
    var spent = 0;
    for (final proficiency in character.proficiencies) {
      spent += pending[proficiency.name] ?? proficiency.pips;
    }
    final left = character.proficiencySlots - spent;
    final exhausted = rulesBind && left <= 0;

    return PanelCard(
      title: 'Proficiencies',
      note: rulesBind
          ? left > 0
                ? '$left of ${character.proficiencySlots} slots still to '
                      'spend. Each row also has its own ceiling.'
                : 'All ${character.proficiencySlots} slots are spent. Take a '
                      'pip back to free one.'
          : 'Slots are not being counted. ${character.proficiencySlots} is '
                'what the class grants.',
      trailing: exhausted
          ? Tag('$spent/${character.proficiencySlots}', tone: TagTone.conflict)
          : Tag(
              '$spent/${character.proficiencySlots}',
              tone: rulesBind ? TagTone.neutral : TagTone.enhanced,
            ),
      children: [
        for (final proficiency in character.proficiencies)
          Builder(
            builder: (context) {
              final pips = pending[proficiency.name] ?? proficiency.pips;
              // Always reachable while it holds something — a pip you cannot
              // take back is a slot you cannot free, and that would strand the
              // whole panel the moment the budget ran out.
              final live = !exhausted || pips > 0;
              final meter = PipMeter(
                proficiency: proficiency,
                pending: pending[proficiency.name],
                onTap: live
                    ? () => onOpen(ProficiencySubject(proficiency))
                    : null,
              );
              return Opacity(opacity: live ? 1 : 0.45, child: meter);
            },
          ),
      ],
    );
  }
}


class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.file_upload_outlined),
          onPressed: () {},
          child: const Text('Export this character…'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.restore),
          onPressed: () {},
          child: Text('Reload $fileName from disk'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.history),
          onPressed: () {},
          child: const Text('What changed since it was opened'),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        onPressed: controller.isOpen ? controller.close : controller.open,
        tooltip: 'More',
        icon: const Icon(Icons.more_vert),
      ),
    );
  }
}

/// The rules check, as a visible mode rather than a hidden preference.
///
/// ⚠️ **A mode you cannot see is a mode that surprises you**, so this is a
/// labelled control in the app bar and not an item in a menu. On, the rules
/// bind and Save refuses an edit they would not produce. Off, the same edit is
/// allowed and *marked* — the game will take it, so the application's job is to
/// say plainly that it is not what the rules would give you, not to prevent it.
///
/// That off state is the reason a save editor exists. Calling it *enhanced*
/// rather than *invalid* is the honest word for a value the engine accepts.
class _RulesToggle extends StatelessWidget {
  const _RulesToggle({required this.binding, required this.onChanged});

  final bool binding;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: binding
          ? 'Rules check on — Save refuses a value the rules would not produce'
          : 'Rules check off — values beyond the rules are allowed and marked',
      child: TextButton.icon(
        onPressed: () => onChanged(!binding),
        icon: Icon(
          binding ? Icons.rule : Icons.auto_fix_high_outlined,
          size: 18,
          color: binding ? null : colors.secondary,
        ),
        label: Text(
          binding ? 'Rules' : 'Enhanced',
          style: binding ? null : TextStyle(color: colors.secondary),
        ),
      ),
    );
  }
}
