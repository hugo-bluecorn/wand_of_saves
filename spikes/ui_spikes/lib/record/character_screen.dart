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

/// The character as **one sheet you read top to bottom**.
///
/// No tabs and no category navigation: a cover, then seven chapters, then the
/// endnotes. The index rail tracks the reader rather than steering them, and
/// every value is edited where it sits.
///
/// Two shapes are copied from BG:EE's own record screen rather than invented:
/// the four identity facts are **stacked lines**, not one concatenated
/// sentence, and a base value sits **directly above** the value derived from
/// it, in the same list, the way `Base THAC0` sits above `Main Hand THAC0`.
///
/// The document is a single scroll view over a column, deliberately not a lazy
/// list: every chapter has to stay laid out for the rail to be able to measure
/// where it is.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/demo/portrait.dart';
import 'package:ui_spikes/record/field_row.dart';
import 'package:ui_spikes/record/index_rail.dart';
import 'package:ui_spikes/record/inventory_screen.dart';
import 'package:ui_spikes/record/proficiency_list.dart';
import 'package:ui_spikes/record/running_head.dart';
import 'package:ui_spikes/record/theme.dart';

/// The identity list is gender, race, class, alignment — the order the engine
/// prints them and the order the demo data holds them in. The class is the one
/// fact set in full ink.
const int _classFact = 2;

/// How far into the viewport a chapter head has to be before the rail counts
/// the reader as being inside that chapter.
const double _activeThreshold = 96;

/// Where a chapter head lands when the rail is used to jump to it.
const double _landing = 24;

/// The whole record, as a document.
class CharacterScreen extends StatefulWidget {
  /// Opens [character], scrolled to [initialChapter].
  ///
  /// Chapter 0 means offset 0 — the cover — rather than a jump that skips it.
  const CharacterScreen({
    required this.character,
    this.initialChapter = 0,
    super.key,
  });

  /// Whose record this is.
  final DemoCharacter character;

  /// Which chapter to open on. Clamped; out of range is not an error.
  final int initialChapter;

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  final ScrollController _controller = ScrollController();
  final GlobalKey<State<StatefulWidget>> _viewportKey = GlobalKey();
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  final ValueNotifier<int> _active = ValueNotifier<int>(0);
  final Map<String, String> _edits = {};
  final Map<String, int> _pips = {};
  final List<_Revision> _history = [];
  late final _Chapters _chapters;
  int _cursor = 0;

  @override
  void initState() {
    super.initState();
    _chapters = _Chapters.of(widget.character);
    // ⚠️ A jump in a post-frame callback, never an animation and never a
    // build-time offset. Nothing on this machine can drive the pointer, so a
    // chapter that needs scrolling to reach cannot be photographed at all
    // unless this lands on the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootScroll());
  }

  @override
  void dispose() {
    _controller.dispose();
    _progress.dispose();
    _active.dispose();
    super.dispose();
  }

  /// Where a chapter head sits relative to the top of the viewport.
  double? _headOffset(int index) {
    if (index < 0 || index >= _chapters.length) return null;
    final viewport = _viewportKey.currentContext?.findRenderObject();
    final head = _chapters.specs[index].key.currentContext?.findRenderObject();
    if (viewport is! RenderBox || head is! RenderBox) return null;
    if (!viewport.hasSize || !head.hasSize) return null;
    return head.localToGlobal(Offset.zero, ancestor: viewport).dy;
  }

  int _activeChapter() {
    var found = 0;
    for (var i = 0; i < _chapters.length; i++) {
      final dy = _headOffset(i);
      if (dy != null && dy <= _activeThreshold) found = i;
    }
    // Otherwise a short closing chapter can never become active, however far
    // the reader scrolls.
    if (_controller.hasClients &&
        _controller.offset >= _controller.position.maxScrollExtent - 1) {
      found = _chapters.length - 1;
    }
    return found;
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    _progress.value = (notification.metrics.pixels / 120)
        .clamp(0, 1)
        .toDouble();
    if (_chapters.isNotEmpty) _active.value = _activeChapter();
    return false;
  }

