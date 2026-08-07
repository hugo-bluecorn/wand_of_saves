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

/// One field of a binary structure: where it starts, and how wide it is.
///
/// Implemented by **enhanced enums** (D6), so a format's layout is a *value*
/// per field rather than a bag of loose integers. The point is not tidiness:
/// because an enum's `values` is iterable, the layout's own consistency
/// becomes a test — no overlapping fields, everything inside the struct, and
/// the last field ending exactly at the declared size. That last assertion is
/// the fact whose absence caused the stride bug.
///
/// See `test/support/layout.dart` for the check, and
/// `docs/findings/verified-format-offsets.md` for where the numbers come from.
/// ### Why there is no `name` member here
///
/// An earlier draft required `String get name`, on the assumption that an
/// enum's `.name` would satisfy it. **It does not.** `dart:core` declares it
/// as `extension EnumName on Enum`, and the SDK says why
/// (`lib/core/enum.dart:134-137`): it is an extension *"instead of an instance
/// method in order to allow enum values to have the name `name`"*. So `.name`
/// is available when the static type is the enum, but it cannot discharge an
/// interface obligation, and `enum X implements FormatField` fails to compile.
///
/// Diagnostics therefore use [Object.toString], which for an enum yields
/// `GamHeaderField.partyGold` — a better label than the bare identifier
/// anyway. Non-enum implementers should override `toString`.
abstract interface class FormatField {
  /// Byte offset from the start of the structure this field belongs to.
  int get offset;

  /// Width of the field in bytes.
  int get length;
}
