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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';
import 'package:wand_of_saves/domain/rules/hit_die_tables.dart';
import 'package:wand_of_saves/domain/rules/rules_tables.dart';
import 'package:wand_of_saves/domain/rules/saving_throw_tables.dart';
import 'package:wand_of_saves/domain/rules/table_columns.dart';
import 'package:wand_of_saves/domain/skill_catalogue.dart';

/// Source of truth for the rules tables that live inside the game's archives.
///
/// **Why this exists when there is already a generated rules layer.** D9 reads
/// the game's `2DA` and `IDS` files from IESDP and commits the result, which
/// is right for tables of pure numbers and confirmed in game. It is not right
/// in general: IESDP ships the **BG2:EE** `weapprof.2da`, and its `NAME_REF`
/// column is a strref into a talk table that is per game. Generating
/// proficiency names from it ships tutorial prose as the name of Two-Weapon
/// Style. That is D11, and this is the reader it calls for.
///
/// Outputs **domain models**, per the repository charter — nothing above this
/// layer sees `Table2da`, `KeyIndex` or a BIFF.
///
/// **Concrete, unlike `StringRepository`, and with no "absent" sibling.** That
/// pairing exists there because `TlkStringRepository` holds an open file and
/// something has to stand in when there is none. Here the absent case is not a
/// different implementation, it is the same one finding no installation and
/// answering [ProficiencyCatalogue.empty] — a second class would have been the
/// same behaviour written twice. A test substitutes this the way Dart always
/// allows: `implements ResourceRepository`.
class ResourceRepository {
  /// Reads the installation [_profile] locates.
  ///
  /// Positional, unlike the other repositories: the field is private, and a
  /// named parameter cannot be an initialising formal for one.
  ResourceRepository(this._profile);

  /// Where the game is on this machine.
  ///
  /// Private so that `implements ResourceRepository` needs only the method —
  /// a test double has no installation to point at, and being made to invent
  /// one would be the interface leaking into its own substitutes.
  final GameProfileService _profile;

  /// The parsed `chitin.key`, read once.
  ///
  /// ⚠️ **This used to be re-read and re-parsed on every lookup** — 37,342
  /// entries, plus the whole containing archive, per call. Two calls at load
  /// made that invisible; a grid of portraits made it a stall.
  ///
  /// ⚠️⚠️ **The cache holds the *Future*, not the result, and that is the whole
  /// point.** Caching the result meant setting a "read it already" flag before
  /// the `await`, so every caller that arrived while the first was still
  /// reading got `null` — and the home screen asks for several portraits at
  /// once. It showed one picture and two blanks, and it looked like a decoding
  /// problem rather than a caching one. Memoising the Future makes late callers
  /// wait for the first read instead of racing past it.
  Future<KeyIndex?>? _index;

  /// Archives opened so far, by path relative to the installation.
  ///
  /// `PORTRAIT.BIF` is 24 MB and every portrait comes out of it, so the same
  /// memoisation matters twice over here: without it, a grid of portraits reads
  /// and parses that file once per picture.
  final Map<String, Future<BifArchive?>> _archives = {};

  /// Every proficiency the player's `weapprof.2da` names.
  ///
  /// Names are left as strrefs: resolving them needs the talk table, which is
  /// a different repository, and repositories must never be aware of each
  /// other. The merge happens in the ViewModel, exactly as it does for the
  /// names companions do not carry in the savegame.
  ///
  /// ⚠️ **Not cached here.** `rulesCataloguesProvider` memoises the merged
  /// result, and a second cache for one value is how two copies of it start
  /// disagreeing. The parsed key file and archive underneath *are* cached,
  /// which is the part that costs.
  Future<ProficiencyCatalogue> proficiencies() async =>
      proficienciesFrom(await _table(weaponProficiencyTable));

  /// Which thief skills each class and kit may allocate points to.
  ///
  /// No talk-table merge, unlike [proficiencies]: `thiefscl.2da` carries no
  /// strrefs, only numbers, so what comes back is already complete.
  ///
  /// Not cached here either — see [proficiencies].
  Future<SkillCatalogue> thiefSkills() async =>
      thiefSkillsFrom(await _table(thiefSkillTable));

