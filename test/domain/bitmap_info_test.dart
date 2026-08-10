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

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/domain/bitmap_info.dart';

/// A BMP header with the values given. Only the header matters here.
Uint8List bmp({
  String signature = 'BM',
  int width = 169,
  int height = 266,
  int bitDepth = 24,
  int compression = 0,
  int length = 54,
}) {
  final bytes = Uint8List(length);
  if (signature.length >= 2) {
    bytes[0] = signature.codeUnitAt(0);
    bytes[1] = signature.codeUnitAt(1);
  }
  if (length >= 54) {
    ByteData.sublistView(bytes)
      ..setInt32(0x12, width, Endian.little)
      ..setInt32(0x16, height, Endian.little)
      ..setUint16(0x1c, bitDepth, Endian.little)
      ..setUint32(0x1e, compression, Endian.little);
  }
  return bytes;
}

void main() {
  group('reading a header', () {
    test('reads the size, depth and compression', () {
      // Offsets measured by parsing all 210 portraits the game ships, not
      // recalled: width 0x12, height 0x16, depth 0x1c, compression 0x1e.
      final info = BitmapInfo.parse(bmp())!;

      expect(info.width, 169);
      expect(info.height, 266);
      expect(info.bitDepth, 24);
      expect(info.isCompressed, isFalse);
    });

    test('takes the height as written, however it is written', () {
      // A negative height is a top-down bitmap, which is a row order rather
      // than a size. Reporting -266 to a player would be nonsense.
      expect(BitmapInfo.parse(bmp(height: -266))!.height, 266);
    });

    test('answers null for something that is not a BMP at all', () {
      expect(BitmapInfo.parse(bmp(signature: 'ÿØ')), isNull);
    });

    test('answers null for a file too short to hold a header', () {
      expect(BitmapInfo.parse(bmp(length: 20)), isNull);
    });
  });

  group('what the game actually ships', () {
    test('recognises the three conventional sizes', () {
      // 68 of the game's portraits are 210x330, 67 are 169x266 and 65 are
      // 54x84 -- the L, M and S variants.
      for (final (w, h) in [(210, 330), (169, 266), (54, 84)]) {
        expect(
          BitmapInfo.parse(bmp(width: w, height: h))!.isConventionalSize,
          isTrue,
          reason: '$w x $h is one the game uses',
        );
      }
    });

    test('an odd size is allowed, because the engine allows it', () {
      // ⚠️ Eleven of the game's own 210 depart from the conventional sizes --
      // 54x85, 38x60, 110x170, 172x266 and one 1x1 -- so refusing on size
      // would be stricter than the engine.
      expect(
        BitmapInfo.parse(bmp(width: 110, height: 170))!.isConventionalSize,
        isFalse,
      );
    });

    test('an odd depth is allowed too, for the same reason', () {
      // ⚠️ And this is the correction: NOPORTLL is 32-bit BI_BITFIELDS and
      // MBAS_GR is 8-bit. A depth check would be exactly as wrong as a size
      // check, which the earlier draft of this feature did not notice.
      expect(BitmapInfo.parse(bmp(bitDepth: 32, compression: 3)), isNotNull);
      expect(BitmapInfo.parse(bmp(bitDepth: 8))!.isConventionalFormat, isFalse);
      expect(BitmapInfo.parse(bmp())!.isConventionalFormat, isTrue);
    });
  });

  group('what it says about itself', () {
    test('describes the picture in the player’s terms', () {
      expect(BitmapInfo.parse(bmp())!.description, '169 × 266, 24-bit');
    });

    test('names compression when there is any', () {
      expect(
        BitmapInfo.parse(bmp(bitDepth: 32, compression: 3))!.description,
        contains('compressed'),
      );
    });
  });
}
