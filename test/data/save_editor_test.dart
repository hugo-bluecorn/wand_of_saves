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
import 'package:wand_of_saves/data/save_editor.dart';
import 'package:wand_of_saves/domain/character_identity.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/edit_command.dart';

import '../support/synthetic_save.dart';

void main() {
  Gam openSave() => GamCodec.decode(buildSave());
  int creOffsetOf(Gam gam) => gam.partyMembers.single.creOffset;

  Cre creatureIn(Gam gam) => CreCodec.decode(gam.partyMembers.single.creBytes);

  group('SetCharacterStat', () {
    test('writes the stat into the creature record', () {
      final gam = openSave();

      final edited = applyEdit(
        gam,
        SetCharacterStat(
          creOffset: creOffsetOf(gam),
          stat: CharacterStat.strength,
          value: 19,
        ),
      );

      expect(creatureIn(edited).strength, 19);
    });

    test('writes a negative armour class', () {
      final gam = openSave();

      final edited = applyEdit(
        gam,
        SetCharacterStat(
          creOffset: creOffsetOf(gam),
          stat: CharacterStat.armorClassNatural,
          value: -2,
        ),
      );

      expect(creatureIn(edited).armorClassNatural, -2);
    });

    test('refuses a value outside the stat range, not just the field', () {
      // 200 fits the byte. The stat is what says it is not a Strength.
      final gam = openSave();

      expect(
        () => applyEdit(
          gam,
          SetCharacterStat(
            creOffset: creOffsetOf(gam),
            stat: CharacterStat.strength,
            value: 200,
          ),
        ),
        throwsA(isA<InvalidEditException>()),
      );
    });

    test('leaves the save it was given alone', () {
      final gam = openSave();

      applyEdit(
        gam,
        SetCharacterStat(
          creOffset: creOffsetOf(gam),
          stat: CharacterStat.strength,
          value: 19,
        ),
      );

      expect(creatureIn(gam).strength, 18, reason: 'the original was mutated');
    });
  });

  group('SetProficiency', () {
    /// A save whose sole character has Aard's two proficiencies.
    Gam openProficientSave() => GamCodec.decode(
      buildSave(
        party: const [
          SyntheticCharacter(proficiencies: {114: 2, 100: 2}),
        ],
      ),
    );

    int offsetOf(Gam gam, int id) => CreCodec.decode(
      gam.partyMembers.single.creBytes,
    ).effects.firstWhere((e) => e.isProficiency && e.parameter2 == id).start;

    test('raises a pip inside the effect that already grants it', () {
      final gam = openProficientSave();

      final edited = applyEdit(
        gam,
        SetProficiency(
          creOffset: creOffsetOf(gam),
          effectOffset: offsetOf(gam, 114),
          proficiencyId: 114,
          pips: 3,
        ),
      );

      expect(creatureIn(edited).proficiencies, {114: 3, 100: 2});
    });

    test('touches exactly one byte and does not resize the save', () {
      // The whole reason a pip is editable this early. Parameter 1 is a dword
      // already sitting in the record, so 2 -> 3 moves its low byte and
      // nothing else — no layout pass, no offset cascade, no chance for the
      // GAM's nine offset fields to disagree with the file.
      final gam = openProficientSave();

      final edited = applyEdit(
        gam,
        SetProficiency(
          creOffset: creOffsetOf(gam),
          effectOffset: offsetOf(gam, 114),
          proficiencyId: 114,
          pips: 3,
        ),
      );

      expect(edited.bytes, hasLength(gam.bytes.length));
      expect(
        [
          for (var i = 0; i < gam.bytes.length; i++)
            if (gam.bytes[i] != edited.bytes[i]) i,
        ],
        hasLength(1),
      );
    });

    test('leaves the other proficiencies alone', () {
      // Two effects, one stride apart. Patching the wrong one is the failure
      // this catches, and it would look like a working edit on a character
      // with only one proficiency.
      final gam = openProficientSave();

      final edited = applyEdit(
        gam,
        SetProficiency(
          creOffset: creOffsetOf(gam),
          effectOffset: offsetOf(gam, 100),
          proficiencyId: 100,
          pips: 5,
        ),
      );

      expect(creatureIn(edited).proficiencies, {114: 2, 100: 5});
    });

    test('leaves the save it was given alone', () {
      final gam = openProficientSave();

      applyEdit(
        gam,
        SetProficiency(
          creOffset: creOffsetOf(gam),
          effectOffset: offsetOf(gam, 114),
          proficiencyId: 114,
          pips: 3,
        ),
      );

      expect(creatureIn(gam).proficiencies, {114: 2, 100: 2});
    });

    test('refuses a pip count the field cannot hold', () {
      // No game-rules cap lives here: IESDP states no range for opcode 233's
      // Amount, and the per-class ceiling is in the player's own weapprof.2da,
      // which is the panel's to consult. What this rejects is a number the
      // dword itself cannot store.
      final gam = openProficientSave();

      expect(
        () => applyEdit(
          gam,
          SetProficiency(
            creOffset: creOffsetOf(gam),
            effectOffset: offsetOf(gam, 114),
            proficiencyId: 114,
            pips: -1,
          ),
        ),
        throwsA(isA<InvalidEditException>()),
      );
    });
  });

  group('SetPartyGold', () {
    test('writes the shared purse', () {
      final edited = applyEdit(openSave(), const SetPartyGold(12345));

      expect(edited.partyGold, 12345);
    });

    test('refuses a negative purse', () {
      expect(
        () => applyEdit(openSave(), const SetPartyGold(-1)),
        throwsA(isA<InvalidEditException>()),
      );
    });
  });

  group('command labels', () {
    test('say what the edit did, for the undo entry', () {
      const command = SetCharacterStat(
        creOffset: 532,
        stat: CharacterStat.strength,
        value: 19,
      );

      expect(command.label, contains('Strength'));
      expect(command.label, contains('19'));
      expect(const SetPartyGold(500).label, contains('500'));
      // The proficiency has only a number to go on: naming it needs the
      // player's weapprof.2da, which no domain command may reach for.
      const proficiency = SetProficiency(
        creOffset: 532,
        effectOffset: 1340,
        proficiencyId: 114,
        pips: 3,
      );
      expect(proficiency.label, contains('3'));
      expect(proficiency.label, contains('114'));
    });
  });

  group('the same command against an exported character', () {
    // One character sheet drives both documents, so an edit that works on a
    // savegame must do exactly the same thing to a .chr. A field that behaved
    // differently in one would reach the user as "this only works when I open
    // the save".
    Chr openCharacter() => ChrCodec.decode(buildCharacterFile(name: 'Aurel'));

    test('writes the stat into the record', () {
      final chr = openCharacter();

      final edited = applyCharacterEdit(
        chr,
        SetCharacterStat(
          creOffset: chr.creOffset,
          stat: CharacterStat.strength,
          value: 19,
        ),
      );

      expect(CreCodec.decode(edited.creBytes).strength, 19);
    });

    test('returns the concrete document, not the interface', () {
      // What the type parameter on CreatureDocument buys: an editor's undo
      // stack is a List<Chr>, not a list of things that might be savegames.
      final chr = openCharacter();

      final Chr edited = applyCharacterEdit(
        chr,
        SetCharacterStat(
          creOffset: chr.creOffset,
          stat: CharacterStat.strength,
          value: 19,
        ),
      );

      expect(edited, isA<Chr>());
    });

    test('raises a pip in an effect', () {
      final chr = ChrCodec.decode(
        buildCharacterFile(
          character: const SyntheticCharacter(proficiencies: {114: 2}),
        ),
      );
      final effect = CreCodec.decode(chr.creBytes).effects.single;

      final edited = applyCharacterEdit(
        chr,
        SetProficiency(
          creOffset: chr.creOffset,
          effectOffset: effect.start,
          proficiencyId: 114,
          pips: 3,
        ),
      );

      expect(CreCodec.decode(edited.creBytes).proficiencies, {114: 3});
    });

    test('refuses a value the stat does not accept', () {
      final chr = openCharacter();

      expect(
        () => applyCharacterEdit(
          chr,
          SetCharacterStat(
            creOffset: chr.creOffset,
            stat: CharacterStat.strength,
            value: 300,
          ),
        ),
        throwsA(isA<InvalidEditException>()),
      );
    });

    test('a savegame takes the same command through the same path', () {
      // The shared route is not a second implementation: applyEdit hands every
      // character edit to applyCharacterEdit.
      final gam = openSave();
      final command = SetCharacterStat(
        creOffset: creOffsetOf(gam),
        stat: CharacterStat.strength,
        value: 19,
      );

      expect(
        applyEdit(gam, command).bytes,
        applyCharacterEdit(gam, command).bytes,
      );
    });
  });

  group('party gold is a savegame edit and only a savegame edit', () {
    test('is not a character edit, so a .chr cannot be given one', () {
      // ⚠️ Enforced by the type system rather than by a runtime throw. A .chr
      // has no party, and a document that had to refuse this at run time is
      // exactly the bug a sealed hierarchy prevents at compile time.
      expect(const SetPartyGold(1), isNot(isA<CharacterEditCommand>()));
      expect(
        const SetCharacterStat(
          creOffset: 0,
          stat: CharacterStat.strength,
          value: 18,
        ),
        isA<CharacterEditCommand>(),
      );
    });
  });

  group('SetPortrait', () {
    // The first edit that writes text rather than a number, and it is
    // fixed-width like every other one here: two 8-byte resrefs that exactly
    // fill the gap the spec leaves between effectVersion and reputation.
    test('writes both variants from one base name', () {
      final gam = openSave();

      final edited = applyEdit(
        gam,
        SetPortrait(creOffset: creOffsetOf(gam), baseName: 'AJANTIS'),
      );

      final cre = creatureIn(edited);
      expect(cre.portraitMedium, 'AJANTISM');
      expect(cre.portraitLarge, 'AJANTISL');
    });

    test('moves only those sixteen bytes', () {
      final gam = openSave();

      final edited = applyEdit(
        gam,
        SetPortrait(creOffset: creOffsetOf(gam), baseName: 'AJANTIS'),
      );

      final moved = [
        for (var i = 0; i < gam.bytes.length; i++)
          if (gam.bytes[i] != edited.bytes[i]) i,
      ];
      expect(moved, hasLength(16));
      expect(
        moved.first,
        creOffsetOf(gam) + CreHeaderField.portraitMedium.offset,
      );
    });

    test('an empty name clears both fields', () {
      final gam = applyEdit(
        openSave(),
        SetPortrait(creOffset: creOffsetOf(openSave()), baseName: 'AJANTIS'),
      );

      final cleared = applyEdit(
        gam,
        SetPortrait(creOffset: creOffsetOf(gam), baseName: ''),
      );

      expect(creatureIn(cleared).portraitMedium, isEmpty);
      expect(creatureIn(cleared).portraitLarge, isEmpty);
    });

    test('refuses a base name too long to carry a variant letter', () {
      // ⚠️ Seven, not eight: the suffix has to fit an 8-byte resref. Checked
      // against the base name so the message names the limit the player typed
      // against, rather than the field's.
      final gam = openSave();

      expect(
        () => applyEdit(
          gam,
          SetPortrait(creOffset: creOffsetOf(gam), baseName: 'TOOLONGX'),
        ),
        throwsA(
          isA<InvalidEditException>().having((e) => e.maximum, 'maximum', 7),
        ),
      );
    });

    test('works the same on an exported character', () {
      final chr = ChrCodec.decode(buildCharacterFile());

      final edited = applyCharacterEdit(
        chr,
        SetPortrait(creOffset: chr.creOffset, baseName: 'AJANTIS'),
      );

      expect(CreCodec.decode(edited.creBytes).portraitMedium, 'AJANTISM');
    });

    test('says what it did, by name', () {
      expect(
        const SetPortrait(creOffset: 0, baseName: 'AJANTIS').label,
        contains('AJANTIS'),
      );
      expect(
        const SetPortrait(creOffset: 0, baseName: '').label,
        contains('Clear'),
      );
    });
  });

  group('SetCharacterIdentity', () {
    // Who the character *is* — gender, race, class, alignment, specialisation.
    // Every one is a fixed-width field the spec already carries, so these are
    // as safe as a stat edit; what makes them their own command is that the
    // legal values are an enumeration rather than a range.
    test('writes the race into the creature record', () {
      final gam = openSave();

      final edited = applyEdit(
        gam,
        SetCharacterIdentity(
          creOffset: creOffsetOf(gam),
          identity: CharacterIdentity.race,
          value: 4,
        ),
      );

      expect(creatureIn(edited).raceId, 4);
    });

    test('writes class, gender and alignment', () {
      var gam = openSave();
      for (final (identity, value) in [
        (CharacterIdentity.characterClass, 6),
        (CharacterIdentity.gender, 2),
        (CharacterIdentity.alignment, 0x11),
      ]) {
        gam = applyEdit(
          gam,
          SetCharacterIdentity(
            creOffset: creOffsetOf(gam),
            identity: identity,
            value: value,
          ),
        );
      }

      final cre = creatureIn(gam);
      expect(cre.classId, 6);
      expect(cre.genderId, 2);
      expect(cre.alignmentId, 0x11);
    });

    test('moves exactly one byte for a one-byte field', () {
      final gam = openSave();

      final edited = applyEdit(
        gam,
        SetCharacterIdentity(
          creOffset: creOffsetOf(gam),
          identity: CharacterIdentity.race,
          value: 4,
        ),
      );

      final moved = [
        for (var i = 0; i < gam.bytes.length; i++)
          if (gam.bytes[i] != edited.bytes[i]) i,
      ];
      expect(edited.bytes, hasLength(gam.bytes.length));
      expect(moved, [creOffsetOf(gam) + CreHeaderField.race.offset]);
    });

    test('writes the kit as a dword, raw', () {
      // ⚠️ The stored value carries the KIT.IDS key in its **high word** — the
      // fixture's 0x40000000 is TRUECLASS. The command writes what it is given
      // and shifts nothing: which dword a specialisation means is the rules
      // tables' question, answered before a command is ever built.
      final gam = openSave();

      final edited = applyEdit(
        gam,
        SetCharacterIdentity(
          creOffset: creOffsetOf(gam),
          identity: CharacterIdentity.kit,
          value: 0x40070000,
        ),
      );

      expect(creatureIn(edited).kitId, 0x40070000);

      // Not a byte count: 0x40000000 and 0x40070000 differ in one byte, and
      // asserting "one" would pin an accident of these two values. What the
      // writer must guarantee is that nothing outside the field moved.
      final field = creOffsetOf(gam) + CreHeaderField.kit.offset;
      final moved = [
        for (var i = 0; i < gam.bytes.length; i++)
          if (gam.bytes[i] != edited.bytes[i]) i,
      ];
      expect(edited.bytes, hasLength(gam.bytes.length));
      expect(moved, isNotEmpty);
      expect(
        moved.every((i) => i >= field && i < field + CreHeaderField.kit.length),
        isTrue,
        reason: 'every changed byte must lie inside the 4-byte kit field',
      );
    });

    test('refuses a value the field cannot hold', () {
      final gam = openSave();

      expect(
        () => applyEdit(
          gam,
          SetCharacterIdentity(
            creOffset: creOffsetOf(gam),
            identity: CharacterIdentity.race,
            value: 300,
          ),
        ),
        throwsA(isA<InvalidEditException>()),
      );
    });

    test('leaves the save it was given alone', () {
      final gam = openSave();

      applyEdit(
        gam,
        SetCharacterIdentity(
          creOffset: creOffsetOf(gam),
          identity: CharacterIdentity.race,
          value: 4,
        ),
      );

      expect(creatureIn(gam).raceId, 2);
    });

    test('works the same on an exported character', () {
      final chr = ChrCodec.decode(buildCharacterFile());

      final edited = applyCharacterEdit(
        chr,
        SetCharacterIdentity(
          creOffset: chr.creOffset,
          identity: CharacterIdentity.race,
          value: 4,
        ),
      );

      expect(CreCodec.decode(edited.creBytes).raceId, 4);
    });

    test('says what it did, naming the field', () {
      expect(
        const SetCharacterIdentity(
          creOffset: 0,
          identity: CharacterIdentity.race,
          value: 4,
        ).label,
        contains('Race'),
      );
    });
  });

  group('edits that make the record bigger', () {
    // ⚠️ **The first commands that resize.** They exist because a created
    // character is otherwise an empty shell: `CHARBASE` carries zero effects
    // and zero known spells, so `SetProficiency` — which only raises a pip that
    // is already there — has nothing to raise.
    Chr blank() => ChrCodec.decode(buildCharacterFile());

    test('grants a proficiency to a character that had none', () {
      final chr = blank();
      final before = CreCodec.decode(chr.creBytes);

      final after = applyCharacterEdit(
        chr,
        GrantProficiency(
          creOffset: chr.creOffset,
          proficiencyId: 114,
          pips: 2,
        ),
      );

      final cre = CreCodec.decode(after.creBytes);
      expect(cre.effectsCount, before.effectsCount + 1);
      expect(cre.proficiencies[114], 2);
      expect(cre.contentEnd, cre.bytes.length);
    });

    test('the CHR header’s length follows the record it describes', () {
      // The whole of what resizing costs an exported character: one dword.
      final chr = blank();

      final after = applyCharacterEdit(
        chr,
        GrantProficiency(creOffset: chr.creOffset, proficiencyId: 89, pips: 1),
      );

      expect(after.creLength, chr.creLength + creEffectV2Length);
      expect(after.bytes, hasLength(chr.bytes.length + creEffectV2Length));
      expect(CreCodec.decode(after.creBytes).proficiencies[89], 1);
    });

    test('a second proficiency joins the first rather than replacing it', () {
      var chr = blank();
      for (final (id, pips) in [(89, 1), (114, 2)]) {
        chr = applyCharacterEdit(
          chr,
          GrantProficiency(
            creOffset: chr.creOffset,
            proficiencyId: id,
            pips: pips,
          ),
        );
      }

      expect(CreCodec.decode(chr.creBytes).proficiencies, {89: 1, 114: 2});
    });

    test('⚠️ grants one to the template, whose effects are still v1', () {
      // **The shape a created character actually arrives in.** `CHARBASE`
      // stores `effectVersion` 0 — 48-byte v1 effects — and **zero** effects,
      // while the character BG:EE itself builds from it stores 1 and 264-byte
      // v2 records. A proficiency effect is v2, so granting one to the template
      // as it comes asks a 48-byte section to accept 264 bytes.
      //
      // ⚠️ **Nothing else here could see it**: the synthetic builder wrote
      // `effectVersion` 1 unconditionally, which is true of every character in
      // a save and of nothing a new one is built from. Against the real
      // template this threw `a effects entry is 48 bytes: 264`.
      final chr = ChrCodec.decode(
        buildCharacterFile(character: SyntheticCharacter.template),
      );
      expect(CreCodec.decode(chr.creBytes).effectVersion, 0);

      final after = applyCharacterEdit(
        chr,
        GrantProficiency(creOffset: chr.creOffset, proficiencyId: 114, pips: 2),
      );

      final cre = CreCodec.decode(after.creBytes);
      expect(cre.effectVersion, 1, reason: 'what the engine itself writes');
      expect(cre.proficiencies[114], 2);
      expect(cre.contentEnd, cre.bytes.length);
    });

    test('learns a spell into a book that did not exist', () {
      final chr = blank();

      final after = applyCharacterEdit(
        chr,
        LearnSpell(
          creOffset: chr.creOffset,
          resref: 'SPWI112',
          level: 1,
          type: SpellType.wizard,
        ),
      );

      final cre = CreCodec.decode(after.creBytes);
      expect(cre.knownSpellsCount, 1);
      expect(cre.contentEnd, cre.bytes.length);
    });

    test('memorises a spell into a book that had no sections at all', () {
      final chr = blank();

      final after = applyCharacterEdit(
        chr,
        MemoriseSpell(
          creOffset: chr.creOffset,
          resref: 'SPWI112',
          level: 1,
          type: SpellType.wizard,
          memorisable: 1,
        ),
      );

      final cre = CreCodec.decode(after.creBytes);
      // The engine's own Aurel, row for row: one wizard row at first level
      // saying one memorisable and one memorised, and `SPWI112` ready to cast.
      expect(cre.memorizations.single, (
        level: 1,
        memorisable: 1,
        afterEffects: 1,
        type: SpellType.wizard.stored,
        firstIndex: 0,
        count: 1,
      ));
      expect(cre.memorizedSpells.single.resref, 'SPWI112');
      expect(cre.memorizedSpells.single.isMemorized, isTrue);
      expect(cre.contentEnd, cre.bytes.length);
    });

    test('a second spell of the same level widens the window it is in', () {
      var chr = blank();
      for (final resref in ['SPWI112', 'SPWI114']) {
        chr = applyCharacterEdit(
          chr,
          MemoriseSpell(
            creOffset: chr.creOffset,
            resref: resref,
            level: 1,
            type: SpellType.wizard,
            memorisable: 2,
          ),
        );
      }

      final cre = CreCodec.decode(chr.creBytes);
      expect(cre.memorizations, hasLength(1));
      expect(cre.memorizations.single.count, 2);
      expect(cre.memorizedSpells.map((s) => s.resref), [
        'SPWI112',
        'SPWI114',
      ]);
    });

    test('⚠️ filling an earlier window moves the later ones along', () {
      // **The one place a resize is not mechanical.** A memorisation row names
      // a window of the memorised array by index, so a spell inserted into an
      // earlier window shifts a pointer in a section the insert never touched.
      // Appending instead would file the new spell under the *last* window.
      var chr = blank();
      for (final (level, resref) in [
        (1, 'SPWI112'),
        (2, 'SPWI212'),
        (1, 'SPWI114'),
      ]) {
        chr = applyCharacterEdit(
          chr,
          MemoriseSpell(
            creOffset: chr.creOffset,
            resref: resref,
            level: level,
            type: SpellType.wizard,
            memorisable: 2,
          ),
        );
      }

      final cre = CreCodec.decode(chr.creBytes);
      final first = cre.memorizations.singleWhere((r) => r.level == 1);
      final second = cre.memorizations.singleWhere((r) => r.level == 2);

      expect((first.firstIndex, first.count), (0, 2));
      expect((second.firstIndex, second.count), (2, 1));
      expect(cre.memorizedSpells.map((s) => s.resref), [
        'SPWI112',
        'SPWI114',
        'SPWI212',
      ]);
      // The invariant the engine's own records satisfy: each window begins
      // where the ones before it end.
      var running = 0;
      for (final row in cre.memorizations) {
        expect(row.firstIndex, running);
        running += row.count;
      }
      expect(running, cre.memorizedSpellsCount);
      expect(cre.contentEnd, cre.bytes.length);
    });

    test('a priest spell opens a window of its own, not a wizard’s', () {
      var chr = blank();
      for (final type in [SpellType.wizard, SpellType.priest]) {
        chr = applyCharacterEdit(
          chr,
          MemoriseSpell(
            creOffset: chr.creOffset,
            resref: type == SpellType.wizard ? 'SPWI112' : 'SPPR103',
            level: 1,
            type: type,
            memorisable: 1,
          ),
        );
      }

      final cre = CreCodec.decode(chr.creBytes);
      expect(cre.memorizations, hasLength(2));
      expect(
        cre.memorizations.map((r) => (r.type, r.firstIndex, r.count)),
        [(SpellType.wizard.stored, 0, 1), (SpellType.priest.stored, 1, 1)],
      );
    });

    test('⚠️ a savegame now MEMORISES, and grows to fit', () {
      // **This test used to assert the opposite**, and the inversion is the
      // point of the GAM relocation rather than an accident of refactoring:
      // `Gam.withCreature` threw, so every resizing command shared one refusal.
      // It now relocates — 43 pointers on the real fixture — so the assertion
      // that guarded the limitation becomes the assertion that proves it gone.
      final gam = openSave();
      final before = gam.bytes.length;

      final after = applyEdit(
        gam,
        MemoriseSpell(
          creOffset: creOffsetOf(gam),
          resref: 'SPWI112',
          level: 1,
          type: SpellType.wizard,
          memorisable: 1,
        ),
      );

      expect(
        after.bytes.length,
        greaterThan(before),
        reason: 'memorising adds a row and a spell, so the file grows',
      );
      // What the refusal was really protecting: a save that still parses.
      expect(after.partyMembers, hasLength(gam.partyMembers.length));
    });

    test('says what it did, naming the spell', () {
      expect(
        const MemoriseSpell(
          creOffset: 0,
          resref: 'SPWI112',
          level: 1,
          type: SpellType.wizard,
          memorisable: 1,
        ).label,
        contains('SPWI112'),
      );
    });

    test(
      '⚠️ a savegame takes a resizing edit and relocates around it',
      () {
        // The other half of the same inversion. Adding one 264-byte effect
        // inside a save moves 43 pointers — measured, and three of them were
        // invisible to the codec until the header table named them. The
        // refusal this test used to assert was honest while that was true.
        final gam = openSave();

        expect(
          () => applyEdit(
            gam,
            SetCharacterIdentity(
              creOffset: creOffsetOf(gam),
              identity: CharacterIdentity.race,
              value: 2,
            ),
          ),
          returnsNormally,
          reason: 'a fixed-width edit is still fine',
        );

        final grown = applyEdit(
          gam,
          GrantProficiency(
            creOffset: creOffsetOf(gam),
            proficiencyId: 89,
            pips: 1,
          ),
        );

        expect(
          grown.bytes.length,
          gam.bytes.length + creEffectV2Length,
          reason: 'the file grows by exactly one effect record',
        );
        // Every character is still where the header says, which is the thing
        // a silently-wrong relocation would break.
        expect(grown.partyMembers, hasLength(gam.partyMembers.length));
        expect(grown.nonPartyMembers, hasLength(gam.nonPartyMembers.length));
      },
    );
  });

  group('SetClassLevels', () {
    test('writes one level per class and clears the slots past them', () {
      // ⚠️ The clearing is the part that matters. `CHARBASE` carries its own
      // level slots, so a single-class character built from it would keep a
      // second and a third and read as a multi-class to anything counting
      // filled slots.
      final gam = openSave();

      final edited = applyEdit(
        gam,
        SetClassLevels(creOffset: creOffsetOf(gam), levels: const [2, 1]),
      );

      expect(creatureIn(edited).levels, (2, 1, 0));
    });

    test('a single class clears both of the others', () {
      final gam = openSave();

      final edited = applyEdit(
        gam,
        SetClassLevels(creOffset: creOffsetOf(gam), levels: const [1]),
      );

      expect(creatureIn(edited).levels, (1, 0, 0));
    });

    test('refuses more levels than the record has slots', () {
      final gam = openSave();

      expect(
        () => applyEdit(
          gam,
          SetClassLevels(
            creOffset: creOffsetOf(gam),
            levels: const [1, 1, 1, 1],
          ),
        ),
        throwsA(isA<InvalidEditException>()),
      );
    });

    test('refuses a level the field cannot hold', () {
      final gam = openSave();

      expect(
        () => applyEdit(
          gam,
          SetClassLevels(creOffset: creOffsetOf(gam), levels: const [999]),
        ),
        throwsA(isA<InvalidEditException>()),
      );
    });
  });
}
