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

part 'ability_scores.mapper.dart';

/// A character's six ability scores.
///
/// Grouped rather than spread across `Character` because they are edited as a
/// set — the stats editor changes several at once, and `copyWith` on a nested
/// value keeps that one call rather than six.
@MappableClass()
class AbilityScores with AbilityScoresMappable {
  /// Creates a set of ability scores.
  const AbilityScores({
    required this.strength,
    required this.strengthBonus,
    required this.dexterity,
    required this.constitution,
    required this.intelligence,
    required this.wisdom,
    required this.charisma,
  });

  /// The lowest value the engine stores.
  static const int minimum = 1;

  /// The highest value the engine stores. 18 is the human cap; 19-25 come
  /// from items and from non-human races.
  static const int maximum = 25;

  /// Strength.
  final int strength;

  /// Percentile strength, 0-100.
  ///
  /// Meaningful **only at [strength] 18**, where 18/00 is the top of the
  /// range. The engine stores it whatever the strength is, so it is carried
  /// rather than folded into [strength].
  final int strengthBonus;

  /// Dexterity.
  final int dexterity;

  /// Constitution.
  final int constitution;

  /// Intelligence.
  final int intelligence;

  /// Wisdom.
  final int wisdom;

  /// Charisma.
  final int charisma;

  /// Strength as the game writes it — `18/00` rather than `18` plus a field.
  String get strengthLabel => strength == 18 && strengthBonus > 0
      ? '18/${strengthBonus == 100 ? '00' : strengthBonus.toString().padLeft(2, '0')}'
      : '$strength';
}
