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

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late String target;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('infinity_atomic');
    target = '${tmp.path}${Platform.pathSeparator}BALDUR.gam';
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Uint8List bytes(List<int> values) => Uint8List.fromList(values);

  test('writes the bytes to the target', () async {
    await writeFileAtomically(target, bytes([1, 2, 3]));

    expect(File(target).readAsBytesSync(), orderedEquals([1, 2, 3]));
  });

  test('leaves a .bak holding exactly what was there before', () async {
    File(target).writeAsBytesSync([9, 9, 9]);

    await writeFileAtomically(target, bytes([1, 2, 3]));

    expect(File('$target.bak').readAsBytesSync(), orderedEquals([9, 9, 9]));
    expect(File(target).readAsBytesSync(), orderedEquals([1, 2, 3]));
  });

  test('writes no .bak when there was nothing to back up', () async {
    await writeFileAtomically(target, bytes([1, 2, 3]));

    expect(File('$target.bak').existsSync(), isFalse);
  });

  test('leaves no temp file behind on success', () async {
    await writeFileAtomically(target, bytes([1, 2, 3]));

    expect(File('$target.tmp').existsSync(), isFalse);
  });

  test('leaves the target untouched when the write fails', () async {
    // Forced naturally rather than through a test-only seam: a directory
    // sitting where the temp file goes makes writing it throw. The target is
    // only ever modified by the final rename, so it must survive intact --
    // which for a savegame is the difference between "unchanged" and
    // "destroyed".
    File(target).writeAsBytesSync([9, 9, 9]);
    Directory('$target.tmp').createSync();

    await expectLater(
      writeFileAtomically(target, bytes([1, 2, 3])),
      throwsA(isA<FileSystemException>()),
    );
    expect(File(target).readAsBytesSync(), orderedEquals([9, 9, 9]));
  });
}
