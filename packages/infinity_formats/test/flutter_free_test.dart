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

import 'package:test/test.dart';

/// The architecture rule that has to hold from file one: `infinity_formats` is pure
/// Dart and never imports Flutter. Running this suite under `dart test` already
/// makes a `package:flutter` import a compile error, but only for files the
/// suite actually reaches. This walks every source file so the rule covers the
/// whole package, including code no test imports yet.
///
/// See planning/architecture.md.
void main() {
  test('no source file imports package:flutter', () {
    final lib = Directory('lib');
    expect(
      lib.existsSync(),
      isTrue,
      reason: 'run from packages/infinity_formats',
    );

    final offenders = <String>[];
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (RegExp(r'''^\s*import\s+['"]package:flutter/''').hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'infinity_formats must stay Flutter-free; offending imports: $offenders',
    );
  });
}
