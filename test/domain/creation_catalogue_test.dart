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

import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';

/// The real `clsrcreq.2da`, its 21 `CLASS.IDS` rows copied verbatim.
///
/// ⚠️ **The whole matrix, not a sample.** "An elf may take exactly ten classes"
/// is only worth asserting against every row that could have said otherwise.
const String _classRaceRequirements = '''
2DA V1.0
0
                    HUMAN      ELF        HALF_ELF   DWARF      HALFLING   GNOME      HALFORC
MAGE                1          1          1          0          0          1          0
FIGHTER             1          1          1          1          1          1          1
CLERIC              1          1          1          1          1          1          1
THIEF               1          1          1          1          1          1          1
BARD                1          0          1          0          0          0          0
PALADIN             1          0          0          0          0          0          0
FIGHTER_MAGE        0          1          1          0          0          1          0
FIGHTER_CLERIC      0          0          1          1          0          1          1
FIGHTER_THIEF       0          1          1          1          1          1          1
FIGHTER_MAGE_THIEF  0          1          1          0          0          0          0
DRUID               1          0          1          0          0          0          0
RANGER              1          1          1          0          0          0          0
MAGE_THIEF          0          1          1          0          0          1          0
CLERIC_MAGE         0          0          1          0          0          1          0
CLERIC_THIEF        0          0          0          0          0          1          1
FIGHTER_DRUID       0          0          1          0          0          0          0
FIGHTER_MAGE_CLERIC 0          0          1          0          0          0          0
CLERIC_RANGER       0          0          1          0          0          0          0
SORCERER            1          1          1          0          0          0          0
MONK                1          0          0          0          0          0          0
SHAMAN              1          0          1          0          0          0          1
''';

/// `alignmnt.2da`, the rows this suite reasons about, copied verbatim.
///
/// ⚠️ **Kits are rows here too, and they differ from their class.** A Fighter
/// may take any alignment; a Kensai may take none of the three chaotic ones.
const String _alignmentRequirements = '''
2DA V1.0
0
                    L_G   L_N   L_E   N_G   N_N   N_E   C_G   C_N   C_E
MAGE                1     1     1     1     1     1     1     1     1
FIGHTER             1     1     1     1     1     1     1     1     1
THIEF               0     1     1     1     1     1     1     1     1
PALADIN             1     0     0     0     0     0     0     0     0
RANGER              1     0     0     1     0     0     1     0     0
DRUID               0     0     0     0     1     0     0     0     0
FIGHTER_MAGE        1     1     1     1     1     1     1     1     1
KENSAI              1     1     1     1     1     1     0     0     0
BERSERKER           0     0     0     1     1     1     1     1     1
''';

/// `kitlist.2da`, copied verbatim for the Ranger's three and two Fighter kits.
///
/// ⚠️ **`FERALAN` is what the engine displays as "Archer"** — strref 25335.
/// The identifier is not the name, which is the whole reason this table's
/// strrefs are carried rather than its row labels.
const String _kits = '''
2DA V1.0
*
     ROWNAME      LOWER   MIXED   HELP    ABILITIES  PROFICIENCY UNUSABLE   CLASS  KITIDS
0    RESERVE      *       *       *       *          *           *          *      *
1    BERSERKER    25298   25329   24284   CLABFI02   29          0x00000001 2      0x00004001
3    KENSAI       25300   25331   24286   CLABFI04   31          0x00000004 2      0x00004003
7    FERALAN      25304   25335   24298   CLABRN02   35          0x00008000 12     0x00004007
8    STALKER      25305   25336   24299   CLABRN03   36          0x00010000 12     0x00004008
9    BEASTMASTER  25306   25337   24300   CLABRN04   37          0x00020000 12     0x00004009
23   NECROMANCER  25325   25356   24296   *          *           0x00001000 1      0x00001000
''';

/// `clastext.2da`, copied verbatim for the classes this suite names.
///
/// ⚠️ **`KITID` is `16384` on a plain class** — `0x4000`, `TRUECLASS` — which
/// is how a class row is told from a kit row sharing its `CLASSID`.
const String _classText = '''
2DA V1.0
-1
                    CLASSID  KITID   LOWER   DESCSTR  MIXED   BIOGRAPHY  FALLEN  BRIEFDESC
FIGHTER             2        16384   7201    9556     1076    15881      0       31252
MAGE                1        16384   7191    9563     1069    15884      0       31255
RANGER              12       16384   7206    9557     1081    15887      0       31253
FIGHTER_MAGE        7        16384   7211    9574     1086    15881      0       31252
KENSAI              2        3       25300   24286    25331   15881      0       31252
''';

