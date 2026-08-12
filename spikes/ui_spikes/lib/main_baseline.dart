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

/// The **before** picture: the real application's character sheet.
///
/// This is not a spike. It boots the app's own `CharacterPanel`, its own
/// `AppTheme`, and its own widgets, with a character standing in for one the
/// repository would have loaded — so the comparison against the three spikes
/// is against the actual current UI rather than a redrawing of it from memory.
///
/// It exists because **nothing on this machine can drive the pointer**: the app
/// cannot be clicked from the save browser through to a character sheet, so the
/// sheet has to be booted into directly.
///
/// Run:
/// ```sh
/// fvm flutter run -d linux -t lib/main_baseline.dart
/// SPIKE_WIDTH=1920 SPIKE_HEIGHT=1080 ./build/.../ui_spikes
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_spikes/demo/boot.dart';
import 'package:wand_of_saves/domain/ability_scores.dart';
import 'package:wand_of_saves/domain/armor_class_modifiers.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/resistances.dart';
import 'package:wand_of_saves/domain/saving_throws.dart';
import 'package:wand_of_saves/domain/thief_skills.dart';
import 'package:wand_of_saves/ui/character/character_panel.dart';
import 'package:wand_of_saves/ui/core/theme.dart';

/// Boots the real character sheet.
void main() => runApp(const ProviderScope(child: _BaselineApp()));

class _BaselineApp extends StatelessWidget {
  const _BaselineApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wand of Saves — current UI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const _BaselineShell(),
    );
  }
}

class _BaselineShell extends StatelessWidget {
  const _BaselineShell();

  @override
  Widget build(BuildContext context) {
    // The controller belongs above the panel, exactly as the party shell and
    // the character-file shell both place it. `initialIndex` is how the other
    // three tabs get photographed at all — they cannot be clicked to.
    return DefaultTabController(
      length: CharacterPanel.tabCount,
      initialIndex: requestedTab.clamp(0, CharacterPanel.tabCount - 1),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AARD.CHR'),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.undo)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.redo)),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: CharacterPanel(
          character: _aard,
          onEdit: (_) {},
          warnsAboutImport: true,
        ),
      ),
    );
  }
}

/// Aard, taken off BG:EE's own record screen — the same numbers the spikes use.
const Character _aard = Character(
  name: 'Aard',
  nameStrref: -1,
  creResref: '*HARBASE',
  partyOrder: 0,
  structOffset: 0,
  creOffset: 0,
  creLength: 0,
  currentHitPoints: 18,
  maximumHitPoints: 12,
  experience: 2000,
  gold: 189,
  thac0: 15,
  armorClass: 6,
  armorClassNatural: 10,
  levelFirstClass: 2,
  levelSecondClass: 1,
  levelThirdClass: 0,
  reputation: 10,
  classId: 7,
  raceId: 2,
  alignmentId: 0x21,
  genderId: 1,
  kitId: 0x40000000,
  abilities: AbilityScores(
    strength: 19,
    strengthBonus: 0,
    dexterity: 17,
    constitution: 18,
    intelligence: 18,
    wisdom: 9,
    charisma: 9,
  ),
  savingThrows: SavingThrows(
    death: 14,
    wands: 16,
    polymorph: 15,
    breath: 17,
    spells: 17,
  ),
  resistances: Resistances.none,
  thiefSkills: ThiefSkills(
    hideInShadows: 0,
    detectIllusion: 0,
    setTraps: 0,
    lore: 3,
    lockpicking: 0,
    moveSilently: 0,
    findTraps: 0,
    pickPockets: 0,
  ),
  armorClassModifiers: ArmorClassModifiers.none,
  numberOfAttacks: 2,
  morale: 10,
  moraleBreak: 0,
  luck: 0,
  fatigue: 0,
  intoxication: 0,
  turnUndeadLevel: 0,
  // The anomaly the spikes also carry: a Fighter / Mage cannot allocate this.
  trackingSkill: 25,
);
