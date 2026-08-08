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

import 'package:dart_mappable/dart_mappable.dart';

part 'thief_skills.mapper.dart';

/// The thief skills and Lore, **as the savegame stores them**.
///
/// ⚠️ **Allocated points, not the skill the game shows.** Measured
/// 2026-08-08: a thief storing Move Silently 15 displayed 35, and two
/// characters both storing Lore 3 displayed 10 and 15. The engine adds class,
/// race and Dexterity bonuses before printing them.
///
/// Same hazard as hit points and THAC0, and it is handled the same way — the
/// panel labels these as bases rather than inventing a derived figure. Turning
/// 15 into 35 needs `skilldex.2da` and the class tables, which is recorded as
/// deferred rather than guessed at.
///
/// Lore rides with them because the engine treats it identically, even though
/// every class has it and only a thief has the rest.
@MappableClass()
class ThiefSkills with ThiefSkillsMappable {
  /// Creates a set of skills.
  const ThiefSkills({
    required this.hideInShadows,
    required this.detectIllusion,
    required this.setTraps,
    required this.lore,
    required this.lockpicking,
    required this.moveSilently,
    required this.findTraps,
    required this.pickPockets,
  });

  /// Every skill zero — what a character with no points allocated stores.
  static const ThiefSkills none = ThiefSkills(
    hideInShadows: 0,
    detectIllusion: 0,
    setTraps: 0,
    lore: 0,
    lockpicking: 0,
    moveSilently: 0,
    findTraps: 0,
    pickPockets: 0,
  );

  /// Hide in Shadows. Stored apart from the rest, at CRE `0x45`.
  final int hideInShadows;

  /// Detect Illusion.
  final int detectIllusion;

  /// Set Traps.
  final int setTraps;

  /// Lore.
  final int lore;

  /// Lockpicking — the record screen's "Open Locks".
  final int lockpicking;

  /// Move Silently.
  final int moveSilently;

  /// Find/disarm traps — "Find Traps".
  final int findTraps;

  /// Pick Pockets.
  final int pickPockets;
}
