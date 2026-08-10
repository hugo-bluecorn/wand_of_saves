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
import 'package:infinity_formats/src/text/fixed_field.dart';

/// The kinds of resource this project asks `chitin.key` for.
///
/// Deliberately partial. The engine defines dozens; naming only the ones a
/// character editor needs keeps the enum honest about what has been verified,
/// and [KeyIndex.locate] takes this rather than a bare number so a call site
/// cannot pass a type nobody has checked.
enum ResourceType {
  /// A `2DA` rules table, e.g. `weapprof.2da`.
  table2da(0x03f4),

  /// An `ITM` item, e.g. `AX1H03.ITM`.
  item(0x03ed),

  /// A `CRE` creature, e.g. `CHARBASE`.
  ///
  /// ⚠️ **This was `0x03f9` and that is `.bs`, a script.** Corrected
  /// 2026-08-09 against IESDP's own type table and against the data: a BG:EE
  /// install indexes **2,253** resources at `0x03f1`, `CHARBASE` among them,
  /// and **none at all** at `0x03f9`. The bug never fired because
  /// [KeyIndex.locate] was only ever called for [table2da] — and it would not
  /// have thrown when it did, it would have answered `null` forever.
  creature(0x03f1),

  /// A `BMP` bitmap, e.g. `AJANTISM`.
  ///
  /// Portraits are these. All 210 in `data/PORTRAIT.BIF` carry this type.
  bitmap(0x0001),

  /// An `SPL` spell, e.g. `SPWI112.SPL` — Magic Missile.
  ///
  /// A BG:EE install indexes **1,207** of these, 1,115 in `data/Spells.bif`.
  /// Most are not spells anyone learns: the engine keeps its own plumbing here
  /// too, and tells them apart by whether the header names a string.
  spell(0x03ee);

  const ResourceType(this.code);

  /// The number the key file stores.
  final int code;
}

/// Where one resource lives: which archive, and which entry inside it.
typedef ResourceLocation = ({int archive, int file});

/// `chitin.key` — the index that says which BIFF archive holds what.
///
/// The game keeps almost everything in a handful of large archives, and this
/// is the only way to find a resource inside them. Reading it is cheap: the
/// whole table is a flat array and indexing all 37,342 entries of a BG:EE
/// install takes milliseconds.
///
/// **Why the app needs this at all, when the rules layer is generated from
/// IESDP.** IESDP's 2DA copies are per-game, and its `weapprof.2da` is the
/// BG2:EE one — its `NAME_REF` strrefs point into a different talk table, so
/// generating proficiency names from it produces tutorial prose. Tables of
/// pure numbers happened to match and are confirmed in game; **anything
/// carrying a strref has to come from the player's own installation.**
final class KeyIndex {
  const KeyIndex._(
    this.archives,
    this._locations,
    this.resourceCount,
    this.resourceTableOffset,
  );

