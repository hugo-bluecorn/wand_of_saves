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
  SetPortrait(:final creOffset, :final baseName) => () {
    // ⚠️ Checked here rather than left to the codec, because the codec sees
    // the *suffixed* resref and would report a limit of 8 for a name the
    // player typed at 7. The bound is the base name's, and it comes from the
    // game's own naming: base plus one letter must fit an 8-byte field.
    if (baseName.length > portraitBaseNameLimit) {
      throw InvalidEditException(
        what: 'a portrait name',
        value: baseName.length,
        minimum: 0,
        maximum: portraitBaseNameLimit,
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

/// The longest a portrait's base name may be.
///
/// Seven, so the `L`/`M`/`S` variant suffix fits an 8-byte resref. Measured
/// across all 210 portraits the game ships: every one that is part of a triple
/// has a base of seven characters or fewer.
const int portraitBaseNameLimit = 7;

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
};
