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

/// The sum, on its own full-width line beneath the value it explains.
///
/// ⚠️ **No `maxLines` and no `TextOverflow.ellipsis`, ever.** The current
/// application truncates `stored 12, +4/level from Constit…`, which turns the
/// one line that answers *why* into a line that raises the question. This
/// widget wraps instead, and every caller gives it the full width of its row.
class ArithmeticLine extends StatelessWidget {
  /// Draws [text] as the helper line.
  const ArithmeticLine(this.text, {super.key});

  /// The arithmetic itself, exactly as the data supplies it.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
