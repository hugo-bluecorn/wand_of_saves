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

/// Thrown when a file does not match the format this library expects.
///
/// Implements [FormatException], so a caller who only cares that *some* input
/// was malformed can catch the core type, while the data layer can catch this
/// one and translate only this library's failures. That distinction is what the
/// repository layer needs to turn a codec failure into a domain failure.
///
/// This is an [Exception], never an [Error]: Effective Dart reserves `Error`
/// for programmatic mistakes, and malformed save data is not a programmer
/// mistake — reading other people's files is the whole job. See
/// `context/dart-data-modelling.md` §6.
///
/// Named constructors enumerate the failure taxonomy rather than leaving it to
/// free-text messages. Add one when a codec needs it, not before.
final class InfinityFormatException implements FormatException {
  const InfinityFormatException._(this.message, {this.source, this.offset});

  /// The file does not begin with the magic this codec expects.
  factory InfinityFormatException.badSignature({
    required String expected,
    required String found,
    Object? source,
  }) => InfinityFormatException._(
    "expected signature '$expected', found '$found'",
    source: source,
  );

  /// The signature matched, but the version is one this codec does not read.
  ///
  /// Distinct from [InfinityFormatException.badSignature] because it is
  /// recoverable information: the file is the right kind, just a layout this
  /// build has no codec for.
  factory InfinityFormatException.unsupportedVersion({
    required String found,
    required Iterable<String> supported,
    Object? source,
  }) => InfinityFormatException._(
    "unsupported version '$found'; this codec reads "
    "${supported.map((v) => "'$v'").join(', ')}",
    source: source,
  );

  /// A structure declares more bytes than the file actually provides.
  ///
  /// [what] names the structure so the message identifies it without the
  /// caller having to reconstruct context from a stack trace.
  factory InfinityFormatException.truncated({
    required String what,
    required int expected,
    required int actual,
    Object? source,
    int? offset,
  }) => InfinityFormatException._(
    '$what declares $expected bytes but only $actual are available',
    source: source,
    offset: offset,
  );

  /// A field's declared width is not one this library can read or write.
  ///
  /// Numeric access handles 1, 2 and 4 bytes; a string field or a mistyped
  /// width reaches here. A programmer error in spirit, but an [Exception] all
  /// the same — see the class note.
  factory InfinityFormatException.unreadableField({
    required String what,
    required int length,
    Object? source,
  }) => InfinityFormatException._(
    '$what is $length bytes, which is not a readable numeric width',
    source: source,
  );

  /// A value does not fit the field it was to be written into.
  ///
  /// Refused rather than truncated: a wrapped number written into a savegame
  /// is silent corruption, which is precisely the failure this project is
  /// shaped around.
  factory InfinityFormatException.valueOutOfRange({
    required String what,
    required int value,
    required int minimum,
    required int maximum,
    Object? source,
  }) => InfinityFormatException._(
    '$value does not fit $what, which holds $minimum to $maximum',
    source: source,
  );

  @override
  final String message;

  @override
  final dynamic source;

  @override
  final int? offset;

  @override
  String toString() {
    final where = offset == null ? '' : ' (at offset $offset)';
    return 'InfinityFormatException: $message$where';
  }
}