  /// How many hit points each class gains per level.
  ///
  /// ⚠️ **D13.** This replaced a written-out `(die, afterNine)` map that had
  /// every class stop rolling at level 9 — `hpwiz.2da` and `hprog.2da` roll
  /// through 11. Two table reads: `hpclass.2da` names the table for each class
  /// *and kit*, then each named table is read for its rows.
  ///
  /// No strrefs anywhere, so this comes back finished rather than needing a
  /// talk-table merge — the same as [thiefSkills].
  Future<HitDieTables> hitDieTables() async {
    final classes = await _table(hitDieClassTable);

    final tableByClass = <String, String>{
      for (final row in classes.rows.keys)
        if (classes.cell(row, TableColumn.hitDieTable.header)
            case final String table)
          if (table != tableAbsent) row: table,
    };

    final rowsByTable = <String, List<HitDieRow>>{};
    for (final name in tableByClass.values.toSet()) {
      final table = await _table(name.toLowerCase());
      final rows = <HitDieRow>[];
      // Levels are the row labels and they run 1..40 in order; reading them in
      // file order is what makes the list index the level.
      for (final row in table.rows.keys) {
        final sides = table.number(row, 'SIDES');
        final rolls = table.number(row, 'ROLLS');
        final modifier = table.number(row, 'MODIFIER');
        if (sides == null || rolls == null || modifier == null) continue;
        rows.add((sides: sides, rolls: rolls, modifier: modifier));
      }
      if (rows.isNotEmpty) rowsByTable[name] = rows;
    }

    return HitDieTables(tableByClass: tableByClass, rowsByTable: rowsByTable);
  }

  /// The five saving-throw progressions.
  ///
  /// ⚠️ **D13, and unlike the hit dice there is no index table to follow.**
  /// `hpclass.2da` names the table for each class; nothing does that for
  /// saving throws, so the five files are read by name and the class-to-table
  /// mapping is a written rule in `GeneratedGameRules.savingThrowTables`.
  ///
  /// No strrefs anywhere, so this comes back finished — the same as
  /// [thiefSkills]. Not cached here; see [proficiencies].
  Future<SavingThrowTables> savingThrowTables() async {
    final tables = await Future.wait(savingThrowTableNames.map(_table));
    return savingThrowTablesFrom({
      for (var i = 0; i < savingThrowTableNames.length; i++)
        savingThrowTableNames[i]: tables[i],
    });
  }

  /// The game's other numeric rules tables, by resref.
  ///
  /// One reader for all of them because they are one shape — a row, a column
  /// and a number. Which row and which column answers which question is a rule
  /// and lives in `GameRules`; this only hands over what the files hold.
  ///
  /// No strrefs anywhere, so this comes back finished. Not cached here; see
  /// [proficiencies].
  Future<RulesTables> rulesTables() async {
    final tables = await Future.wait(numericRulesTables.map(_table));
    return rulesTablesFrom({
      for (var i = 0; i < numericRulesTables.length; i++)
        numericRulesTables[i]: tables[i],
    });
  }

  /// What the installation calls races, classes and kits — as **strrefs**.
  ///
  /// ⚠️ **D13.** These names used to be derived from the IDS identifiers inside
  /// `GameRules`. The game ships them: `racetext.2da`'s `UPPERCASE`,
  /// `clastext.2da`'s `MIXED` for the plain-class rows, and `kitlist.2da`'s
  /// `MIXED`. Resolving the strrefs needs the talk table, so that happens in
  /// `loadNameTables`, not here.
  ///
  /// Read separately from [creationCatalogue] even though two of the three
  /// tables overlap: naming what is in a savegame must not depend on anything
  /// about *creating* one. The key index and archives underneath are cached, so
  /// the second read costs three small table parses.
  Future<
    ({
      Map<int, int> races,
      Map<int, int> classes,
      Map<String, int> kits,
    })
  >
  nameStrrefs() async {
    final raceText = await _table(raceTextTable);
    final classText = await _table(classTextTable);
    final kits = await _table(kitTable);

    return (
      // ⚠️ Keyed on the table's own `ID` column: it spells the seventh race
      // `HALF_ORC` where `RACE.IDS` says `HALFORC`.
      races: {
        for (final row in raceText.rows.keys)
          if (raceText.number(row, 'ID') case final int id)
            if (raceText.number(row, TableColumn.raceName.header)
                case final int strref)
              if (strref >= 0) id: strref,
      },
      // Only the plain-class rows — a kit row shares its `CLASSID`.
      //
      // ⚠️ **And the FALLEN rows share everything.** `FALLEN_CLERIC` carries
      // `CLASSID 3` and `KITID 16384` exactly as `CLERIC` does, and it comes
      // later in the file — so keying on those two alone let it win, and the
      // creation screen offered **"Fallen Cleric"** where the game draws
      // "Cleric". The same displaced-row trap `IdsMap` and `Table2da` were
      // both fixed for. The table's own `FALLEN` column is the discriminator.
      classes: {
        for (final row in classText.rows.keys)
          if (classText.number(row, 'KITID') == trueClassKitId)
            if (classText.number(row, TableColumn.fallen.header) != fallenClass)
              if (classText.number(row, 'CLASSID') case final int id)
                if (classText.number(row, TableColumn.mixedCaseName.header)
                    case final int strref)
                  if (strref >= 0) id: strref,
      },
      kits: {
        for (final row in kits.rows.keys)
          if (kits.cell(row, 'ROWNAME') case final String identifier)
            if (kits.number(row, TableColumn.mixedCaseName.header)
                case final int strref)
              if (strref >= 0) identifier: strref,
      },
    );
  }

