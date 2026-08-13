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
import 'package:wand_of_saves/domain/character_identity.dart';
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

/// Sets one identity field — who the character is, rather than how good.
///
/// Its own command rather than a [CharacterStat] entry, for the reason
/// [CharacterIdentity] exists at all: **the legal values are an enumeration,
/// not a range.** Race 4 is `DWARF` and race 5 is `HALFLING`; neither is more
/// than the other, and a sheet that offered a spinner for them would be lying
/// about what the field is.
///
/// ⚠️ **Fixed-width, so it is as safe as a stat edit.** Four of the five fields
/// are a single byte and the fifth is a dword; nothing resizes and the layout
/// pass is not involved.
///
/// [value] is what the record stores, unshifted. For [CharacterIdentity.kit]
/// that is the whole dword with the `KIT.IDS` key in its high word — turning a
/// chosen specialisation into that number needs the player's `kitlist.2da`, and
/// a command must not reach for a data source.
final class SetCharacterIdentity extends CharacterEditCommand {
  /// Sets [identity] to [value] on the creature record at [creOffset].
  const SetCharacterIdentity({
    required this.creOffset,
    required this.identity,
    required this.value,
  });

  @override
  final int creOffset;

  /// Which field to write.
  final CharacterIdentity identity;

  /// The new value, exactly as the record stores it.
  final int value;

  /// What this edit did.
  ///
  /// Names the field and the stored number, not the race. Saying "Elf" needs
  /// `RACE.IDS` and, for a kit, the player's own `kitlist.2da` — the same
  /// reason [SetProficiency] names its proficiency by number.
  @override
  String get label => 'Set ${identity.label} to $value';
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

/// Sets the character's level in each of their classes.
///
/// **Its own command rather than three [CharacterStat] entries**, because it is
/// one fact about a character rather than three numbers: a Fighter/Mage has two
/// levels and a Thief has one, and the slots past the class count are not
/// smaller levels but *absent* ones.
///
/// ⚠️ **The bytes cannot say how many slots are in use.** A savegame leaves the
/// unused ones holding `1` in every shipped NPC record and `0` in the player's
/// own, so `CLASS.IDS` is what the count comes from. This command is given the
/// levels already resolved, and writes `0` to every slot beyond them — which is
/// what the protagonist's own record holds.
///
/// Fixed-width: three single bytes, nothing resizes.
final class SetClassLevels extends CharacterEditCommand {
  /// Sets the creature at [creOffset] to [levels], one per class.
  const SetClassLevels({required this.creOffset, required this.levels});

  @override
  final int creOffset;

  /// The level in each class, in `CLASS.IDS` order — `[2, 1]` is a Fighter 2 /
  /// Mage 1. Anything past the end is written as `0`.
  final List<int> levels;

  /// How many level slots the record has.
  ///
  /// Three, and it is a fact about the format rather than about any character:
  /// `CLASS.IDS` names no class with four parts.
  static const int slots = 3;

  @override
  String get label => 'Set the class levels to ${levels.join('/')}';
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

/// How a spell is filed in a creature's book.
///
/// The word in the record, from IESDP's known-spell entry: `0` priest,
/// `1` wizard, `2` innate.
enum SpellType {
  /// A cleric's or druid's.
  priest(0),

  /// A mage's or bard's.
  wizard(1),

  /// A racial or class ability rather than a memorised spell.
  innate(2);

  const SpellType(this.stored);

  /// What the record stores.
  final int stored;
}

/// Grants a proficiency the character does not have.
///
/// ⚠️ **The first edit in this project that makes a record bigger**, and it
/// exists because a created character is otherwise stuck: `CHARBASE` carries
/// **zero** effects, so [SetProficiency] — which raises a pip already in the
/// record — has nothing to raise.
///
/// On BG:EE a proficiency is a 264-byte opcode 233 effect, so granting one adds
/// an entry to the effects section and moves everything after it.
///
/// ⚠️ **A savegame took this from 2026-08-12.** Growing a record inside a save
/// moves 43 pointers against a `.chr`'s one, which is why creation still writes
/// a character file — but it is no longer a refusal.
final class GrantProficiency extends CharacterEditCommand {
  /// Grants [proficiencyId] at [pips] to the creature at [creOffset].
  const GrantProficiency({
    required this.creOffset,
    required this.proficiencyId,
    required this.pips,
  });

  @override
  final int creOffset;

