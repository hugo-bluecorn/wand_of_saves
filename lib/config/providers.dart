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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/repositories/save_game_repository.dart';
import 'package:wand_of_saves/data/repositories/string_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
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
