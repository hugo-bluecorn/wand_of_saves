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

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/data/repositories/save_game_repository.dart';
import 'package:wand_of_saves/domain/save_slot.dart';
import 'package:wand_of_saves/ui/saves/save_browser_viewmodel.dart';

SaveSlot slot(String label) => SaveSlot(
  directoryName: '000000022-$label',
  path: '/tmp/$label',
  area: 'AR2600',
  gameTime: 4791,
  partySize: 1,
  gold: 161,
  modified: DateTime(2026),
);

/// Substituted for the real repository through a ProviderScope override —
/// the seam the architecture exists to provide.
class _FakeRepository implements SaveGameRepository {
  _FakeRepository({this.slots = const [], this.failure});

  List<SaveSlot> slots;
  Exception? failure;
  int listCalls = 0;

  @override
  Future<List<SaveSlot>> listSlots() async {
    listCalls++;
    if (failure != null) throw failure!;
    return slots;
  }

  @override
  Future<Gam> load(SaveSlot slot) => throw UnimplementedError();
}

void main() {
  // ProviderContainer.test disposes itself via addTearDown; disposing a plain
  // container by hand raced the in-flight build and hung the error test.
  ProviderContainer containerWith(_FakeRepository repository) =>
      ProviderContainer.test(
        overrides: [saveGameRepositoryProvider.overrideWithValue(repository)],
      );

  test('exposes the slots the repository returns', () async {
    final container = containerWith(
      _FakeRepository(slots: [slot('last'), slot('start')]),
    );

    final slots = await container.read(saveBrowserProvider.future);

    expect(slots.map((s) => s.label), ['last', 'start']);
  });

  test('has no slots when the save directory is empty', () async {
    final container = containerWith(_FakeRepository());

    expect(await container.read(saveBrowserProvider.future), isEmpty);
  });

  test('surfaces a load failure as an error state, not a crash', () async {
    // A missing or unreadable save directory is an ordinary situation on a
    // machine where the game is not installed, and the screen has to say so
    // rather than throwing into the widget tree.
    final container = containerWith(
      _FakeRepository(failure: const FileSystemException('nope')),
    );

    // Read directly rather than through `.future`: that completes normally on
    // success but never settles when build() throws. The claim under test is
    // only that the failure lands in the state instead of escaping.
    final subscription = container.listen(saveBrowserProvider, (_, _) {});
    addTearDown(subscription.close);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final state = subscription.read();

    expect(
      state.hasError,
      isTrue,
      reason: 'the failure escaped instead of landing in the state',
    );

    expect(
      container.read(saveBrowserProvider).error,
      isA<FileSystemException>(),
    );
  });

  test('refresh re-reads the directory', () async {
    // The game is very likely running while this app is open, so the first
    // read cannot be assumed to stay true.
    final repository = _FakeRepository(slots: [slot('last')]);
    final container = containerWith(repository);
    await container.read(saveBrowserProvider.future);

    repository.slots = [slot('last'), slot('newer')];
    await container.read(saveBrowserProvider.notifier).refresh();

    expect(repository.listCalls, 2);
    expect(container.read(saveBrowserProvider).value, hasLength(2));
  });
}
