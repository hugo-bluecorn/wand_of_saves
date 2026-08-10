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

// Builds one level-1 character with every field at a diagnostic extreme, so
// that importing and re-exporting it in BG:EE says which fields the ENGINE
// owns and which the app owns.
//
// Usage, from the repository root:
//   fvm dart run tool/dev/make_probe_character.dart
//
// Writes only under build/staged-characters/. Installing it into the game is a
// separate, deliberate act — the tool prints the one command that does it. The
// same rule set_gold.dart follows.
//
// ⚠️ **Every value here is chosen to be un-derivable.** A field that comes back
// unchanged is one the app owns; a field that comes back different is one the
// engine derives, and what it derives it *to* is the second half of the answer.
// So a value equal to what the engine would compute teaches nothing, and three
// of these are picked to be deliberately WORSE than the computed value — that
// is what separates "the engine never recomputes" from "it recomputes and keeps
// whichever is better", which are otherwise the same reading.
//
// A command-line tool: stdout is the output, written directly rather than
// through dart:core's print(), because avoid_print is enabled repo-wide (D8).

import 'dart:io';
import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/save_editor.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/character_identity.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/edit_command.dart';

const String _staging = 'build/staged-characters';
const String _fileName = 'WANDMAX.chr';

/// The character, chosen to exercise the most derivations in one file.
///
/// An **elf Fighter / Mage / Thief** — three save tables (`savewar`, `savewiz`,
/// `saverog`), thief skills, a spellbook and proficiencies, all on one record.
/// A single-class character would leave most of that untested.
const int _elf = 2;
const int _fighterMageThief = 10;
const int _male = 1;
const int _neutralGood = 0x21;
const int _trueClass = 0x40000000;

/// ⚠️ **Experience stays at zero and the levels stay at one.**
///
/// The engine derives level from experience on import — that is how D10 was
/// closed, by writing 4000 and letting it do the rest. Maxing experience would
/// therefore change the very thing this run holds fixed, and past
/// `startare.2da`'s `START_XP_CAP` of 161,000 the engine writes `CHR V2.1`,
/// which this codec refuses by name.
const int _experience = 0;

/// What each field is set to, and why that value and not another.
///
/// The `why` is printed beside the value so the screenshots can be read against
/// it without going back to the source.
typedef _Probe = (CharacterStat stat, int value, String why);

