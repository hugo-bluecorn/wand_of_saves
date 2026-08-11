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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/data/services/recycle_service.dart';

import '../../support/synthetic_save.dart';

void main() {
  late Directory temp;
  late Directory saveRoot;
  late Directory characterRoot;
  late RecycleService recycler;

  String at(List<String> parts) => parts.join(Platform.pathSeparator);

  setUp(() {
    temp = Directory.systemTemp.createTempSync('wand_recycle_');
    saveRoot = Directory(at([temp.path, 'save']));
    characterRoot = Directory(at([temp.path, 'characters']));
    writeSaveSlot(saveRoot, '000000001-keep');
    recycler = RecycleService(
      profile: GameProfileService(
        saveCandidates: [saveRoot.path],
        environment: const {},
      ),
    );
  });

  tearDown(() => temp.deleteSync(recursive: true));

  group('where deleted things go', () {
    test('is beside the save root, never inside it', () async {
      // ⚠️ A slot is recognised by containing BALDUR.gam, and the engine agrees
      // -- so a `deleted/` folder *inside* the save root would still be listed
      // as a save, by this app and by the game. Outside it, nothing looks.
      expect(recycler.recycleRoot(), at([temp.path, 'deleted']));
      expect(recycler.recycleRoot(), isNot(contains(saveRoot.path)));
    });

    test('is still found once the last save has been deleted', () async {
      // ⚠️ **The end of the cascade that greyed out "Empty deleted items".**
      // Recycling the only slot leaves the save folder empty, which used to
      // stop it being recognised as the save root at all -- so the bin's own
      // address, derived from that root, went null and the one command that
      // could clear it was disabled over a bin that was full.
      //
      // The settings file beside the folder is what keeps the address. This is
      // the state the app puts itself in, reached the way it reaches it.
      File(
        at([temp.path, GameProfileService.settingsMarker]),
      ).writeAsStringSync('x');
      await recycler.recycleSaveAt(at([saveRoot.path, '000000001-keep']));

      expect(saveRoot.listSync(), isEmpty);
      expect(recycler.recycleRoot(), at([temp.path, 'deleted']));
      expect(recycler.hasRecycled, isTrue);
    });
  });

  group('recycling a save', () {
    test('moves the whole directory, not just the savegame', () async {
      // A slot holds BALDUR.gam, the screenshot and one portrait per member.
      // Unlinking the savegame alone would leave a directory the browser skips
      // and the player cannot restore.
      final slot = writeSaveSlot(
        saveRoot,
        '000000002-go',
        portraits: [0, 1],
        withScreenshot: true,
      );

      final moved = await recycler.recycleSaveAt(slot);

      expect(Directory(slot).existsSync(), isFalse);
      expect(Directory(moved).listSync(), hasLength(4));
      expect(moved, startsWith(at([temp.path, 'deleted', 'save'])));
    });

    test('never overwrites an earlier deletion of the same name', () async {
      // Delete, restore, delete again is an ordinary sequence. The second move
      // must not clobber the first, because there is nothing behind it.
      final first = writeSaveSlot(saveRoot, '000000002-go');
      final firstMoved = await recycler.recycleSaveAt(first);
      final second = writeSaveSlot(saveRoot, '000000002-go');

      final secondMoved = await recycler.recycleSaveAt(second);

      expect(secondMoved, isNot(firstMoved));
      expect(Directory(firstMoved).existsSync(), isTrue);
      expect(Directory(secondMoved).existsSync(), isTrue);
    });
  });

  group('recycling a character', () {
    test('takes the .bio sidecar with it', () async {
      // ⚠️ One document in two files. A biography left behind is a quiet
      // half-deletion: the character is gone and the orphan stays.
      final path = writeCharacterFile(
        characterRoot,
        'aurel',
        withBiography: true,
      );

      final moved = await recycler.recycleCharacterAt(path);

      expect(File(path).existsSync(), isFalse);
      expect(File(at([characterRoot.path, 'aurel.bio'])).existsSync(), isFalse);
      expect(File(moved).existsSync(), isTrue);
      expect(
        File('${moved.substring(0, moved.length - 4)}.bio').existsSync(),
        isTrue,
      );
    });

    test('copes with a character that has no biography', () async {
      final path = writeCharacterFile(characterRoot, 'aurel');

      final moved = await recycler.recycleCharacterAt(path);

      expect(File(moved).existsSync(), isTrue);
    });

    test('never overwrites an earlier deletion of the same name', () async {
      final first = writeCharacterFile(characterRoot, 'aurel');
      final firstMoved = await recycler.recycleCharacterAt(first);
      final second = writeCharacterFile(characterRoot, 'aurel');

      final secondMoved = await recycler.recycleCharacterAt(second);

      expect(secondMoved, isNot(firstMoved));
      expect(File(firstMoved).existsSync(), isTrue);
    });
  });

  group('emptying', () {
    test('reports whether there is anything to empty', () async {
      expect(recycler.hasRecycled, isFalse);

      await recycler.recycleSaveAt(writeSaveSlot(saveRoot, '000000002-go'));

      expect(recycler.hasRecycled, isTrue);
    });

    test('removes everything and leaves the live folders alone', () async {
      // The one irreversible operation in the app, which is why it is a
      // separate control with a confirm of its own.
      await recycler.recycleSaveAt(writeSaveSlot(saveRoot, '000000002-go'));
      await recycler.recycleCharacterAt(
        writeCharacterFile(characterRoot, 'aurel'),
      );

      await recycler.empty();

      expect(recycler.hasRecycled, isFalse);
      expect(
        Directory(at([saveRoot.path, '000000001-keep'])).existsSync(),
        isTrue,
        reason: 'emptying must not touch anything still live',
      );
    });

    test('is harmless when there is nothing there', () async {
      await expectLater(recycler.empty(), completes);
    });
  });
}
