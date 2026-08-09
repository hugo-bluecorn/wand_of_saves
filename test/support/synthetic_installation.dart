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

/// A game installation small enough to write into a temporary directory.
///
/// **`ResourceRepository`'s reading path had no test at all** — every existing
/// one exercised the pure `proficienciesFrom` / `thiefSkillsFrom` functions and
/// stopped at the file boundary. That left the index cache, the archive cache
/// and everything between them covered only by "it worked when I looked", which
/// is how a race that loses two portraits out of three reaches a screenshot.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';

/// One resource to write into the synthetic installation.
typedef SyntheticResource = ({
  String resref,
  ResourceType type,
  List<int> bytes,
});

/// Writes a `chitin.key` and one `data/DEFAULT.BIF` into [root].
///
/// Returns [root]'s path, ready to hand to a `GameProfileService` as its only
/// game candidate.
String writeInstallation(
  Directory root,
  List<SyntheticResource> resources,
) {
  final separator = Platform.pathSeparator;
  Directory('${root.path}${separator}data').createSync(recursive: true);

  File('${root.path}${separator}chitin.key').writeAsBytesSync(_key(resources));
  File(
    '${root.path}${separator}data${separator}DEFAULT.BIF',
  ).writeAsBytesSync(_bif(resources));
  return root.path;
}

/// A `KEY V1` naming one archive and every resource in [resources].
///
/// Each resource's locator is its index in the archive, which is what
/// `BifArchive.resource` takes.
Uint8List _key(List<SyntheticResource> resources) {
  const nameOffset = 24;
  const name = r'data\DEFAULT.BIF';
  const archiveTable = nameOffset + name.length + 1;
  const resourceTable = archiveTable + KeyIndex.archiveEntrySize;

  final bytes = Uint8List(
    resourceTable + resources.length * KeyIndex.entrySize,
  );
  final view = ByteData.sublistView(bytes);
  bytes
    ..setRange(0, 4, ascii.encode('KEY '))
    ..setRange(4, 8, ascii.encode('V1  '));
  view
    ..setUint32(8, 1, Endian.little)
    ..setUint32(12, resources.length, Endian.little)
    ..setUint32(16, archiveTable, Endian.little)
    ..setUint32(20, resourceTable, Endian.little);

  bytes.setRange(nameOffset, nameOffset + name.length, ascii.encode(name));
  view
    ..setUint32(archiveTable + 4, nameOffset, Endian.little)
    ..setUint16(archiveTable + 8, name.length + 1, Endian.little);

  for (var i = 0; i < resources.length; i++) {
    final entry = resourceTable + i * KeyIndex.entrySize;
    final resref = ascii.encode(resources[i].resref);
    bytes.setRange(entry, entry + resref.length, resref);
    view
      ..setUint16(entry + 8, resources[i].type.code, Endian.little)
      // Archive 0, file index i.
      ..setUint32(entry + 10, i, Endian.little);
  }
  return bytes;
}

/// A `BIFF V1` holding every resource's bytes, in order.
Uint8List _bif(List<SyntheticResource> resources) {
  const table = 20;
  final payload = table + resources.length * BifArchive.entrySize;
  final total = resources.fold<int>(payload, (sum, r) => sum + r.bytes.length);

  final bytes = Uint8List(total);
  final view = ByteData.sublistView(bytes);
  bytes
    ..setRange(0, 4, ascii.encode('BIFF'))
    ..setRange(4, 8, ascii.encode('V1  '));
  view
    ..setUint32(8, resources.length, Endian.little)
    ..setUint32(16, table, Endian.little);

  var at = payload;
  for (var i = 0; i < resources.length; i++) {
    final entry = table + i * BifArchive.entrySize;
    view
      ..setUint32(entry, i, Endian.little)
      ..setUint32(entry + 4, at, Endian.little)
      ..setUint32(entry + 8, resources[i].bytes.length, Endian.little);
    bytes.setRange(at, at + resources[i].bytes.length, resources[i].bytes);
    at += resources[i].bytes.length;
  }
  return bytes;
}
