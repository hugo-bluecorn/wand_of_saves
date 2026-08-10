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
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/repositories/character_file_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';

import '../../support/synthetic_save.dart';

void main() {
  late Directory temp;
  late Directory saveRoot;
  late Directory characterRoot;
  late FileCharacterFileRepository repository;

  setUp(() {
    // The real layout: `characters/` is a **sibling** of `save/`, not a
    // directory inside it. A test that nests them would pass against a
    // repository that looked in the wrong place.
    temp = Directory.systemTemp.createTempSync('wand_chr_');
    saveRoot = Directory('${temp.path}${Platform.pathSeparator}save');
    characterRoot = Directory(
      '${temp.path}${Platform.pathSeparator}characters',
    );
    writeSaveSlot(saveRoot, '000000001-a');
    repository = FileCharacterFileRepository(
      profile: GameProfileService(
        saveCandidates: [saveRoot.path],
        environment: const {},
      ),
    );
  });

  tearDown(() => temp.deleteSync(recursive: true));

  group('listing', () {
    test('is empty when the game has no characters folder at all', () async {
      // An ordinary state, not a failure: a player who has never pressed the
      // Record screen's EXPORT button has none.
      expect(await repository.listFiles(), isEmpty);
    });

    test('finds every .chr beside the save root', () async {
      writeCharacterFile(characterRoot, 'aurel');
      writeCharacterFile(characterRoot, 'Aard1');

      final found = await repository.listFiles();

      expect(
        found.map((f) => f.fileName),
        containsAll(['aurel.chr', 'Aard1.chr']),
      );
    });

    test('ignores the .bio sidecar and anything else in the folder', () async {
      writeCharacterFile(characterRoot, 'aurel', withBiography: true);
      File(
        '${characterRoot.path}${Platform.pathSeparator}notes.txt',
      ).writeAsStringSync('hello');

      expect(await repository.listFiles(), hasLength(1));
    });

    test(
      'skips a file that will not parse rather than failing the list',
      () async {
        // The same rule listSlots follows: one damaged character must not hide
        // the others.
        writeCharacterFile(characterRoot, 'good');
        File(
          '${characterRoot.path}${Platform.pathSeparator}broken.chr',
        ).writeAsBytesSync(Uint8List.fromList([1, 2, 3]));

        final found = await repository.listFiles();

        expect(found, hasLength(1));
        expect(found.single.fileName, 'good.chr');
      },
    );

    test('is newest first, as the save browser is', () async {
      writeCharacterFile(characterRoot, 'older');
      final older = File(
        '${characterRoot.path}${Platform.pathSeparator}older.chr',
      )..setLastModifiedSync(DateTime(2020));
      writeCharacterFile(characterRoot, 'newer');
      File(
        '${characterRoot.path}${Platform.pathSeparator}newer.chr',
      ).setLastModifiedSync(DateTime(2026));

      expect(older.existsSync(), isTrue);
      expect(
        (await repository.listFiles()).map((f) => f.fileName),
        ['newer.chr', 'older.chr'],
      );
    });
  });

  group('the character behind the file', () {
    test('takes its name from the CHR header, not from the record', () async {
      // The embedded record carries no name at all -- dialogFile is eight zero
      // bytes and longNameStrref is -1 on every exported character measured.
      // The 32-byte header is the only place a name lives.
      writeCharacterFile(
        characterRoot,
        'whatever',
        chr: buildCharacterFile(name: 'Aurel'),
      );

      final file = (await repository.listFiles()).single;

      expect(file.character.name, 'Aurel');
      expect(file.fileName, 'whatever.chr');
    });

    test('reads stats out of the embedded record', () async {
      writeCharacterFile(
        characterRoot,
        'aurel',
        chr: buildCharacterFile(
          character: const SyntheticCharacter(
            strengthBonus: 27,
            maximumHitPoints: 12,
          ),
        ),
      );

      final character = (await repository.listFiles()).single.character;

      expect(character.abilities.strength, 18);
      expect(character.abilities.strengthBonus, 27);
      expect(character.maximumHitPoints, 12);
      expect(character.classId, 7);
    });

    test(
      'is not in a party, and says so rather than claiming slot 0',
      () async {
        // partyOrder 0 would make a lone character look like the protagonist of
        // a save, and PORTRT0.bmp would be looked for beside a file that has no
        // sidecar at all.
        writeCharacterFile(characterRoot, 'aurel');

        final character = (await repository.listFiles()).single.character;

        expect(character.isInParty, isFalse);
        expect(character.portraitPath, isNull);
      },
    );

    test('addresses the record at the offset the header declares', () async {
      // 100 on every file measured -- and read rather than assumed, so an edit
      // lands in the right place whatever the header says.
      writeCharacterFile(characterRoot, 'aurel');

      expect(
        (await repository.listFiles()).single.character.creOffset,
        ChrHeaderField.headerSize,
      );
    });
  });

  group('resolving one by name', () {
    test('finds the file the route names', () async {
      writeCharacterFile(characterRoot, 'aurel');

      expect((await repository.fileNamed('aurel.chr'))?.fileName, 'aurel.chr');
    });

    test('answers null for a name that is not there', () async {
      writeCharacterFile(characterRoot, 'aurel');

      expect(await repository.fileNamed('gone.chr'), isNull);
    });
  });

  group('creating one by exporting', () {
    test('writes a new file and reports it', () async {
      final created = await repository.create(
        'aurel.chr',
        ChrCodec.decode(buildCharacterFile(name: 'Aurel')),
      );

      expect(created.fileName, 'aurel.chr');
      expect(created.character.name, 'Aurel');
      expect((await repository.listFiles()).single.fileName, 'aurel.chr');
    });

    test(
      'makes the characters folder when the player has never exported',
      () async {
        // The common case for a first export: `characters/` does not exist yet,
        // because the game only creates it when the Record screen writes one.
        expect(characterRoot.existsSync(), isFalse);

        await repository.create(
          'aurel.chr',
          ChrCodec.decode(buildCharacterFile()),
        );

        expect(characterRoot.existsSync(), isTrue);
      },
    );

    test('refuses to overwrite a character that is already there', () async {
      // ⚠️ Export is the one write in this app that creates rather than
      // replaces, so "already exists" is a real answer rather than a race. A
      // silent overwrite would destroy an export the player still wanted, and
      // unlike an edit there is no `.bak` convention for a file that was never
      // opened.
      final original = buildCharacterFile(name: 'Aurel');
      writeCharacterFile(characterRoot, 'aurel', chr: original);

      await expectLater(
        repository.create(
          'aurel.chr',
          ChrCodec.decode(buildCharacterFile(name: 'Someone else')),
        ),
        throwsA(isA<CharacterFileExistsException>()),
      );
      expect(
        File(
          '${characterRoot.path}${Platform.pathSeparator}aurel.chr',
        ).readAsBytesSync(),
        original,
      );
    });
  });

  group('writing', () {
    test('round-trips a load and a write with no edits', () async {
      final original = buildCharacterFile(name: 'Aurel');
      writeCharacterFile(characterRoot, 'aurel', chr: original);
      final file = (await repository.fileNamed('aurel.chr'))!;

      await repository.write(file, await repository.load(file));

      expect(File(file.path).readAsBytesSync(), original);
    });

    test('leaves a .bak of what was there', () async {
      // The rule the whole project is shaped around: never edit a real file in
      // place without a way back.
      final original = buildCharacterFile(name: 'Aurel');
      writeCharacterFile(characterRoot, 'aurel', chr: original);
      final file = (await repository.fileNamed('aurel.chr'))!;

      await repository.write(
        file,
        ChrCodec.decode(buildCharacterFile(name: 'Changed')),
      );

      expect(
        File('${file.path}$atomicBackupSuffix').readAsBytesSync(),
        original,
      );
      final written = ChrCodec.decode(File(file.path).readAsBytesSync());
      expect(written.name, 'Changed');
    });
  });
}
