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
/// because it knows `Gam`; the commands themselves know only domain concepts,
/// so nothing in `lib/ui/` needs to.
library;

import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/domain/edit_command.dart';

/// [gam] with [command] applied, as a new savegame.
///
/// Never mutates: the result is a patched copy, and everything this project
/// does not understand about the file survives untouched.
///
/// The `switch` is **exhaustive over a sealed hierarchy**, so a new kind of
/// edit does not compile until it is handled here — which is the whole reason
/// commands are sealed rather than a bag of closures.
///
/// Throws [InvalidEditException] if the value is outside what the stat
/// accepts. The check is here rather than only at the format boundary because
/// the field is the looser gate of the two: a Strength of 200 fits its byte.
Gam applyEdit(Gam gam, EditCommand command) => switch (command) {
  SetCharacterStat(:final creOffset, :final stat, :final value) => () {
    if (!stat.holds(value)) {
      throw InvalidEditException(
        what: stat.label,
        value: value,
        minimum: stat.minimum,
        maximum: stat.maximum,
      );
    }
    return gam.withCreatureField(
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
      return gam.withEffectField(
        creOffset: creOffset,
        effectStart: effectOffset,
        field: EffectV2Field.parameter1,
        value: pips,
      );
    }(),
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