const List<_Probe> _probes = [
  // ⚠️ Strength is 18, not 25, and the percentile is what is being asked.
  // A percentile is only meaningful at 18, and whether a stored 100 prints as
  // "18/00" is an experiment this project has owed for days.
  (CharacterStat.strength, 18, 'the roll ceiling; 25 needs magic'),
  (CharacterStat.strengthBonus, 100, 'does 100 print as 18/00?'),
  // 25 is the engine's absolute cap and far past an elf's rolled ceiling of 19
  // Dexterity and 17 Constitution — so a clamp on import would show.
  (CharacterStat.dexterity, 25, 'past the elf ceiling of 19'),
  (CharacterStat.constitution, 25, 'past the elf ceiling of 17'),
  (CharacterStat.intelligence, 25, 'past the roll ceiling of 18'),
  (CharacterStat.wisdom, 25, 'past the roll ceiling of 18'),
  (CharacterStat.charisma, 25, 'past the roll ceiling of 18'),

  // A level-1 character rolls about 13 at the very most.
  (CharacterStat.currentHitPoints, 999, 'no level-1 roll reaches this'),
  (
    CharacterStat.maximumHitPoints,
    999,
    'a stored 45 was once recomputed to 12',
  ),
  (CharacterStat.experience, _experience, 'HELD — the engine derives level'),
  (CharacterStat.gold, 999999, 'authored by definition; a control'),

  // ⚠️ WORSE than computed, deliberately. A level-1 character computes to 20,
  // and 25 separates "never recomputes" from "recomputes, keeps the better".
  (CharacterStat.thac0, 25, 'WORSE than the computed 20 — the separator'),

  // Unarmoured is 10. Two different impossible values, so the run also says
  // which of the two fields the engine actually reads.
  (CharacterStat.armorClassNatural, 20, 'worse than the unarmoured 10'),
  (CharacterStat.armorClassEffective, -5, 'better than any unarmoured value'),
  (CharacterStat.armorClassCrushing, -20, 'no level-1 character has one'),
  (CharacterStat.armorClassMissile, -20, 'no level-1 character has one'),
  (CharacterStat.armorClassPiercing, -20, 'no level-1 character has one'),
  (CharacterStat.armorClassSlashing, -20, 'no level-1 character has one'),

  (CharacterStat.numberOfAttacks, 10, 'CHARBASE stores 255, a compute-me flag'),

  // ⚠️ WORSE than computed again, and 20 rather than 25 because the field's
  // own documented range stops there — the app refused 25, which is the check
  // working. A level-1 Fighter / Mage / Thief computes 11-16 across the five,
  // so 20 is still worse than every one of them.
  (CharacterStat.saveVersusDeath, 20, 'WORSE than computed — the separator'),
  (CharacterStat.saveVersusWands, 20, 'WORSE than computed — the separator'),
  (CharacterStat.saveVersusPolymorph, 20, 'WORSE than computed'),
  (CharacterStat.saveVersusBreath, 20, 'WORSE than computed'),
  (CharacterStat.saveVersusSpells, 20, 'WORSE than computed'),

  // A level-1 thief has 40 points to spread over seven skills. 100 in each of
  // eight is 800, so any clamp at all is visible.
  (CharacterStat.hideInShadows, 100, '40 points exist, in total'),
  (CharacterStat.detectIllusion, 100, '40 points exist, in total'),
  (CharacterStat.setTraps, 100, '40 points exist, in total'),
  (CharacterStat.lockpicking, 100, '40 points exist, in total'),
  (CharacterStat.moveSilently, 100, '40 points exist, in total'),
  (CharacterStat.findTraps, 100, '40 points exist, in total'),
  (CharacterStat.pickPockets, 100, '40 points exist, in total'),
  (CharacterStat.lore, 100, 'the engine gave Aurel 3'),

  // The two open questions about who may do what — nothing found governs
  // either, so both stay editable and this asks the engine directly.
  (CharacterStat.turnUndeadLevel, 25, 'may a Fighter/Mage/Thief turn undead?'),
  (CharacterStat.trackingSkill, 100, 'may a non-ranger track?'),

  // An elf has no resistances at all, so every one of these is impossible.
  (CharacterStat.resistFire, 100, 'an elf has none'),
  (CharacterStat.resistCold, 100, 'an elf has none'),
  (CharacterStat.resistElectricity, 100, 'an elf has none'),
  (CharacterStat.resistAcid, 100, 'an elf has none'),
  (CharacterStat.resistMagic, 100, 'an elf has none'),
  (CharacterStat.resistMagicFire, 100, 'an elf has none'),
  (CharacterStat.resistMagicCold, 100, 'an elf has none'),
  (CharacterStat.resistSlashing, 100, 'an elf has none'),
  (CharacterStat.resistCrushing, 100, 'an elf has none'),
  (CharacterStat.resistPiercing, 100, 'an elf has none'),
  (CharacterStat.resistMissile, 100, 'an elf has none'),

  // ⚠️ **These three are deliberately NOT maxed, and the first run is why.**
  //
  // Maxed, they produced a character that imported perfectly and then could not
  // be played at all — he stumbled around at random, took no orders, and both
  // Save Game and EXPORT were greyed out. Two causes, and the run could not
  // separate them:
  //
  //   * **Morale break 20 against morale 20.** Morale break is the morale *at
  //     which the creature panics*, so panic fired immediately and never
  //     cleared. The protagonist stores **0** here for exactly this reason.
  //   * **Intoxication 100.** The character shows as `Intoxicated` and the
  //     engine **gates EXPORT on it** — which is what cost the first run its
  //     third state.
  //
  // Both are legal values in range, which is the point: an editor that offers
  // the whole field bricks somebody's character. Backed off to mild values that
  // are still nothing the engine would produce, so they stay diagnostic.
  (CharacterStat.fatigue, 10, 'mild; 100 may compound the same problem'),
  (CharacterStat.intoxication, 0, '⚠️ non-zero disables EXPORT'),
  (CharacterStat.luck, 10, 'default is 0'),
  (CharacterStat.morale, 20, 'IESDP caps this at 20'),
  // ⚠️ 1, not 20. Above morale, this panics the character permanently.
  (CharacterStat.moraleBreak, 1, 'a protagonist stores 0; 20 is unplayable'),
];

