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

import 'dart:typed_data';

import 'package:infinity_formats/src/cre/cre_item.dart';
import 'package:infinity_formats/src/cre/cre_section.dart';
import 'package:infinity_formats/src/cre/effect.dart';
import 'package:infinity_formats/src/exceptions.dart';
import 'package:infinity_formats/src/spec/cre_v1_0.dart';
import 'package:infinity_formats/src/spec/format_field.dart';
import 'package:infinity_formats/src/text/fixed_field.dart';

/// A parsed creature record — the `CRE` embedded in a savegame.
///
/// Like `Gam`, **the bytes are the model**: every accessor reads through
/// [bytes], so there is no parsed copy to drift out of step with the file.
final class Cre {
  /// Wraps [bytes], which must already be validated.
  const Cre.trusted(this.bytes);

  /// The complete creature record, exactly as read.
  final Uint8List bytes;

  ByteData get _view => ByteData.sublistView(bytes);

  /// Reads [field] at its declared width and signedness.
  ///
  /// One reader for every numeric field, rather than each accessor picking
  /// `getInt16` or `getUint16` for itself. That discretion is what produced
  /// the armour-class bug: the table already knew the answer and the getter
  /// was free to ignore it. `Gam.withCreatureField` writes through the mirror
  /// of this, so the two cannot drift.
  int _read(CreHeaderField field) => _readAt(0, field);

  /// Reads [field] of a structure beginning at [base].
  ///
  /// The same reader serves the header and every section entry, so the three
  /// spell layouts cannot pick a different width or signedness from the one
  /// their table declares — which is the whole of what D6 buys.
  int _readAt(int base, FormatField field) =>
      switch ((field.length, field.signed)) {
        (1, false) => _view.getUint8(base + field.offset),
        (1, true) => _view.getInt8(base + field.offset),
        (2, false) => _view.getUint16(base + field.offset, Endian.little),
        (2, true) => _view.getInt16(base + field.offset, Endian.little),
        (4, false) => _view.getUint32(base + field.offset, Endian.little),
        (4, true) => _view.getInt32(base + field.offset, Endian.little),
        _ => throw InfinityFormatException.unreadableField(
          what: '$field',
          length: field.length,
        ),
      };

  /// Reads [field] of the header, at the width and signedness it declares.
  ///
  /// **The read counterpart of `withCreatureField`.** Every named accessor here
  /// is a spelling of this with the field filled in; this one exists for the
  /// callers that hold a field rather than a name — a test comparing the six
  /// abilities, or a tool checking that everything it wrote survived. Both were
  /// writing the six out by hand.
  ///
  /// ⚠️ **The table decides the signedness, not the caller.** That discretion
  /// is what produced the armour-class bug, where the layout already recorded
  /// "signed word" and the getter used `getUint16` anyway.
  ///
  /// Throws [InfinityFormatException] for a field that is not a 1-, 2- or
  /// 4-byte number — a resref, for instance.
  int readField(CreHeaderField field) => _read(field);

  /// Where entry [at] of [section] begins, relative to this record.
  ///
  /// ⚠️ **Never derived from the gap to the next section.** The offset field is
  /// the only source; a section's neighbours may be absent, in which case they
  /// carry `0` and the arithmetic produces a negative stride.
  int entryStart(CreSection section, int at) =>
      _read(section.offsetField) + at * section.strideIn(this);

  /// Strref of this creature's long name, or `-1` when there is none.
  ///
  /// `-1` for the protagonist, whose name is not in `dialog.tlk` — it comes
  /// from the GAM NPC struct instead.
  ///
  /// Read **signed**, so the engine's "no string" sentinel arrives as the `-1`
  /// every consumer is written around rather than as `4294967295`. `Tlk.get`
  /// documents its contract in terms of a negative strref; an unsigned read
  /// satisfied it only by accident of the bounds check.
  int get longNameStrref => _read(CreHeaderField.longName);

  /// This character's experience points.
  ///
  /// The same field means "power level" for summoned creatures; see
  /// [CreHeaderField.experience].
  int get experience => _read(CreHeaderField.experience);

  /// Gold carried by this creature specifically, not the shared party purse.
  int get gold => _read(CreHeaderField.gold);

  /// Current hit points.
  int get currentHitPoints => _read(CreHeaderField.currentHitPoints);

  /// Maximum hit points.
  int get maximumHitPoints => _read(CreHeaderField.maximumHitPoints);

