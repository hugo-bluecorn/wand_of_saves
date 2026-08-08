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

/// The application's Material 3 theme, defined once.
///
/// Centralised per `context/flutter-ai-rules.md`: no widget defines its own
/// colours, so a change here reaches the whole app and contrast can be reasoned
/// about in one place.
///
/// Both brightnesses are generated from a single seed with
/// [ColorScheme.fromSeed], which is what keeps the palette harmonious — and
/// keeps light and dark genuinely equivalent rather than one being an
/// afterthought.
abstract final class AppTheme {
  /// Seed colour: weathered bronze.
  ///
  /// Chosen to sit alongside the game's own art, which the UI shows a great
  /// deal of — save screenshots and character portraits are the loudest things
  /// on screen, so the chrome around them is deliberately quiet.
  static const Color seed = Color(0xFF8C6A3F);

  /// The light theme.
  static ThemeData get light => _themeFor(Brightness.light);

  /// The dark theme.
  static ThemeData get dark => _themeFor(Brightness.dark);

  static ThemeData _themeFor(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colors,
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