/// Fields with no [CharacterStat] entry, written through the codec directly.
///
/// Not an oversight in the curation: levels and reputation are not things the
/// character sheet offers, and this tool is asking the engine about them rather
/// than about the app.
const List<(CreHeaderField field, int value, String why)> _rawProbes = [
  (CreHeaderField.levelFirstClass, 1, 'HELD at one'),
  (CreHeaderField.levelSecondClass, 1, 'HELD at one'),
  // ⚠️ A three-class character uses all three slots, so this one is genuinely
  // 1 rather than the stale 1 that CHARBASE leaves in an unused slot.
  (CreHeaderField.levelThirdClass, 1, 'HELD at one'),
  (CreHeaderField.reputation, 200, 'stored ×10, so 20.0 — the maximum'),
  (CreHeaderField.racialEnemy, 5, "a ranger's field, on a non-ranger"),
];

/// Five pips in each of four proficiencies — twenty, where four are legal.
const Map<int, int> _proficiencies = {
  89: 5, // Bastard Sword
  90: 5, // Long Sword
  102: 5, // Quarterstaff
  114: 5, // Two-Weapon Style
};

/// How many first-level spells to memorise, against a legal one.
const int _memorisable = 9;

Never _bail(String message) {
  stderr
    ..writeln('make_probe_character: $message')
    ..writeln();
  exit(1);
}

Future<void> main() async {
  const profile = GameProfileService();
  final game = profile.findGameDirectory();
  if (game == null) {
    _bail(
      'no Baldur’s Gate installation found; there is no CHARBASE to build '
      'from.',
    );
  }

  final resources = ResourceRepository(profile);
  final template = await resources.creature(characterTemplate);
  if (template == null) {
    _bail('the installation has no $characterTemplate.');
  }

  var chr = ChrCodec.blank(
    name: 'Maxwell',
    record: Uint8List.fromList(template),
  );

  for (final (identity, value) in const [
    (CharacterIdentity.gender, _male),
    (CharacterIdentity.race, _elf),
    (CharacterIdentity.characterClass, _fighterMageThief),
    (CharacterIdentity.alignment, _neutralGood),
    (CharacterIdentity.kit, _trueClass),
  ]) {
    chr = applyCharacterEdit(
      chr,
      SetCharacterIdentity(
        creOffset: chr.creOffset,
        identity: identity,
        value: value,
      ),
    );
  }

  chr = applyCharacterEdit(
    chr,
    SetPortrait(creOffset: chr.creOffset, baseName: 'BDTMI'),
  );

  for (final (stat, value, _) in _probes) {
    chr = applyCharacterEdit(
      chr,
      SetCharacterStat(creOffset: chr.creOffset, stat: stat, value: value),
    );
  }
  for (final (field, value, _) in _rawProbes) {
    chr = chr.withCreatureField(
      creOffset: chr.creOffset,
      field: field,
      value: value,
    );
  }

  for (final MapEntry(key: id, value: pips) in _proficiencies.entries) {
    chr = applyCharacterEdit(
      chr,
      GrantProficiency(creOffset: chr.creOffset, proficiencyId: id, pips: pips),
    );
  }

  // Every first-level wizard spell the installation has — 22 of them, against
  // the two a new mage may learn.
  final spells = await resources.wizardSpells(level: 1);
  for (final spell in spells) {
    chr = applyCharacterEdit(
      chr,
      LearnSpell(
        creOffset: chr.creOffset,
        resref: spell.resref,
        level: 1,
        type: SpellType.wizard,
      ),
    );
  }
  // Memorise nine of them, against the one a level-1 mage may prepare.
  for (final spell in spells.take(_memorisable)) {
    chr = applyCharacterEdit(
      chr,
      MemoriseSpell(
        creOffset: chr.creOffset,
        resref: spell.resref,
        level: 1,
        type: SpellType.wizard,
        memorisable: _memorisable,
      ),
    );
  }

  // The gate every writer in this project answers to. A record whose sections
  // do not reconcile is one the engine may refuse outright, and a refused
  // import wastes the whole trip.
  final written = CreCodec.decode(chr.creBytes);
  if (written.contentEnd != written.bytes.length) {
    _bail(
      'the record does not reconcile: contentEnd ${written.contentEnd} against '
      '${written.bytes.length} bytes. Refusing to stage it.',
    );
  }

  Directory(_staging).createSync(recursive: true);
  final path = '$_staging${Platform.pathSeparator}$_fileName';
  File(path).writeAsBytesSync(ChrCodec.encode(chr));

  // ⚠️ **Read it back off disk before saying it is ready.** The expensive
  // failure here is not a wrong value, it is a wasted trip into the game: a
  // field that silently did not land would look exactly like a field the engine
  // corrected, and the run would answer the wrong question.
  _verify(path);

  _report(path, written, spells.map((s) => s.resref).toList());
}