  /// What this installation says a new character may be.
  ///
  /// Six tables at once, read together because they answer one question
  /// between them and no step of a creation flow is useful without the rest.
  /// They are small — the largest is 9 KB — and the key file and archives
  /// underneath are already cached.
  ///
  /// Names and descriptions come back as **strrefs**, exactly as
  /// [proficiencies] leaves them: resolving one needs the talk table, which is
  /// a different repository, and repositories must never be aware of each
  /// other.
  ///
  /// Not cached here either — see [proficiencies].
  Future<CreationCatalogue> creationCatalogue({
    required GameRules rules,
  }) async {
    final tables = await Future.wait(creationTables.map(_table));
    return creationCatalogueFrom(
      classRaceRequirements: tables[0],
      alignmentRequirements: tables[1],
      kits: tables[2],
      classText: tables[3],
      raceText: tables[4],
      racialAdjustments: tables[5],
      proficiencySlots: tables[6],
      proficiencyRankCaps: tables[7],
      wizardMemorisation: tables[8],
      sorcererMemorisation: tables[9],
      sorcererKnownSpells: tables[10],
      bardMemorisation: tables[11],
      raceAbilityRequirements: tables[12],
      classAbilityRequirements: tables[13],
      thiefSkillPoints: tables[14],
      thiefSkillClasses: tables[15],
      magicSchools: tables[16],
      wizardSpells: await wizardSpells(level: 1),
      proficiencies: await proficiencies(),
      rules: rules,
    );
  }

  /// Every wizard spell of [level] a character may learn.
  ///
  /// ⚠️ **D13, and the one case where the answer is in no table.** Checked and
  /// rejected: `spells.2da` is a flat cap of fifty per level, `speldesc.2da`
  /// lists descriptions for a few dozen, `mschool.2da` names the schools,
  /// `splsrckn.2da` and the ten `mxspl*` tables are progressions. None
  /// enumerates the spells. The spells themselves do.
  ///
  /// So this reads the `SPL` headers, and needs **three** filters rather than
  /// the obvious one, each measured against a real installation:
  ///
  /// 1. **The header's own type and level.** Necessary, and nowhere near
  ///    sufficient: 108 resources claim first-level wizard.
  /// 2. **A name strref.** Eighty-six of those 108 carry `-1` — the engine's
  ///    own plumbing, cast at creatures rather than learned.
  /// 3. ⚠️ **The resref's level digit must agree with the header's.** What is
  ///    left after the first two filters still holds `SPWI003`, `SPWI020`,
  ///    `SPWI989` and `SPWI998` — all named, all claiming level 1, none of them
  ///    a first-level spell. The naming is `SPWI<level><nn>`, and where the
  ///    name and the header disagree the resource is not what it looks like.
  ///
  /// With all three, first level yields **22** — which is the count the
  /// engine's own Mage Book screen shows.
  ///
  /// Never throws: no installation means no spells, and the step says so.
  Future<List<SpellChoice>> wizardSpells({required int level}) async {
    final index = await _keyIndex();
    if (index == null) return const [];

    final prefix = '$wizardSpellPrefix$level';
    final found = <SpellChoice>[];
    for (final resref in index.resrefsOf(ResourceType.spell)) {
      if (!_isWizardSpellName(resref, prefix)) continue;

      final bytes = await _resource(resref, ResourceType.spell);
      if (bytes == null) continue;
      final Spl spell;
      try {
        spell = SplCodec.decode(bytes, source: resref);
      } on InfinityFormatException {
        continue;
      }
      if (spell.type != SplType.wizard || spell.level != level) continue;
      if (spell.nameStrref case final int strref) {
        found.add(
          SpellChoice(
            resref: resref.toUpperCase(),
            school: spell.school,
            excludedSchools: {
              for (var each = 1; each <= Spl.lastSchoolExcluded; each++)
                if (spell.excludesSpecialist(each)) each,
            },
            nameStrref: strref,
            descriptionStrref: spell.descriptionStrref,
          ),
        );
      }
    }
    // By resref, so the order is stable whatever the archive's is. The screen
    // sorts by name, which needs the talk table and happens above this layer.
    return found..sort((a, b) => a.resref.compareTo(b.resref));
  }

