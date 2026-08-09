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

/// The rules tables a character sheet needs, with their names resolved.
///
/// **A use-case, and it is here because a second ViewModel now needs it.**
/// `PartyViewModel` carried this merge inline with a note saying it would move
/// the moment something else wanted it; `CharacterFileViewModel` is that
/// something else, and two copies of a cross-repository merge is how the two
/// screens start disagreeing about what a proficiency is called.
///
/// ⚠️ **The merge cannot live in a repository.** Repositories must never be
/// aware of each other, and this joins two: the player's `weapprof.2da` for the
/// rows, and their talk table for the text. That is D11 in practice — IESDP's
/// copy of the table is BG2:EE's and its strrefs name tutorial prose.
library;

import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/repositories/string_repository.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/domain/skill_catalogue.dart';

/// What a character sheet needs to name and bound what it shows.
typedef RulesCatalogues = ({
  ProficiencyCatalogue proficiencies,
  SkillCatalogue skills,
});

/// Reads both tables and resolves the names in them.
///
/// Empty catalogues on a machine with no game installed, which the panel reads
/// as "numbers without names" and "allow everything" rather than failing to
/// draw — refusing edits on the strength of a table that was never read would
/// be a broken screen.
Future<RulesCatalogues> loadRulesCatalogues({
  required ResourceRepository resources,
  required StringRepository strings,
}) async {
  final skills = await resources.thiefSkills();
  final catalogue = await resources.proficiencies();

  return (
    proficiencies: catalogue.withNames({
      for (final entry in catalogue.entries.values)
        if (entry.nameStrref case final int strref)
          if (await strings.lookup(strref) case final String name) strref: name,
    }),
    skills: skills,
  );
}
