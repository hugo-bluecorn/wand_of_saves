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

part 'armor_class_modifiers.mapper.dart';

/// Armour class adjustments by attack type. **Negative is better**, as armour
/// class runs downwards.
///
/// ⚠️ **Signed, and that is not decoration.** IESDP gives all four as "2
/// (signed word)". Reading them unsigned turns a −3 into 65533, which is the
/// same defect that once rendered plate-and-shield armour class as 65534.
@MappableClass()
class ArmorClassModifiers with ArmorClassModifiersMappable {
  /// Creates a set of modifiers.
  const ArmorClassModifiers({
    required this.crushing,
    required this.missile,
    required this.piercing,
    required this.slashing,
  });

  /// No adjustment at all, which is every character in the fixture.
  static const ArmorClassModifiers none = ArmorClassModifiers(
    crushing: 0,
    missile: 0,
    piercing: 0,
    slashing: 0,
  );

  /// Adjustment against crushing attacks.
  final int crushing;

  /// Adjustment against missile attacks.
  final int missile;

  /// Adjustment against piercing attacks.
  final int piercing;

  /// Adjustment against slashing attacks.
  final int slashing;
}
