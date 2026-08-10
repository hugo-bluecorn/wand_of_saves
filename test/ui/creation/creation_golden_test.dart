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
/// **What is compared has grown with the flow.** It began as the five identity
/// fields, because that was all creation wrote. It now also covers the three
/// sections `CHARBASE` does not have and this flow has to *create* —
/// proficiencies, the spellbook and the memorisation row — and on all three the
/// record this app builds equals the one BG:EE built.
///
/// ⚠️ **Two things are still deliberately not compared, and neither is a
/// hedge.** The **abilities**, because the engine's roller is undocumented and
/// a random roll cannot equal a recorded one — what is asserted is that every
/// score landed inside the bounds the game itself prints. And the **whole
/// record**, because the engine's Aurel also has hit points, a biography and an
/// item, and a golden test that fails for reasons which are not defects is one
/// that gets deleted.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/ui/creation/creation_viewmodel.dart';
import 'package:wand_of_saves/ui/saves/save_browser_viewmodel.dart';

import '../../support/fakes.dart';

/// The fixture slot BG:EE wrote when the walkthrough finished.
const String goldenSlot =
    'packages/infinity_formats/test/fixtures/saves/'
    '000000101-Aurel Start/BALDUR.gam';

void main() {
  // The three the engine's own Aurel carries, by `weapprof.2da`'s `ID` column.
  // Read off his record rather than typed from the screenshots — the pictures
  // say War Hammer, Flail and Two-Weapon Style, and these are the numbers.
  const warHammer = 100;
  const flail = 97;
  const twoWeaponStyle = 114;

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

    test(
      'exactly the 22 first-level spells the Mage Book screen lists',
      () async {
        // ⚠️ **The count no filter would have found by accident.** 108 `SPL`
        // resources claim to be first-level wizard spells; the engine's own
        // screen offers 22, and getting from one number to the other took
        // three separate filters. See `ResourceRepository.wizardSpells`.
        final (container, _) = realContainer();
        final catalogue = await container.read(
          creationCatalogueProvider.future,
        );

        expect(catalogue.wizardSpells, hasLength(22));
        expect(
          catalogue.wizardSpells.map((s) => s.resref),
          contains('SPWI112'),
          reason: 'Magic Missile, which Aurel learned',
        );
        // ⚠️ SPWI109 does not exist. Enumerating the index rather than a range
        // is what makes the gap a non-event.
        expect(
          catalogue.wizardSpells.map((s) => s.resref),
          isNot(contains('SPWI109')),
        );
      },
      skip: installed ? false : why,
    );

    test(
      'names the spells with the words the game prints',
      () async {
        final (container, _) = realContainer();
        final catalogue = await container.read(
          creationCatalogueProvider.future,
        );
        final missile = catalogue.wizardSpells.singleWhere(
          (s) => s.resref == 'SPWI112',
        );

        expect(catalogue.textFor(missile.nameStrref), 'Magic Missile');
      },
      skip: installed ? false : why,
    );

    test(
      'gives a Fighter / Mage four proficiency slots and one spell slot',
      () async {
        // The engine's own Aurel spent exactly four pips and memorised one.
        final (container, _) = realContainer();
        final catalogue = await container.read(
          creationCatalogueProvider.future,
        );

        expect(catalogue.proficiencySlotsFor('FIGHTER_MAGE'), 4);
        expect(catalogue.proficiencyRankCapFor('FIGHTER_MAGE'), 2);
        expect(catalogue.wizardSpellsMemorisable, 1);
      },
      skip: installed ? false : why,
    );

    test(
      'an elf rolls Dexterity 7 to 19, as screen 14 prints it',
      () async {
        final (container, _) = realContainer();
        final catalogue = await container.read(
          creationCatalogueProvider.future,
        );
        final elf = catalogue.races.singleWhere((r) => r.identifier == 'ELF');

        expect(
          catalogue.abilityBoundsFor(
            raceId: elf.value,
            characterClass: 'FIGHTER_MAGE',
            ability: CreationAbility.dexterity,
          ),
          (minimum: 7, maximum: 19),
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

  /// Drives the real flow with the choices the screenshots record.
  ///
  /// Hoisted out of its group because two of them compare against it now: the
  /// identity fields, and the sections the flow had to *grow*.
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
      // 14-abilities-rolled.png. The engine's own numbers are not
      // reproducible — its roller is undocumented — so the roll is taken as
      // it comes and only the *shape* of the step is asserted.
      ..roll()
      ..next()
      // 18-proficiencies-hammer-flail.png and 19-…-two-weapon-style.png.
      ..raiseProficiency(warHammer)
      ..raiseProficiency(flail)
      ..raiseProficiency(twoWeaponStyle)
      ..raiseProficiency(twoWeaponStyle)
      ..next()
      // 22-mage-book-magic-missile.png: two chosen. 24-…: one memorised.
      ..learnSpell('SPWI114')
      ..learnSpell('SPWI112')
      ..memoriseSpell('SPWI112')
      ..next()
      // 31-name-aurel.png.
      ..rename('Aurel');

    final state = container.read(creationProvider);
    expect(
      state.steps,
      isNot(contains(CreationStep.kit)),
      reason: 'the walkthrough never showed a specialisation screen',
    );
    expect(
      state.proficiencyPipsRemaining,
      0,
      reason: 'four pips, exactly the four profs.2da gives a Fighter / Mage',
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
          abilities: {
            for (final MapEntry(key: ability, value: score)
                in state.abilities.entries)
              ability.stat: score,
          },
          derived: container.read(creationProvider.notifier).derivedStats(),
          classLevels: state.classLevels,
          proficiencies: state.proficiencies,
          knownSpells: state.knownSpells,
          memorisedSpells: state.memorisedSpells,
          spellsMemorisable: state.spellsMemorisable,
        );

    return CreCodec.decode(characters.created.single.$2.creBytes);
  }

  group('making the walkthrough’s character', () {
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

  group('the record it grew, against the record the engine grew', () {
    test(
      'carries the same three proficiencies at the same pips',
      () async {
        // ⚠️ **`CHARBASE` has zero effects**, so every one of these is a
        // section this flow created and a 264-byte record it appended. That the
        // engine's own character holds exactly the same map is the strongest
        // statement available short of loading the game.
        final theirs = theEnginesAurel();
        final ours = await ourAurel();

        expect(ours.proficiencies, theirs.proficiencies);
        expect(ours.proficiencies, {warHammer: 1, flail: 1, twoWeaponStyle: 2});
      },
      skip: installed && golden ? false : why,
    );

    test(
      'knows the same two spells and has prepared the same one',
      () async {
        final theirs = theEnginesAurel();
        final ours = await ourAurel();

        expect(
          ours.knownSpells.map((s) => (s.resref, s.level, s.type)),
          theirs.knownSpells.map((s) => (s.resref, s.level, s.type)),
        );
        expect(
          ours.memorizedSpells.map((s) => (s.resref, s.isMemorized)),
          theirs.memorizedSpells.map((s) => (s.resref, s.isMemorized)),
        );
      },
      skip: installed && golden ? false : why,
    );

    test(
      'its memorisation row says what the engine’s says',
      () async {
        // ⚠️ **Not row for row** — the engine writes a full grid of sixteen and
        // this writes the one it uses. What has to match is the row that
        // *carries* something: same level, same type, same window, and the same
        // number of slots.
        final theirs = theEnginesAurel().memorizations.singleWhere(
          (r) => r.count > 0,
        );
        final ours = (await ourAurel()).memorizations.singleWhere(
          (r) => r.count > 0,
        );

        expect(ours, theirs);
      },
      skip: installed && golden ? false : why,
    );

    test(
      'the record still reconciles after everything it grew',
      () async {
        // The single check that covers all six section pointers, every entry
        // size and the effect-version flag — after four resizes.
        final ours = await ourAurel();

        expect(ours.contentEnd, ours.bytes.length);
        expect(
          ours.effectVersion,
          1,
          reason:
              'CHARBASE arrives as v1 with no effects; the engine’s own '
              'finished character is v2',
        );
      },
      skip: installed && golden ? false : why,
    );

    test(
      'every ability landed inside what the tables allow',
      () async {
        // The roll is not comparable — the engine's roller is undocumented —
        // but the bounds are, and they are the numbers the game prints.
        final (container, _) = realContainer();
        final catalogue = await container.read(
          creationCatalogueProvider.future,
        );
        final ours = await ourAurel();
        final elf = catalogue.races.singleWhere((r) => r.identifier == 'ELF');
        final stored = {
          CreationAbility.strength: ours.strength,
          CreationAbility.dexterity: ours.dexterity,
          CreationAbility.constitution: ours.constitution,
          CreationAbility.intelligence: ours.intelligence,
          CreationAbility.wisdom: ours.wisdom,
          CreationAbility.charisma: ours.charisma,
        };

        for (final MapEntry(key: ability, value: score) in stored.entries) {
          final bounds = catalogue.abilityBoundsFor(
            raceId: elf.value,
            characterClass: 'FIGHTER_MAGE',
            ability: ability,
          );
          expect(
            score,
            inInclusiveRange(bounds.minimum, bounds.maximum),
            reason: ability.label,
          );
        }
      },
      skip: installed && golden ? false : why,
    );
  });

  group('the fields the engine writes at creation and never maintains', () {
    // ⚠️ **D14's sixty-seven.** The engine wrote these into its own Aurel and
    // then left them alone through import and play, so a character created
    // without them keeps the template's values for the whole game. Comparing
    // against the engine's own record is the only way to know ours are right.
    test(
      'the five saving throws are the engine’s, exactly',
      () async {
        final theirs = theEnginesAurel().savingThrows;
        final ours = (await ourAurel()).savingThrows;

        expect(ours.death, theirs.death, reason: 'death');
        expect(ours.wands, theirs.wands, reason: 'wands');
        expect(ours.polymorph, theirs.polymorph, reason: 'polymorph');
        expect(ours.breath, theirs.breath, reason: 'breath');
        expect(ours.spells, theirs.spells, reason: 'spells');
      },
      skip: installed && golden ? false : why,
    );

    test(
      'THAC0 and Lore are the engine’s',
      () async {
        final theirs = theEnginesAurel();
        final ours = await ourAurel();

        expect(
          ours.readField(CreHeaderField.thac0),
          theirs.readField(CreHeaderField.thac0),
          reason: 'THAC0',
        );
        expect(
          ours.readField(CreHeaderField.lore),
          theirs.readField(CreHeaderField.lore),
          reason: 'Lore',
        );
      },
      skip: installed && golden ? false : why,
    );

    test(
      'the class levels are 1/1/0, and the third slot is cleared',
      () async {
        // ⚠️ The template's own levels would otherwise survive, and a Fighter /
        // Mage carrying a third would read as a triple-class to anything
        // counting filled slots.
        final theirs = theEnginesAurel();
        final ours = await ourAurel();

        expect(ours.levels, theirs.levels);
        expect(ours.levels, (1, 1, 0));
      },
      skip: installed && golden ? false : why,
    );

    test(
      'the morale break is below morale, so the character can be played',
      () async {
        final ours = await ourAurel();

        expect(
          ours.readField(CreHeaderField.moraleBreak),
          lessThan(ours.readField(CreHeaderField.morale)),
        );
      },
      skip: installed && golden ? false : why,
    );
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
