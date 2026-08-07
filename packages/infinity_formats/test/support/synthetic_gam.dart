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

/// Builds a GAM V2.0 image.
///
/// Defaults produce a well-formed file whose values match the real fixture, so
/// synthetic and fixture-backed tests assert the same numbers. Each parameter
/// introduces one specific deviation.
Uint8List buildGam({
  String signature = 'GAME',
  String version = 'V2.0',
  int partyGold = 161,
  int partyNpcOffset = 180,
  int partyNpcCount = 1,
  int partyInventoryOffset = 0,
  int nonPartyNpcCount = 36,
  int? truncateTo,
}) {
  final headerEnd = GamHeaderField.values.fold<int>(
    0,
    (most, f) => f.offset + f.length > most ? f.offset + f.length : most,
  );
  final out = Uint8List(headerEnd + syntheticGamTrailerLength);
  final data = ByteData.sublistView(out);

  out
    ..setRange(0, 4, _ascii(signature, 4))
    ..setRange(4, 8, _ascii(version, 4));

  void put(GamHeaderField field, int value) =>
      data.setUint32(field.offset, value, Endian.little);

  put(GamHeaderField.partyGold, partyGold);
  put(GamHeaderField.partyNpcOffset, partyNpcOffset);
  put(GamHeaderField.partyNpcCount, partyNpcCount);
  put(GamHeaderField.partyInventoryOffset, partyInventoryOffset);
  put(GamHeaderField.nonPartyNpcCount, nonPartyNpcCount);

  // A pattern rather than zeroes, so "preserved" means something.
  for (var i = 0; i < syntheticGamTrailerLength; i++) {
    out[headerEnd + i] = (i * 7 + 3) & 0xff;
  }

  return truncateTo == null ? out : Uint8List.sublistView(out, 0, truncateTo);
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
