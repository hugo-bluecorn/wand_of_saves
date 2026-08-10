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

/// The editing session, on its own.
///
/// Undo, redo and the dirty rule were only ever reachable through a ViewModel,
/// so the rules themselves — which are the same for both documents — had no
/// test of their own. They do now, and they are the same object in both
/// editors.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/ui/edit_session.dart';

import '../support/synthetic_save.dart';

void main() {
  Chr open() => ChrCodec.decode(buildCharacterFile(name: 'Aurel'));

  Chr changed(Chr from, int strength) => from.withCreatureField(
    creOffset: from.creOffset,
    field: CreHeaderField.strength,
    value: strength,
  );

  group('a freshly opened document', () {
    test('is clean, with nothing to undo or redo', () {
      final chr = open();
      final session = EditSession<Chr>.opened(chr);

      expect(session.document, same(chr));
      expect(session.isDirty, isFalse);
      expect(session.canUndo, isFalse);
      expect(session.canRedo, isFalse);
    });
  });

  group('editing', () {
    test('replaces the document and marks it dirty', () {
      final chr = open();
      final next = changed(chr, 18);

      final session = EditSession<Chr>.opened(chr).edited(next);

      expect(session.document, same(next));
      expect(session.isDirty, isTrue);
      expect(session.canUndo, isTrue);
    });

    test('clears the redo stack, so history cannot fork', () {
      // A redo kept across a fresh edit would reapply an edit onto a history
      // it was never taken from.
      final chr = open();
      final session = EditSession<Chr>.opened(
        chr,
      ).edited(changed(chr, 18)).undone().edited(changed(chr, 17));

      expect(session.canRedo, isFalse);
    });
  });

  group('undo and redo', () {
    test('undo goes back and offers a redo', () {
      final chr = open();
      final next = changed(chr, 18);

      final session = EditSession<Chr>.opened(chr).edited(next).undone();

      expect(session.document, same(chr));
      expect(session.canRedo, isTrue);
      expect(session.canUndo, isFalse);
    });

    test('redo puts it back', () {
      final chr = open();
      final next = changed(chr, 18);

      final session = EditSession<Chr>.opened(
        chr,
      ).edited(next).undone().redone();

      expect(session.document, same(next));
    });

    test('are harmless when there is nothing to go back to', () {
      final session = EditSession<Chr>.opened(open());

      expect(session.undone(), same(session));
      expect(session.redone(), same(session));
    });
  });

  group('the dirty rule', () {
    test('⚠️ is identity, not a byte comparison', () {
      // **This is load-bearing and not obvious.** Undoing back to the loaded
      // snapshot restores *that same object*, so "nothing to save" needs no
      // 96 KB diff. A byte comparison would give the same answer far more
      // slowly; a `==` on the document would give the wrong one, since these
      // codec types compare by identity anyway.
      final chr = open();

      final back = EditSession<Chr>.opened(
        chr,
      ).edited(changed(chr, 18)).undone();

      expect(back.document, same(chr));
      expect(back.isDirty, isFalse, reason: 'it is the object that was loaded');
    });

    test('an edit that lands on the same value is still a change', () {
      // Two patched copies are two objects. The editor does not pretend a
      // no-op edit never happened -- the undo entry is real either way.
      final chr = open();
      final same = changed(chr, chr.bytes[chr.creOffset + 0x238]);

      expect(EditSession<Chr>.opened(chr).edited(same).isDirty, isTrue);
    });

    test('saving makes the working copy the one on disk', () {
      final chr = open();
      final next = changed(chr, 18);

      final saved = EditSession<Chr>.opened(chr).edited(next).saved();

      expect(saved.isDirty, isFalse);
      expect(saved.document, same(next));
      expect(saved.canUndo, isTrue, reason: 'saving is not forgetting');
    });
  });

  group('it serves both documents', () {
    test('a savegame session behaves identically', () {
      // One session type, because the rules are the same. Two would be two
      // chances for undo to mean something slightly different in one editor.
      final gam = GamCodec.decode(buildSave());
      final next = gam.withPartyGold(999);

      final session = EditSession<Gam>.opened(gam).edited(next);

      expect(session.document, same(next));
      expect(session.isDirty, isTrue);
      expect(session.undone().document, same(gam));
    });
  });
}
