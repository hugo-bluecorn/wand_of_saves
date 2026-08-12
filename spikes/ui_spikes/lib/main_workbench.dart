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

/// Spike C — **Workbench**.
///
/// *You came here to change one specific thing. The application shows you
/// what the character **is**, what is **wrong with it**, and gets out of the
/// way until you ask for something.*
///
/// The whole record on one sheet, with a command palette that reaches any
/// field, proficiency or item by name in two keystrokes. What this application
/// noticed is **marked on the field it is about** rather than listed
/// separately, and a rules check in the app bar decides whether those marks
/// merely advise or actually bind.
///
/// ```sh
/// fvm flutter run -d linux -t lib/main_workbench.dart
/// SPIKE_SCREEN=character SPIKE_TAB=2 ./ui_spikes
/// SPIKE_SCREEN=character SPIKE_PALETTE=de-stijl SPIKE_THEME=light ./ui_spikes
/// SPIKE_SCREEN=character SPIKE_PALETTE=starfleet SPIKE_THEME=dark ./ui_spikes
/// ```
///
/// `SPIKE_TAB` on the character screen: `1` opens the palette with `ac`
/// already typed, `2` opens the side sheet on `Reputation (party)`, `3` opens
/// it on `Tracking` — the conflict — and `4` opens the palette empty, on its
/// flagged-first list.
///
/// `SPIKE_PALETTE` picks the colour scheme: `bronze` (the default, and the
/// control), `de-stijl`, `pop` or `starfleet`. Case and punctuation are
/// ignored, so `deStijl` and `destijl` reach it too. See [WorkbenchPalette].
///
/// `SPIKE_THEME` forces a brightness: `light`, `dark`, or the desktop's own
/// when unset. ⚠️ **Every alternate has a first capture and they are not all
/// the same one.** Each of these palettes has one form that is the source and
/// one that is an invention, and a capture of the invention misrepresents the
/// idea. De Stijl and Pop are light-ground systems, so both want `light`;
/// Starfleet is a bridge console, so it wants **`dark`** — its day is the
/// invented half.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:ui_spikes/workbench/app.dart';
import 'package:ui_spikes/workbench/palette.dart';

/// Boots the Workbench spike.
void main() => runApp(
  WorkbenchApp(palette: _requestedPalette, themeMode: _requestedThemeMode),
);

/// What `SPIKE_THEME` asks for — `light`, `dark`, or the desktop's own.
ThemeMode get _requestedThemeMode => switch (_plain(
  Platform.environment['SPIKE_THEME'],
)) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

/// What `SPIKE_PALETTE` asks for, defaulting to [WorkbenchPalette.starfleet].
///
/// ⚠️ **The default is the decision, not the control** (D15). Bronze, De Stijl
/// and Pop are still reachable by name because they are the record of how the
/// choice was made — but the spike now opens on what was chosen, so nobody has
/// to remember an environment variable to see it.
///
/// Read at **run** time and in the same shape as `boot.dart` reads
/// `SPIKE_SCREEN`, for the same reason: one build, as many captures as there
/// are combinations. ⚠️ One concession the screen names did not need — the
/// comparison ignores case and any punctuation, because `deStijl` is a
/// miserable thing to type at a shell and `de-stijl` should not silently
/// hand back the control palette.
WorkbenchPalette get _requestedPalette {
  final asked = _plain(Platform.environment['SPIKE_PALETTE']);
  return WorkbenchPalette.values.firstWhere(
    (palette) => _plain(palette.name) == asked,
    orElse: () => WorkbenchPalette.starfleet,
  );
}

String? _plain(String? name) =>
    name?.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