  /// THAC0.
  ///
  /// Unsigned, and verified as such rather than assumed: IESDP gives this one
  /// as "1 (byte)" with a range of 1-25, while the armour class fields two
  /// rows above it are explicitly signed.
  int get thac0 => _read(CreHeaderField.thac0);

  /// Effective armour class — what the character actually defends at.
  ///
  /// **Signed**, per IESDP's "2 (signed word)". Plate and shield reaches AC
  /// −2, and an unsigned read renders that as 65534. Nothing in the fixture
  /// catches this: all 37 creatures there sit at AC 10.
  int get armorClass => _read(CreHeaderField.armorClassEffective);

  /// Natural armour class, before equipment.
  int get armorClassNatural => _read(CreHeaderField.armorClassNatural);

  /// Reputation, as displayed — the stored value divided by ten.
  ///
  /// The field holds `110` where the game shows 11.0. Confirmed rather than
  /// assumed: BG1 reputation only ranges 0-20, so a stored 110 cannot be raw.
  double get reputation => _read(CreHeaderField.reputation) / 10;

  /// Levels in each of the three class slots.
  (int, int, int) get levels => (
    _read(CreHeaderField.levelFirstClass),
    _read(CreHeaderField.levelSecondClass),
    _read(CreHeaderField.levelThirdClass),
  );

  /// Attacks per round.
  int get numberOfAttacks => _read(CreHeaderField.numberOfAttacks);

  /// The five saving throws. Lower is better.
  ///
  /// A record because they are read as a set and the names carry the meaning
  /// — the game labels them "Paralysis / Poison / Death", "Rod / Staff /
  /// Wand", "Petrification / Polymorph", "Breath Weapon" and "Spell".
  ///
  /// **Stored exactly as displayed**, unusually for this format. Verified
  /// 2026-08-08: a creature holding 14/11/13/15/12 showed those five numbers
  /// on the record screen with nothing added.
  ({int death, int wands, int polymorph, int breath, int spells})
  get savingThrows => (
    death: _read(CreHeaderField.saveVersusDeath),
    wands: _read(CreHeaderField.saveVersusWands),
    polymorph: _read(CreHeaderField.saveVersusPolymorph),
    breath: _read(CreHeaderField.saveVersusBreath),
    spells: _read(CreHeaderField.saveVersusSpells),
  );

  /// Percentage resistances to each damage type.
  ({
    int fire,
    int cold,
    int electricity,
    int acid,
    int magic,
    int magicFire,
    int magicCold,
    int slashing,
    int crushing,
    int piercing,
    int missile,
  })
  get resistances => (
    fire: _read(CreHeaderField.resistFire),
    cold: _read(CreHeaderField.resistCold),
    electricity: _read(CreHeaderField.resistElectricity),
    acid: _read(CreHeaderField.resistAcid),
    magic: _read(CreHeaderField.resistMagic),
    magicFire: _read(CreHeaderField.resistMagicFire),
    magicCold: _read(CreHeaderField.resistMagicCold),
    slashing: _read(CreHeaderField.resistSlashing),
    crushing: _read(CreHeaderField.resistCrushing),
    piercing: _read(CreHeaderField.resistPiercing),
    missile: _read(CreHeaderField.resistMissile),
  );

  /// Armour class modifiers by damage type. Signed; negative is better.
  ({int crushing, int missile, int piercing, int slashing})
  get armorClassModifiers => (
    crushing: _read(CreHeaderField.armorClassCrushing),
    missile: _read(CreHeaderField.armorClassMissile),
    piercing: _read(CreHeaderField.armorClassPiercing),
    slashing: _read(CreHeaderField.armorClassSlashing),
  );

  /// The thief skills and Lore, **as the file stores them**.
  ///
  /// ⚠️ **These are allocated points, not the skill the game shows.** Measured
  /// 2026-08-08: a thief storing Move Silently 15 displayed 35, and two
  /// characters both storing Lore 3 displayed 10 and 15. The engine adds
  /// class, race and Dexterity bonuses. Presenting these as the skill would
  /// repeat the hit-point mistake, so the UI labels them.
  ({
    int hideInShadows,
    int detectIllusion,
    int setTraps,
    int lore,
    int lockpicking,
    int moveSilently,
    int findTraps,
    int pickPockets,
  })
  get thiefSkills => (
    hideInShadows: _read(CreHeaderField.hideInShadows),
    detectIllusion: _read(CreHeaderField.detectIllusion),
    setTraps: _read(CreHeaderField.setTraps),
    lore: _read(CreHeaderField.lore),
    lockpicking: _read(CreHeaderField.lockpicking),
    moveSilently: _read(CreHeaderField.moveSilently),
    findTraps: _read(CreHeaderField.findTraps),
    pickPockets: _read(CreHeaderField.pickPockets),
  );

