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

import 'package:infinity_formats/src/cre/cre.dart';
import 'package:infinity_formats/src/exceptions.dart';
import 'package:infinity_formats/src/spec/cre_v1_0.dart';

/// Reads `CRE` creature records.
///
/// Version dispatch follows the same reasoning as `GamCodec`: the offsets live
/// in [CreHeaderField], a data table, so supporting IWD's V9.0 or IWD2's V2.2
/// means adding a table and choosing between them rather than rewriting a
/// reader. D3 is satisfied by where the data lives, not by a class hierarchy.
abstract final class CreCodec {
  static const String _signature = 'CRE ';

  /// Versions this build reads. BG1EE only, per D3.
  static const Set<String> supportedVersions = {'V1.0'};

  /// Parses [bytes] as a creature record.
  ///
  /// Unlike a savegame, a CRE usually arrives as a *slice* of its parent GAM —
  /// see `GamNpc.creBytes` — so this does not copy. The slice already inherits
  /// the savegame buffer's unmodifiability.
  ///
  /// Throws [InfinityFormatException] if the record is too short for its fixed
  /// header, or carries a signature or version this codec does not read.
  static Cre decode(Uint8List bytes, {Object? source}) {
    if (bytes.length < CreHeaderField.headerSize) {
      throw InfinityFormatException.truncated(
        what: 'CRE header',
        expected: CreHeaderField.headerSize,
        actual: bytes.length,
        source: source,
      );
    }

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

    return Cre.trusted(bytes);
  }
}
