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

import 'package:infinity_formats/src/spec/format_field.dart';

/// Bytes of `SPL V1` header, before the first extended header.
///
/// IESDP: "Header:Size=114 Bytes".
const int splHeaderLength = 114;

/// The fields of an `SPL V1` header this project reads.
///
/// **A verified subset**, so the layout check runs without a struct size — the
/// gaps between these are real fields nothing here needs, and the exact-fit
/// rule would be wrong to apply.
///
/// Offsets read from `../iesdp/_data/file_formats/spl_v1/header.yml`, whose own
/// anchors name three of them: `splv1_Header_0x8`, `splv1_Header_0x1C` and
/// `splv1_Header_0x34`.
enum SplHeaderField implements FormatField {
  /// Strref of the displayed name. **Signed** — `-1` means the spell has none.
  ///
  /// ⚠️ **That is the field that separates a spell from an internal.** 108 of
  /// the installation's `SPL` files claim to be first-level wizard spells;
  /// eighty-six of them carry `-1` here and are engine plumbing.
  name(0x08, 4, signed: true),

  /// What kind of spell this is — see [SplType].
  spellType(0x1c, 2),

  /// The school, as `mschool.2da` numbers them. `0` is none.
  school(0x25, 1),

  /// The spell's level, as a player counts it.
  ///
  /// ⚠️ **Nothing is subtracted here**, unlike the creature record's own
  /// known-spell entry, which stores the level less one. Two structures a few
  /// hundred bytes apart that disagree about what "level" means.
  level(0x34, 4),

  /// Strref of the description shown beside the name.
  description(0x50, 4, signed: true);

  const SplHeaderField(this.offset, this.length, {this.signed = false});

  @override
  final int offset;

  @override
  final int length;

  @override
  final bool signed;
}

/// What kind of spell an `SPL` header declares.
///
/// ⚠️ **Not the numbering a creature's known-spell entry uses.** There,
/// `0` is priest, `1` wizard and `2` innate; here `1` is wizard, `2` priest and
/// `4` innate. The two agree on exactly one value — wizard — which is the worst
/// possible overlap, because a mistake is invisible on the one case anybody
/// tests first.
enum SplType {
  /// Cast with no school and no spellbook.
  special(0),

  /// A mage's or bard's.
  wizard(1),

  /// A cleric's or druid's.
  priest(2),

  /// Psionic. Treated as innate by the engine.
  psionic(3),

  /// A racial or class ability.
  innate(4),

  /// A bard song.
  bardSong(5);

  const SplType(this.stored);

  /// What the header stores.
  final int stored;

  /// The type [stored] names, or `null` for a value the format does not define.
  ///
  /// IESDP says every value from 6 up behaves as [psionic]; `null` says
  /// plainly that this is not one of the six rather than guessing which.
  static SplType? forStored(int stored) {
    for (final type in values) {
      if (type.stored == stored) return type;
    }
    return null;
  }
}