  /// Fatigue (0-100).
  int get fatigue => _read(CreHeaderField.fatigue);

  /// Intoxication (0-100).
  int get intoxication => _read(CreHeaderField.intoxication);

  /// Luck.
  int get luck => _read(CreHeaderField.luck);

  /// Turn undead level.
  int get turnUndeadLevel => _read(CreHeaderField.turnUndeadLevel);

  /// Tracking skill (0-100).
  int get trackingSkill => _read(CreHeaderField.trackingSkill);

  /// Morale. IESDP: "default value is 10 (capped 0-20)".
  int get morale => _read(CreHeaderField.morale);

  /// The morale at which this creature panics.
  int get moraleBreak => _read(CreHeaderField.moraleBreak);

  /// Ticks before morale recovers.
  int get moraleRecoveryTime => _read(CreHeaderField.moraleRecoveryTime);

  /// The ranger's chosen foe (`RACE.IDS`).
  int get racialEnemy => _read(CreHeaderField.racialEnemy);

  /// Strength (1-25).
  int get strength => _read(CreHeaderField.strength);

  /// Percentile strength bonus, meaningful only at Strength 18.
  int get strengthBonus => _read(CreHeaderField.strengthBonus);

  /// Intelligence (1-25).
  int get intelligence => _read(CreHeaderField.intelligence);

  /// Wisdom (1-25).
  int get wisdom => _read(CreHeaderField.wisdom);

  /// Dexterity (1-25).
  int get dexterity => _read(CreHeaderField.dexterity);

  /// Constitution (1-25).
  int get constitution => _read(CreHeaderField.constitution);

  /// Charisma (1-25).
  int get charisma => _read(CreHeaderField.charisma);

  /// Class, as a `CLASS.IDS` number. `7` is `FIGHTER_MAGE`.
  ///
  /// Reported as the number it is: naming it needs `CLASS.IDS`, which is game
  /// data rather than file layout, so it belongs above a codec.
  int get classId => _read(CreHeaderField.characterClass);

  /// Race, as a `RACE.IDS` number. `2` is `ELF`.
  int get raceId => _read(CreHeaderField.race);

  /// Alignment, as an `ALIGNMEN.IDS` number. `0x21` is `NEUTRAL_GOOD`.
  int get alignmentId => _read(CreHeaderField.alignment);

  /// Gender, as a `GENDER.IDS` number. `1` is `MALE`.
  int get genderId => _read(CreHeaderField.gender);

  /// The kit dword. `0x40000000` means no kit.
  int get kitId => _read(CreHeaderField.kit);

  /// Resref of the medium portrait, e.g. `BDTMIM`.
  ///
  /// ⚠️ **IESDP calls this field "Small Portrait" and it is not** — see
  /// `CreHeaderField.portraitMedium`. This is the one a character sheet shows.
  ///
  /// Empty when the record names none, which is an ordinary state for a
  /// creature that is not a character.
  String get portraitMedium => decodeFixedString(
    bytes,
    CreHeaderField.portraitMedium.offset,
    CreHeaderField.portraitMedium.length,
  );

  /// Resref of the large portrait, e.g. `BDTMIL`.
  String get portraitLarge => decodeFixedString(
    bytes,
    CreHeaderField.portraitLarge.offset,
    CreHeaderField.portraitLarge.length,
  );

  /// Resref of this creature's dialogue file.
  String get dialogFile => decodeFixedString(
    bytes,
    CreHeaderField.dialogFile.offset,
    CreHeaderField.dialogFile.length,
  );

  /// Raw effect-layout selector: `0` → v1, `1` → v2.
  int get effectVersion => _read(CreHeaderField.effectVersion);

  /// Bytes per effect entry, chosen by [effectVersion].
  ///
  /// Reading this wrong does not produce a slightly-off value; it makes the
  /// section chain miss the end of the file entirely.
  int get effectLength =>
      effectVersion == 0 ? creEffectV1Length : creEffectV2Length;

  /// Offset of the known-spells section, relative to this creature's start.
  int get knownSpellsOffset => _read(CreHeaderField.knownSpellsOffset);

  /// Number of known spells.
  int get knownSpellsCount => _read(CreHeaderField.knownSpellsCount);

