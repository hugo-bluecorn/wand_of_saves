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
import 'package:wand_of_saves/data/repositories/save_game_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/character.dart';

import '../../support/synthetic_save.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('wos_repo'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// The smallest GAM this repository can read: a header and nothing else.
  Uint8List gamBytes({
    int gold = 161,
    int partyCount = 1,
    int gameTime = 4791,
    String area = 'AR2600',
    String signature = 'GAME',
  }) {
    final out = Uint8List(GamCodec.minimumSize)
      ..setRange(0, 4, signature.codeUnits)
      ..setRange(4, 8, 'V2.0'.codeUnits)
      ..setRange(
        GamHeaderField.currentArea.offset,
        GamHeaderField.currentArea.offset + area.length,
        area.codeUnits,
      );
    final view = ByteData.sublistView(out);
    void put(GamHeaderField f, int v) =>
        view.setUint32(f.offset, v, Endian.little);
    put(GamHeaderField.partyGold, gold);
    put(GamHeaderField.partyNpcCount, partyCount);
    put(GamHeaderField.gameTime, gameTime);
    return out;
  }

  String makeSlot(String name, {Uint8List? gam, bool withScreenshot = false}) {
    final separator = Platform.pathSeparator;
    final dir = Directory('${tmp.path}${separator}save$separator$name')
      ..createSync(recursive: true);
    File(
      '${dir.path}${separator}BALDUR.gam',
    ).writeAsBytesSync(gam ?? gamBytes());
    if (withScreenshot) {
      File('${dir.path}${separator}BALDUR.bmp').writeAsBytesSync([0x42, 0x4d]);
    }
    return dir.path;
  }

  SaveGameRepository repositoryOver(String root) => FileSaveGameRepository(
    profile: GameProfileService(saveCandidates: [root]),
  );

  String saveRoot() => '${tmp.path}${Platform.pathSeparator}save';

  test('is empty when there is no save directory at all', () async {
    final repository = repositoryOver('/definitely/not/here');

    expect(await repository.listSlots(), isEmpty);
  });

  test('summarises a slot from its savegame header', () async {
    makeSlot('000000022-last', withScreenshot: true);

    final slots = await repositoryOver(saveRoot()).listSlots();

    expect(slots, hasLength(1));
    final slot = slots.single;
    expect(slot.directoryName, '000000022-last');
    expect(slot.label, 'last', reason: 'the digits are plumbing, not a name');
    expect(slot.area, 'AR2600');
    expect(slot.gold, 161);
    expect(slot.partySize, 1);
    expect(slot.hoursPlayed, closeTo(15.97, 0.01));
    expect(slot.screenshotPath, endsWith('BALDUR.bmp'));
  });

  test('reports a missing screenshot as null rather than a bad path', () async {
    makeSlot('000000020-start');

    final slot = (await repositoryOver(saveRoot()).listSlots()).single;

    expect(slot.screenshotPath, isNull);
  });

  test('skips a damaged slot instead of failing the whole listing', () async {
    // One unreadable save must not hide the others — that would make the app
    // look broken when only one file is.
    makeSlot('000000020-start');
    makeSlot('000000021-corrupt', gam: gamBytes(signature: 'XXXX'));

    final slots = await repositoryOver(saveRoot()).listSlots();

    expect(slots, hasLength(1));
    expect(slots.single.directoryName, '000000020-start');
  });

  test('orders slots newest first', () async {
    final older = makeSlot('000000020-start');
    final newer = makeSlot('000000022-last');
    final separator = Platform.pathSeparator;
    File('$older${separator}BALDUR.gam').setLastModifiedSync(
      DateTime(2020),
    );
    File('$newer${separator}BALDUR.gam').setLastModifiedSync(
      DateTime(2026),
    );

    final slots = await repositoryOver(saveRoot()).listSlots();

    expect(slots.map((s) => s.label), ['last', 'start']);
  });

  test('loads the full savegame behind a slot', () async {
    makeSlot('000000022-last');
    final repository = repositoryOver(saveRoot());
    final slot = (await repository.listSlots()).single;

    expect((await repository.load(slot)).partyGold, 161);
  });

  test('loading a slot that will not parse fails loudly', () async {
    // Unlike listing, where a damaged save is skipped: the user picked this
    // one, so silence would be worse than an error.
    makeSlot('000000022-last');
    final repository = repositoryOver(saveRoot());
    final slot = (await repository.listSlots()).single;
    File(
      '${slot.path}${Platform.pathSeparator}BALDUR.gam',
    ).writeAsBytesSync(gamBytes(signature: 'XXXX'));

    expect(
      () => repository.load(slot),
      throwsA(isA<InfinityFormatException>()),
    );
  });

  test('two reads of the same slot compare equal', () async {
    // dart_mappable value equality (D9): without it every refresh would look
    // like a change and rebuild the entire grid.
    makeSlot('000000022-last');
    final repository = repositoryOver(saveRoot());

    expect(
      (await repository.listSlots()).single,
      (await repository.listSlots()).single,
    );
  });

  group('slotNamed', () {
    test('resolves a slot from its directory name', () async {
      // This is what the route parameter carries: the directory name survives
      // a reload, where an in-memory object would not.
      makeSlot('000000020-start');
      makeSlot('000000022-last');

      final slot = await repositoryOver(saveRoot()).slotNamed(
        '000000022-last',
      );

      expect(slot, isNotNull);
      expect(slot!.label, 'last');
      expect(slot.gold, 161);
    });

    test('is null for a name that is not there', () async {
      makeSlot('000000022-last');

      expect(
        await repositoryOver(saveRoot()).slotNamed('000000099-gone'),
        isNull,
      );
    });

    test('is null when there is no save directory at all', () async {
      expect(
        await repositoryOver('/definitely/not/here').slotNamed('anything'),
        isNull,
      );
    });
  });

  group('party', () {
    Future<List<Character>> partyOf(
      List<SyntheticCharacter> characters, {
      List<int> portraits = const [],
    }) async {
      final separator = Platform.pathSeparator;
      writeSaveSlot(
        Directory('${tmp.path}${separator}save')..createSync(recursive: true),
        '000000022-last',
        gam: buildSave(party: characters),
        portraits: portraits,
      );
      final repository = repositoryOver(saveRoot());
      final slot = (await repository.listSlots()).single;
      return repository.party(slot);
    }

    test('reads one character per party struct', () async {
      // Two members, because every real fixture has exactly one -- the blind
      // spot that hid the spike's stride of -180. A wrong stride reads the
      // second character out of the middle of the first.
      final party = await partyOf(const [
        SyntheticCharacter(),
        SyntheticCharacter(
          resref: '*INSC',
          displayName: '',
          nameStrref: 9501,
          partyOrder: 1,
          experience: 36293,
        ),
      ]);

      expect(party, hasLength(2));
      expect(party[0].creResref, '*HARBASE');
      expect(party[1].creResref, '*INSC');
      expect(party[1].experience, 36293);
      expect(party[1].partyOrder, 1);
    });

    test('reads the stats out of the embedded creature record', () async {
      final character = (await partyOf(const [SyntheticCharacter()])).single;

      expect(character.currentHitPoints, 6);
      expect(character.maximumHitPoints, 7);
      expect(character.experience, 325);
      expect(character.thac0, 20);
      expect(character.armorClass, 10);
      expect(character.levels, [1, 1, 0]);
      expect(character.reputation, 11.0);
      expect(character.abilities.strength, 18);
      expect(character.abilities.strengthLabel, '18/00');
      expect(character.abilities.dexterity, 17);
      expect(character.abilities.constitution, 16);
      expect(character.abilities.intelligence, 18);
      expect(character.abilities.wisdom, 9);
      expect(character.abilities.charisma, 9);
    });

    test('reads a negative armour class as negative', () async {
      // Plate and shield. Read unsigned this is 65534, and no real fixture
      // would catch it -- every creature in the save sits at AC 10.
      final party = await partyOf(const [SyntheticCharacter(armorClass: -2)]);

      expect(party.single.armorClass, -2);
    });

    test('carries who the character is, as the engine numbers it', () async {
      // Naming these is CLASS.IDS/RACE.IDS/ALIGNMEN.IDS, which is game data,
      // not file layout -- so the projection reports numbers and the rules
      // layer turns them into "Fighter / Mage", "Elf", "Neutral Good".
      final character = (await partyOf(const [SyntheticCharacter()])).single;

      expect(character.classId, 7);
      expect(character.raceId, 2);
      expect(character.alignmentId, 0x21);
    });

    test('carries the byte identity an edit will need', () async {
      // A character is addressed by where they are in the file. Two party
      // members may legitimately share a name.
      final character = (await partyOf(const [SyntheticCharacter()])).single;

      expect(character.structOffset, syntheticPartyOffset);
      expect(character.creOffset, greaterThan(character.structOffset));
      expect(character.creLength, 724);
    });

    test('leaves the name empty when the save carries none', () async {
      // The 36 companions waiting to be recruited are stored this way.
      // Resolving the strref needs the talk table, which is a different
      // repository -- so that merge happens above this layer, not here.
      final party = await partyOf(const [
        SyntheticCharacter(displayName: '', nameStrref: 9501),
      ]);

      expect(party.single.name, isEmpty);
      expect(party.single.nameStrref, 9501);
    });

    test("takes the protagonist's name from the savegame", () async {
      final character = (await partyOf(const [SyntheticCharacter()])).single;

      expect(character.name, 'Aard');
      expect(character.nameStrref, -1);
    });

    test('finds the portrait the game wrote beside the savegame', () async {
      final party = await partyOf(
        const [SyntheticCharacter(), SyntheticCharacter(partyOrder: 1)],
        portraits: [0, 1],
      );

      expect(party[0].portraitPath, endsWith('PORTRT0.bmp'));
      expect(party[1].portraitPath, endsWith('PORTRT1.bmp'));
    });

    test('reports a missing portrait as null rather than a bad path', () async {
      final party = await partyOf(const [SyntheticCharacter()]);

      expect(party.single.portraitPath, isNull);
    });

    test('writes an edited save and leaves the original as a .bak', () async {
      // The rule the whole project is built around: never edit a real save in
      // place, always leave a way back.
      final separator = Platform.pathSeparator;
      final original = buildSave();
      writeSaveSlot(
        Directory('${tmp.path}${separator}save')..createSync(recursive: true),
        '000000022-last',
        gam: original,
      );
      final repository = repositoryOver(saveRoot());
      final slot = (await repository.listSlots()).single;
      final gam = await repository.load(slot);

      await repository.write(
        slot,
        gam.withCreatureField(
          creOffset: gam.partyMembers.single.creOffset,
          field: CreHeaderField.strength,
          value: 19,
        ),
      );

      final reread = await repository.party(slot);
      expect(reread.single.abilities.strength, 19);
      expect(
        File(
          '${slot.path}${separator}BALDUR.gam$atomicBackupSuffix',
        ).readAsBytesSync(),
        orderedEquals(original),
        reason: 'the backup must hold exactly what was there before',
      );
    });

    test('leaves no temporary file behind', () async {
      final separator = Platform.pathSeparator;
      writeSaveSlot(
        Directory('${tmp.path}${separator}save')..createSync(recursive: true),
        '000000022-last',
      );
      final repository = repositoryOver(saveRoot());
      final slot = (await repository.listSlots()).single;

      await repository.write(slot, await repository.load(slot));

      expect(
        File(
          '${slot.path}${separator}BALDUR.gam$atomicTempSuffix',
        ).existsSync(),
        isFalse,
      );
    });

    test('a damaged creature record fails loudly', () async {
      // Unlike listing, where a broken save is skipped: the user chose to open
      // this one, so silence would be worse than an error.
      expect(
        partyOf(const [SyntheticCharacter(creSignature: 'XXXX')]),
        throwsA(isA<InfinityFormatException>()),
      );
    });
  });
}