  /// Reads an index from the bytes of a `chitin.key`.
  ///
  /// Throws [InfinityFormatException] if the signature, version or table
  /// bounds do not hold.
  factory KeyIndex.parse(Uint8List bytes, {Object? source}) {
    if (bytes.length < headerSize) {
      throw InfinityFormatException.truncated(
        what: 'KEY header',
        expected: headerSize,
        actual: bytes.length,
        source: source,
      );
    }
    final signature = decodeFixedString(bytes, 0, 4);
    if (signature != _signature) {
      throw InfinityFormatException.badSignature(
        expected: _signature,
        found: signature,
        source: source,
      );
    }
    final version = decodeFixedString(bytes, 4, 4);
    if (!supportedVersions.contains(version)) {
      throw InfinityFormatException.unsupportedVersion(
        found: version,
        supported: supportedVersions,
        source: source,
      );
    }

    final view = ByteData.sublistView(bytes);
    final archiveCount = view.getUint32(8, Endian.little);
    final resourceCount = view.getUint32(12, Endian.little);
    final archiveTable = view.getUint32(16, Endian.little);
    final resourceTable = view.getUint32(20, Endian.little);

    _requireWithin(
      bytes,
      archiveTable + archiveCount * archiveEntrySize,
      'archive table',
      source,
    );
    _requireWithin(
      bytes,
      resourceTable + resourceCount * entrySize,
      'resource table',
      source,
    );

    final archives = <String>[];
    for (var i = 0; i < archiveCount; i++) {
      final entry = archiveTable + i * archiveEntrySize;
      final nameOffset = view.getUint32(entry + 4, Endian.little);
      final nameLength = view.getUint16(entry + 8, Endian.little);
      _requireWithin(bytes, nameOffset + nameLength, 'archive name', source);
      // The stored length counts the terminating NUL, and the separator is
      // the one the game shipped on Windows.
      archives.add(
        decodeFixedString(bytes, nameOffset, nameLength).replaceAll(r'\', '/'),
      );
    }

    final locations = <String, ResourceLocation>{};
    for (var i = 0; i < resourceCount; i++) {
      final entry = resourceTable + i * entrySize;
      final type = view.getUint16(entry + 8, Endian.little);
      final locator = view.getUint32(entry + 10, Endian.little);
      final resref = decodeFixedString(bytes, entry, 8).toUpperCase();
      locations['$type/$resref'] = (
        // The locator packs three fields; a tileset index sits between them
        // and is not used here.
        archive: (locator >> 20) & 0xFFF,
        file: locator & 0x3FFF,
      );
    }

    return KeyIndex._(
      List.unmodifiable(archives),
      Map.unmodifiable(locations),
      resourceCount,
      resourceTable,
    );
  }

  /// Bytes before the archive table. The format fixes this.
  static const int headerSize = 24;

  /// Bytes per archive entry: length, name offset, name length, location.
  static const int archiveEntrySize = 12;

  /// Bytes per resource entry: 8 resref, 2 type, 4 locator.
  static const int entrySize = 14;

  static const String _signature = 'KEY ';

  /// Versions this codec reads.
  static const Set<String> supportedVersions = {'V1  '};

  /// The archives this index names, as paths relative to the game directory.
  final List<String> archives;

  final Map<String, ResourceLocation> _locations;

  /// How many resources the index describes.
  final int resourceCount;

  /// Where the resource table begins, so a caller can check it closes at EOF.
  final int resourceTableOffset;

  /// Where [resref] of [type] lives, or `null` if the index has no such entry.
  ///
  /// Case-insensitive: resrefs appear in mixed case across the game's own
  /// files, and the CRE records that reference them are no more consistent.
  ResourceLocation? locate(String resref, ResourceType type) =>
      _locations['${type.code}/${resref.toUpperCase()}'];

  /// Every resref of [type], upper-cased, in no particular order.
  ///
  /// Optionally narrowed to one [archive] by index into [archives].
  ///
  /// **The index had no way to enumerate until a picker needed one.** Choosing
  /// a portrait means offering what the game ships, and the honest way to find
  /// those is to ask which resources live in `data/PORTRAIT.BIF` — a dedicated
  /// archive of exactly 210 bitmaps. Guessing at name shapes instead is how
  /// `CMISC4S` ends up in a list of portraits because it happens to end in `S`.
  List<String> resrefsOf(ResourceType type, {int? archive}) => [
    for (final entry in _locations.entries)
      if (entry.key.startsWith('${type.code}/'))
        if (archive == null || entry.value.archive == archive)
          entry.key.substring('${type.code}/'.length),
  ];

  /// The index of the archive whose path ends with [name], or `null`.
  ///
  /// Case-insensitive, and matched on the trailing path segment so a caller
  /// says `PORTRAIT.BIF` rather than reproducing the engine's own `data\`
  /// notation.
  int? archiveNamed(String name) {
    final wanted = name.toUpperCase();
    for (var i = 0; i < archives.length; i++) {
      if (archives[i].toUpperCase().split('/').last == wanted) return i;
    }
    return null;
  }

  static void _requireWithin(
    Uint8List bytes,
    int end,
    String what,
    Object? source,
  ) {
    if (end > bytes.length) {
      throw InfinityFormatException.truncated(
        what: 'KEY $what',
        expected: end,
        actual: bytes.length,
        source: source,
      );
    }
  }

  @override
  String toString() =>
      'KeyIndex(${archives.length} archives, $resourceCount resources)';
}
