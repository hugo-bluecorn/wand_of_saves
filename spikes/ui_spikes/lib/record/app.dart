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

/// The Record spike, wired together.
///
/// Both brightnesses are built, and the theme mode follows the platform the
/// way the baseline shell does, so the light and dark captures of all four
/// screens are comparable with each other.
library;

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/aard.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/record/home_screen.dart';
import 'package:ui_spikes/record/theme.dart';

/// The application shell.
class RecordApp extends StatelessWidget {
  /// Creates the shell, optionally opening straight onto [openOnBoot].
  const RecordApp({
    required this.bootChapter,
    this.openOnBoot,
    super.key,
  });

  /// Which chapter [openOnBoot] should be scrolled to.
  final int bootChapter;

  /// A record to open immediately, or null to stay on the index.
  final DemoCharacter? openOnBoot;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wand of Saves — Record',
      debugShowCheckedModeBanner: false,
      theme: RecordTheme.light,
      darkTheme: RecordTheme.dark,
      home: HomeScreen(
        characters: const [aard, nadia],
        bootChapter: bootChapter,
        openOnBoot: openOnBoot,
      ),
    );
  }
}
