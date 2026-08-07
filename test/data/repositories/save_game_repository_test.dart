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
}
