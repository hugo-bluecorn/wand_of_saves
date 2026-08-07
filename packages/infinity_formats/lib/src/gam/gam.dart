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

import 'package:infinity_formats/src/exceptions.dart';
import 'package:infinity_formats/src/gam/gam_npc.dart';
import 'package:infinity_formats/src/spec/gam_v2_0.dart';
import 'package:infinity_formats/src/text/fixed_field.dart';

/// A parsed BG:EE savegame — `BALDUR.gam`.
///
/// **The bytes are the model.** Every accessor reads through [bytes] rather
/// than caching a parsed copy, which removes a whole class of bug: there is no
/// second representation to drift out of step with the file. An edit produces
/// a *new* `Gam` over a patched copy of the buffer, so the "preserve unknown
/// bytes" rule holds by construction instead of by diligence — nothing is ever
/// regenerated from fields the model happens to understand.
///
/// [bytes] is an unmodifiable view, so that guarantee is enforced rather than
/// documented.
final class Gam {
  /// Wraps [bytes], which must already be validated and unmodifiable.
  const Gam.trusted(this.bytes);

  /// The complete file, exactly as read. Unmodifiable.
  final Uint8List bytes;

  int _u32(GamHeaderField field) =>
      ByteData.sublistView(bytes).getUint32(field.offset, Endian.little);

  /// Elapsed game time. 300 units is one in-game hour.
  int get gameTime => _u32(GamHeaderField.gameTime);

  /// Resref of the area the party is standing in, e.g. `AR2600`.
  String get currentArea => decodeFixedString(
    bytes,
    GamHeaderField.currentArea.offset,
    GamHeaderField.currentArea.length,
  );

  /// Party reputation, as displayed — the stored value divided by ten.
  double get reputation => _u32(GamHeaderField.reputation) / 10;

  /// Shared party gold.
  int get partyGold => _u32(GamHeaderField.partyGold);

  /// Absolute offset to the party NPC struct array.
  int get partyNpcOffset => _u32(GamHeaderField.partyNpcOffset);

  /// Number of party NPC structs, including the protagonist.
  int get partyNpcCount => _u32(GamHeaderField.partyNpcCount);

  /// Absolute offset to the party inventory, or `0` when there is none.
  ///
  /// Prefer [hasPartyInventory] over comparing this to zero — see its note.
  int get partyInventoryOffset => _u32(GamHeaderField.partyInventoryOffset);

  /// Absolute offset to the non-party NPC struct array.
  int get nonPartyNpcOffset => _u32(GamHeaderField.nonPartyNpcOffset);

  /// Number of non-party NPC structs.
  int get nonPartyNpcCount => _u32(GamHeaderField.nonPartyNpcCount);

  /// The party, in array order.
  List<GamNpc> get partyMembers => _npcsAt(
    partyNpcOffset,
    partyNpcCount,
    'party',
  );

  /// Characters tracked by the save but not in the party.
  ///
  /// 36 of them on every BG1EE save examined — the recruitable companions.
  /// This array is the project's best stride test on real data: read at the
  /// documented 352-byte stride, all 36 embedded CRE blobs chain without a
  /// gap, and a wrong stride breaks the chain at the first link.
  List<GamNpc> get nonPartyMembers => _npcsAt(
    nonPartyNpcOffset,
    nonPartyNpcCount,
    'non-party',
  );

  List<GamNpc> _npcsAt(int offset, int count, String what) {
    final end = offset + count * GamNpcField.structSize;
    if (count < 0 || end > bytes.length) {
      // A corrupt count would otherwise be read as characters out of whatever
      // happens to follow in the buffer.
      throw InfinityFormatException.truncated(
        what: '$what NPC array ($count structs at $offset)',
        expected: end,
        actual: bytes.length,
      );
    }
    return [
      for (var i = 0; i < count; i++)
        GamNpc.at(bytes, offset + i * GamNpcField.structSize),
    ];
  }

  /// Whether this save has a shared party inventory section at all.
  ///
  /// **An offset of `0` means the section is absent, not that it sits at the
  /// start of the file.** Every BG1EE save examined carries
  /// `partyInventoryOffset = 0`, and treating that as a real position is
  /// exactly what produced the spike's stride of −180. This getter exists so
  /// callers express the question that has a correct answer.
  bool get hasPartyInventory => partyInventoryOffset != 0;

  /// A copy of this save with party gold set to [gold].
  ///
  /// Patches four bytes of a copy of the original buffer and leaves every
  /// other byte alone — including the regions this codec does not understand.
  /// That is the whole discipline: a save is *edited*, never regenerated from
  /// the fields a model happens to know about.
  ///
  /// This one is easy because [GamHeaderField.partyGold] is fixed-width, so
  /// nothing moves. Editing a section that changes size needs a layout pass
  /// and does not belong here.
  Gam withPartyGold(int gold) => _patchU32(GamHeaderField.partyGold, gold);

  Gam _patchU32(GamHeaderField field, int value) {
    final copy = Uint8List.fromList(bytes);
    ByteData.sublistView(copy).setUint32(field.offset, value, Endian.little);
    return Gam.trusted(copy.asUnmodifiableView());
  }
}
