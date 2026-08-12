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

/// Spike B — **Record**: the character as one sheet you read top to bottom.
///
/// No tabs and no category navigation. A running head, an index rail that
/// tracks the reader, and one continuous document with editing in place. The
/// inventory is a chapter of it rather than a destination, which is this
/// approach's answer to the question the whole exercise is asking.
///
/// Run:
/// ```sh
/// fvm flutter run -d linux -t lib/main_record.dart
/// SPIKE_SCREEN=character SPIKE_TAB=3 ./ui_spikes
/// ```
///
/// `SPIKE_TAB` indexes the chapters —
/// `Character · Abilities · Skills · Combat · Proficiencies · Inventory ·
/// Notes` — and is clamped, so a number out of range is not a failure to
/// start. **`SPIKE_TAB=0` means offset 0**, so the cover is photographed
/// rather than skipped past.
library;

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/aard.dart';
import 'package:ui_spikes/demo/boot.dart';
import 'package:ui_spikes/record/app.dart';

/// Where the inventory sits in the chapter list.
const int _inventoryChapter = 5;

/// Boots the Record spike.
void main() {
  final screen = BootScreen.requested;
  final chapter = switch (screen) {
    BootScreen.home => 0,
    BootScreen.character => requestedTab,
    BootScreen.inventory => _inventoryChapter,
    // See main_workbench.dart: spells arrived after this spike was
    // frozen, so it opens on the document instead.
    BootScreen.spells => 0,
  };
  runApp(
    RecordApp(
      bootChapter: chapter,
      openOnBoot: screen == BootScreen.home ? null : aard,
    ),
  );
}
