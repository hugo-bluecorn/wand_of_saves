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

/// Turns an [EditCommand] into bytes.
///
/// The one place a domain command meets the format. It lives in the data layer
/// because it knows the codecs; the commands themselves know only domain
/// concepts, so nothing in `lib/ui/` needs to.
///
/// **Two entry points, and the smaller one is the general one.**
/// [applyCharacterEdit] works on anything holding a creature record, which is
/// both documents this app opens; [applyEdit] adds the handful of edits that
/// only a savegame can take.
library;

import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/domain/edit_command.dart';

/// [document] with [command] applied, as a new document of the same kind.
///
/// **Generic over [CreatureDocument]**, so one implementation serves a savegame
/// and an exported character alike — they wrap the same creature record, and an
/// edit that behaved differently in one of them would reach the user as "that
/// field only works when I open the save".
///
/// The type parameter is the concrete document rather than the interface, so
/// editing a `Chr` yields a `Chr` and an editor's undo stack stays a
/// `List<Chr>`.
///
/// Never mutates: the result is a patched copy, and everything this project
/// does not understand about the file survives untouched.
///
/// The `switch` is **exhaustive over a sealed hierarchy**, so a new kind of
/// character edit does not compile until it is handled here.
///
/// Throws [InvalidEditException] if the value is outside what the stat
/// accepts. The check is here rather than only at the format boundary because
/// the field is the looser gate of the two: a Strength of 200 fits its byte.
T applyCharacterEdit<T extends CreatureDocument<T>>(
  T document,
  CharacterEditCommand command,
) => switch (command) {
  SetCharacterStat(:final creOffset, :final stat, :final value) => () {
    if (!stat.holds(value)) {
      throw InvalidEditException(
        what: stat.label,
        value: value,
        minimum: stat.minimum,
        maximum: stat.maximum,
      );
    }
    return document.withCreatureField(
      creOffset: creOffset,
      field: stat.field,
      value: value,
    );
  }(),
  // ⚠️ **The two that resize.** Both go through `Cre.withEntryAppended`, which
  // creates the section when it is absent — `CHARBASE` has neither — and then
  // through `withCreature`, which relocates in a savegame and patches one
  // pointer in a `.chr`.
  GrantProficiency(:final creOffset, :final proficiencyId, :final pips) => () {
    if (!EffectV2Field.parameter1.holds(pips)) {
      throw InvalidEditException(
        what: 'proficiency $proficiencyId',
        value: pips,
        minimum: EffectV2Field.parameter1.minimum,
        maximum: EffectV2Field.parameter1.maximum,
      );
    }
    final creature = CreCodec.decode(document.creatureAt(creOffset));
    final effect = proficiencyEffectTemplate();
    ByteData.sublistView(effect)
      ..setUint32(EffectV2Field.parameter1.offset, pips, Endian.little)
      ..setUint32(
        EffectV2Field.parameter2.offset,
        proficiencyId,
        Endian.little,
      );

    return document.withCreature(
      creOffset: creOffset,
      // ⚠️ **The version comes first, and a created character needs it.**
      // `CHARBASE` arrives claiming 48-byte v1 effects while carrying none;
      // the character the engine finishes building from it stores v2, which is
      // what `proficiencyEffectTemplate` writes. Without this the very first
      // proficiency granted to a new character is refused outright — and the
      // suite could not see it, because the synthetic record wrote v2 always.
      // `withEffectVersion` refuses rather than converts once effects exist, so
      // this can only ever fire on a record with nothing to reinterpret.
      creature: creature
          .withEffectVersion(1)
          .withEntryAppended(section: CreSection.effects, entry: effect),
    );
  }(),
  // ⚠️ **Where the entry goes is not the caller's business, and used to be.**
  // This composed `withEntryAppended` with `withItemSlot`, which is right only
  // when [slot] sits above every occupied one — into a hole it writes an
  // inversion the engine never produces. `withItemAdded` owns the ordered
  // position and the renumbering above it, the way `withItemRemoved` has always
  // owned the renumbering below.
  AddItem(
    :final creOffset,
    :final resref,
    :final slot,
    :final quantity,
  ) =>
    document.withCreature(
      creOffset: creOffset,
      creature:
          CreCodec.decode(
            document.creatureAt(creOffset),
          ).withItemAdded(
            entry: itemEntry(resref: resref, quantity: quantity),
            slot: slot,
          ),
    ),

  LearnSpell(:final creOffset, :final resref, :final level, :final type) => () {
    final creature = CreCodec.decode(document.creatureAt(creOffset));

    return document.withCreature(
      creOffset: creOffset,
      creature: creature.withEntryAppended(
        section: CreSection.knownSpells,
        // The "Spell Level -1" arithmetic lives in the builder, once.
        entry: knownSpellEntry(
          resref: resref,
          level: level,
          type: type.stored,
        ),
      ),
    );
  }(),
  MemoriseSpell(
    :final creOffset,
    :final resref,
    :final level,
    :final type,
    :final memorisable,
  ) =>
    () {
      var creature = CreCodec.decode(document.creatureAt(creOffset));

      // The window this spell belongs to, opened if the character has none.
      // ⚠️ A new row starts at the **end** of the memorised array, which is
      // what leaves every window already there pointing where it did.
      var row = creature.memorizations.indexWhere(
        (r) => r.level == level && r.type == type.stored,
      );
      if (row < 0) {
        creature = creature.withEntryAppended(
          section: CreSection.memorizationInfo,
          entry: memorizationRowEntry(
            level: level,
            type: type.stored,
            memorisable: memorisable,
            firstIndex: creature.memorizedSpellsCount,
          ),
        );
        row = creature.memorizationInfoCount - 1;
      }

      final window = creature.memorizations[row];
      final insertAt = window.firstIndex + window.count;
      creature = creature.withEntryInserted(
        section: CreSection.memorizedSpells,
        at: insertAt,
        entry: memorizedSpellEntry(resref: resref),
      );

      creature = creature
          .withEntryField(
            section: CreSection.memorizationInfo,
            at: row,
            field: CreMemorizationField.count,
            value: window.count + 1,
          )
          .withEntryField(
            section: CreSection.memorizationInfo,
            at: row,
            field: CreMemorizationField.memorisable,
            value: memorisable,
          )
          .withEntryField(
            section: CreSection.memorizationInfo,
            at: row,
            field: CreMemorizationField.afterEffects,
            value: memorisable,
          );

      // ⚠️ **The part `withEntryInserted` cannot do for itself.** Every window
      // after this one begins one entry later than it did. Rows are checked on
      // *both* their position and their index: on the engine's own characters
      // the two agree — each row starts where the ones before it end — and a
      // record where they disagree is one this must not make worse.
      for (var i = row + 1; i < creature.memorizationInfoCount; i++) {
        final other = creature.memorizations[i];
        if (other.firstIndex < insertAt) continue;
        creature = creature.withEntryField(
          section: CreSection.memorizationInfo,
          at: i,
          field: CreMemorizationField.firstIndex,
          value: other.firstIndex + 1,
        );
      }

      return document.withCreature(creOffset: creOffset, creature: creature);
    }(),
  SetCharacterIdentity(:final creOffset, :final identity, :final value) => () {
    // The field's bound, not the game's. Which classes an elf may take lives
    // in the player's `clsrcreq.2da` and is settled before a command is built
    // — the same division `SetProficiency` makes just below.
    if (!identity.holds(value)) {
      throw InvalidEditException(
        what: identity.label,
        value: value,
        minimum: identity.field.minimum,
        maximum: identity.field.maximum,
      );
    }
    return document.withCreatureField(
      creOffset: creOffset,
      field: identity.field,
      value: value,
    );
  }(),
  SetProficiency(
    :final creOffset,
    :final effectOffset,
    :final proficiencyId,
    :final pips,
  ) =>
    () {
      // No game-rules cap belongs here: IESDP states no range for opcode
      // 233's Amount, and the per-class ceiling lives in the player's own
      // `weapprof.2da`, which the panel consults. This is the field's bound,
      // stated in domain terms so the failure reads the same as any other.
      if (!EffectV2Field.parameter1.holds(pips)) {
        throw InvalidEditException(
          what: 'proficiency $proficiencyId',
          value: pips,
          minimum: EffectV2Field.parameter1.minimum,
          maximum: EffectV2Field.parameter1.maximum,
        );
      }
      return document.withEffectField(
        creOffset: creOffset,
        effectStart: effectOffset,
        field: EffectV2Field.parameter1,
        value: pips,
      );
    }(),
  SetClassLevels(:final creOffset, :final levels) => () {
    // ⚠️ Every slot is written, not only the ones in use. A record whose
    // second slot still holds the template's value reads as a multi-class the
    // character is not, and `classCount` would then disagree with the bytes.
    const fields = [
      CreHeaderField.levelFirstClass,
      CreHeaderField.levelSecondClass,
      CreHeaderField.levelThirdClass,
    ];
    if (levels.length > fields.length) {
      throw InvalidEditException(
        what: 'the class levels',
        value: levels.length,
        minimum: 0,
        maximum: fields.length,
      );
    }

    var updated = document;
    for (var slot = 0; slot < fields.length; slot++) {
      final level = slot < levels.length ? levels[slot] : 0;
      if (!fields[slot].holds(level)) {
        throw InvalidEditException(
          what: 'a class level',
          value: level,
          minimum: fields[slot].minimum,
          maximum: fields[slot].maximum,
        );
      }
      updated = updated.withCreatureField(
        creOffset: creOffset,
        field: fields[slot],
        value: level,
      );
    }
    return updated;
  }(),
  SetPortrait(:final creOffset, :final baseName) => () {
    // ⚠️ Checked here rather than left to the codec, because the codec sees
    // the *suffixed* resref and would report a limit of 8 for a name the
    // player typed at 7. The bound is the base name's, and it comes from the
    // game's own naming: base plus one letter must fit an 8-byte field.
    if (baseName.length > SetPortrait.baseNameLimit) {
      throw InvalidEditException(
        what: 'a portrait name',
        value: baseName.length,
        minimum: 0,
        maximum: SetPortrait.baseNameLimit,
      );
    }
    final portrait = SetPortrait(creOffset: creOffset, baseName: baseName);
    return document
        .withCreatureText(
          creOffset: creOffset,
          field: CreHeaderField.portraitMedium,
          value: portrait.medium,
        )
        .withCreatureText(
          creOffset: creOffset,
          field: CreHeaderField.portraitLarge,
          value: portrait.large,
        );
  }(),
};

