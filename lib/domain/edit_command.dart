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

/// An edit to one character, which **either document can accept**.
///
/// The application opens two kinds of file — a savegame and an exported
/// character — and both wrap the same `CRE V1.0` record. Every edit in this
/// subtree names a creature by [creOffset] and touches only bytes inside it, so
/// it means the same thing whichever file it is applied to.
/// `applyCharacterEdit` is generic over exactly this.
///
/// ⚠️ **The split is what keeps a `.chr` from being handed a savegame edit.**
/// `SetPartyGold` deliberately sits outside: a character file has no party, and
/// a document that had to throw `UnsupportedError` at run time would be the
/// very bug a sealed hierarchy exists to catch at compile time.
sealed class CharacterEditCommand extends EditCommand {
  /// Creates a character edit.
  const CharacterEditCommand();

  /// Where the creature record starts **within the file being edited**.
  ///
  /// An absolute position in a savegame, and the CHR header's own offset in an
  /// exported character. A character is addressed by where they are, not by
  /// name: two party members may legitimately share one.
  int get creOffset;
}

/// Sets one numeric field on one character.
final class SetCharacterStat extends CharacterEditCommand {
  /// Sets [stat] to [value] on the creature record at [creOffset].
  const SetCharacterStat({
    required this.creOffset,
    required this.stat,
    required this.value,
  });

  @override
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
final class SetProficiency extends CharacterEditCommand {
  /// Sets the effect at [effectOffset] to grant [pips].
  const SetProficiency({
    required this.creOffset,
    required this.effectOffset,
    required this.proficiencyId,
    required this.pips,
  });

  @override
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

/// Sets which portrait a character uses.
///
/// **The first edit that writes text rather than a number.** A portrait is
/// named by an 8-byte resref in two fields — the `…M` variant the sheet shows
/// and the `…L` variant — and both are written together, because a character
/// with mismatched pictures is one the game draws inconsistently.
///
/// ⚠️ **Fixed-width, so it is as safe as a pip edit.** The two fields exactly
/// fill the gap the spec leaves between `effectVersion` and `reputation`;
/// nothing resizes and the layout pass is not involved.
///
/// The base name carries no `L`/`M`/`S` suffix — [medium] and [large] are
/// derived from it — because that is how the game names a portrait: one base,
/// three variants, and the CRE references two of them.
final class SetPortrait extends CharacterEditCommand {
  /// Points the character at the portrait called [baseName].
  const SetPortrait({required this.creOffset, required this.baseName});

  @override
  final int creOffset;

  /// The longest a portrait's base name may be.
  ///
  /// Seven, so the `L`/`M`/`S` variant suffix fits an 8-byte resref. Measured
  /// across all 210 portraits the game ships: every one that is part of a
  /// triple has a base of seven characters or fewer.
  ///
  /// **The only hard requirement a portrait has to meet.** Depth, compression
  /// and dimensions are all reported and allowed, because the game's own
  /// portraits include eleven off-size ones, a 32-bit one and an 8-bit one — a
  /// check stricter than the engine refuses files the engine would draw.
  static const int baseNameLimit = 7;

  /// The portrait's base name, e.g. `AJANTIS`, with no variant suffix.
  ///
  /// At most seven characters, so the suffix fits an 8-byte resref. Empty
  /// clears both fields, which is how "no portrait" is written.
  final String baseName;

  /// The resref of the medium variant — what the sheet shows.
  String get medium => baseName.isEmpty ? '' : '${baseName}M';

  /// The resref of the large variant.
  String get large => baseName.isEmpty ? '' : '${baseName}L';

  @override
  String get label =>
      baseName.isEmpty ? 'Clear the portrait' : 'Set the portrait to $baseName';
}

/// Sets the shared party purse.
///
/// Its own command rather than a [CharacterStat]: the purse lives in the GAM
/// header and belongs to the party, not to anyone in it.
///
/// ⚠️ **Outside [CharacterEditCommand], and that is the point.** An exported
/// character has no party purse, so this must not be applicable to one — and
/// the type system is where that is said, not a run-time refusal.
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