  /// Offset of the spell-memorisation info section.
  int get memorizationInfoOffset =>
      _read(CreHeaderField.memorizationInfoOffset);

  /// Number of spell-memorisation info entries.
  int get memorizationInfoCount => _read(CreHeaderField.memorizationInfoCount);

  /// Offset of the memorised-spells section.
  int get memorizedSpellsOffset => _read(CreHeaderField.memorizedSpellsOffset);

  /// Number of memorised spells.
  int get memorizedSpellsCount => _read(CreHeaderField.memorizedSpellsCount);

  /// Offset of the fixed-size item-slot table.
  int get itemSlotsOffset => _read(CreHeaderField.itemSlotsOffset);

  /// Offset of the items section.
  int get itemsOffset => _read(CreHeaderField.itemsOffset);

  /// Number of items.
  int get itemsCount => _read(CreHeaderField.itemsCount);

  /// Offset of the effects section.
  int get effectsOffset => _read(CreHeaderField.effectsOffset);

  /// Number of effects.
  int get effectsCount => _read(CreHeaderField.effectsCount);

  /// This creature's effects, in the order the record stores them.
  ///
  /// Views rather than copies, so walking them costs nothing and each knows
  /// the offset a writer would patch.
  List<Effect> get effects => [
    for (var i = 0; i < effectsCount; i++)
      Effect.at(bytes, effectsOffset + i * effectLength),
  ];

  /// Proficiency pips by `STATS.IDS` index.
  ///
  /// Which indices exist is the player's `weapprof.2da` to say, not this
  /// codec's — see [Effect.proficiencyOpcode].
  ///
  /// ⚠️ **Proficiencies are not header bytes on BG:EE.** IESDP documents them
  /// at `0x6e`-`0x81`, and those bytes are zero on every character in a save
  /// where the game plainly shows pips. They are stored as
  /// [Effect.proficiencyOpcode] effects instead, with the count in
  /// `parameter1` and the proficiency in `parameter2`.
  ///
  /// Verified 2026-08-08: a Fighter/Mage wielding a Battle Axe and a Flail
  /// reads `{114: 2}` — two pips in `PROFICIENCY2WEAPON` — against a record
  /// screen showing "Attacks per Round: 2" and a separate off-hand THAC0.
  ///
  /// Later entries win if an opcode repeats a proficiency, which is what the
  /// engine's own last-write-wins stacking implies; no fixture does it.
  Map<int, int> get proficiencies => {
    for (final effect in effects)
      if (effect.isProficiency) effect.parameter2: effect.parameter1,
  };

  /// The spells this creature knows, in the order the record stores them.
  ///
  /// The `level` of each is the level a **player** counts, not what the field
  /// holds: IESDP names it "Spell Level -1" and the arithmetic belongs here
  /// rather than at every call site.
  ///
  /// Empty when the section is absent, which is an ordinary state — two of the
  /// 37 creatures in the party fixture carry `knownSpellsOffset == 0`.
  List<({String resref, int level, int type})> get knownSpells => [
    for (var i = 0; i < knownSpellsCount; i++)
      if (entryStart(CreSection.knownSpells, i) case final int at)
        (
          resref: decodeFixedString(
            bytes,
            at + CreKnownSpellField.resref.offset,
            CreKnownSpellField.resref.length,
          ),
          level: _readAt(at, CreKnownSpellField.levelLessOne) + 1,
          type: _readAt(at, CreKnownSpellField.type),
        ),
  ];

  /// How many spells of each level and type this creature may memorise.
  ///
  /// ⚠️ **The rows partition [memorizedSpells] in order.** Each carries a
  /// window — `firstIndex` and `count` — and on every character the engine has
  /// made, a row's index is the running total of the counts before it. That is
  /// what makes inserting a memorised spell an edit to two sections.
  List<
    ({
      int level,
      int memorisable,
      int afterEffects,
      int type,
      int firstIndex,
      int count,
    })
  >
  get memorizations => [
    for (var i = 0; i < memorizationInfoCount; i++)
      if (entryStart(CreSection.memorizationInfo, i) case final int at)
        (
          level: _readAt(at, CreMemorizationField.levelLessOne) + 1,
          memorisable: _readAt(at, CreMemorizationField.memorisable),
          afterEffects: _readAt(at, CreMemorizationField.afterEffects),
          type: _readAt(at, CreMemorizationField.type),
          firstIndex: _readAt(at, CreMemorizationField.firstIndex),
          count: _readAt(at, CreMemorizationField.count),
        ),
  ];