  /// Whether [resref] is `SPWI` + a level digit + exactly two more digits.
  ///
  /// Rejects `SPWI119A` and `spwi117a`, which are sub-spells rather than
  /// entries in anyone's book.
  static bool _isWizardSpellName(String resref, String prefix) {
    if (resref.length != wizardSpellNameLength) return false;
    if (!resref.toUpperCase().startsWith(prefix.toUpperCase())) return false;
    return int.tryParse(resref.substring(prefix.length)) != null;
  }

  /// The bitmap named [resref], or `null` if there is none.
  ///
  /// ⚠️ **The player's own `portraits/` folder is searched before the game's
  /// archives**, which is the order the engine itself uses and is the whole of
  /// what "custom portrait" means: a loose file that shadows a packed one. A
  /// portrait is named by resref either way, so there is no separate field,
  /// flag or code path — only a different place to look first.
  ///
  /// **Never throws.** A missing installation, an unreadable file and an
  /// unknown resref are all ordinary, and a card without a picture is a far
  /// better outcome than a screen that fails to draw.
  Future<Uint8List?> portrait(String resref) async {
    if (resref.isEmpty) return null;

    final custom = _customPortrait(resref);
    if (custom != null) return custom;

    return _resource(resref, ResourceType.bitmap);
  }

  /// Base names of every portrait the game ships, plus the player's own.
  ///
  /// ⚠️ **Filtered by *archive*, not by name shape.** `data/PORTRAIT.BIF` is a
  /// dedicated archive of exactly 210 bitmaps, so asking which resources live
  /// in it is exact — where guessing at names puts `CMISC4S` in the list
  /// because it happens to end in `S`.
  ///
  /// Returns base names with the `L`/`M`/`S` suffix removed and duplicates
  /// collapsed, so one entry is one portrait rather than three.
  Future<List<String>> portraitNames() async {
    final index = await _keyIndex();
    final names = <String>{};

    if (index != null) {
      final archive = index.archiveNamed(portraitArchive);
      for (final resref in index.resrefsOf(
        ResourceType.bitmap,
        archive: archive,
      )) {
        names.add(_baseNameOf(resref));
      }
    }
    names.addAll(_customPortraitNames());

    return names.toList()..sort();
  }

  /// The creature record named [resref], or `null` if there is none.
  ///
  /// Used for exactly one thing so far: [characterTemplate], the seed every
  /// protagonist is built from.
  ///
  /// **Never throws.** A machine with no game installed simply cannot create a
  /// character, and the screen says so rather than failing to draw.
  Future<Uint8List?> creature(String resref) =>
      _resource(resref, ResourceType.creature);

  /// The `2DA` named [resref], or an empty table if it cannot be read.
  ///
  /// **Never throws.** A missing or unreadable installation is an ordinary
  /// state — the app opens saves on machines with no game on them — and the
  /// panel degrades to numbers without names rather than failing to draw.
  Future<Table2da> _table(String resref) async {
    final bytes = await _resource(resref, ResourceType.table2da);
    if (bytes == null) return Table2da.parse('');
    try {
      return Table2da.parse(utf8.decode(bytes));
    } on FormatException {
      // A 2DA that is not UTF-8. Every BG:EE table is, but a mod's need not
      // be, and a rules table is not worth failing an app launch over.
      return Table2da.parse('');
    }
  }

