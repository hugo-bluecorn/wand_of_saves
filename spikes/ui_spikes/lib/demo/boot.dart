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

/// Which screen a spike opens on, read from the environment at **run** time.
///
/// ⚠️ **This exists because nothing on this machine can drive the pointer.**
/// The app is a Wayland window, XTEST cannot reach it, and no input tool is
/// installed — so a screen that needs a click to reach cannot be photographed.
/// Every spike therefore boots straight onto whichever screen is being
/// captured, and still opens on the home screen by default so a person can
/// click through it normally.
///
/// A `--dart-define` would have meant one rebuild per screen. An environment
/// variable means one build and as many captures as there are screens:
///
/// ```sh
/// SPIKE_SCREEN=character SPIKE_TAB=3 ./ui_spikes
/// ```
///
/// This is the only place any spike touches `dart:io`. The demo data is static
/// and reads nothing.
library;

import 'dart:io' show Platform;

/// The screens a spike can open on.
enum BootScreen {
  /// The lineup — the application's main entry point.
  home,

  /// The character sheet, for a character that has been created.
  character,

  /// The inventory, which is what this whole exercise is choosing a shape for.
  inventory,

  /// The spellbook and what is memorised from it.
  spells;

  /// What `SPIKE_SCREEN` asks for, defaulting to [BootScreen.home].
  static BootScreen get requested {
    final name = Platform.environment['SPIKE_SCREEN'];
    return BootScreen.values.firstWhere(
      (screen) => screen.name == name,
      orElse: () => BootScreen.home,
    );
  }
}

/// How far down the screen to sit on boot, from `SPIKE_SCROLL` — `0` for the
/// top, `1` for the bottom, anything between for a fraction of the way.
///
/// ⚠️ **A sheet that is taller than the screen cannot otherwise be
/// photographed below the fold**, because nothing here can drive the pointer
/// and the window cannot grow past the display. The panel someone asks about
/// is rarely the one at the top.
double get requestedScroll {
  final raw = Platform.environment['SPIKE_SCROLL'];
  if (raw == null) return 0;
  return (double.tryParse(raw) ?? 0).clamp(0, 1);
}

/// Which section or tab of the character sheet to open on, from `SPIKE_TAB`.
///
/// Zero when unset or unparseable, so a spike never fails to start over this.
int get requestedTab {
  final raw = Platform.environment['SPIKE_TAB'];
  if (raw == null) return 0;
  return int.tryParse(raw) ?? 0;
}
