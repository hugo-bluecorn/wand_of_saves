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

/// Merges the item list with the talk table.
///
/// **A use-case, not a repository.** `ResourceRepository` reads the archives
/// and `StringRepository` reads `dialog.tlk`; neither may know about the other,
/// so the merge belongs here — the same promotion `loadRulesCatalogues` made,
/// and the one `planning/architecture.md` predicted would happen "at the item
/// and spell pickers".
library;

import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/repositories/string_repository.dart';
import 'package:wand_of_saves/domain/item_catalogue.dart';

/// Every item the installation ships, named.
///
/// ⚠️ **This is where the second stage of the offerable filter lives**, and it
/// can only live here. `ResourceRepository.items()` already dropped the 102
/// items that name no string; five more carry a real strref pointing at *empty
/// text*, and telling those apart needs the talk table — which the format
/// package must never open (D11). 102 + 5 = the 107 measured on 2026-08-12.
/// [ItemEntry.isOfferable] is the predicate; nothing is dropped here, so a
/// caller that wants everything still can.
///
/// Measured 2026-08-12: 1,530 items and roughly 4,600 strref lookups in about
/// 146 ms end to end. That is why there is no paging, no debounce and no
/// isolate — the number was taken through this same `Tlk`, on the far side of
/// the talk table, rather than guessed from the archive read alone.
Future<ItemCatalogue> loadItemCatalogue({
  required ResourceRepository resources,
  required StringRepository strings,
}) async {
  final items = await resources.items();
  final named = <String, ItemEntry>{};

  for (final item in items) {
    named[item.resref] = item.withNames(
      identified: await _text(strings, item.identifiedNameStrref),
      unidentified: await _text(strings, item.unidentifiedNameStrref),
      description: await _text(strings, item.descriptionStrref),
    );
  }
  return ItemCatalogue(named);
}

Future<String?> _text(StringRepository strings, int? strref) async =>
    strref == null ? null : strings.lookup(strref);
