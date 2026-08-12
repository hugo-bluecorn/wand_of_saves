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

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/aard.dart';
import 'package:ui_spikes/demo/boot.dart';
import 'package:ui_spikes/workbench/character_screen.dart';
import 'package:ui_spikes/workbench/home_screen.dart';
import 'package:ui_spikes/workbench/inventory_screen.dart';
import 'package:ui_spikes/workbench/palette.dart';
import 'package:ui_spikes/workbench/spells_screen.dart';
import 'package:ui_spikes/workbench/theme.dart';

/// The Workbench spike, booted onto whichever screen is being captured, in
/// whichever palette is being compared.
///
/// ⚠️ It still opens on the lineup by default, so a person can click through
/// it normally; `SPIKE_SCREEN` exists because nothing on this machine can
/// drive the pointer, not because the app has three front doors.
class WorkbenchApp extends StatelessWidget {
  /// Creates the spike in [palette], which defaults to the chosen one (D15).
  const WorkbenchApp({
    this.palette = WorkbenchPalette.starfleet,
    this.themeMode = ThemeMode.system,
    super.key,
  });

  /// Which of the four palettes to wear. It reaches nothing but the two
  /// themes below — see [WorkbenchPalette].
  final WorkbenchPalette palette;

  /// Which brightness to force, from `SPIKE_THEME`.
  ///
  /// ⚠️ **Needed to photograph De Stijl at all.** That palette's whole thesis
  /// is a white canvas held together by a black grid; its dark form is an
  /// invention rather than a translation. Following the desktop — which is
  /// dark here — would show only the invention and misrepresent the idea.
  ///
  /// ⚠️ **And needed the other way round for Starfleet**, whose source is the
  /// dark form and whose day is the invented one. The desktop being dark is
  /// not a reason to leave this unset: it would be right by accident for one
  /// palette and wrong for two.
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wand of Saves — Workbench',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: WorkbenchTheme.light(palette),
      darkTheme: WorkbenchTheme.dark(palette),
      home: switch (BootScreen.requested) {
        BootScreen.home => const HomeScreen(),
        BootScreen.character => const CharacterScreen(character: aard),
        BootScreen.inventory => const InventoryScreen(character: aard),
        BootScreen.spells => const SpellsScreen(
          character: aard,
          rulesBind: true,
        ),
      },
    );
  }
}
