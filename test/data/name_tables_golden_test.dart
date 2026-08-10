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

/// D13's gate: the names come from the player's own tables.
///
/// Skipped with no installation, like `chr_export_test.dart` — and that skip is
/// itself part of the point, since the fallback path is what runs there.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';

void main() {
  const profile = GameProfileService();
  final installed = profile.findGameDirectory() != null;
  const why = 'no Baldur’s Gate installation';

  Future<GameRules> realRules() async {
    final container = ProviderContainer.test();
    await container.read(nameTablesProvider.future);
    return container.read(gameRulesProvider);
  }

  group('what the installation calls things', () {
    test(
      'a half-orc is named by the table, not by our exception map',
      () async {
        // ⚠️ The rule this replaced needed `{'HALFORC': 'Half-Orc'}` spelled
        // out, because no amount of splitting `HALFORC` on underscores gets
        // there. `racetext.2da`'s UPPERCASE column simply says so.
        final rules = await realRules();

        expect(rules.raceName(7), 'Half-Orc');
        expect(rules.raceName(3), 'Half-Elf');
        expect(rules.raceName(2), 'Elf');
      },
      skip: installed ? false : why,
    );

    test(
      'a multi-class is named by clastext, separator and all',
      () async {
        // `CLERIC_RANGER` reads `Cleric / Ranger` in the table. What the
        // derivation produced happened to match for this one — which is exactly
        // why it survived so long.
        final rules = await realRules();

        expect(rules.className(18), 'Cleric / Ranger');
      },
      skip: installed ? false : why,
    );

    test(
      'a kit is named by the talk table — FERALAN is Archer',
      () async {
        // ⚠️ The case the derivation could never get right at all.
        final rules = await realRules();

        expect(rules.kitName(0x40070000), 'Archer');
      },
      skip: installed ? false : why,
    );

    test('the tables were actually read', () async {
      final container = ProviderContainer.test();
      final tables = await container.read(nameTablesProvider.future);

      expect(tables.isEmpty, isFalse);
      expect(tables.raceNames, isNotEmpty);
      expect(tables.kitNames, isNotEmpty);
    }, skip: installed ? false : why);
  });

  group('hit dice, where the written-out rule was measurably wrong', () {
    Future<GameRules> withDice() async {
      final container = ProviderContainer.test();
      await container.read(hitDieTablesProvider.future);
      return container.read(gameRulesProvider);
    }

    test('a mage and a thief keep rolling past level 9', () async {
      // ⚠️ **The bug this found.** The old rule stopped every class at 9, so a
      // Mage 12 came out 3 short and a Thief 12 four short. `hpwiz.2da` and
      // `hprog.2da` roll through 11.
      final rules = await withDice();

      expect(rules.maximumRolledHitPoints('MAGE', 12), 42);
      expect(rules.maximumRolledHitPoints('THIEF', 12), 64);
    }, skip: installed ? false : why);

    test(
      'a warrior and a priest are unchanged, which is why it hid',
      () async {
        final rules = await withDice();

        expect(rules.maximumRolledHitPoints('FIGHTER', 12), 99);
        expect(rules.maximumRolledHitPoints('CLERIC', 12), 78);
      },
      skip: installed ? false : why,
    );

    test('a kit does not follow its class', () async {
      // `DWARVEN_DEFENDER` uses HPBARB — a d12 — where its Fighter base uses
      // HPWAR. Any rule that walked from a kit to its class would say d10.
      final rules = await withDice();

      expect(rules.maximumRolledHitPoints('DWARVEN_DEFENDER', 1), 12);
      expect(rules.maximumRolledHitPoints('FIGHTER', 1), 10);
    }, skip: installed ? false : why);
  });

  group('with no installation at all', () {
    test('the rules still name what is in a savegame', () {
      // The app opens saves on machines with no game on them. The derivation
      // stays for exactly this, and nothing else reaches it.
      const rules = GeneratedGameRules();

      expect(rules.tables.isEmpty, isTrue);
      expect(rules.raceName(7), 'Half-Orc');
      expect(rules.className(7), 'Fighter / Mage');
      expect(rules.raceName(999), isNull);
    });
  });
}
