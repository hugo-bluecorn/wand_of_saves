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

import 'dart:developer';
import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';

/// Source of truth for the game's displayable text.
///
/// Every Infinity Engine file stores a 32-bit *strref* rather than text; the
/// words live in `dialog.tlk`. This repository is that indirection, and it is
/// separate from `SaveGameRepository` because they are separate data types —
/// repositories must never be aware of each other, so anything needing both a
/// savegame and its text merges them upstream.
abstract interface class StringRepository {
  /// The text for [strref], or `null` when there is none.
  ///
  /// `null` is an ordinary answer, not a failure: a negative strref, an index
  /// past the end of the table, and a machine with no game installed all reach
  /// it. Callers own the fallback; this layer invents no placeholder text.
  Future<String?> lookup(int strref);

  /// Releases whatever this repository holds open.
  ///
  /// On the interface rather than only on the implementation that needs it, so
  /// the provider can dispose what it built without knowing which one it got.
  Future<void> close();
}

/// Reads text from a TLK talk table on disk.
class TlkStringRepository implements StringRepository {
  /// Creates a repository over the talk table at [path].
  TlkStringRepository({required this.path});

  /// Absolute path to the talk table, as resolved by `GameProfileService`.
  final String path;

  /// The open table, memoised — including the memoised *failure*.
  ///
  /// `dialog.tlk` is several megabytes and is seeked per lookup behind an LRU,
  /// so the handle is opened once and kept. Holding a `Future<Tlk?>` rather
  /// than a `Future<Tlk>` is what keeps a failed open from rethrowing on every
  /// subsequent lookup.
  Future<Tlk?>? _table;

  @override
  Future<String?> lookup(int strref) async {
    if (strref < 0) return null;
    final table = await (_table ??= _open());
    if (table == null) return null;
    try {
      return await table.get(strref);
    } on FormatException catch (error) {
      // A truncated entry costs one name, not the screen. Caught as the core
      // type so no codec exception escapes the data layer.
      _report('strref $strref', error);
      return null;
    }
  }

  /// Releases the file handle. Safe whether or not anything was looked up.
  @override
  Future<void> close() async => (await _table)?.close();

  Future<Tlk?> _open() async {
    try {
      return await Tlk.open(path);
    } on FormatException catch (error) {
      _report('open', error);
      return null;
    } on FileSystemException catch (error) {
      _report('open', error);
      return null;
    }
  }

  /// Reports rather than swallows: names silently degrading to resrefs with no
  /// trace is exactly the kind of quiet wrongness this project guards against.
  void _report(String what, Object error) =>
      log('talk table $path: $what failed: $error', name: 'wand_of_saves');
}

/// The repository used when this machine has no talk table at all.
///
/// A named state rather than a nullable field: the app must open savegames on
/// a machine with no game installed, and there "no text exists" is the honest
/// answer to every lookup rather than a missing dependency.
class AbsentStringRepository implements StringRepository {
  /// Creates the empty repository.
  const AbsentStringRepository();

  @override
  Future<String?> lookup(int strref) async => null;

  @override
  Future<void> close() async {}
}
