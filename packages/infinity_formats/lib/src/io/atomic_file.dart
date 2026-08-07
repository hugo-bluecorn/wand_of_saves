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

import 'dart:io';
import 'dart:typed_data';

/// Suffix of the temporary file written alongside the target.
const String atomicTempSuffix = '.tmp';

/// Suffix of the backup left beside an overwritten file.
const String atomicBackupSuffix = '.bak';

/// Writes [bytes] to [path] atomically, keeping a `.bak` of what was there.
///
/// The order is deliberate: write a temporary file, copy any existing target
/// to `<path>.bak`, then **rename** the temporary over the target. Rename
/// within a directory is atomic on POSIX and on Windows via `MoveFileEx`, so a
/// reader — including the game — sees either the whole old file or the whole
/// new one, never a half-written one. For a savegame that is the difference
/// between "unchanged" and "destroyed".
///
/// Everything before the rename is preparation, so a failure at any earlier
/// step leaves the target exactly as it was. The temporary is written *first*
/// so the most likely failure leaves nothing behind at all.
///
/// The temporary lives in the same directory on purpose: a rename across
/// filesystems is neither atomic nor always permitted, so writing to the
/// system temp directory and moving would silently give up the guarantee this
/// function exists to provide.
///
/// The temporary name is derived from [path] rather than randomised, which
/// assumes a single writer per file. That holds for a desktop editor working
/// on one save, and it is what makes the failure path testable.
///
/// This owns the *mechanism*. Policy — where backups live, how many to keep —
/// belongs to the application layer's `BackupService`.
Future<void> writeFileAtomically(String path, Uint8List bytes) async {
  final target = File(path);
  final temporary = File('$path$atomicTempSuffix');

  await temporary.writeAsBytes(bytes, flush: true);

  if (target.existsSync()) {
    await target.copy('$path$atomicBackupSuffix');
  }

  await temporary.rename(path);
}
