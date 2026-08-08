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
import 'package:wand_of_saves/data/repositories/string_repository.dart';

import '../../support/synthetic_tlk.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('wos_strings'));
  tearDown(() => tmp.deleteSync(recursive: true));

  TlkStringRepository repositoryOver(List<String> strings) {
    final repository = TlkStringRepository(path: writeTlk(tmp, strings));
    addTearDown(repository.close);
    return repository;
  }

  test('returns the text behind a strref', () async {
    final repository = repositoryOver(['Minsc', 'Dynaheir', 'Jaheira']);

    expect(await repository.lookup(1), 'Dynaheir');
  });

  test('decodes non-ASCII text as UTF-8', () async {
    // The project record said cp1252 for a long time and was wrong; a name
    // with an umlaut is the cheapest guard against that regressing.
    final repository = repositoryOver(['Söhne der Küste', 'Хранитель']);

    expect(await repository.lookup(0), 'Söhne der Küste');
    expect(await repository.lookup(1), 'Хранитель');
  });

  test('is null for a negative strref', () async {
    // The protagonist's creature record carries 0xFFFFFFFF, so this is the
    // ordinary case rather than an error: their name lives in the GAM.
    final repository = repositoryOver(['Minsc']);

    expect(await repository.lookup(-1), isNull);
  });

  test('is null past the end of the table', () async {
    final repository = repositoryOver(['Minsc']);

    expect(await repository.lookup(9999), isNull);
  });

  test(
    'is null rather than throwing when the file is not a talk table',
    () async {
      // A name that will not resolve must degrade to a fallback, not take the
      // party screen down with it.
      final repository = TlkStringRepository(
        path: writeTlk(tmp, ['Minsc'], signature: 'XXXX'),
      );
      addTearDown(repository.close);

      expect(await repository.lookup(0), isNull);
    },
  );

  test('is null when the file does not exist', () async {
    final repository = TlkStringRepository(
      path: '${tmp.path}${Platform.pathSeparator}absent.tlk',
    );
    addTearDown(repository.close);

    expect(await repository.lookup(0), isNull);
  });

  test('survives a second lookup after a failed open', () async {
    // The open is memoised, so a failure must be memoised as a failure rather
    // than left as a broken future that rethrows on every later lookup.
    final repository = TlkStringRepository(
      path: '${tmp.path}${Platform.pathSeparator}absent.tlk',
    );
    addTearDown(repository.close);

    expect(await repository.lookup(0), isNull);
    expect(await repository.lookup(1), isNull);
  });

  test('closing without ever looking anything up is harmless', () async {
    final repository = TlkStringRepository(path: writeTlk(tmp, ['Minsc']));

    await expectLater(repository.close(), completes);
  });

  test('the absent repository answers null for everything', () async {
    // A machine with saves but no game installed: strrefs cannot resolve, and
    // that is an ordinary state rather than a failure.
    const repository = AbsentStringRepository();

    expect(await repository.lookup(0), isNull);
    expect(await repository.lookup(9501), isNull);
  });
}
