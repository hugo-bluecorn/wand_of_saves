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
import 'dart:io';
import 'dart:typed_data';

import 'package:infinity_formats/src/exceptions.dart';

/// Reads strings from a TLK V1 talk table — `dialog.tlk` and its siblings.
///
/// Every piece of displayed text in an Infinity Engine game lives in a TLK and
/// is addressed by a 32-bit index called a *strref*. Creature, item and save
/// files store strrefs, never text; that indirection is how the engine changes
/// language by swapping a single file.
///
/// Lookups are lazy. `dialog.tlk` runs to several megabytes — 4.7 MB for BG:EE
/// `en_US`, 8.0 MB for `ru_RU` — and Dart has no mmap, so entries are seeked
/// per lookup and results held in a small LRU. Do not load every string.
///
/// String bodies are decoded as **UTF-8**, verified against the shipped game
/// data across four locales. Earlier project notes claimed cp1252; that is true
/// only of the classic engine. See `docs/findings/verified-format-offsets.md`
/// §TLK.
///
/// This type takes a path and performs no discovery. Which file corresponds to
/// the player's configured language is a fact about their machine, not about
/// the format, and belongs to the application layer.
///
/// Specified by IESDP `file_formats/ie_formats/tlk_v1.htm`.
final class Tlk {
  Tlk._(this._file, this._count, this._stringBase, this._cacheCapacity);

  /// Bytes before the entry array. The format fixes this; it is not derived.
  static const int _headerSize = 18;

  /// Bytes per strref entry.
  static const int _entrySize = 26;

  static const String _signature = 'TLK ';

  /// Versions this codec reads.
  ///
  /// A lookup rather than an inline comparison, so supporting another version
  /// is a table edit (D3). TLK has only ever had one, unlike GAM and CRE.
  static const Set<String> _supportedVersions = {'V1  '};

  final RandomAccessFile _file;
  final int _count;
  final int _stringBase;
  final int _cacheCapacity;

  /// Recently returned strings, least-recently-used first.
  ///
  /// A plain map is enough: Dart preserves insertion order, so re-inserting on
  /// a hit keeps `keys.first` as the eviction candidate. No dependency needed.
  final Map<int, String> _cache = {};

  /// The last file operation queued, so the next one waits for it.
  ///
  /// ⚠️ **A lookup is a seek and then a read, and that pair is not atomic.**
  /// Dart's `RandomAccessFile` refuses a second operation while one is in
  /// flight — `FileSystemException: An async operation is currently pending` —
  /// so two overlapping lookups break *both*, and neither caller did anything
  /// wrong. Nothing in this API suggests they must take turns, and in the
  /// application two providers resolve names concurrently as a matter of
  /// course: it surfaced the moment one of them grew a few more strrefs to
  /// resolve.
  ///
  /// So the queue is here rather than left to every caller. It is the same
  /// shape as memoising a `Future` — the fix that stopped the portrait cache
  /// racing — applied to ordering rather than to sharing.
  Future<void> _queue = Future<void>.value();

  /// Opens the TLK at [path].
  ///
  /// Throws [FormatException] if the header is absent, truncated, or carries a
  /// signature or version this codec does not read. The file handle is closed
  /// before any such throw; on success the caller owns it and must [close] it.
  static Future<Tlk> open(String path, {int cacheCapacity = 256}) async {
    assert(cacheCapacity > 0, 'cacheCapacity must be positive');
    final file = await File(path).open();
    try {
      final header = await file.read(_headerSize);
      if (header.length < _headerSize) {
        throw InfinityFormatException.truncated(
          what: 'TLK header',
          expected: _headerSize,
          actual: header.length,
          source: path,
        );
      }

      // Fixed-width ASCII magic. latin1 is used only because it cannot throw
      // on a corrupt file, so the message can report what was actually found.
      final signature = latin1.decode(header.sublist(0, 4));
      if (signature != _signature) {
        throw InfinityFormatException.badSignature(
          expected: _signature,
          found: signature,
          source: path,
        );
      }
      final version = latin1.decode(header.sublist(4, 8));
      if (!_supportedVersions.contains(version)) {
        throw InfinityFormatException.unsupportedVersion(
          found: version,
          supported: _supportedVersions,
          source: path,
        );
      }

      final view = ByteData.sublistView(header);
      return Tlk._(
        file,
        view.getUint32(0x0a, Endian.little),
        // Read, never computed. It happens to equal the end of the entry
        // table in every shipped file, but the format carries the field
        // precisely so that need not hold.
        view.getUint32(0x0e, Endian.little),
        cacheCapacity,
      );
    } on Object {
      // Any failure past the open leaves a live handle, so close it before the
      // exception escapes. `on Object` rather than a bare catch: it is an
      // honest on-clause, and rethrow preserves the original error.
      await file.close();
      rethrow;
    }
  }

  /// The number of strref entries in this table.
  int get length => _count;

  /// The string for [strref], or `null` if there is no such entry.
  ///
  /// `null` covers a negative strref — the protagonist's creature record
  /// carries `0xFFFFFFFF` — and one past the end. Callers decide what to
  /// display; this layer does not manufacture placeholder text.
  ///
  /// Throws [FormatException] if the entry is truncated or its string runs
  /// past the end of the file.
  Future<String?> get(int strref) {
    if (strref < 0 || strref >= _count) return Future<String?>.value();

    final hit = _cache.remove(strref);
    if (hit != null) {
      _cache[strref] = hit; // re-inserted, so it is now most recently used
      return Future<String?>.value(hit);
    }

    return _inTurn(() => _read(strref));
  }

  /// Runs [operation] once every operation queued before it has finished.
  ///
  /// ⚠️ **The failure is swallowed for the *queue* only**, never for the
  /// caller: the returned future still carries it. Chaining `_queue` on the
  /// result directly would poison every later lookup with the first truncated
  /// entry, which is one bad string costing a whole screen of names.
  Future<T> _inTurn<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<String?> _read(int strref) async {
    await _file.setPosition(_headerSize + strref * _entrySize);
    final entry = await _file.read(_entrySize);
    if (entry.length < _entrySize) {
      throw InfinityFormatException.truncated(
        what: 'TLK entry $strref',
        expected: _entrySize,
        actual: entry.length,
        offset: _headerSize + strref * _entrySize,
      );
    }
    final view = ByteData.sublistView(entry);
    final offset = view.getUint32(0x12, Endian.little);
    final length = view.getUint32(0x16, Endian.little);

    final text = length == 0 ? '' : await _readString(strref, offset, length);
    _remember(strref, text);
    return text;
  }

  /// Releases the underlying file handle. Cached strings remain readable.
  Future<void> close() => _file.close();

  /// Reads [length] bytes at [offset] relative to the string section.
  Future<String> _readString(int strref, int offset, int length) async {
    await _file.setPosition(_stringBase + offset);
    final body = await _file.read(length);
    if (body.length < length) {
      throw InfinityFormatException.truncated(
        what: 'TLK string $strref',
        expected: length,
        actual: body.length,
        offset: _stringBase + offset,
      );
    }
    // IESDP: classic-era strings may or may not be NUL-terminated, so the
    // length and any terminator have to be combined. BG:EE files contain no
    // NUL at all, making this a no-op there. Safe regardless: 0x00 in UTF-8
    // only ever means U+0000.
    final end = body.indexOf(0);
    return utf8.decode(end < 0 ? body : body.sublist(0, end));
  }

  void _remember(int strref, String text) {
    _cache[strref] = text;
    while (_cache.length > _cacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
  }
}
