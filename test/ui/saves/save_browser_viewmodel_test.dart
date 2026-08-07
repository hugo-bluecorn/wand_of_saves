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
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/ui/saves/save_browser_viewmodel.dart';

import '../../support/fakes.dart';

void main() {
  // ProviderContainer.test disposes itself via addTearDown; disposing a plain
  // container by hand raced the in-flight build and hung the error test.
  ProviderContainer containerWith(FakeSaveGameRepository repository) =>
      ProviderContainer.test(
        overrides: [saveGameRepositoryProvider.overrideWithValue(repository)],
      );

  test('exposes the slots the repository returns', () async {
    final container = containerWith(
      FakeSaveGameRepository(slots: [fakeSlot('last'), fakeSlot('start')]),
    );

    final slots = await container.read(saveBrowserProvider.future);

    expect(slots.map((s) => s.label), ['last', 'start']);
  });

  test('has no slots when the save directory is empty', () async {
    final container = containerWith(FakeSaveGameRepository());

    expect(await container.read(saveBrowserProvider.future), isEmpty);
  });

  test('surfaces a load failure as an error state, not a crash', () async {
    // A missing or unreadable save directory is an ordinary situation on a
    // machine where the game is not installed, and the screen has to say so
    // rather than throwing into the widget tree.
    final container = containerWith(
      FakeSaveGameRepository(failure: const FileSystemException('nope')),
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
    final repository = FakeSaveGameRepository(slots: [fakeSlot('last')]);
    final container = containerWith(repository);
    await container.read(saveBrowserProvider.future);

    repository.slots = [fakeSlot('last'), fakeSlot('newer')];
    await container.read(saveBrowserProvider.notifier).refresh();

    expect(repository.listCalls, 2);
    expect(container.read(saveBrowserProvider).value, hasLength(2));
  });
}