/// `racetext.2da`, copied verbatim.
///
/// ⚠️ **The row label is `HALF_ORC` where `RACE.IDS` says `HALFORC`.** That is
/// why the join is on the `ID` column and never on the label — the same lesson
/// `weapprof.2da` already taught about row labels not being keys.
const String _raceText = '''
2DA V1.0
-1
          ID   NAME    DESCSTR  UPPERCASE  BIOGRAPHY
HUMAN     1    7193    9550     1096       15895
ELF       2    7194    9552     1097       15891
HALF_ELF  3    7197    9555     1098       15892
DWARF     4    7182    9551     1100       15890
HALFLING  5    7195    9554     1101       15893
GNOME     6    7196    9553     1099       15894
HALF_ORC  7    24200   24204    24202      31709
''';

/// `abracead.2da`, copied verbatim — the racial ability adjustments.
const String _racialAdjustments = '''
2DA V1.0
0
         MOD_STR  MOD_DEX  MOD_CON  MOD_INT  MOD_WIS  MOD_CHR
HUMAN    0        0        0        0        0        0
DWARF    0        -1       1        0        0        -2
ELF      0        1        -1       0        0        0
GNOME    0        0        0        1        -1       0
HALF_ELF 0        0        0        0        0        0
HALFLING -1       1        0        0        -1       0
HALFORC  1        0        1        -2       0        0
''';

CreationCatalogue buildCatalogue() => creationCatalogueFrom(
  classRaceRequirements: Table2da.parse(_classRaceRequirements),
  alignmentRequirements: Table2da.parse(_alignmentRequirements),
  kits: Table2da.parse(_kits),
  classText: Table2da.parse(_classText),
  raceText: Table2da.parse(_raceText),
  racialAdjustments: Table2da.parse(_racialAdjustments),
  rules: const GeneratedGameRules(),
);