  void _goTo(int index) {
    final dy = _headOffset(index);
    if (dy == null || !_controller.hasClients) return;
    unawaited(
      _controller.animateTo(
        _target(dy),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  /// Re-clamped against the extent, because the trailing padding that lets the
  /// last chapter reach the top is itself only as tall as the viewport.
  double _target(double dy) => (_controller.offset + dy - _landing)
      .clamp(0, _controller.position.maxScrollExtent)
      .toDouble();

  void _bootScroll() {
    if (!mounted || _chapters.isEmpty) return;
    final index = widget.initialChapter.clamp(0, _chapters.length - 1);
    _active.value = index;
    if (index == 0) return;
    final dy = _headOffset(index);
    if (dy == null || !_controller.hasClients) return;
    final target = _target(dy);
    _controller.jumpTo(target);
    _progress.value = (target / 120).clamp(0, 1).toDouble();
  }

  void _record(_Revision revision) {
    if (_cursor < _history.length) {
      _history.removeRange(_cursor, _history.length);
    }
    _history.add(revision);
    _cursor = _history.length;
  }

  void _edit(String key, String value) {
    setState(() {
      _record(_FieldRevision(key: key, before: _edits[key], after: value));
      _edits[key] = value;
    });
  }

  void _setPips(String name, int value) {
    setState(() {
      _record(_PipRevision(name: name, before: _pips[name], after: value));
      _pips[name] = value;
    });
  }

  void _undo() {
    if (_cursor == 0) return;
    setState(() {
      _cursor--;
      switch (_history[_cursor]) {
        case _FieldRevision(:final key, :final before):
          if (before == null) {
            _edits.remove(key);
          } else {
            _edits[key] = before;
          }
        case _PipRevision(:final name, :final before):
          if (before == null) {
            _pips.remove(name);
          } else {
            _pips[name] = before;
          }
      }
    });
  }

  void _redo() {
    if (_cursor >= _history.length) return;
    setState(() {
      switch (_history[_cursor]) {
        case _FieldRevision(:final key, :final after):
          _edits[key] = after;
        case _PipRevision(:final name, :final after):
          _pips[name] = after;
      }
      _cursor++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    final character = widget.character;
    final size = MediaQuery.sizeOf(context);
    final headHeight = context.scaledByText(64);
    final railWidth = context.scaledByText(
      size.width < 1200 ? 184 : tokens.railWidth,
    );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(headHeight),
        child: ValueListenableBuilder<double>(
          valueListenable: _progress,
          builder: (context, progress, _) => RunningHead(
            character: character,
            progress: progress,
            height: headHeight,
            onSave: () {},
            onUndo: _cursor > 0 ? _undo : null,
            onRedo: _cursor < _history.length ? _redo : null,
          ),
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_chapters.isNotEmpty)
            ValueListenableBuilder<int>(
              valueListenable: _active,
              builder: (context, active, _) => IndexRail(
                titles: _chapters.titles,
                activeIndex: active,
                onSelected: _goTo,
                width: railWidth,
              ),
            ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              // The whole document is selectable, which is how a value gets
              // copied out of it at all.
              child: SelectionArea(
                child: SizedBox.expand(
                  key: _viewportKey,
                  child: Scrollbar(
                    controller: _controller,
                    child: SingleChildScrollView(
                      controller: _controller,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: tokens.measure,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Cover(character: character),
                                if (_chapters.isEmpty) const _EmptyRecord(),
                                for (final spec in _chapters.specs)
                                  _Chapter(
                                    title: spec.title,
                                    headKey: spec.key,
                                    body: switch (spec.kind) {
                                      _ChapterKind.fields => Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (final group
                                              in spec.section?.groups ??
                                                  const <DemoGroup>[])
                                            _GroupBlock(
                                              chapterTitle: spec.title,
                                              group: group,
                                              showHead:
                                                  group.title != spec.title,
                                              edits: _edits,
                                              onChanged: _edit,
                                            ),
                                        ],
                                      ),
                                      _ChapterKind.proficiencies =>
                                        ProficiencyList(
                                          proficiencies:
                                              character.proficiencies,
                                          pips: _pips,
                                          onChanged: _setPips,
                                        ),
                                      _ChapterKind.inventory =>
                                        InventoryChapter(
                                          equipped: character.equipped,
                                          backpack: character.backpack,
                                        ),
                                      _ChapterKind.notes => _NotesChapter(
                                        notes: character.anomalies,
                                      ),
                                    },
                                  ),
                                // So the closing chapter can still reach the
                                // top of the viewport.
                                SizedBox(height: size.height * 0.7),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What kind of body a chapter has.
enum _ChapterKind {
  /// Groups of ordinary fields.
  fields,

  /// The proficiency run, which the engine prints inside the combat list.
  proficiencies,

  /// What is carried, which in this approach is a chapter and not a screen.
  inventory,

  /// The endnotes, which is what makes the dagger in the body mean something.
  notes,
}

typedef _ChapterSpec = ({
  String title,
  _ChapterKind kind,
  DemoSection? section,
  GlobalKey<State<StatefulWidget>> key,
});

/// The chapter list, which the rail and the scrollspy both read.
class _Chapters {
  const _Chapters._(this.specs);

  factory _Chapters.of(DemoCharacter character) {
    final specs = <_ChapterSpec>[];
    var placedProficiencies = false;
    for (final section in character.sections) {
      // ⚠️ A section with no groups is the inventory: its content lives in
      // `equipped` and `backpack` rather than in fields.
      if (section.groups.isEmpty) {
        if (!placedProficiencies && character.proficiencies.isNotEmpty) {
          specs.add((
            title: 'Proficiencies',
            kind: _ChapterKind.proficiencies,
            section: null,
            key: GlobalKey(),
          ));
          placedProficiencies = true;
        }
        specs.add((
          title: section.title,
          kind: _ChapterKind.inventory,
          section: null,
          key: GlobalKey(),
        ));
      } else {
        specs.add((
          title: section.title,
          kind: _ChapterKind.fields,
          section: section,
          key: GlobalKey(),
        ));
      }
    }
    if (!placedProficiencies && character.proficiencies.isNotEmpty) {
      specs.add((
        title: 'Proficiencies',
        kind: _ChapterKind.proficiencies,
        section: null,
        key: GlobalKey(),
      ));
    }
    if (character.anomalies.isNotEmpty) {
      specs.add((
        title: 'Notes',
        kind: _ChapterKind.notes,
        section: null,
        key: GlobalKey(),
      ));
    }
    return _Chapters._(specs);
  }

  final List<_ChapterSpec> specs;

  List<String> get titles => [for (final spec in specs) spec.title];

  int get length => specs.length;

  bool get isEmpty => specs.isEmpty;

  bool get isNotEmpty => specs.isNotEmpty;
}

/// The record's own arithmetic line, with a revision mark once it has moved.
String? _arithmeticFor(DemoField field, String value) {
  final base = field.arithmetic;
  if (value == field.stored) return base;
  return base == null ? 'was ${field.stored}' : '$base — was ${field.stored}';
}

/// What the engine will draw, moved by the same amount the stored value was.
///
/// ⚠️ **Demo-only.** One derivation is wired for real so that the relationship
/// between a stored number and the drawn one can be felt rather than read
/// about. The engine's actual rule reads the class, the level and a table.
String? _inGameFor(DemoField field, String value) {
  if (!field.differsInGame) return null;
  final shown = field.inGame;
  if (shown == null) return null;
  if (field.label != 'Maximum hit points') return shown;
  final edited = int.tryParse(value);
  final stored = int.tryParse(field.stored);
  final drawn = int.tryParse(shown);
  if (edited == null || stored == null || drawn == null) return shown;
  return '${edited + drawn - stored}';
}

/// The first field whose drawn value differs from its stored one, which is what
/// the cover's key is drawn from.
DemoField? _keySample(DemoCharacter character) {
  for (final field in character.allFields) {
    if (field.differsInGame) return field;
  }
  return null;
}

/// The document's cover: who this is, in the engine's own four stacked lines.
class _Cover extends StatelessWidget {
  const _Cover({required this.character});

  final DemoCharacter character;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    final identity = character.identity;
    final sample = _keySample(character);
    return Padding(
      padding: const EdgeInsets.only(top: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DemoPortrait(
                initial: character.name.isEmpty ? '?' : character.name[0],
                width: 92,
                radius: 4,
              ),
              const SizedBox(width: 30),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(character.name, style: tokens.coverName),
                    const SizedBox(height: 3),
                    Text(character.fileName, style: tokens.caption),
                    const SizedBox(height: 20),
                    // ⚠️ Four facts on four lines, which is what the engine
                    // prints. The application concatenates them into one
                    // sentence; this does not.
                    for (var i = 0; i < identity.length; i++)
                      Text(
                        identity[i],
                        style: i == _classFact
                            ? tokens.identityLineStrong
                            : tokens.identityLine,
                      ),
                    Text(
                      character.levelLine,
                      style: tokens.identityLineStrong,
                    ),
                    const SizedBox(height: 6),
                    Text(character.experienceLine, style: tokens.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Divider(),
          if (sample != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(sample.stored, style: tokens.storedValue),
                  const SizedBox(width: 8),
                  Text('stored', style: tokens.caption),
                  const SizedBox(width: 34),
                  Text(sample.inGame ?? '', style: tokens.derivedValue),
                  const SizedBox(width: 8),
                  Text('in game', style: tokens.derivedTag),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One chapter: the head, the rule above the body, and the space before it.
class _Chapter extends StatelessWidget {
  const _Chapter({
    required this.title,
    required this.headKey,
    required this.body,
  });

  final String title;
  final GlobalKey<State<StatefulWidget>> headKey;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.recordTokens.chapterGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChapterHead(key: headKey, title: title),
          const SizedBox(height: 18),
          body,
        ],
      ),
    );
  }
}

class _ChapterHead extends StatelessWidget {
  const _ChapterHead({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title.toUpperCase(), style: context.recordTokens.chapterHead),
        const SizedBox(height: 9),
        const Divider(),
      ],
    );
  }
}

/// A bare-word run heading and the rows under it. Rows are separated by
/// leading, not by rules — the only rules in the document are chapter heads.
class _GroupBlock extends StatelessWidget {
  const _GroupBlock({
    required this.chapterTitle,
    required this.group,
    required this.showHead,
    required this.edits,
    required this.onChanged,
  });

  final String chapterTitle;
  final DemoGroup group;
  final bool showHead;
  final Map<String, String> edits;
  final void Function(String key, String value) onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    final note = group.note;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHead) ...[
            Text(group.title, style: tokens.groupHead),
            const SizedBox(height: 2),
          ],
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 24),
              child: Text(note, style: tokens.caption),
            ),
          for (final field in group.fields)
            _FieldLine(
              fieldKey: '$chapterTitle/${group.title}/${field.label}',
              field: field,
              edits: edits,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

/// Resolves what a row should currently show, and hands it to [FieldRow].
class _FieldLine extends StatelessWidget {
  const _FieldLine({
    required this.fieldKey,
    required this.field,
    required this.edits,
    required this.onChanged,
  });

  final String fieldKey;
  final DemoField field;
  final Map<String, String> edits;
  final void Function(String key, String value) onChanged;

  @override
  Widget build(BuildContext context) {
    final value = edits[fieldKey] ?? field.stored;
    return FieldRow(
      field: field,
      value: value,
      edited: value != field.stored,
      onChanged: (edited) => onChanged(fieldKey, edited),
      arithmetic: _arithmeticFor(field, value),
      inGame: _inGameFor(field, value),
    );
  }
}

/// The closing chapter: what this application knows is odd about the record.
class _NotesChapter extends StatelessWidget {
  const _NotesChapter({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final note in notes)
          Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.rowGap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: tokens.gutter,
                  child: Text(
                    '†',
                    style: tokens.caveat.copyWith(color: tokens.anomalyInk),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 24),
                    child: Text(note, style: tokens.caveat),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A record nothing has been read out of yet. Honest, and about ten lines.
class _EmptyRecord extends StatelessWidget {
  const _EmptyRecord();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 52),
      child: Text(
        'Nothing has been read from this record yet.',
        style: context.recordTokens.identityLine,
      ),
    );
  }
}

sealed class _Revision {
  const _Revision();
}

final class _FieldRevision extends _Revision {
  const _FieldRevision({
    required this.key,
    required this.before,
    required this.after,
  });

  final String key;
  final String? before;
  final String after;
}

final class _PipRevision extends _Revision {
  const _PipRevision({
    required this.name,
    required this.before,
    required this.after,
  });

  final String name;
  final int? before;
  final int after;
}
