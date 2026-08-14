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

/// One item the game ships, as a picker needs to know it.
///
/// ⚠️ **Keyed by [resref] and nothing else.** `BOOT01`, `BOOTDRIZ`, `DASBOOT`
/// and `TROLLBOO` all resolve to "The Paws of the Cheetah" — the fifth time
/// this project has met "a name is not a key", after `KIT.IDS`, two `AXE` rows
/// in `weapprof.2da`, `FALLEN_CLERIC` and `weapprof`'s padding band.
class ItemEntry {
  /// Records an item.
  const ItemEntry({
    required this.resref,
    required this.itemType,
    this.identifiedName,
    this.unidentifiedName,
    this.description,
    this.identifiedNameStrref,
    this.unidentifiedNameStrref,
    this.descriptionStrref,
    this.isMovable = true,
    this.isCursed = false,
  });

  /// The `ITM` resource, e.g. `BOOT01`. Upper case.
  final String resref;

  /// What kind of item, as `ITEMCAT.IDS` numbers it.
  final int itemType;

  /// Whether the engine will let this item be moved at all.
  ///
  /// ⚠️ **Clear on 432 of the 1,428 named items an installation ships**, and
  /// the reason this field exists: `BOW99` was added to a character who could
  /// then neither equip it nor move it out. IESDP names ITM header bit 2
  /// "Movable / Droppable"; BioWare authors it clear on plot items, on creature
  /// attacks, and on a handful of ordinary-looking weapons.
  ///
  /// Defaults to `true` so a test fixture describes an ordinary item without
  /// having to say so.
  final bool isMovable;

  /// Whether the engine will refuse to let it be taken off once worn.
  ///
  /// ⚠️ **Not the same as [isMovable], and deliberately not a reason to refuse
  /// it.** IESDP's bit 4 means "cannot be unequipped": the item carries, moves
  /// and changes hands perfectly well until somebody equips it, and the game's
  /// own shops sell them. Worth saying; not worth overruling the player about.
  final bool isCursed;

  /// The name once identified, or `null` before the talk table is merged.
  final String? identifiedName;

  /// The name before identification — often just "Boots".
  ///
  /// ⚠️ **Not a fallback to ignore in a search box.** Ten of the fourteen items
  /// whose name contains "boot" are called simply *Boots* here, and that is
  /// what a player who has not identified one actually sees.
  final String? unidentifiedName;

  /// The identified description.
  ///
  /// ⚠️ **Carried because the ask depends on it.** "Boots of Speed" matches no
  /// item *name* in BG:EE and three item *descriptions*.
  final String? description;

  /// Strref of [identifiedName], before resolution.
  final int? identifiedNameStrref;

  /// Strref of [unidentifiedName], before resolution.
  final int? unidentifiedNameStrref;

  /// Strref of [description], before resolution.
  final int? descriptionStrref;

  /// What to show a player, preferring the identified name.
  ///
  /// Falls back to the resref, which is never empty — a row with no label at
  /// all is worse than a row labelled with the thing you can search for.
  String get label =>
      _firstNonEmpty(identifiedName, unidentifiedName) ?? resref;

  /// Whether this is worth offering at all.
  ///
  /// ⚠️ **The second half of a two-stage filter.** `Itm.hasName` drops the 102
  /// items that name no string; this drops the five more whose strref resolves
  /// to *empty text*, which only the talk table can see. 102 + 5 = the 107
  /// measured on 2026-08-12.
  bool get isOfferable =>
      _firstNonEmpty(identifiedName, unidentifiedName) != null;

  /// The name the *game* would draw, given whether the carrier identified it.
  ///
  /// ⚠️ **A rule about the engine, not a layout choice, which is why it lives
  /// here and not in a widget.** With the flag clear BG:EE shows the plain name
  /// — "Belt", never "Belt of Antipode" — and `Aard1.chr` carries exactly that
  /// case. Two surfaces ask this question, the backpack cell and the equipped
  /// row, and a copy of the rule in each is how they drift apart.
  ///
  /// Falls back to whichever name exists when the other does not, and to `null`
  /// when neither does; the resref is always there to show instead.
  String? nameWhen({required bool identified}) => identified
      ? _firstNonEmpty(identifiedName, unidentifiedName)
      : _firstNonEmpty(unidentifiedName, identifiedName);

