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

import 'package:infinity_formats/src/spec/gam_v2_0.dart';
import 'package:infinity_formats/src/text/fixed_field.dart';

/// One character's entry in a GAM's party or non-party array.
///
/// A **view** over the savegame buffer, not a copy: it holds the whole GAM
/// plus [structOffset], and every accessor reads through. Two reasons. The
/// bytes stay the single source of truth, as they do for `Gam` itself; and
/// [structOffset] is exactly what a writer needs in order to patch this struct
/// in place rather than re-deriving its position from an index and a stride it
/// might get wrong — which is the mistake that produced the spike's −180.
///
/// Party and non-party characters share this layout; see [GamNpcField].
final class GamNpc {
  /// Views the struct that begins at [structOffset] within [_gam].
  const GamNpc.at(this._gam, this.structOffset);

  final Uint8List _gam;

  /// Byte offset of this struct from the start of the savegame.
  final int structOffset;

  ByteData get _view => ByteData.sublistView(_gam);

  int _u16(GamNpcField field) =>
      _view.getUint16(structOffset + field.offset, Endian.little);

  int _u32(GamNpcField field) =>
      _view.getUint32(structOffset + field.offset, Endian.little);

  String _string(GamNpcField field) =>
      decodeFixedString(_gam, structOffset + field.offset, field.length);

  /// Party order; `0xFFFF` means not in the party.
  int get partyOrder => _u16(GamNpcField.partyOrder);

  /// Absolute offset of this character's embedded CRE, from the file start.
  int get creOffset => _u32(GamNpcField.creOffset);

  /// Size in bytes of this character's embedded CRE.
  int get creLength => _u32(GamNpcField.creLength);

  /// The CRE resref, e.g. `*HARBASE`.
  ///
  /// IESDP labels this field "Character Name"; it is not the name. The
  /// player-visible one is [displayName].
  String get creResref => _string(GamNpcField.creResref);

  /// The player-visible name, e.g. `Aard`.
  ///
  /// This is where the displayed name comes from when the CRE's own name
  /// strref is `-1`, which is the protagonist's case.
  String get displayName => _string(GamNpcField.displayName);

  /// Resref of the area this character is in.
  String get currentArea => _string(GamNpcField.currentArea);

  /// This character's embedded CRE, as a view into the savegame buffer.
  ///
  /// A view rather than a copy, so locating a creature costs nothing. It
  /// inherits the buffer's unmodifiability.
  Uint8List get creBytes =>
      Uint8List.sublistView(_gam, creOffset, creOffset + creLength);

  @override
  String toString() => 'GamNpc($creResref "$displayName" @$structOffset)';
}
