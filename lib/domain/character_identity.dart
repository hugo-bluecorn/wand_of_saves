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

import 'package:infinity_formats/infinity_formats.dart';

/// A field saying who a character *is*, rather than how good they are at it.
///
/// **The counterpart of `CharacterStat`, and separate from it on purpose.** A
/// stat is a number on a range — Strength runs 1 to 25, and every value in
/// between is meaningful. An identity is an **enumeration**: race 4 is `DWARF`
/// and race 5 is `HALFLING`, and nothing about 4 makes it *less* than 5.
/// Folding these into `CharacterStat` would put a numeric spinner for Race on
/// the character sheet, which is why they are their own table and their own
/// command.
///
/// Each value carries its [CreHeaderField] rather than restating an offset, so
/// there is still exactly one table of layout facts (D6).
enum CharacterIdentity {
  /// Gender (`GENDER.IDS`). `1` is `MALE`.
  ///
  /// ⚠️ **The table has eight values and only two are people.** `OTHER`,
  /// `NIETHER` (the game's spelling), `BOTH`, `SUMMONED`, `ILLUSIONARY` and
  /// `EXTRA` are engine categories for things that are not player characters.
  /// What a creation flow
  /// may offer is the two the game's own gender screen shows —
  /// `docs/findings/screens/char-create/02-gender.png` — and that is the
  /// catalogue's business, not this enum's.
  gender(CreHeaderField.gender, 'Gender'),

  /// Race (`RACE.IDS`). `2` is `ELF`.
  ///
  /// The playable seven are the *columns* of the player's own `clsrcreq.2da`,
  /// which is a fact about their installation rather than about this field.
  race(CreHeaderField.race, 'Race'),

  /// Class (`CLASS.IDS`). `7` is `FIGHTER_MAGE`.
  ///
  /// Named to match `CreHeaderField.characterClass`, which is named around
  /// `class` being a Dart keyword.
  characterClass(CreHeaderField.characterClass, 'Class'),

  /// Alignment (`ALIGNMEN.IDS`). `0x21` is `NEUTRAL_GOOD`.
  ///
  /// ⚠️ **That table is written in hex** where `CLASS.IDS` and `RACE.IDS` are
  /// decimal, so the stored byte 33 reads as `0x21`.
  alignment(CreHeaderField.alignment, 'Alignment'),

  /// Specialisation — a kit (`KIT.IDS`), stored as a **dword**.
  ///
  /// ⚠️ **The key lives in the high word**, so a stored `0x10000000` is
  /// `0x1000`, `MAGESCHOOL_NECROMANCER`. Both `0x40000000` (`TRUECLASS`) and
  /// plain `0` mean no kit. Settled 2026-08-08 against a four-member party.
  ///
  /// This field is reported and written **raw**. Which dword a specialisation
  /// means comes from the player's `kitlist.2da`, and turning one into the
  /// other is the catalogue's job — a command that had to shift would be one
  /// that knew a rules table.
  kit(CreHeaderField.kit, 'Specialisation');

  const CharacterIdentity(this.field, this.label);

  /// The creature-record field this identity is stored in.
  final CreHeaderField field;

  /// What to call it on screen.
  final String label;

  /// Whether [value] is one this field can physically hold.
  ///
  /// ⚠️ **Deliberately only the field's bound, not the game's.** Which races
  /// may be a Paladin is in the player's `clsrcreq.2da`, and a command must
  /// not reach for a data source — the same line `SetProficiency` already draws
  /// for its per-class pip ceiling. The flow that offers the choice is what
  /// keeps an illegal one from ever being built.
  bool holds(int value) => value >= field.minimum && value <= field.maximum;
}
