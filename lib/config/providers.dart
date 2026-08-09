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

/// The dependency graph, declared by hand.
///
/// No `@riverpod`, no `*.g.dart` for providers (D2) — these are written out as
/// top-level finals so the graph is readable in one place rather than inferred
/// from annotations scattered across the tree. Riverpod *is* the DI container
/// here (D7); there is no second wiring mechanism.
///
/// Overriding any of these in a `ProviderScope` is the testing seam, which is
/// why the repository is an interface.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod keeps the family provider *types* in its own `misc` library, since
// they are rarely written out. `specify_nonobvious_property_types` requires
// naming this one, so the import is the honest way to satisfy it (D8).
import 'package:flutter_riverpod/misc.dart';
import 'package:wand_of_saves/data/repositories/character_file_repository.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/repositories/save_game_repository.dart';
import 'package:wand_of_saves/data/repositories/string_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/data/services/portrait_import_service.dart';
import 'package:wand_of_saves/data/services/recycle_service.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';

/// Locates the game installation and save directory on this machine.
final gameProfileServiceProvider = Provider<GameProfileService>(
  (ref) => const GameProfileService(),
);

/// Source of truth for savegames.
final saveGameRepositoryProvider = Provider<SaveGameRepository>(
  (ref) => FileSaveGameRepository(
    profile: ref.watch(gameProfileServiceProvider),
  ),
);

/// Source of truth for exported characters — the `.chr` files beside the saves.
///
/// A peer of [saveGameRepositoryProvider], not a detail of it: a character file
/// is a document in its own right, and one this app creates never came from a
/// savegame at all.
final characterFileRepositoryProvider = Provider<CharacterFileRepository>(
  (ref) => FileCharacterFileRepository(
    profile: ref.watch(gameProfileServiceProvider),
  ),
);

/// Moves deleted saves and characters somewhere they can be fetched back from.
///
/// ⚠️ **Deletion is the only operation in this app with no `.bak`**, so it gets
/// one of its own: nothing is unlinked, everything is moved beside the save
/// root where neither this app nor the game will look.
final recycleServiceProvider = Provider<RecycleService>(
  (ref) => RecycleService(profile: ref.watch(gameProfileServiceProvider)),
);

/// The game's own rules tables.
///
/// A snapshot generated from IESDP's copies of the shipped `2DA` and `IDS`
/// files, which is right for an unmodded install. It is a provider so Phase
/// 3's resource index can override it with the player's actual files — a
/// modded game has different tables, and nothing above this should have to
/// know which it got.
final gameRulesProvider = Provider<GameRules>(
  (ref) => const GeneratedGameRules(),
);

/// Source of truth for the rules tables inside the game's own archives.
///
/// **Not the same thing as [gameRulesProvider], and the difference is D11.**
/// That one is a snapshot generated from IESDP, which is right for tables of
/// pure numbers. This one reads the player's installation, which is the only
/// correct source for anything whose values are string references — IESDP
/// ships the BG2:EE `weapprof.2da`, and its strrefs name tutorial prose in a
/// BG:EE talk table.
///
/// On a machine with no game installed this answers an empty catalogue —
/// no second implementation, because there is no open file to stand in for.
final resourceRepositoryProvider = Provider<ResourceRepository>(
  (ref) => ResourceRepository(ref.watch(gameProfileServiceProvider)),
);

/// Puts a portrait of the player's own where the engine looks first.
///
/// The whole of what a "custom portrait" is: a loose file in
/// `<user data>/portraits/` shadows a packed one of the same name, so the same
/// two CRE resrefs serve either and nothing else in the app needs to know
/// which it got.
final portraitImportServiceProvider = Provider<PortraitImportService>(
  (ref) => PortraitImportService(
    profile: ref.watch(gameProfileServiceProvider),
  ),
);

/// A character's portrait, by base name — the picture the record names.
///
/// ⚠️ **Not the same thing as a save's `PORTRT<n>.bmp`.** That sidecar is what
/// the engine drew when the file was written, hit points baked in, and it goes
/// stale as soon as anything is edited; an exported character has none at all.
/// This is the clean portrait the creature record points at, and it is the only
/// one that responds to a change.
///
/// Keyed by base name, so the `…M` variant is chosen here rather than at every
/// call site. `null` when there is no game installed, no such portrait, or the
/// character names none — all ordinary, and all drawn as a placeholder.
final FutureProviderFamily<Uint8List?, String> portraitProvider =
    FutureProvider.family<Uint8List?, String>((ref, baseName) {
      if (baseName.isEmpty) return Future.value();
      return ref.watch(resourceRepositoryProvider).portrait('${baseName}M');
    });

/// Source of truth for the game's displayable text.
///
/// Which `dialog.tlk` to open is a fact about this machine, so the choice is
/// made here from the profile service rather than inside the repository. A
/// machine with saves but no game installed gets [AbsentStringRepository] — an
/// explicit state, not a null to thread through every caller.
final stringRepositoryProvider = Provider<StringRepository>((ref) {
  final path = ref.watch(gameProfileServiceProvider).findDialogTlk();
  if (path == null) return const AbsentStringRepository();

  final repository = TlkStringRepository(path: path);
  ref.onDispose(repository.close);
  return repository;
});
