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

import 'dart:convert';
import 'dart:typed_data';

import 'package:infinity_formats/src/exceptions.dart';
import 'package:infinity_formats/src/spec/spl_v1.dart';

/// A spell resource, read only as deeply as listing one needs.
///
/// **Deliberately shallow, exactly as `Effect` is.** A spell's extended headers
/// and feature blocks are what it *does*; this reads what it *is*, which is
/// what a character-creation screen has to show. The rest arrives when
/// something needs it.
///
/// Like the other models here, **the bytes are the model** — every accessor
/// reads through [bytes], so there is no parsed copy to drift.
final class Spl {
  /// Wraps [bytes], which must already be validated.
  const Spl.trusted(this.bytes);

  /// The complete resource, exactly as read.
  final Uint8List bytes;

  int _read(SplHeaderField field) {
    final view = ByteData.sublistView(bytes);
    return switch ((field.length, field.signed)) {
      (1, false) => view.getUint8(field.offset),
      (2, false) => view.getUint16(field.offset, Endian.little),
      (4, false) => view.getUint32(field.offset, Endian.little),
      (4, true) => view.getInt32(field.offset, Endian.little),
      _ => throw InfinityFormatException.unreadableField(
        what: '$field',
        length: field.length,
      ),
    };
  }

  /// Strref of the displayed name, or `null` when the header carries none.
  ///
  /// `null` rather than `-1`, because "this spell has no name" is the question
  /// every caller is really asking — it is what tells a spell somebody can
  /// learn from a resource the engine casts at itself.
  int? get nameStrref {
    final strref = _read(SplHeaderField.name);
    return strref < 0 ? null : strref;
  }

  /// Strref of the description, or `null` when there is none.
  int? get descriptionStrref {
    final strref = _read(SplHeaderField.description);
    return strref < 0 ? null : strref;
  }

  /// What kind of spell this is, or `null` for a value the format leaves open.
  SplType? get type => SplType.forStored(_read(SplHeaderField.spellType));

  /// The spell's level, as a player counts it.
  int get level => _read(SplHeaderField.level);

  /// Its school, as `mschool.2da` numbers them. `0` is none.
  int get school => _read(SplHeaderField.school);

  /// Which specialists may not learn this spell, as a bit per school.
  ///
  /// See [SplHeaderField.exclusionFlags]. Prefer [excludesSpecialist] to
  /// reading the bits at a call site.
  int get exclusionFlags => _read(SplHeaderField.exclusionFlags);

  /// The bit that excludes the first specialist school, `ABJURER`.
  ///
  /// `mschool.2da` numbers the schools from 1 and the exclusion bits start at
  /// 6, so a school's bit is its row number plus five.
  static const int firstSchoolExclusionBit = 6;

  /// The last school with an exclusion bit of its own, `TRANSMUTER`.
  static const int lastSchoolExcluded = 8;

  /// Whether a specialist of [school] is barred from this spell.
  ///
  /// [school] is the `mschool.2da` row number, which is what a creature's kit
  /// resolves to. `false` for `0`, which is no school at all, and for anything
  /// past the eight the format has a bit for — `GENERALIST` is bit 14 and
  /// means wild magic rather than an opposed school.
  bool excludesSpecialist(int school) {
    if (school < 1 || school > lastSchoolExcluded) return false;
    return exclusionFlags & (1 << (firstSchoolExclusionBit + school - 1)) != 0;
  }

  @override
  String toString() => 'Spl(${type?.name ?? 'unknown'} level $level)';
}

/// Reads an `SPL V1` resource.
class SplCodec {
  const SplCodec._();

  /// The signature every spell resource begins with.
  static const String signature = 'SPL ';

  /// Parses [bytes] as a spell.
  ///
  /// Checks the signature and the length and nothing else: this reads five
  /// fields of a header, so there is no section chain to reconcile and no
  /// writer to keep honest. The version is deliberately **not** checked — every
  /// `SPL` in a BG:EE installation is `V1`, and a codec that refused an
  /// unfamiliar one would drop a modded spell from a list rather than show it.
  ///
  /// Throws [InfinityFormatException] if [bytes] is not a spell header.
  static Spl decode(Uint8List bytes, {Object? source}) {
    if (bytes.length < splHeaderLength) {
      throw InfinityFormatException.truncated(
        what: 'an SPL header',
        expected: splHeaderLength,
        actual: bytes.length,
        source: source,
      );
    }
    final found = latin1.decode(bytes.sublist(0, 4));
    if (found != signature) {
      throw InfinityFormatException.badSignature(
        expected: signature,
        found: found,
        source: source,
      );
    }
    return Spl.trusted(bytes.asUnmodifiableView());
  }
}
