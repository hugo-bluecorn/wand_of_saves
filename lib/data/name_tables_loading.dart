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

/// What the installation calls races, classes and kits.
///
/// **A use-case, like `loadRulesCatalogues` and `loadCreationCatalogue`**, and
/// here for the same reason: it joins the player's `2DA` tables to their talk
/// table, and repositories must never be aware of each other.
///
/// ⚠️ **This is D13 in practice.** Everything it produces used to be derived
/// in `GameRules` from the IDS identifiers — which could only ever produce
/// English, needed a hand-maintained exception map for `Half-Orc`, and was
/// simply wrong for kits, where `FERALAN` is drawn as *Archer*.
library;

import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/repositories/string_repository.dart';
import 'package:wand_of_saves/domain/rules/name_tables.dart';

/// Reads the three name tables and resolves every strref in them.
///
/// Empty on a machine with no game installed, which is an ordinary state:
/// `GameRules` then falls back to deriving from the identifiers, because that
/// is the only thing left to do and a savegame still has to be readable.
Future<NameTables> loadNameTables({
  required ResourceRepository resources,
  required StringRepository strings,
}) async {
  final strrefs = await resources.nameStrrefs();

  // One lookup per distinct strref — several classes share a template.
  final wanted = <int>{
    ...strrefs.races.values,
    ...strrefs.classes.values,
    ...strrefs.kits.values,
  };
  final text = <int, String>{
    for (final strref in wanted)
      if (await strings.lookup(strref) case final String value) strref: value,
  };

  Map<K, String> resolve<K>(Map<K, int> source) => {
    for (final MapEntry(:key, value: strref) in source.entries)
      if (text[strref] case final String value)
        if (value.isNotEmpty) key: value,
  };

  return NameTables(
    raceNames: resolve(strrefs.races),
    classNames: resolve(strrefs.classes),
    kitNames: resolve(strrefs.kits),
  );
}
