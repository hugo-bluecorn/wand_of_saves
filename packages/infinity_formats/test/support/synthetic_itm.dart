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

/// Builds `ITM V1` images in memory, so the codec suite needs no game data.
///
/// ⚠️ **The defaults reproduce `BOOT01`**, an item read out of the player's
/// own installation on 2026-08-12 — a 114-byte header plus two 48-byte
/// feature blocks, 210 bytes exactly. A builder whose shape nobody checked
/// against a real file only ever proves that the code runs.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';

/// Builds an `ITM V1` image.
///
/// ⚠️ **[unidentifiedName] and [identifiedName] default to real strrefs and
/// accept negatives**, because `-1` is how the format says "no name" and 195 of
/// the installation's 1,530 items use it. A builder that could only produce
/// present names would make the absent case untestable, which is exactly the
/// hole that let `EXTRA2`…`EXTRA15` reach the proficiency list.
Uint8List buildItm({
  String signature = 'ITM ',
  String version = 'V1  ',
  int unidentifiedName = 6339,
  int identifiedName = 6823,
  int flags = 0x6c,
  int itemType = 4,
  List<int> usability = const [0, 0, 0, 0],
  int price = 2300,
  int stackAmount = 1,
  String inventoryIcon = 'IBOOT01',
  int loreToIdentify = 30,
  String groundIcon = 'GBOOT01',
  int weight = 4,
  int unidentifiedDescription = 6824,
  int identifiedDescription = 7375,
  String descriptionIcon = 'CBOOT01',
  int extendedHeaderCount = 0,
  int equippingCount = 2,
  int? truncateTo,
}) {
  final out = Uint8List(itmHeaderLength + equippingCount * 48);
  final data = ByteData.sublistView(out);

  void ascii(int at, int width, String text) {
    final bytes = utf8.encode(text);
    out.setRange(at, at + (bytes.length < width ? bytes.length : width), bytes);
  }

  ascii(0, 4, signature);
  ascii(4, 4, version);

  void i32(ItmHeaderField f, int v) =>
      data.setInt32(f.offset, v, Endian.little);
  void u32(ItmHeaderField f, int v) =>
      data.setUint32(f.offset, v, Endian.little);
  void u16(ItmHeaderField f, int v) =>
      data.setUint16(f.offset, v, Endian.little);

  i32(ItmHeaderField.unidentifiedName, unidentifiedName);
  i32(ItmHeaderField.identifiedName, identifiedName);
  u32(ItmHeaderField.flags, flags);
  u16(ItmHeaderField.itemType, itemType);
  for (var i = 0; i < 4 && i < usability.length; i++) {
    out[ItmHeaderField.usability1.offset + i] = usability[i];
  }
  u32(ItmHeaderField.price, price);
  u16(ItmHeaderField.stackAmount, stackAmount);
  ascii(ItmHeaderField.inventoryIcon.offset, 8, inventoryIcon);
  u16(ItmHeaderField.loreToIdentify, loreToIdentify);
  ascii(ItmHeaderField.groundIcon.offset, 8, groundIcon);
  u32(ItmHeaderField.weight, weight);
  i32(ItmHeaderField.unidentifiedDescription, unidentifiedDescription);
  i32(ItmHeaderField.identifiedDescription, identifiedDescription);
  ascii(ItmHeaderField.descriptionIcon.offset, 8, descriptionIcon);

  // The header points at the feature pool, which begins where it ends — which
  // is what `BOOT01` does, and what makes its length close exactly.
  u32(ItmHeaderField.extendedHeaderOffset, itmHeaderLength);
  u16(ItmHeaderField.extendedHeaderCount, extendedHeaderCount);
  u32(ItmHeaderField.featureBlockOffset, itmHeaderLength);
  u16(ItmHeaderField.equippingIndex, 0);
  u16(ItmHeaderField.equippingCount, equippingCount);

  return truncateTo == null ? out : Uint8List.sublistView(out, 0, truncateTo);
}