  /// Which proficiency, as `weapprof.2da` numbers it.
  final int proficiencyId;

  /// How many pips to grant.
  final int pips;

  @override
  String get label => 'Grant proficiency $proficiencyId at $pips';
}

/// Puts a spell in the character's book.
///
/// Adds a 12-byte entry to the known-spells section, which `CHARBASE` also does
/// not have — so this creates it.
final class LearnSpell extends CharacterEditCommand {
  /// Teaches [resref] at [level] to the creature at [creOffset].
  const LearnSpell({
    required this.creOffset,
    required this.resref,
    required this.level,
    required this.type,
  });

  @override
  final int creOffset;

  /// The `SPL` resource, e.g. `SPWI112` for Magic Missile.
  final String resref;

  /// The spell's level, as a player counts it — 1 for a first-level spell.
  ///
  /// ⚠️ **The record stores this less one**, which the writer handles. IESDP
  /// labels the field "Spell Level -1" and a book full of level-0 spells is
  /// what happens when that is missed.
  final int level;

  /// Priest, wizard or innate.
  final SpellType type;

  @override
  String get label => 'Learn $resref';
}

/// Prepares a spell the character already knows.
///
/// ⚠️ **The only edit here that touches two sections at once**, and the reason
/// is in the format: a memorisation row names a *window* of the memorised-spell
/// array by index and length, so preparing a spell inserts into one section and
/// repairs pointers in another. Adding it at the end instead would file it
/// under whichever window happens to run last.
///
/// `CHARBASE` has neither section, so this creates both — the row first, opened
/// at the end of the array where it disturbs nothing.
final class MemoriseSpell extends CharacterEditCommand {
  /// Prepares [resref] at [level] for the creature at [creOffset].
  const MemoriseSpell({
    required this.creOffset,
    required this.resref,
    required this.level,
    required this.type,
    required this.memorisable,
  });

  @override
  final int creOffset;

  /// The `SPL` resource, e.g. `SPWI112` for Magic Missile.
  final String resref;

  /// The spell's level, as a player counts it — 1 for a first-level spell.
  final int level;

  /// Priest, wizard or innate. With [level] it picks the window.
  final SpellType type;

  /// How many spells of this level and type the character may prepare.
  ///
  /// ⚠️ **Carried rather than computed, and that is deliberate.** The number
  /// comes from the player's own `mxsplwiz.2da` and depends on class and level;
  /// a command that worked it out would be reaching for a data source, which is
  /// the same line [SetProficiency] draws around its per-class pip ceiling.
  ///
  /// It is written to the row whether the row is new or not, so a caller that
  /// knows the character's slots keeps the record saying the same thing twice.
  final int memorisable;

  @override
  String get label => 'Memorise $resref';
}

/// Puts an item the game ships into a character's inventory.
///
/// ⚠️ **Two writes, and the second is what makes it visible.** Appending the
/// 20-byte entry puts the item in the file; writing [slot] is what puts it in
/// the game. Every engine-written record references every item from a slot —
/// measured across 18 of them — so an item nothing points at would be this
/// application inventing a shape the engine has never produced.
///
/// ⚠️ **[slot] is resolved by the caller**, not chosen here. Finding the first
/// free backpack slot means reading the record, and a command that reads the
/// file it is about to change is no longer a description of an edit — the same
/// line [SetProficiency] draws around `effectOffset` and [MemoriseSpell] around
/// `memorisable`.
///
/// This resizes, so before the GAM relocation shipped it would have been a
/// `.chr`-only edit. It is not any more.
final class AddItem extends CharacterEditCommand {
  /// Gives the creature at [creOffset] the item [resref], in [slot].
  const AddItem({
    required this.creOffset,
    required this.resref,
    required this.slot,
    this.quantity = 1,
  });

  @override
  final int creOffset;

  /// The `ITM` resource, e.g. `BOOT01`.
  ///
  /// ⚠️ **The key, and the only one.** Four items resolve to the name "The Paws
  /// of the Cheetah"; nothing but the resref tells them apart.
  final String resref;

  /// Where it goes.
  final CreItemSlot slot;

  /// How many, for something that stacks.
  final int quantity;

  /// What this edit did.
  ///
  /// Names the item by resref, because naming it properly needs the archives
  /// and the player's own talk table — which a domain command must not reach
  /// for.
  @override
  String get label => 'Add $resref';
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
