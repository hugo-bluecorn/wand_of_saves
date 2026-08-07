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