  /// The spells this creature has prepared, in memorised-array order.
  List<({String resref, bool isMemorized, bool isDisabled})>
  get memorizedSpells => [
    for (var i = 0; i < memorizedSpellsCount; i++)
      if (entryStart(CreSection.memorizedSpells, i) case final int at)
        if (_readAt(at, CreMemorizedSpellField.flags) case final int flags)
          (
            resref: decodeFixedString(
              bytes,
              at + CreMemorizedSpellField.resref.offset,
              CreMemorizedSpellField.resref.length,
            ),
            isMemorized: flags & creSpellMemorizedFlag != 0,
            isDisabled: flags & creSpellDisabledFlag != 0,
          ),
  ];

  /// A copy of this creature with [entry] appended to [section].
  ///
  /// **The first write in this project that changes a record's size**, and the
  /// reason it can exist yet is that the creation flow puts it in a `.chr`: one
  /// length field in a 100-byte header, against a file this app built seconds
  /// earlier. The same edit inside a savegame moves thirty-nine pointers and is
  /// still Phase 1's work.
  ///
  /// What it does, in order:
  ///
  /// 1. **Creates the section if it is absent.** An offset of `0` means absent,
  ///    so `CHARBASE` — carrying no effects at all — needs the section made
  ///    rather than written at zero.
  /// 2. Splices [entry] in at the end of the section.
  /// 3. Raises that section's count by one.
  /// 4. **Shifts every other section that started at or after the splice**, and
  ///    leaves an absent section's `0` alone. Adding a stride to `0` would turn
  ///    "absent" into a pointer at the stride.
  ///
  /// ⚠️ **[CreSection.memorizationInfo] entries hold an index into the
  /// memorised-spell array**, so growing that array shifts windows this method
  /// knows nothing about. Whoever inserts a memorised spell owns keeping those
  /// indices honest — [withEntryField] is how.
  ///
  /// The result satisfies `contentEnd == bytes.length`, which is the single
  /// check that reconciles all six pointers, every entry size and the
  /// effect-version flag.
  ///
  /// Throws [ArgumentError] if [entry] is not exactly one entry wide.
  Cre withEntryAppended({
    required CreSection section,
    required Uint8List entry,
  }) => withEntryInserted(
    section: section,
    at: _read(section.countField),
    entry: entry,
  );

  /// A copy of this creature with [entry] spliced into [section] at index [at].
  ///
  /// The general form of [withEntryAppended], and it exists for one structure:
  /// a memorised spell belongs to the window its memorisation row names, so the
  /// second spell of a level that already has one goes **inside** the array.
  /// Appending would file it under whichever window happens to run last.
  ///
  /// [at] counts entries, not bytes, and may equal the current count — which is
  /// an append. Everything [withEntryAppended] documents applies: an absent
  /// section is created rather than written at zero, and a section carrying `0`
  /// keeps it rather than being shifted into a pointer at the stride.
  ///
  /// Throws [ArgumentError] if [entry] is not exactly one entry wide, and
  /// [RangeError] if [at] is outside the section.
  Cre withEntryInserted({
    required CreSection section,
    required int at,
    required Uint8List entry,
  }) {
    final stride = section.strideIn(this);
    if (entry.length != stride) {
      throw ArgumentError.value(
        entry.length,
        'entry',
        'a ${section.name} entry is $stride bytes',
      );
    }

    final offset = _read(section.offsetField);
    final count = _read(section.countField);
    if (at < 0 || at > count) {
      RangeError.checkValueInInterval(at, 0, count, 'at');
    }

    // An absent section starts where the content currently ends, so the splice
    // is an append to the file and nothing else moves.
    final present = hasSection(offset);
    final start = present ? offset : contentEnd;
    final spliceAt = present ? offset + at * stride : contentEnd;

    final out = Uint8List(bytes.length + stride)
      ..setRange(0, spliceAt, bytes)
      ..setRange(spliceAt, spliceAt + stride, entry)
      ..setRange(spliceAt + stride, bytes.length + stride, bytes, spliceAt);

    final view = ByteData.sublistView(out)
      ..setUint32(section.offsetField.offset, start, Endian.little)
      ..setUint32(section.countField.offset, count + 1, Endian.little);

    for (final other in CreSection.all) {
      if (other == section) continue;
      final where = _read(other.offsetField);
      if (!hasSection(where) || where < spliceAt) continue;
      view.setUint32(other.offsetField.offset, where + stride, Endian.little);
    }
    // The slot table has an offset and no count, so it moves but never grows.
    final slots = itemSlotsOffset;
    if (hasSection(slots) && slots >= spliceAt) {
      view.setUint32(
        CreHeaderField.itemSlotsOffset.offset,
        slots + stride,
        Endian.little,
      );
    }

    return Cre.trusted(out.asUnmodifiableView());
  }

