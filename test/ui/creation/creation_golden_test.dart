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

/// The creation flow against a character **the engine itself made**.
///
/// `000000101-Aurel Start` is BG:EE's own output for the walkthrough kept in
/// `docs/findings/screens/char-create/` — 34 screenshots of one character being
/// created. So the choices are known from the pictures and the result is known
/// from the bytes, which makes this a golden test in the strict sense: the
/// expected values were produced by the program we are imitating, not by us.
///
/// It needs the player's installation for the rules tables and `CHARBASE`, and
/// the fixture save for the golden. Both are gitignored, so both are `skip`ped
/// on a fresh clone rather than failing it — the convention
/// `chr_export_test.dart` already follows.
///
/// ⚠️ **Only the identity fields are compared, and that is not a hedge.** The
/// engine rolled Aurel's abilities to 18/27 Strength, gave him hit points, four
/// proficiency slots, two spells and a biography. This flow copies `CHARBASE`
/// and writes five fields. Asserting whole records would fail for reasons that
/// are not defects, which is the fastest way to make a golden test worthless.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/ui/creation/creation_viewmodel.dart';
import 'package:wand_of_saves/ui/saves/save_browser_viewmodel.dart';

import '../../support/fakes.dart';

/// The fixture slot BG:EE wrote when the walkthrough finished.
const String goldenSlot =
    'packages/infinity_formats/test/fixtures/saves/'
    '000000101-Aurel Start/BALDUR.gam';