  /// The bytes of [resref] of [type] from the game's archives, or `null`.
  ///
  /// One lookup path for every kind of resource, so the index and the archives
  /// are cached in one place rather than once per caller.
  Future<Uint8List?> _resource(String resref, ResourceType type) async {
    final game = _profile.findGameDirectory();
    final index = await _keyIndex();
    if (game == null || index == null) return null;

    final where = index.locate(resref, type);
    if (where == null) return null;

    final archive = await _archive(game, index.archives[where.archive]);
    if (archive == null) return null;

    // Checked rather than caught: `BifArchive.resource` reports a bad index
    // with a `RangeError`, which is an Error and not ours to swallow. The key
    // file and the archive disagreeing is corrupt data, and the honest answer
    // here is the same as for an unknown resref -- no such resource.
    if (where.file < 0 || where.file >= archive.resourceCount) return null;

    try {
      return archive.resource(where.file);
    } on InfinityFormatException {
      return null;
    }
  }

  Future<KeyIndex?> _keyIndex() => _index ??= _readIndex();

  Future<KeyIndex?> _readIndex() async {
    final game = _profile.findGameDirectory();
    if (game == null) return null;
    try {
      return KeyIndex.parse(
        await File(
          '$game${Platform.pathSeparator}${GameProfileService.gameMarker}',
        ).readAsBytes(),
        source: GameProfileService.gameMarker,
      );
    } on FileSystemException {
      return null;
    } on InfinityFormatException {
      return null;
    }
  }

  Future<BifArchive?> _archive(String game, String path) =>
      _archives[path] ??= _readArchive(game, path);