  /// A copy of this creature with [field] of entry [at] in [section] set.
  ///
  /// Fixed-width and therefore cheap: nothing moves, and everything this
  /// project does not understand about the entry survives untouched. It is the
  /// counterpart of [withEntryInserted] — one grows the section, this repairs
  /// what growing it invalidated, which for memorisation rows is a pointer into
  /// a section the insert never touched.
  ///
  /// ⚠️ **[field] must belong to [section]'s own layout.** The stride is
  /// checked, so a field from a wider structure is refused rather than allowed
  /// to write through into the next entry.
  ///
  /// Throws [RangeError] if [at] is outside the section, and [ArgumentError] if
  /// [field] does not fit the entry or [value] does not fit the field.
  Cre withEntryField({
    required CreSection section,
    required int at,
    required FormatField field,
    required int value,
  }) {
    final stride = section.strideIn(this);
    final count = _read(section.countField);
    RangeError.checkValidIndex(at, this, 'at', count);

    if (field.offset + field.length > stride) {
      throw ArgumentError.value(
        '$field',
        'field',
        'ends at ${field.offset + field.length}, past a ${section.name} '
            'entry of $stride bytes',
      );
    }
    if (!field.holds(value)) {
      throw ArgumentError.value(
        value,
        'value',
        '$field accepts ${field.minimum} to ${field.maximum}',
      );
    }

    final at0 = entryStart(section, at) + field.offset;
    final out = Uint8List.fromList(bytes);
    final view = ByteData.sublistView(out);
    switch ((field.length, field.signed)) {
      case (1, false):
        view.setUint8(at0, value);
      case (1, true):
        view.setInt8(at0, value);
      case (2, false):
        view.setUint16(at0, value, Endian.little);
      case (2, true):
        view.setInt16(at0, value, Endian.little);
      case (4, false):
        view.setUint32(at0, value, Endian.little);
      case (4, true):
        view.setInt32(at0, value, Endian.little);
      case _:
        throw InfinityFormatException.unreadableField(
          what: '$field',
          length: field.length,
        );
    }
    return Cre.trusted(out.asUnmodifiableView());
  }

  /// A copy of this creature whose effects are [version] — `0` v1, `1` v2.
  ///
  /// ⚠️ **The one edit here that changes no bytes but changes what the file
  /// means.** [effectVersion] picks the stride of every entry in the effects
  /// section, so writing it while entries exist reinterprets all of them where
  /// they lie — a corruption with no symptom until something reads them.
  ///
  /// It exists because the engine's own template needs it. `CHARBASE` stores
  /// **0** and carries **no effects**; the character BG:EE finishes building
  /// from it stores **1** with 264-byte records. Granting the first proficiency
  /// is where a created character crosses that line, and the crossing is safe
  /// for exactly the reason the template makes it: there is nothing to
  /// reinterpret.
  ///
  /// Throws [ArgumentError] for a version the format does not define, and
  /// [StateError] when this record already holds effects.
  Cre withEffectVersion(int version) {
    if (version != 0 && version != 1) {
      throw ArgumentError.value(
        version,
        'version',
        'a CRE effect version is 0 (v1) or 1 (v2)',
      );
    }
    if (version == effectVersion) return this;
    if (effectsCount != 0) {
      throw StateError(
        'this creature holds $effectsCount effects at '
        '$effectLength bytes each; changing the version to $version would '
        'reinterpret them where they lie rather than convert them',
      );
    }

    final out = Uint8List.fromList(bytes);
    out[CreHeaderField.effectVersion.offset] = version;
    return Cre.trusted(out.asUnmodifiableView());
  }

  /// Whether this creature has a section at [offset] at all.
  ///
  /// **An offset of `0` means absent, not "at the start of the record".** Two
  /// of the 37 creatures in the fixture carry `knownSpellsOffset == 0`, and
  /// several carry `itemsOffset == 0`. This is the same rule that governs the
  /// GAM's party inventory, and doing arithmetic on such an offset is how the
  /// spike computed a stride of −180.
  static bool hasSection(int offset) => offset != 0;