/// [gam] with [command] applied, as a new savegame.
///
/// Every character edit is handed straight to [applyCharacterEdit], so there is
/// exactly one implementation of what an edit does to a creature record. What
/// is left here is what only a savegame has.
Gam applyEdit(Gam gam, EditCommand command) => switch (command) {
  final CharacterEditCommand edit => applyCharacterEdit(gam, edit),
  SetPartyGold(:final value) => () {
    if (!GamHeaderField.partyGold.holds(value)) {
      throw InvalidEditException(
        what: 'party gold',
        value: value,
        minimum: GamHeaderField.partyGold.minimum,
        maximum: GamHeaderField.partyGold.maximum,
      );
    }
    return gam.withPartyGold(value);
  }(),
  MoveItem(:final from, :final to, :final itemIndex, :final resref) => () {
    if (from == to) {
      throw ArgumentError.value(to, 'to', 'already holds it');
    }
    RangeError.checkValidIndex(from, gam.partyMembers, 'from');
    RangeError.checkValidIndex(to, gam.partyMembers, 'to');

    final sourceOffset = gam.partyMembers[from].creOffset;
    final source = CreCodec.decode(gam.creatureAt(sourceOffset));
    RangeError.checkValidIndex(itemIndex, source.items, 'itemIndex');

    final item = source.items[itemIndex];
    // ⚠️ The index is positional and shifts under any earlier removal, so the
    // resref is what catches a command built from a list that has moved on.
    if (item.resref != resref) {
      throw ArgumentError.value(
        itemIndex,
        'itemIndex',
        'holds ${item.resref}, not $resref',
      );
    }

    // ⚠️ Backpack only. Equipment is not modelled, and unequipping would change
    // a stored armour class the engine reads rather than recomputes.
    final held = source.itemSlots.entries
        .where((slot) => slot.value == itemIndex)
        .map((slot) => slot.key)
        .firstOrNull;
    if (held == null || !held.isPack) {
      throw ArgumentError.value(
        itemIndex,
        'itemIndex',
        'is not in a backpack slot',
      );
    }

    // ⚠️ **The entry's own bytes, copied.** Rebuilding it through `itemEntry`
    // would quietly drop the second and third charge counts and the expiration
    // — and preserving what this project does not model is a rule, not a
    // nicety.
    final entry = Uint8List.fromList(
      source.bytes.sublist(item.start, item.start + creItemLength),
    );

    final shrunk = gam.withCreature(
      creOffset: sourceOffset,
      creature: source.withItemRemoved(itemIndex),
    );

    // ⚠️ **Re-read, and this line is why the command takes positions.** The
    // removal above moved every record after the source, so the offset this
    // needs did not exist when the command was built.
    final destinationOffset = shrunk.partyMembers[to].creOffset;
    final destination = CreCodec.decode(shrunk.creatureAt(destinationOffset));

    final free = destination.firstFreePackSlot;
    if (free == null) {
      throw ArgumentError.value(to, 'to', 'has no free backpack slot');
    }

    return shrunk.withCreature(
      creOffset: destinationOffset,
      creature: destination.withItemAdded(entry: entry, slot: free),
    );
  }(),
};