  Future<BifArchive?> _readArchive(String game, String path) async {
    // The key file writes archive paths in the engine's own notation, which is
    // Windows-separated whatever the host is.
    final relative = path.replaceAll(r'\', Platform.pathSeparator);
    try {
      return BifArchive.parse(
        await File('$game${Platform.pathSeparator}$relative').readAsBytes(),
        source: relative,
      );
    } on FileSystemException {
      return null;
    } on InfinityFormatException {
      return null;
    }
  }

  /// A portrait from the player's own folder, or `null`.
  Uint8List? _customPortrait(String resref) {
    final root = _profile.findPortraitRoot();
    if (root == null) return null;

    final file = File(
      '$root${Platform.pathSeparator}$resref$portraitFileExtension',
    );
    try {
      return file.existsSync() ? file.readAsBytesSync() : null;
    } on FileSystemException {
      return null;
    }
  }

  /// Base names of the portraits in the player's own folder.
  Set<String> _customPortraitNames() {
    final root = _profile.findPortraitRoot();
    if (root == null) return const {};

    final dir = Directory(root);
    if (!dir.existsSync()) return const {};
    return {
      for (final file in dir.listSync().whereType<File>())
        if (file.path.toLowerCase().endsWith(portraitFileExtension))
          _baseNameOf(
            file.path.split(Platform.pathSeparator).last.split('.').first,
          ),
    };
  }
}

/// The creature the engine builds every protagonist from.
///
/// ⚠️ **The game's own template, read at run time — never vendored.** The same
/// rule as D11: it is the player's game data, and it is why every player
/// character's resref reads `*HARBASE`, the engine having overwritten the first
/// byte with `*`. Creating a character means loading this and editing it.
const String characterTemplate = 'CHARBASE';

/// The archive holding every portrait the game ships.
const String portraitArchive = 'PORTRAIT.BIF';

/// The extension a loose portrait file carries.
const String portraitFileExtension = '.bmp';

/// [resref] with its `L`/`M`/`S` variant letter removed.
///
/// ⚠️ **Only when there is one.** Six of the game's own 210 portraits are not
/// part of a triple — `MBAS_GR`, `NOPORTMD` and `TESTPOR` carry no variant
/// suffix at all — so a blind chop would rename them.
String _baseNameOf(String resref) {
  if (resref.isEmpty) return resref;
  final last = resref[resref.length - 1].toUpperCase();
  return last == 'M' || last == 'L' || last == 'S'
      ? resref.substring(0, resref.length - 1)
      : resref;
}

/// The resref of the weapon-proficiency table.
const String weaponProficiencyTable = 'weapprof';

/// The six tables a creation flow needs, all from the player's installation.
///
/// ⚠️ **Read the file before believing its name.** `abracerq.2da` is the
/// *ability minima* per race and is not one of these; `clasiskl.2da` is not a
/// class list. The names here were each opened and checked.
const List<String> creationTables = [
  classRaceRequirementTable,
  alignmentRequirementTable,
  kitTable,
  classTextTable,
  raceTextTable,
  racialAdjustmentTable,
  proficiencySlotTable,
  proficiencyRankCapTable,
  wizardMemorisationTable,
  sorcererMemorisationTable,
  sorcererKnownSpellTable,
  bardMemorisationTable,
  raceAbilityTable,
  classAbilityTable,
  // ⚠️ **Two tables one letter apart**, and creation needs both: `thiefskl`
  // says how many points there are to spend and `thiefscl` which skills they
  // may go into. Reading either alone gives a Thief 40 points and nowhere to
  // put them, or seven skills and nothing to spend.
  thiefSkillPointTable,
  thiefSkillTable,
  magicSchoolTable,
];

/// The magic schools, in the order that **is** their numbering.
///
/// ⚠️ **The row's position is the school number**, and the file has no column
/// carrying it — `RES_REF` is the strref of the message shown when magic of
/// that school is dispelled. `None` is row 0, `ABJURER` is 1, and a spell's
/// `SPL` header stores exactly these numbers.
const String magicSchoolTable = 'mschool';

/// How many thief-skill points each class and kit starts with.
const String thiefSkillPointTable = 'thiefskl';

/// How many proficiency pips each class has at first level, and its rate after.
///
/// ⚠️ **Not [proficiencyRankCapTable], which is one letter away.** This is the
/// number of pips to spend — MAGE 1, FIGHTER 4 — where that is how many may go
/// into any one proficiency.
const String proficiencySlotTable = 'profs';

/// The most ranks one proficiency may hold, by class and level band.
const String proficiencyRankCapTable = 'profsmax';

/// Memorisable wizard spells: a row per caster level, a column per spell level.
///
/// ⚠️ **Three of these, one per casting class, and nothing joins a class to
/// its own.** `hpclass.2da` does exactly that job for hit dice; there is no
/// equivalent here, which is why `CreationCatalogue.spellsMemorisableFor`
/// carries the mapping as a stated rule.
const String wizardMemorisationTable = 'mxsplwiz';

/// The sorcerer's memorisation progression — three at first level, not one.
const String sorcererMemorisationTable = 'mxsplsrc';

/// How many spells a sorcerer *knows*, which for every other class is untabled.
const String sorcererKnownSpellTable = 'splsrckn';

/// The bard's, and ⚠️ **it starts at row 2** — a bard casts nothing at first.
const String bardMemorisationTable = 'mxsplbrd';

/// What each race may roll for each ability, before its own adjustments.
///
/// ⚠️ **Composes with [racialAdjustmentTable]** to give what the game prints:
/// an elf's Dexterity is this table's 6–18 plus that one's +1, and the engine's
/// own screen says 7 to 19.
const String raceAbilityTable = 'abracerq';

/// The ability minima each class **and kit** requires.
const String classAbilityTable = 'abclasrq';

/// The resref prefix every wizard spell carries, before its level digit.
const String wizardSpellPrefix = 'SPWI';

/// How long a wizard spell's resref is: `SPWI` plus three digits.
const int wizardSpellNameLength = 7;

/// Which classes each race may take — a row per class or kit, a column per
/// race. **Its columns are the playable races.**
const String classRaceRequirementTable = 'clsrcreq';

/// Which alignments each class or kit may hold, as nine `L_G`…`C_E` columns.
const String alignmentRequirementTable = 'alignmnt';

/// Every specialisation, the class it belongs to, and the dword it stores.
const String kitTable = 'kitlist';

/// Each class's and kit's description strref.
///
/// ⚠️ **Its `MIXED` column is not a usable name** — `FIGHTER` holds the token
/// `<FIGHTERTYPE>`, which only the engine substitutes. Take `DESCSTR` from here
/// and let `GameRules.className` do the naming.
const String classTextTable = 'clastext';

/// Each race's name and description strref, keyed by its **`ID` column**.
const String raceTextTable = 'racetext';

/// What each race adds to and takes from the ability scores.
const String racialAdjustmentTable = 'abracead';

/// The five saving-throw tables, one per class group.
///
/// ⚠️ **`savename.2da` is not one of them.** It is the list of savegame *slot*
/// names — the near-name trap this project has walked into twice, with
/// `thiefskl`/`thiefscl` and `profs`/`profsmax`. `savecng` and `savecndh` are
/// not saving throws either.
/// ⚠️ **Plus the two racial Constitution bonuses**, which are the same shape
/// and are read together because a derivation without them is wrong rather
/// than merely incomplete: a dwarf, gnome or halfling improves three of the
/// five by up to five points.
const List<String> savingThrowTableNames = [
  'savewar',
  'savewiz',
  'saveprs',
  'saverog',
  'savemonk',
  'savecndh',
  'savecng',
];

/// Every numeric rules table that is a plain row-by-column grid.
///
/// Two groups, and both are read together because they are one mechanism:
///
/// - **What a character's stored values should be** — `thac0`, `lore`,
///   `thiefskl` for the points a thief spends, and `skillbrd` and `skillrng`
///   for the two skills that are fixed by level rather than allocated.
/// - **What the game adds before showing them** — `lorebon` by Intelligence
///   and Wisdom, `skilldex` by Dexterity, `skillrac` by race, `strmod` and
///   `strmodex` by Strength, `intmod` for the chance to learn a spell.
///
/// ⚠️ **Read the file before believing the name**, which this list has already
/// paid for twice: `thiefskl` is the points and `thiefscl` is which skills a
/// class may have; `savename` is savegame slots and not a saving throw at all.
const List<String> numericRulesTables = [
  'thac0',
  'lore',
  'thiefskl',
  'skillbrd',
  'skillrng',
  'lorebon',
  'skilldex',
  'skillrac',
  'strmod',
  'strmodex',
  'intmod',
];

/// Which hit-die table each class and kit uses.
///
/// ⚠️ **Kits are listed individually and do not follow their class** —
/// `DWARVEN_DEFENDER` uses `HPBARB` where its Fighter base uses `HPWAR`.
const String hitDieClassTable = 'hpclass';

/// What a `2DA` cell holds when the row has no value at all.
const String tableAbsent = '*';

/// What the `FALLEN` column holds for a row that is not a real class
/// choice.
const int fallenClass = 1;

/// The resref of the table saying which classes have which thief skills.
///
/// Not to be confused with `thiefskl.2da`, which is the *number of points* a
/// thief gets per level, or with `tracking.2da`, which despite the name is a
/// list of per-area strings and says nothing about who may track.
const String thiefSkillTable = 'thiefscl';

/// The highest strref a talk table could hold.
///
/// The unused rows of `weapprof.2da` carry `4294967296` — two to the
/// thirty-second, one past the top of a dword. It is a filler value, not a
/// string reference, and passing it to a lookup would be asking for entry
/// number four billion.
const int maximumStrref = 0xFFFFFFFF;

/// One class-or-kit column of a rules table: its header and where it sits.
typedef _ClassColumn = ({String name, int index});

/// Every column of [table] that names a class or kit.
///
/// Taken by **exclusion** rather than from a list of classes, because the set
/// of kits is exactly what varies between installations — a mod adding one is
/// the case the generated tables get wrong, and D11 is the decision that says
/// to read the player's file instead.
///
/// `thiefscl.2da` excludes nothing, since every column of it is a class;
/// `weapprof.2da` excludes its id and its two strrefs.
List<_ClassColumn> _classColumns(
  Table2da table, {
  Set<String> except = const {},
}) => [
  for (var i = 0; i < table.columns.length; i++)
    if (!except.contains(table.columns[i])) (name: table.columns[i], index: i),
];

/// The cell of [row] at column index [at], or `null` when there is none.
///
/// `Table2da.columns` and a row's `cells` both exclude the row label, so they
/// line up directly — this is `Table2da.cell` with the row already in hand. A
/// row too short for a column gets the file's declared default, which is what
/// the second line of a 2DA is for.
String? _cell(Table2da table, TableRow row, int at) {
  if (at < 0) return null;
  return at < row.cells.length ? row.cells[at] : table.defaultValue;
}

/// [SavingThrowTables] from the parsed `save…2da` files, keyed by resref.
///
/// A free function for the same reason [proficienciesFrom] is one: it is pure,
/// so it is testable without an installation.
///
/// ⚠️ **The level columns are read by name, not by position.** They are headed
/// `1` to `40`, and taking a row's cells in file order would work right up
/// until a table with an extra leading column, at which point every character
/// in the game gets the wrong saving throws by one level.
SavingThrowTables savingThrowTablesFrom(Map<String, Table2da> tables) {
  final rowsByTable = <String, Map<String, List<int>>>{};

  for (final MapEntry(key: name, value: table) in tables.entries) {
    final rows = <String, List<int>>{};
    for (final row in SavingThrowTables.rows) {
      final values = <int>[];
      for (final column in table.columns) {
        final value = table.number(row, column);
        // A row that stops answering has reached the end of the table; a row
        // that never answered is not in this file at all.
        if (value == null) break;
        values.add(value);
      }
      if (values.isNotEmpty) rows[row] = values;
    }
    // All five or none: a half-read table would answer some categories and
    // silently drop others, which is worse than saying the file is not there.
    if (rows.length == SavingThrowTables.rows.length) {
      rowsByTable[name.toUpperCase()] = rows;
    }
  }

  return SavingThrowTables(rowsByTable: rowsByTable);
}

/// [RulesTables] from parsed 2DAs, keyed by resref.
///
/// Pure, so it is testable without an installation — the same reason
/// [proficienciesFrom] and [savingThrowTablesFrom] are free functions.
///
/// ⚠️ **Walks `allRows`, not `rows`.** A repeated row label is real data in
/// these files, as `weapprof.2da` proved; the first one wins here, which keeps
/// the reading the same as `Table2da`'s own.
RulesTables rulesTablesFrom(Map<String, Table2da> tables) {
  final byName = <String, Map<String, Map<String, int>>>{};

  for (final MapEntry(key: name, value: table) in tables.entries) {
    final rows = <String, Map<String, int>>{};
    for (final row in table.allRows) {
      final cells = <String, int>{};
      for (var i = 0; i < table.columns.length; i++) {
        if (int.tryParse(_cell(table, row, i) ?? '') case final int value) {
          cells[table.columns[i]] = value;
        }
      }
      if (cells.isNotEmpty) {
        rows.putIfAbsent(row.label.toUpperCase(), () => cells);
      }
    }
    if (rows.isNotEmpty) byName[name.toUpperCase()] = rows;
  }

  return RulesTables(byName: byName);
}

/// [SkillCatalogue] from a parsed `thiefscl.2da`.
///
/// Every column is a class or kit, and every row a skill, so this is the whole
/// table read straight through. Unlike `weapprof.2da` the row label *is* the
/// key here, and no label repeats.
SkillCatalogue thiefSkillsFrom(Table2da table) {
  final columns = _classColumns(table);
  if (columns.isEmpty) return SkillCatalogue.empty;

  return SkillCatalogue({
    for (final row in table.allRows)
      row.label: {
        for (final column in columns)
          if (int.tryParse(_cell(table, row, column.index) ?? '')
              case final int allowance)
            column.name: allowance,
      },
  });
}

/// [ProficiencyCatalogue] from a parsed `weapprof.2da`.
///
/// A free function so the parsing is testable without an installation, and
/// because it is pure — the same reason `charactersFrom` is one.
///
/// ⚠️ **Keyed on the `ID` column, never on the row label.** BG:EE labels two
/// rows `AXE` and two `SPEAR` — the obsolete BG1 proficiencies 6 and 3, then
/// the live 92 and 98 — so the label does not identify a proficiency. That is
/// also why this walks `allRows` rather than `rows`: the displaced half of
/// each pair is real data.
ProficiencyCatalogue proficienciesFrom(Table2da table) {
  final columns = table.columns;
  final idAt = columns.indexOf(TableColumn.proficiencyId.header);
  final nameAt = columns.indexOf(TableColumn.proficiencyName.header);
  if (idAt < 0) return ProficiencyCatalogue.empty;

  final classColumns = _classColumns(
    table,
    except: {
      TableColumn.proficiencyId.header,
      TableColumn.proficiencyName.header,
      TableColumn.proficiencyDescription.header,
    },
  );

  final entries = <int, ProficiencyEntry>{};
  for (final row in table.allRows) {
    String? cell(int column) => _cell(table, row, column);

    final id = int.tryParse(cell(idAt) ?? '');
    if (id == null) continue;

    final strref = int.tryParse(cell(nameAt) ?? '');
    entries[id] = ProficiencyEntry(
      id: id,
      identifier: row.label,
      nameStrref: strref != null && strref >= 0 && strref <= maximumStrref
          ? strref
          : null,
      maximumByColumn: {
        for (final column in classColumns)
          if (int.tryParse(cell(column.index) ?? '') case final int maximum)
            column.name: maximum,
      },
    );
  }
  return ProficiencyCatalogue(entries);
}