/// Re-decodes the staged file and checks every probe value survived.
void _verify(String path) {
  final back = CreCodec.decode(
    ChrCodec.decode(File(path).readAsBytesSync()).creBytes,
  );
  final wrong = <String>[
    for (final (stat, value, _) in _probes)
      if (back.readField(stat.field) != value)
        '${stat.label}: wrote $value, read back ${back.readField(stat.field)}',
    for (final (field, value, _) in _rawProbes)
      if (back.readField(field) != value)
        '$field: wrote $value, read back ${back.readField(field)}',
  ];
  if (wrong.isNotEmpty) {
    _bail('these did not land:\n  ${wrong.join('\n  ')}');
  }
  if (back.proficiencies.toString() != _proficiencies.toString()) {
    _bail('proficiencies read back as ${back.proficiencies}');
  }
}

void _report(String path, Cre written, List<String> spells) {
  stdout
    ..writeln('Wrote $path (${written.bytes.length} bytes of record)')
    ..writeln()
    ..writeln('Elf Fighter / Mage / Thief, level 1 / 1 / 1, 0 experience.')
    ..writeln()
    ..writeln('field                      written  why that value')
    ..writeln('${'-' * 25}  ${'-' * 7}  ${'-' * 44}');

  for (final (stat, value, why) in _probes) {
    stdout.writeln(
      '${stat.label.padRight(25)}  ${value.toString().padLeft(7)}  $why',
    );
  }
  for (final (field, value, why) in _rawProbes) {
    stdout.writeln(
      '${field.toString().replaceFirst('CreHeaderField.', '').padRight(25)}  '
      '${value.toString().padLeft(7)}  $why',
    );
  }

  stdout
    ..writeln()
    ..writeln(
      'proficiencies              ${written.proficiencies}\n'
      '                                    five pips each, where four exist '
      'in total',
    )
    ..writeln(
      'known spells               ${spells.length} '
      '(a new mage learns 2)',
    )
    ..writeln(
      'memorised                  ${written.memorizedSpellsCount} '
      '(a level-1 mage prepares 1)',
    )
    ..writeln()
    ..writeln('To put it where the game’s IMPORT button will find it:')
    ..writeln();

  const profile = GameProfileService();
  final characters = profile.findCharacterRoot();
  stdout
    ..writeln(
      characters == null
          ? '  (no character folder found — export one from the game once)'
          : '  cp $path "$characters/"',
    )
    ..writeln()
    ..writeln(
      '⚠️ Restart the game if it has already imported this file once. BG:EE '
      'caches the character it read, so overwriting the file and backing out '
      'of the Import screen is not enough — the old one comes back.',
    )
    ..writeln()
    ..writeln('Then, in BG:EE:')
    ..writeln(
      '  1. New Game → IMPORT → Maxwell. **Screenshot the Record '
      'screen before anything else** — some fields are corrected on import '
      'and others only on export.',
    )
    ..writeln(
      '  2. Finish creation, start the game, open the Record screen '
      'and screenshot it again.',
    )
    ..writeln(
      '  3. Export the character from the Record screen under a new '
      'name, and say what you called it.',
    )
    ..writeln()
    ..writeln(
      'Three states, and the differences between them are the answer: '
      'what this wrote, what the engine displayed, and what it wrote back.',
    );
}
