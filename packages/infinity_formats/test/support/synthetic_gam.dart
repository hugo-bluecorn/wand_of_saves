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

/// Builds GAM V2.0 images in memory, so the codec suite needs no game data.
///
/// A real `BALDUR.gam` is BioWare's copyright and cannot be committed; logic
/// tests run against files built here, and the real saves are used only to
/// confirm documented values in tests that skip when absent.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';

/// Bytes past the header, filled with a recognisable pattern.
///
/// Their only job is to be *preserved*: a test that edits a header field
/// asserts these are byte-identical afterwards, which is what catches a codec
/// that regenerates a file instead of patching it.
const int syntheticGamTrailerLength = 64;

/// One NPC struct for [buildGam] to emit, with its embedded CRE.
final class SyntheticNpc {
  /// Describes an NPC whose CRE blob is [creLength] bytes.
  const SyntheticNpc({
    required this.resref,
    required this.displayName,
    this.creLength = 32,
  });

  /// The CRE resref, written to `GamNpcField.creResref`.
  final String resref;

  /// The player-visible name, written to `GamNpcField.displayName`.
  final String displayName;

  /// Size of this character's embedded CRE blob.
  final int creLength;
}

/// Builds a GAM V2.0 image.
///
/// Defaults produce a well-formed file whose values match the real fixture, so
/// synthetic and fixture-backed tests assert the same numbers. Each parameter
/// introduces one specific deviation.
///
/// Passing [party] emits real NPC structs and CRE blobs after the trailer, and
/// overrides [partyNpcOffset] / [partyNpcCount] to match. **This is the only
/// way to test the party stride**: every real save has exactly one party
/// member, so any stride reads it correctly — which is precisely how the
/// spike's stride of −180 went unnoticed.
Uint8List buildGam({
  String signature = 'GAME',
  String version = 'V2.0',
  int partyGold = 161,
  int partyNpcOffset = 180,
  int partyNpcCount = 1,
  int partyInventoryOffset = 0,
  int nonPartyNpcCount = 36,
  List<SyntheticNpc> party = const [],
  int? truncateTo,
}) {
  final headerEnd = GamHeaderField.values.fold<int>(
    0,
    (most, f) => f.offset + f.length > most ? f.offset + f.length : most,
  );

  // NPC data goes after the trailer, so the trailer stays put at headerEnd
  // whether or not there are NPCs. Real saves leave a gap here too: their
  // party structs start at 180, past the fields recorded in GamHeaderField.
  final structsAt = headerEnd + syntheticGamTrailerLength;
  final creAt = structsAt + party.length * GamNpcField.structSize;
  final creBytes = party.fold<int>(0, (sum, npc) => sum + npc.creLength);
  final total = party.isEmpty ? structsAt : creAt + creBytes;

  final out = Uint8List(total);
  final data = ByteData.sublistView(out);

  out
    ..setRange(0, 4, _ascii(signature, 4))
    ..setRange(4, 8, _ascii(version, 4));

  void put(GamHeaderField field, int value) =>
      data.setUint32(field.offset, value, Endian.little);

  put(GamHeaderField.partyGold, partyGold);
  put(
    GamHeaderField.partyNpcOffset,
    party.isEmpty ? partyNpcOffset : structsAt,
  );
  put(
    GamHeaderField.partyNpcCount,
    party.isEmpty ? partyNpcCount : party.length,
  );
  put(GamHeaderField.partyInventoryOffset, partyInventoryOffset);
  put(GamHeaderField.nonPartyNpcCount, nonPartyNpcCount);

  // A pattern rather than zeroes, so "preserved" means something.
  for (var i = 0; i < syntheticGamTrailerLength; i++) {
    out[headerEnd + i] = (i * 7 + 3) & 0xff;
  }

  var creCursor = creAt;
  for (var i = 0; i < party.length; i++) {
    final npc = party[i];
    final base = structsAt + i * GamNpcField.structSize;

    void putField(GamNpcField field, int value) => data.setUint32(
      base + field.offset,
      value,
      Endian.little,
    );

    putField(GamNpcField.creOffset, creCursor);
    putField(GamNpcField.creLength, npc.creLength);
    _putFixed(
      out,
      base + GamNpcField.creResref.offset,
      GamNpcField.creResref.length,
      npc.resref,
    );
    _putFixed(
      out,
      base + GamNpcField.displayName.offset,
      GamNpcField.displayName.length,
      npc.displayName,
    );

    // A recognisable CRE so tests can assert the blob was located correctly.
    out.setRange(creCursor, creCursor + 8, _ascii('CRE V1.0', 8));
    creCursor += npc.creLength;
  }

  return truncateTo == null ? out : Uint8List.sublistView(out, 0, truncateTo);
}

void _putFixed(Uint8List out, int offset, int width, String text) {
  final bytes = utf8.encode(text);
  final n = bytes.length < width ? bytes.length : width;
  out.setRange(offset, offset + n, bytes);
}

/// The offset at which [buildGam]'s recognisable trailer starts.
int get syntheticGamTrailerOffset => GamHeaderField.values.fold<int>(
  0,
  (most, f) => f.offset + f.length > most ? f.offset + f.length : most,
);

Uint8List _ascii(String text, int width) {
  final out = Uint8List(width)..fillRange(0, width, 0x20);
  final bytes = ascii.encode(text);
  out.setRange(0, bytes.length < width ? bytes.length : width, bytes);
  return out;
}
