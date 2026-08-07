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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Entry point.
///
/// Still Flutter's placeholder body — the real shell comes from
/// `planning/architecture.md`. The one thing already in place is
/// [ProviderScope]: Riverpod without code generation is a closed decision (D2),
/// and the scope has to wrap the whole tree, so it belongs here from the start.
void main() {
  runApp(const ProviderScope(child: WandOfSavesApp()));
}

/// The application root.
///
/// A placeholder shell. Theming here is deliberately minimal — the real
/// `ThemeData` belongs in `ui/core/` per `planning/architecture.md`.
class WandOfSavesApp extends StatelessWidget {
  /// Creates the application root.
  const WandOfSavesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wand of Saves',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      home: const Scaffold(body: Center(child: Text('Wand of Saves'))),
    );
  }
}
