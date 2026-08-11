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

/// The column vocabulary, checked against the player's own files.
///
/// ⚠️ **This is the check with teeth, and it is the one that would have caught
/// the bug.** `profs.2da` and `profsmax.2da` both carry `FIRST_LEVEL`, so
/// reading the wrong one of the pair returns a plausible integer and nothing
/// fails — which is exactly how a wrong proficiency rule shipped. Naming the
/// tables a column belongs to turns "does this table really have that column?"
/// into something the suite answers against the installation rather than
/// something a reader has to take on trust.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/rules/game_tables.dart';
import 'package:wand_of_saves/domain/rules/table_columns.dart';

void main() {
  group('the column vocabulary is internally consistent', () {
    test('every column names at least one table it lives in', () {
      for (final column in TableColumn.values) {
        expect(
          column.inTables,
          isNotEmpty,
          reason: '${column.name} — a column nothing reads is dead weight',
        );
      }
    });

    test('every header is uppercase, as the files spell them', () {
      // ⚠️ Column names are matched **case-sensitively** on purpose: the tables
      // spell them consistently, and case-folding would hide a typo rather
      // than tolerate one.
      for (final column in TableColumn.values) {
        expect(column.header, equals(column.header.toUpperCase()));
      }
    });
  });

  group('against the player’s own installation', () {
    const profile = GameProfileService();
    final game = profile.findGameDirectory();
    final why = game == null ? 'no Baldur’s Gate installation' : null;

    test(
      'every column really is in every table that claims it',
      () async {
        final index = KeyIndex.parse(
          await File(
            '$game${Platform.pathSeparator}${GameProfileService.gameMarker}',
          ).readAsBytes(),
          source: GameProfileService.gameMarker,
        );

        final archives = <String, BifArchive>{};
        Future<Table2da?> read(GameTable table) async {
          final where = index.locate(table.resref, ResourceType.table2da);
          if (where == null) return null;
          final path = index.archives[where.archive].replaceAll(
            r'\',
            Platform.pathSeparator,
          );
          final archive = archives[path] ??= BifArchive.parse(
            await File(
              '$game${Platform.pathSeparator}$path',
            ).readAsBytes(),
            source: path,
          );
          return Table2da.parse(utf8.decode(archive.resource(where.file)));
        }

        final missing = <String>[];
        for (final column in TableColumn.values) {
          for (final table in column.inTables) {
            final parsed = await read(table);
            expect(parsed, isNotNull, reason: table.resref);
            if (!parsed!.columns.contains(column.header)) {
              missing.add('${column.header} is not in ${table.resref}');
            }
          }
        }

        expect(missing, isEmpty);
      },
      skip: why,
    );
  });
}
