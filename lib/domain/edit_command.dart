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

import 'package:wand_of_saves/domain/character_stat.dart';

/// One change the player asked for.
///
/// **Sealed**, so the code that turns a command into bytes is an exhaustive
/// `switch` and adding a kind of edit without handling it fails to compile
/// (D5, `context/dart-data-modelling.md` §5). Edits are described rather than
/// performed: a savegame is never mutated, only rebuilt.
sealed class EditCommand {
  /// Creates a command.
  const EditCommand();

  /// What this edit did, phrased for the undo entry.
  String get label;
}

/// Sets one numeric field on one character.
final class SetCharacterStat extends EditCommand {
  /// Sets [stat] to [value] on the creature record at [creOffset].
  const SetCharacterStat({
    required this.creOffset,
    required this.stat,
    required this.value,
  });

  /// Absolute offset of the creature record within the savegame.
  ///
  /// A character is addressed by where they are, not by name: two party
  /// members may legitimately share one.
  final int creOffset;

  /// Which field to write.
  final CharacterStat stat;

  /// The new value.
  final int value;

  @override
  String get label => 'Set ${stat.label} to $value';
}

/// Sets the pip count of a proficiency the character already has.
///
/// Its own command rather than a [CharacterStat] because the value is not a
/// header field: on BG:EE proficiencies are opcode 233 effects, so this
/// patches parameter 1 of one 264-byte record inside the creature. Fixed
/// width, like every edit this build makes — nothing moves.
///
/// ⚠️ **Only a proficiency that already exists.** Granting one from nothing
/// adds an effect, which resizes the creature, which moves its length in the
/// GAM NPC struct and then every GAM offset after it. That is Phase 1's
/// layout pass and it is deliberately not attempted here.
final class SetProficiency extends EditCommand {
  /// Sets the effect at [effectOffset] to grant [pips].
  const SetProficiency({
    required this.creOffset,
    required this.effectOffset,
    required this.proficiencyId,
    required this.pips,
  });

  /// Absolute offset of the creature record within the savegame.
  final int creOffset;

  /// Offset of the effect record, relative to the start of the creature.
  ///
  /// Carried rather than derived. The alternative is to find the effect by
  /// scanning for [proficiencyId], which needs the savegame the command is
  /// about to be applied to — and a command that reads the file is no longer
  /// a description of an edit.
  final int effectOffset;

  /// Which proficiency, as opcode 233 stores it in parameter 2.
  ///
  /// Not needed to write the bytes; carried so the undo entry can say what
  /// changed and so a mismatch is visible when debugging.
  final int proficiencyId;

  /// The new pip count.
  final int pips;

  /// What this edit did.
  ///
  /// Names the proficiency by number, because naming it properly needs the
  /// player's own `weapprof.2da` and a domain command must not reach for a
  /// data source.
  @override
  String get label => 'Set proficiency $proficiencyId to $pips';
}

/// Sets the shared party purse.
///
/// Its own command rather than a [CharacterStat]: the purse lives in the GAM
/// header and belongs to the party, not to anyone in it.
final class SetPartyGold extends EditCommand {
  /// Sets the shared purse to [value].
  const SetPartyGold(this.value);

  /// The new amount.
  final int value;

  @override
  String get label => 'Set party gold to $value';
}

/// Thrown when a command carries a value the field it targets will not accept.
///
/// A domain failure rather than a codec one: the bytes are fine, the *request*
/// is not. The UI checks ranges before building a command, so reaching this
/// means something upstream skipped that — which is exactly why it is loud.
class InvalidEditException implements Exception {
  /// Records that [value] is not acceptable for [what].
  const InvalidEditException({
    required this.what,
    required this.value,
    required this.minimum,
    required this.maximum,
  });

  /// What was being set.
  final String what;

  /// The value that was refused.
  final int value;

  /// The lowest acceptable value.
  final int minimum;

  /// The highest acceptable value.
  final int maximum;

  @override
  String toString() =>
      'InvalidEditException: $value is not a valid $what '
      '(accepts $minimum to $maximum)';
}
