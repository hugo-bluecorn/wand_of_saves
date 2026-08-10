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

import 'package:meta/meta.dart';

/// What a bitmap says about itself in its header.
///
/// Enough to *describe* a file the player has chosen, which is the whole job:
/// this project imports portraits, it does not convert them.
///
/// ⚠️ **Descriptive, not a gate.** The one thing that genuinely disqualifies a
/// portrait is a base name too long to carry an `L`/`M`/`S` suffix — everything
/// here is reported and allowed, because the game's own 210 portraits include
/// eleven off-size ones, a 32-bit one and an 8-bit one. A check stricter than
/// the engine is a check that refuses files the engine would draw.
///
/// The offsets are measured rather than recalled: every one was read back from
/// all 210 portraits in `data/PORTRAIT.BIF`.
@immutable
class BitmapInfo {
  /// Describes a bitmap of these dimensions and format.
  const BitmapInfo({
    required this.width,
    required this.height,
    required this.bitDepth,
    required this.compression,
  });

  /// Reads [bytes] as a BMP header, or `null` if it is not one.
  ///
  /// `null` covers both "not a bitmap at all" and "too short to have a
  /// header", because the player needs the same answer either way: this is not
  /// a file the game can use as a portrait.
  static BitmapInfo? parse(Uint8List bytes) {
    if (bytes.length < headerSize) return null;
    if (bytes[0] != 0x42 || bytes[1] != 0x4d) return null;

    final view = ByteData.sublistView(bytes);
    return BitmapInfo(
      width: view.getInt32(_width, Endian.little).abs(),
      // ⚠️ A negative height means a top-down row order, not a negative
      // picture. Reporting -266 to a player would be nonsense.
      height: view.getInt32(_height, Endian.little).abs(),
      bitDepth: view.getUint16(_bitDepth, Endian.little),
      compression: view.getUint32(_compression, Endian.little),
    );
  }

  /// Bytes of `BITMAPFILEHEADER` plus `BITMAPINFOHEADER`.
  static const int headerSize = 54;

  static const int _width = 0x12;
  static const int _height = 0x16;
  static const int _bitDepth = 0x1c;
  static const int _compression = 0x1e;

  /// The sizes the game's own `L`, `M` and `S` variants use.
  static const Set<(int, int)> conventionalSizes = {
    (210, 330),
    (169, 266),
    (54, 84),
  };

  /// Picture width in pixels.
  final int width;

  /// Picture height in pixels.
  final int height;

  /// Bits per pixel.
  final int bitDepth;

  /// The `biCompression` value; `0` is uncompressed.
  final int compression;

  /// Whether any compression is declared.
  bool get isCompressed => compression != 0;

  /// Whether this is one of the three sizes the game normally uses.
  bool get isConventionalSize => conventionalSizes.contains((width, height));

  /// Whether this is the 24-bit uncompressed form 208 of the game's 210 use.
  bool get isConventionalFormat => bitDepth == 24 && !isCompressed;

  /// The picture in the player's terms, e.g. `169 × 266, 24-bit`.
  String get description => [
    '$width × $height',
    '$bitDepth-bit',
    if (isCompressed) 'compressed',
  ].join(', ');

  @override
  bool operator ==(Object other) =>
      other is BitmapInfo &&
      other.width == width &&
      other.height == height &&
      other.bitDepth == bitDepth &&
      other.compression == compression;

  @override
  int get hashCode => Object.hash(width, height, bitDepth, compression);

  @override
  String toString() => 'BitmapInfo($description)';
}
