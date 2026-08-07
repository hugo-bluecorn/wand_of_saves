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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/save_slot.dart';

/// ViewModel for the save browser, paired 1:1 with `SaveBrowserView`.
///
/// Holds the presentation state for the screen and exposes [refresh] as its
/// one command. It talks to the repository and never to `infinity_formats`,
/// which is what lets a test swap the repository out entirely.
class SaveBrowserViewModel extends AsyncNotifier<List<SaveSlot>> {
  @override
  Future<List<SaveSlot>> build() =>
      ref.watch(saveGameRepositoryProvider).listSlots();

  /// Re-reads the save directory.
  ///
  /// Saves change underneath us — the game is very likely running while this
  /// app is open — so the browser cannot assume its first read stays true.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(saveGameRepositoryProvider).listSlots(),
    );
  }
}

/// The save browser's state: the slots on disk, or a load failure.
final saveBrowserProvider =
    AsyncNotifierProvider<SaveBrowserViewModel, List<SaveSlot>>(
      SaveBrowserViewModel.new,
    );
