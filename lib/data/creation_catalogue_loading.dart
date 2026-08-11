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

/// What a new character may be, with the words the game would print.
///
/// **A use-case, exactly as `loadRulesCatalogues` is**, and here for the same
/// reason: it joins two repositories — the player's own `2DA` tables for the
/// rules, and their talk table for the text — and repositories must never be
/// aware of each other.
///
/// ⚠️ **Without this join a specialisation cannot be named at all.** The kit
/// table's row label for the Ranger's first kit is `FERALAN`; what the engine
/// draws is *Archer*, and only strref 25335 says so.
library;

import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/repositories/string_repository.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';

/// Reads the six tables and resolves every strref they carry.
///
/// One pass over a **set** of strrefs, so a description shared by several
/// choices — `clastext.2da` gives three classes the same `BRIEFDESC` — is
/// looked up once rather than once per choice.
///
/// An empty catalogue on a machine with no game installed. That is an ordinary
/// state: the app opens savegames there, it simply cannot make a character, and
/// the flow says so rather than failing to draw.
Future<CreationCatalogue> loadCreationCatalogue({
  required ResourceRepository resources,
  required StringRepository strings,
  required GameRules rules,
}) async {
  final catalogue = await resources.creationCatalogue(rules: rules);

  final wanted = <int>{
    for (final choice in [
      ...catalogue.races,
      ...catalogue.classesByRace.values.expand((classes) => classes),
      ...catalogue.kitsByClass.values.expand((kits) => kits),
    ]) ...[
      if (choice.nameStrref case final int strref) strref,
      if (choice.descriptionStrref case final int strref) strref,
    ],
    // Spells carry theirs in the `SPL` header rather than in a table, and are
    // the reason there is anything to look up at all: `SPWI112` is *Magic
    // Missile* only once strref 12052 is resolved.
    for (final spell in catalogue.wizardSpells) ...[
      if (spell.nameStrref case final int strref) strref,
      if (spell.descriptionStrref case final int strref) strref,
    ],
    // ⚠️ **Not carried by any choice, so easily missed.** The other strrefs
    // here come off a row this catalogue already holds; the alignments have no
    // row of their own -- `alignmnt.2da` says who may take which and carries no
    // names at all -- so the pairing lives in `alignmentNameStrrefs` and has to
    // be asked for explicitly. Without this the screen quietly falls back to
    // names derived from `ALIGNMEN.IDS`, which calls true neutral `NEUTRAL`.
    ...alignmentNameStrrefs.values,
    ...alignmentDescriptionStrrefs.values,
    // ⚠️ **`FLAILMORNINGSTAR` is not a name.** Without this the proficiency
    // step falls back to `weapprof.2da`'s row label, which is a join key with
    // the punctuation stripped out — the game writes "Flail/Morning Star".
    // The character sheet resolved these all along, through
    // `loadRulesCatalogues`; the creation flow reads its own catalogue and had
    // to ask for itself.
    for (final entry in catalogue.proficiencies.entries.values)
      if (entry.nameStrref case final int strref) strref,
  };

  return catalogue.withText({
    for (final strref in wanted)
      if (await strings.lookup(strref) case final String text) strref: text,
  });
}
