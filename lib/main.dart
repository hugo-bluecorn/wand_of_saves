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
import 'package:wand_of_saves/ui/core/theme.dart';
import 'package:wand_of_saves/ui/saves/save_browser_view.dart';

/// Entry point.
///
/// [ProviderScope] wraps the whole tree because Riverpod is this app's DI
/// container (D2, D7) — every service, repository and viewmodel is reached
/// through it.
void main() {
  runApp(const ProviderScope(child: WandOfSavesApp()));
}

/// The application root.
class WandOfSavesApp extends StatelessWidget {
  /// Creates the application root.
  const WandOfSavesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wand of Saves',
      // The banner sits exactly where the app bar's actions go, hiding them.
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const SaveBrowserView(),
    );
  }
}