  /// A copy carrying resolved text.
  ItemEntry withNames({
    String? identified,
    String? unidentified,
    String? description,
  }) => ItemEntry(
    resref: resref,
    itemType: itemType,
    identifiedName: identified,
    unidentifiedName: unidentified,
    description: description,
    identifiedNameStrref: identifiedNameStrref,
    unidentifiedNameStrref: unidentifiedNameStrref,
    descriptionStrref: descriptionStrref,
    isMovable: isMovable,
    isCursed: isCursed,
  );

  static String? _firstNonEmpty(String? a, String? b) {
    if (a != null && a.trim().isNotEmpty) return a;
    if (b != null && b.trim().isNotEmpty) return b;
    return null;
  }

  @override
  String toString() => 'ItemEntry($resref, $label)';
}

/// How a search result was reached.
///
/// ⚠️ **The tiers are the feature, not a nicety.** Searching item *names* for
/// "Boots of Speed" returns nothing — BG:EE calls it "The Paws of the Cheetah".
/// It matches three *descriptions*. But searching descriptions for "speed"
/// alone returns 238 hits, so description matches must be separable rather than
/// mixed into the list.
enum ItemMatch {
  /// The query is the item's resref.
  resref,

  /// The query appears in one of its two names.
  name,

  /// The query appears only in its description.
  description,
}

/// Every item the installation ships, searchable.
class ItemCatalogue {
  /// Wraps [entries], keyed by resref.
  const ItemCatalogue(this.entries);

  /// Nothing — a machine with no game installed.
  static const ItemCatalogue empty = ItemCatalogue({});

  /// Every item, by resref.
  final Map<String, ItemEntry> entries;

  /// The items worth offering, in name order.
  List<ItemEntry> get offerable {
    final found = entries.values.where((e) => e.isOfferable).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return found;
  }

  /// Items matching [query], best tier first, and how many were withheld.
  ///
  /// Returns `(entry, how)` per result so the screen can label the description
  /// group rather than leaving a reader wondering why a row appeared.
  ///
  /// ⚠️ **An item the engine cannot move is never offered**, however well it
  /// matches. Adding one produces a row that can be neither equipped nor handed
  /// on — measured on `BOW99`, and true of 432 of the 1,428 named items. They
  /// are *counted* rather than silently dropped: sixty greyed rows would be
  /// wallpaper, but saying nothing would hide a third of the catalogue.
  ({List<({ItemEntry entry, ItemMatch how})> results, int withheld}) search(
    String query, {
    int limit = 60,
  }) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return (results: const [], withheld: 0);

    final byResref = <ItemEntry>[];
    final byName = <ItemEntry>[];
    final byDescription = <ItemEntry>[];
    var withheld = 0;

    for (final entry in offerable) {
      final matches =
          entry.resref.toLowerCase() == needle ||
          entry.resref.toLowerCase().contains(needle) ||
          _has(entry.identifiedName, needle) ||
          _has(entry.unidentifiedName, needle) ||
          _has(entry.description, needle);
      if (matches && !entry.isMovable) {
        withheld++;
        continue;
      }
      if (!matches) continue;

      if (entry.resref.toLowerCase() == needle) {
        byResref.add(entry);
      } else if (entry.resref.toLowerCase().contains(needle) ||
          _has(entry.identifiedName, needle) ||
          _has(entry.unidentifiedName, needle)) {
        byName.add(entry);
      } else {
        byDescription.add(entry);
      }
    }

    return (
      results: [
        for (final e in byResref) (entry: e, how: ItemMatch.resref),
        for (final e in byName) (entry: e, how: ItemMatch.name),
        for (final e in byDescription) (entry: e, how: ItemMatch.description),
      ].take(limit).toList(),
      withheld: withheld,
    );
  }

  static bool _has(String? text, String needle) =>
      text != null && text.toLowerCase().contains(needle);
}