void main() {
  const elf = 2;
  const dwarf = 4;
  const human = 1;
  const halfOrc = 7;
  const ranger = 12;
  const fighter = 2;
  const fighterMage = 7;

  group('races', () {
    test('are the columns of the class table, not a hardcoded list', () {
      final races = buildCatalogue().races.map((r) => r.identifier).toList();

      expect(races, hasLength(7));
      expect(races, contains('HALFORC'));
    });

    test('carry the description strref, joined on ID not on row label', () {
      // ⚠️ racetext labels the row HALF_ORC where RACE.IDS says HALFORC. A
      // label join silently loses exactly this race.
      final orc = buildCatalogue().races.singleWhere((r) => r.value == halfOrc);

      expect(orc.identifier, 'HALFORC');
      expect(orc.descriptionStrref, 24204);
    });

    test('give the elf the description the game prints', () {
      final elves = buildCatalogue().races.singleWhere((r) => r.value == elf);

      expect(elves.descriptionStrref, 9552);
    });
  });

  group('classes for a race', () {
    test('an elf may take exactly the ten the game lists', () {
      // Verified against the engine's own screen —
      // docs/findings/screens/char-create/08-class-list.png.
      final classes = buildCatalogue()
          .classesFor(elf)
          .map((c) => c.identifier)
          .toSet();

      expect(classes, {
        'MAGE',
        'FIGHTER',
        'CLERIC',
        'THIEF',
        'FIGHTER_MAGE',
        'FIGHTER_THIEF',
        'FIGHTER_MAGE_THIEF',
        'RANGER',
        'MAGE_THIEF',
        'SORCERER',
      });
    });

    test('a dwarf may take exactly five', () {
      expect(buildCatalogue().classesFor(dwarf), hasLength(5));
    });

    test('only a human may be a paladin or a monk', () {
      bool has(int race, String what) =>
          buildCatalogue().classesFor(race).any((c) => c.identifier == what);

      expect(has(human, 'PALADIN'), isTrue);
      expect(has(human, 'MONK'), isTrue);
      expect(has(elf, 'PALADIN'), isFalse);
      expect(has(dwarf, 'MONK'), isFalse);
    });

    test('carry the value the record stores and the description strref', () {
      final fighterChoice = buildCatalogue()
          .classesFor(elf)
          .singleWhere((c) => c.identifier == 'FIGHTER');

      expect(fighterChoice.value, fighter);
      expect(fighterChoice.descriptionStrref, 9556);
    });

    test('take the class row of clastext, never a kit row sharing its id', () {
      // KENSAI has CLASSID 2, the same as FIGHTER. Only KITID 16384 tells them
      // apart, and picking the wrong row describes a Fighter as a Kensai.
      final fighterChoice = buildCatalogue()
          .classesFor(human)
          .singleWhere((c) => c.identifier == 'FIGHTER');

      expect(fighterChoice.descriptionStrref, isNot(24286));
    });
  });

  group('kits for a class', () {
    test('a ranger has three, named by strref because the label is not', () {
      // ⚠️ FERALAN is displayed as "Archer". Resolving 25335 against the
      // player's dialog.tlk is the only way to learn that.
      final kits = buildCatalogue().kitsFor(ranger);

      expect(kits.map((k) => k.identifier), [
        'FERALAN',
        'STALKER',
        'BEASTMASTER',
      ]);
      expect(
        kits.singleWhere((k) => k.identifier == 'FERALAN').nameStrref,
        25335,
      );
    });

    test('store the KIT.IDS key in the high word', () {
      // ⚠️ Measured, not derived: Xzar is a Necromancer and his record holds
      // 0x10000000, where kitlist gives NECROMANCER a KITIDS of 0x1000.
      final necromancer = buildCatalogue()
          .kitsFor(1)
          .singleWhere((k) => k.identifier == 'NECROMANCER');

      expect(necromancer.value, 0x10000000);
    });

    test('a multi-class has none', () {
      expect(buildCatalogue().kitsFor(fighterMage), isEmpty);
    });

    test('skip the reserved row', () {
      expect(
        buildCatalogue().kitsFor(fighter).map((k) => k.identifier),
        isNot(contains('RESERVE')),
      );
    });
  });

  group('alignments', () {
    test('a paladin may only be lawful good', () {
      final paladin = buildCatalogue()
          .classesFor(human)
          .singleWhere((c) => c.identifier == 'PALADIN');

      expect(buildCatalogue().alignmentsFor(characterClass: paladin), [0x11]);
    });

    test('a fighter may be anything', () {
      final fighterChoice = buildCatalogue()
          .classesFor(human)
          .singleWhere((c) => c.identifier == 'FIGHTER');

      expect(
        buildCatalogue().alignmentsFor(characterClass: fighterChoice),
        hasLength(9),
      );
    });

    test('a kensai may not be chaotic, where a plain fighter may', () {
      // ⚠️ This is why the specialisation step comes *before* alignment: the
      // kit's row governs, not the class's.
      final catalogue = buildCatalogue();
      final fighterChoice = catalogue
          .classesFor(human)
          .singleWhere((c) => c.identifier == 'FIGHTER');
      final kensai = catalogue
          .kitsFor(fighter)
          .singleWhere((k) => k.identifier == 'KENSAI');

      final allowed = catalogue.alignmentsFor(
        characterClass: fighterChoice,
        kit: kensai,
      );

      expect(allowed, hasLength(6));
      expect(allowed, isNot(contains(0x31)));
      expect(allowed, isNot(contains(0x32)));
      expect(allowed, isNot(contains(0x33)));
    });
  });

  group('racial ability adjustments', () {
    test('an elf trades constitution for dexterity', () {
      // The line the game prints under the race — see
      // docs/findings/screens/char-create/06-race-elf.png.
      expect(buildCatalogue().abilityAdjustmentsFor(elf), {
        'MOD_DEX': 1,
        'MOD_CON': -1,
      });
    });

    test('a human trades nothing, so the line is empty', () {
      expect(buildCatalogue().abilityAdjustmentsFor(human), isEmpty);
    });

    test('are keyed by the RACE.IDS spelling, which racetext does not use', () {
      expect(buildCatalogue().abilityAdjustmentsFor(halfOrc), {
        'MOD_STR': 1,
        'MOD_CON': 1,
        'MOD_INT': -2,
      });
    });
  });

  group('an installation that could not be read', () {
    test('answers empty rather than throwing', () {
      final nothing = creationCatalogueFrom(
        classRaceRequirements: Table2da.parse(''),
        alignmentRequirements: Table2da.parse(''),
        kits: Table2da.parse(''),
        classText: Table2da.parse(''),
        raceText: Table2da.parse(''),
        racialAdjustments: Table2da.parse(''),
        rules: const GeneratedGameRules(),
      );

      expect(nothing.races, isEmpty);
      expect(nothing.classesFor(elf), isEmpty);
      expect(nothing.kitsFor(fighter), isEmpty);
    });
  });
}