  /// Whether this creature knows any spells.
  bool get hasKnownSpells => hasSection(knownSpellsOffset);

  /// Whether this creature has memorised spells.
  bool get hasMemorizedSpells => hasSection(memorizedSpellsOffset);

  /// Whether this creature carries any items.
  bool get hasItems => hasSection(itemsOffset);

  /// Whether this creature has a slot table at all.
  ///
  /// A created character does: `CHARBASE` is 804 bytes — a 724-byte header plus
  /// the 80-byte table — with every word empty and no items section.
  bool get hasItemSlots => hasSection(itemSlotsOffset);

  /// What the creature is carrying, in the order the section stores them.
  ///
  /// ⚠️ **The index into this list is what a slot word holds**, which is why
  /// removing an item is not simply dropping an entry — see [withItemRemoved].
  ///
  /// Empty when the section is absent, which is an ordinary state: `CHARBASE`
  /// carries no items and several fixture creatures carry `itemsOffset == 0`.
  List<CreItem> get items => [
    for (var i = 0; i < itemsCount; i++)
      if (entryStart(CreSection.items, i) case final int at)
        CreItem(
          resref: decodeFixedString(
            bytes,
            at + CreItemField.resref.offset,
            CreItemField.resref.length,
          ),
          quantity: _readAt(at, CreItemField.quantity1),
          quantity2: _readAt(at, CreItemField.quantity2),
          quantity3: _readAt(at, CreItemField.quantity3),
          expiration: _readAt(at, CreItemField.expiration),
          flags: CreItemFlag.setFrom(_readAt(at, CreItemField.flags)),
          start: at,
        ),
  ];

  /// Which item each occupied slot holds, by index into [items].
  ///
  /// ⚠️ **Reads 38 words, not 40.** The last two are *selected weapon* and
  /// *selected weapon ability*; both hold `0` on the fixtures, which as an item
  /// index would read as "item 0 is equipped here" — twice, in slots that are
  /// not slots.
  ///
  /// Empty slots are omitted rather than mapped to `null`, so a caller iterates
  /// what is there instead of filtering.
  Map<CreItemSlot, int> get itemSlots {
    if (!hasItemSlots) return const {};
    final view = ByteData.sublistView(bytes);
    return {
      for (final slot in CreItemSlot.values)
        if (view.getUint16(itemSlotsOffset + slot.byteOffset, Endian.little)
            case final int word when word != CreItemSlot.empty)
          slot: word,
    };
  }

  /// Which item [slot] holds, or `null` when it is empty.
  int? itemIndexAt(CreItemSlot slot) => itemSlots[slot];

  /// The first backpack slot with nothing in it, or `null` when it is full.
  ///
  /// ⚠️ **Scans rather than counts.** Holes are legal — `Aard1.chr` fills packs
  /// 1–7 and 9, leaving 8 empty — so "the number of items" is not the index of
  /// the next free slot, and using it would overwrite an occupied one.
  CreItemSlot? get firstFreePackSlot {
    final occupied = itemSlots.keys.toSet();
    for (final slot in CreItemSlot.pack) {
      if (!occupied.contains(slot)) return slot;
    }
    return null;
  }

  /// Items no slot points at.
  ///
  /// ⚠️ **Always empty on real data**, and that is the finding: every item in
  /// every fixture is referenced by a slot, so the engine keeps the table
  /// tight. Writing an orphan would be novel behaviour rather than something
  /// the engine is known to tolerate — an item nothing points at exists in the
  /// file and nowhere in the game.
  List<int> get orphanedItems {
    final referenced = itemSlots.values.toSet();
    return [
      for (var i = 0; i < itemsCount; i++)
        if (!referenced.contains(i)) i,
    ];
  }

  /// A copy with [slot] pointing at [itemIndex], or cleared when it is `null`.
  ///
  /// **Fixed-width — exactly one word changes.** The slot table never grows, so
  /// this is as safe as any header edit and works in a savegame with no
  /// relocation.
  ///
  /// Throws [InfinityFormatException] if there is no slot table, and
  /// [RangeError] if [itemIndex] names an item the record does not have — a
  /// slot pointing past the array is how an inventory screen reads somebody
  /// else's bytes.
  Cre withItemSlot(CreItemSlot slot, int? itemIndex) {
    if (!hasItemSlots) {
      throw InfinityFormatException.truncated(
        what: 'no item-slot table to write $slot into',
        expected: creItemSlotsLength,
        actual: 0,
      );
    }
    if (itemIndex != null && (itemIndex < 0 || itemIndex >= itemsCount)) {
      throw RangeError.range(itemIndex, 0, itemsCount - 1, 'itemIndex');
    }
    final copy = Uint8List.fromList(bytes);
    ByteData.sublistView(copy).setUint16(
      itemSlotsOffset + slot.byteOffset,
      itemIndex ?? CreItemSlot.empty,
      Endian.little,
    );
    return Cre.trusted(copy.asUnmodifiableView());
  }

