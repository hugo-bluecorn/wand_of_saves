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

/// Locates save-game fixtures — copies of real saves made by
/// `tool/dev/sync_fixtures.dart`.
///
/// Fixtures are never committed: `BALDUR.gam` is BioWare's copyright, and
/// `.gitignore` refuses `**/fixtures/`. Every helper here therefore returns
/// `null` rather than throwing when a fixture is missing, so a suite can pass
/// that straight to `skip:` and stay green on a fresh clone.
///
/// These are *copies*. The originals under the game's save directory are the
/// player's real game and are never opened for writing.
library;

import 'dart:io';

/// Where `sync_fixtures.dart` puts copied slots, relative to the package root.
const String defaultFixtureSaveRoot = 'test/fixtures/saves';

/// The directory of fixture save slot [slot], or `null` if it is unusable.
///
/// "Unusable" covers every way this fails on a machine that has not run
/// `tool/dev/sync_fixtures.dart`: no fixture root at all, no such slot, or a
/// slot directory with no `BALDUR.gam` in it. The last case matters — a
/// half-copied fixture returns `null` here rather than failing obscurely
/// inside a codec several layers down.
String? fixtureSaveSlot(String slot, {String root = defaultFixtureSaveRoot}) {
  final dir = Directory('$root${Platform.pathSeparator}$slot');
  if (!dir.existsSync()) return null;
  final gam = File('${dir.path}${Platform.pathSeparator}$gamFileName');
  return gam.existsSync() ? dir.path : null;
}

/// The `BALDUR.gam` of fixture save slot [slot], or `null` if it is unusable.
String? fixtureGam(String slot, {String root = defaultFixtureSaveRoot}) {
  final dir = fixtureSaveSlot(slot, root: root);
  return dir == null ? null : '$dir${Platform.pathSeparator}$gamFileName';
}

/// The savegame file inside a slot directory.
const String gamFileName = 'BALDUR.gam';
