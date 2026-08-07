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

import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('infinity_fixtures'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String slotRoot() => '${tmp.path}${Platform.pathSeparator}saves';

  Directory makeSlot(String name, {bool withGam = true}) {
    final dir = Directory('${slotRoot()}${Platform.pathSeparator}$name')
      ..createSync(recursive: true);
    if (withGam) {
      File(
        '${dir.path}${Platform.pathSeparator}BALDUR.gam',
      ).writeAsBytesSync([0x47, 0x41, 0x4d, 0x45]);
    }
    return dir;
  }

  group('fixtureSaveSlot', () {
    test('is null when the fixture root does not exist', () {
      // The expected state on a fresh clone: fixtures are gitignored, so
      // suites must skip rather than fail.
      expect(fixtureSaveSlot('000000022-last', root: slotRoot()), isNull);
    });

    test('is null when the named slot is absent', () {
      makeSlot('000000020-start');

      expect(fixtureSaveSlot('000000022-last', root: slotRoot()), isNull);
    });

    test('is null when the slot exists but holds no BALDUR.gam', () {
      // A half-copied fixture is worse than none: it would fail obscurely
      // deep inside a codec rather than skipping cleanly here.
      makeSlot('000000022-last', withGam: false);

      expect(fixtureSaveSlot('000000022-last', root: slotRoot()), isNull);
    });

    test('is the slot directory when it holds a BALDUR.gam', () {
      final slot = makeSlot('000000022-last');

      expect(fixtureSaveSlot('000000022-last', root: slotRoot()), slot.path);
    });
  });

  group('the default root', () {
    // Guards the worst failure mode in this harness: if the default root were
    // wrong, every fixture-backed suite would silently skip and the whole
    // thing would look green. This test skips too when fixtures genuinely are
    // absent — but says so, and says what to run.
    final slot = fixtureSaveSlot('000000022-last');

    test(
      'resolves a synced fixture from the package root',
      () {
        expect(slot, endsWith('000000022-last'));
        expect(fixtureGam('000000022-last'), endsWith(gamFileName));
      },
      skip: slot == null
          ? 'no fixtures: run `fvm dart run tool/dev/sync_fixtures.dart` '
                'from the repository root'
          : null,
    );
  });

  group('fixtureGam', () {
    test('is null when the slot is unusable', () {
      expect(fixtureGam('000000022-last', root: slotRoot()), isNull);
    });

    test('points at BALDUR.gam inside the slot', () {
      final slot = makeSlot('000000022-last');

      expect(
        fixtureGam('000000022-last', root: slotRoot()),
        '${slot.path}${Platform.pathSeparator}BALDUR.gam',
      );
    });
  });
}
