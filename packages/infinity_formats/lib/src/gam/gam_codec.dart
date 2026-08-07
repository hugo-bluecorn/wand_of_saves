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

import 'dart:convert';
import 'dart:typed_data';

import 'package:infinity_formats/src/exceptions.dart';
import 'package:infinity_formats/src/gam/gam.dart';
import 'package:infinity_formats/src/spec/gam_v2_0.dart';

/// Reads `BALDUR.gam` savegames.
///
/// ### On D3's pluggable dispatch
///
/// D3 requires codec dispatch to stay selectable by version signature rather
/// than sealed into one hardcoded reader. That is satisfied here by *where the
/// offsets live*: they are in [GamHeaderField], a data table, and this codec
/// only reads through it. Supporting GAM V2.2 means adding a second field
/// table and choosing between them — not rewriting a reader.
///
/// A class hierarchy dispatching to a layout with no members would be
/// ceremony, not pluggability, so it is deliberately not built until a second
/// version needs one.
abstract final class GamCodec {
  static const String _signature = 'GAME';

  /// Versions this build reads. Adding one is a table edit (D3).
  static const Set<String> supportedVersions = {'V2.0'};

  /// Smallest file that can hold every documented header field.
  ///
  /// Derived from [GamHeaderField] rather than written down, so recording a
  /// new field automatically raises the requirement — one less number to keep
  /// in step by hand.
  static final int minimumSize = GamHeaderField.values.fold<int>(
    0,
    (most, f) => f.offset + f.length > most ? f.offset + f.length : most,
  );

  /// Parses [bytes] as a GAM savegame.
  ///
  /// The returned [Gam] holds an unmodifiable **copy**. Copying rather than
  /// wrapping matters: `asUnmodifiableView` stops writes through the view, but
  /// the caller still holds the original and could mutate it behind us. For a
  /// ~96 KB save that insurance is cheap, and it makes the model genuinely
  /// immutable rather than conditionally so.
  ///
  /// Throws [InfinityFormatException] if the file is too short, or carries a
  /// signature or version this codec does not read.
  static Gam decode(Uint8List bytes, {Object? source}) {
    if (bytes.length < minimumSize) {
      throw InfinityFormatException.truncated(
        what: 'GAM header',
        expected: minimumSize,
        actual: bytes.length,
        source: source,
      );
    }

    // Fixed-width ASCII magic. latin1 cannot throw on corrupt input, so the
    // message can report what was actually there.
    final signature = latin1.decode(bytes.sublist(0, 4));
    if (signature != _signature) {
      throw InfinityFormatException.badSignature(
        expected: _signature,
        found: signature,
        source: source,
      );
    }

    final version = latin1.decode(bytes.sublist(4, 8));
    if (!supportedVersions.contains(version)) {
      throw InfinityFormatException.unsupportedVersion(
        found: version,
        supported: supportedVersions,
        source: source,
      );
    }

    return Gam.trusted(Uint8List.fromList(bytes).asUnmodifiableView());
  }

  /// Serialises [gam] back to bytes.
  ///
  /// **Deliberately trivial, and that is the point.** `Gam` keeps the original
  /// buffer and edits patch a copy of it, so there is nothing to reassemble —
  /// which is precisely why nothing this codec fails to understand can be
  /// lost. Note that this means byte-identity round-tripping proves very
  /// little on its own: a writer of `return input` would pass it. The test
  /// that constrains a writer is "edit one field and assert every *other*
  /// byte is unchanged".
  ///
  /// When an edit can resize a section, the layout pass — compute sizes,
  /// assign offsets, patch every offset field — belongs here. Nothing in this
  /// slice resizes anything.
  static Uint8List encode(Gam gam) => gam.bytes;
}