  /// A copy with the item at [index] removed and every slot renumbered.
  ///
  /// ⚠️ **The renumbering is the whole point, and it is the hazard this class
  /// documents for memorisation windows and never documented for items.** Slot
  /// words are *indices into the items array*, so dropping entry `i` leaves
  /// every word above `i` pointing one item too high — a boot in the helmet
  /// slot, or worse, past the end of the array.
  ///
  /// The slot that held it is cleared; slots below it are untouched.
  ///
  /// Throws [RangeError] if [index] is not an item this record holds.
  Cre withItemRemoved(int index) {
    if (index < 0 || index >= itemsCount) {
      throw RangeError.range(index, 0, itemsCount - 1, 'index');
    }
    final at = entryStart(CreSection.items, index);
    final shrunk = Uint8List(bytes.length - creItemLength)
      ..setRange(0, at, bytes)
      ..setRange(at, bytes.length - creItemLength, bytes, at + creItemLength);
    final view = ByteData.sublistView(shrunk)
      ..setUint32(
        CreHeaderField.itemsCount.offset,
        itemsCount - 1,
        Endian.little,
      );

    // Sections after the removed entry move up by one stride, and so does the
    // slot table — the mirror of what `withEntryInserted` does going the other
    // way.
    for (final section in CreSection.all) {
      if (section == CreSection.items) continue;
      final where = _read(section.offsetField);
      if (!hasSection(where) || where < at) continue;
      view.setUint32(
        section.offsetField.offset,
        where - creItemLength,
        Endian.little,
      );
    }
    final slots = itemSlotsOffset;
    final movedSlots = hasSection(slots) && slots >= at
        ? slots - creItemLength
        : slots;
    if (hasSection(slots) && slots >= at) {
      view.setUint32(
        CreHeaderField.itemSlotsOffset.offset,
        movedSlots,
        Endian.little,
      );
    }

    if (hasItemSlots) {
      for (final entry in itemSlots.entries) {
        final word = switch (entry.value) {
          final int i when i == index => CreItemSlot.empty,
          final int i when i > index => i - 1,
          final int i => i,
        };
        view.setUint16(
          movedSlots + entry.key.byteOffset,
          word,
          Endian.little,
        );
      }
    }
    return Cre.trusted(shrunk.asUnmodifiableView());
  }

  /// Where the creature's content ends — its total size, derived.
  ///
  /// Every section is variable-length, so this is computed from the layout
  /// rather than read from a field. On a well-formed creature it equals
  /// [bytes].length exactly, which makes it the strongest single check
  /// available on a CRE: one comparison reconciles all six section pointers,
  /// every entry size, and the effect-version flag.
  ///
  /// Taken as the furthest end over all **present** sections rather than
  /// assuming effects come last — absent sections carry offset `0`, and a
  /// creature with no known spells would otherwise be measured from there.
  ///
  /// **This is also the arithmetic Phase 1's writer must reproduce.** Adding
  /// one item moves everything after it, then the CRE's size in the GAM, then
  /// every GAM offset past that.
  int get contentEnd {
    var end = CreHeaderField.headerSize;
    void consider(int offset, int length) {
      if (!hasSection(offset)) return;
      if (offset + length > end) end = offset + length;
    }

    consider(knownSpellsOffset, knownSpellsCount * creKnownSpellLength);
    consider(
      memorizationInfoOffset,
      memorizationInfoCount * creMemorizationInfoLength,
    );
    consider(
      memorizedSpellsOffset,
      memorizedSpellsCount * creMemorizedSpellLength,
    );
    consider(itemSlotsOffset, creItemSlotsLength);
    consider(itemsOffset, itemsCount * creItemLength);
    consider(effectsOffset, effectsCount * effectLength);
    return end;
  }

  @override
  String toString() =>
      'Cre(${bytes.length} bytes, $itemsCount items, '
      '$effectsCount effects v${effectVersion + 1})';
}
