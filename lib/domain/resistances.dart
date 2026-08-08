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

part 'resistances.mapper.dart';

/// Percentage resistance to each damage type.
///
/// Eleven contiguous bytes at CRE `0x59`-`0x63`. Zero across the board on
/// every fixture, which is exactly why the offsets needed a check that a run
/// of zeroes could not pass: a reader one byte early lands on the saving
/// throws, which are not zero.
@MappableClass()
class Resistances with ResistancesMappable {
  /// Creates a set of resistances.
  const Resistances({
    required this.fire,
    required this.cold,
    required this.electricity,
    required this.acid,
    required this.magic,
    required this.magicFire,
    required this.magicCold,
    required this.slashing,
    required this.crushing,
    required this.piercing,
    required this.missile,
  });

  /// Resistant to nothing, which is what every party member in the fixture is.
  static const Resistances none = Resistances(
    fire: 0,
    cold: 0,
    electricity: 0,
    acid: 0,
    magic: 0,
    magicFire: 0,
    magicCold: 0,
    slashing: 0,
    crushing: 0,
    piercing: 0,
    missile: 0,
  );

  /// Fire resistance.
  final int fire;

  /// Cold resistance.
  final int cold;

  /// Electricity resistance.
  final int electricity;

  /// Acid resistance.
  final int acid;

  /// Magic resistance.
  final int magic;

  /// Magic fire resistance.
  final int magicFire;

  /// Magic cold resistance.
  final int magicCold;

  /// Slashing resistance.
  final int slashing;

  /// Crushing resistance.
  final int crushing;

  /// Piercing resistance.
  final int piercing;

  /// Missile resistance.
  final int missile;
}