void main() {
  const profile = GameProfileService();
  final installed = profile.findGameDirectory() != null;
  final golden = File(goldenSlot).existsSync();
  final why = [
    if (!installed) 'no Baldur’s Gate installation',
    if (!golden) 'no “$goldenSlot” fixture (run tool/dev/sync_fixtures.dart)',
  ].join(' and ');

  /// What the engine stored for the character it made.
  Cre theEnginesAurel() {
    final gam = GamCodec.decode(File(goldenSlot).readAsBytesSync());
    return CreCodec.decode(gam.partyMembers.first.creBytes);
  }

  /// The real graph, with only the *writer* replaced — this test must never
  /// put a file in the player's characters folder.
  (ProviderContainer, FakeCharacterFileRepository) realContainer() {
    final characters = FakeCharacterFileRepository();
    return (
      ProviderContainer.test(
        overrides: [
          characterFileRepositoryProvider.overrideWithValue(characters),
        ],
      ),
      characters,
    );
  }

  group('what the game offered, our tables offer', () {
    test('an elf is on the list of races', () async {
      final (container, _) = realContainer();
      final catalogue = await container.read(creationCatalogueProvider.future);

      expect(
        catalogue.races.map((r) => r.identifier),
        contains('ELF'),
      );
    }, skip: installed ? false : why);

    test(
      'an elf may be a Fighter / Mage, as screen 09 shows',
      () async {
        final (container, _) = realContainer();
        final catalogue = await container.read(
          creationCatalogueProvider.future,
        );
        final elf = catalogue.races.singleWhere((r) => r.identifier == 'ELF');

        expect(
          catalogue.classesFor(elf.value).map((c) => c.identifier),
          contains('FIGHTER_MAGE'),
        );
      },
      skip: installed ? false : why,
    );

    test('a Fighter / Mage has no specialisation, which is why the '
        'walkthrough never shows one', () async {
      // ⚠️ A cross-check between two independent records of the same fact: 34
      // screenshots that go straight from Class to Alignment, and a kit table
      // that gives multi-classes nothing.
      final (container, _) = realContainer();
      final catalogue = await container.read(creationCatalogueProvider.future);
      final elf = catalogue.races.singleWhere((r) => r.identifier == 'ELF');
      final fighterMage = catalogue
          .classesFor(elf.value)
          .singleWhere((c) => c.identifier == 'FIGHTER_MAGE');

      expect(catalogue.kitsFor(fighterMage.value), isEmpty);
    }, skip: installed ? false : why);
  });

  group('making the walkthrough’s character', () {
    /// Drives the real flow with the choices the screenshots record.
    Future<Cre> ourAurel() async {
      final (container, characters) = realContainer();
      final catalogue = await container.read(creationCatalogueProvider.future);
      final model = container.read(creationProvider.notifier);

      // Chosen by identifier, never by a hardcoded number — so this also
      // proves the catalogue can find each one.
      final elf = catalogue.races.singleWhere((r) => r.identifier == 'ELF');
      final fighterMage = catalogue
          .classesFor(elf.value)
          .singleWhere((c) => c.identifier == 'FIGHTER_MAGE');

      model
        // 02-gender.png — Male.
        ..chooseGender(1)
        ..next()
        // 03-portrait-with-custom.png.
        ..choosePortrait('BDTMI')
        ..next()
        // 06-race-elf.png.
        ..chooseRace(elf)
        ..next()
        // 09-class-fighter-mage.png.
        ..chooseClass(fighterMage)
        ..next()
        // 12-alignment-neutral-good.png. No specialisation step exists here.
        ..chooseAlignment(0x21)
        ..next()
        // 31-name-aurel.png.
        ..rename('Aurel');

      final state = container.read(creationProvider);
      expect(
        state.steps,
        isNot(contains(CreationStep.kit)),
        reason: 'the walkthrough never showed a specialisation screen',
      );
      expect(state.isComplete, isTrue);

      await container
          .read(saveBrowserProvider.notifier)
          .createCharacter(
            name: state.name,
            fileName: 'golden-aurel.chr',
            portraitName: state.portraitName ?? '',
            genderId: state.genderId,
            raceId: state.race?.value,
            classId: state.characterClass?.value,
            alignmentId: state.alignmentId,
            kitValue: state.specialisation?.value,
          );

      return CreCodec.decode(characters.created.single.$2.creBytes);
    }

    test(
      'stores the gender, race, class and alignment the engine stored',
      () async {
        final theirs = theEnginesAurel();
        final ours = await ourAurel();

        expect(ours.genderId, theirs.genderId, reason: 'gender');
        expect(ours.raceId, theirs.raceId, reason: 'race');
        expect(ours.classId, theirs.classId, reason: 'class');
        expect(ours.alignmentId, theirs.alignmentId, reason: 'alignment');
      },
      skip: installed && golden ? false : why,
    );

    test(
      'stores no kit, exactly as the engine does',
      () async {
        // ⚠️ **This failed when first written, and the flow changed.** The
        // engine writes `0x40000000` — `TRUECLASS` in the high word — where
        // `CHARBASE` holds a plain `0`. Both mean "no kit", so nothing was
        // *broken*; but a Fighter / Mage has no specialisation step, and
        // leaving it unanswered left the template's `0` behind. Agreeing with
        // the engine is the point of comparing against it.
        final theirs = theEnginesAurel();
        final ours = await ourAurel();

        expect(theirs.kitId, 0x40000000);
        expect(ours.kitId, theirs.kitId);
      },
      skip: installed && golden ? false : why,
    );

    test('carries the name the player typed', () async {
      final (container, characters) = realContainer();
      await container.read(creationCatalogueProvider.future);
      await container
          .read(saveBrowserProvider.notifier)
          .createCharacter(
            name: 'Aurel',
            fileName: 'golden-aurel.chr',
            portraitName: 'BDTMI',
          );

      expect(characters.created.single.$2.name, 'Aurel');
    }, skip: installed ? false : why);
  });

  group('what this deliberately does not compare', () {
    test(
      'the record is CHARBASE’s, not a rebuilt copy of the engine’s',
      () async {
        // Stated as a test so it cannot quietly stop being true. The engine's
        // Aurel has rolled abilities, hit points, proficiencies and spells;
        // ours is the template with five fields written. They are the same
        // *character* and nothing like the same *record*, and a golden test
        // that forgot that would be deleted the first time it failed for no
        // reason.
        final theirs = theEnginesAurel();
        final ours = await () async {
          final (container, characters) = realContainer();
          await container.read(creationCatalogueProvider.future);
          await container
              .read(saveBrowserProvider.notifier)
              .createCharacter(
                name: 'Aurel',
                fileName: 'golden-aurel.chr',
                portraitName: 'BDTMI',
              );
          return CreCodec.decode(characters.created.single.$2.creBytes);
        }();

        expect(ours.strength, isNot(theirs.strength));
      },
      skip: installed && golden ? false : why,
    );
  });
}
