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

// Vertical-slice spike: GAM V2.0 -> party NPCs -> embedded CRE V1.0 -> dialog.tlk
// Pure Dart, no Flutter. Proves the whole v1 read path.
//
// Usage:
//   dart run tool/spike/gam_cre_tlk_spike.dart [saveSlotDir] [gameDir]
//
// Paths resolve in this order, so nothing is hardcoded to one machine:
//   1. positional arguments
//   2. environment: BGEE_SAVE_DIR (save root or a single slot), BGEE_GAME_DIR
//   3. the well-known install locations in _gameCandidates / _saveCandidates
//
// PROVENANCE (see planning/decisions.md, D1). Field offsets are facts about the file
// formats and are documented in IESDP (file_formats/ie_formats/{gam_v2.0,cre_v1}.htm);
// they were cross-checked against NearInfinity during exploration, before Apache-2.0
// was adopted. No NearInfinity code, structure or naming was used -- the Reader and
// Tlk classes here are original. Codec work from Phase 0 onward is an independent
// implementation from IESDP, with NearInfinity used only as a black-box oracle.
//
// THIS IS A SPIKE, NOT A REFERENCE IMPLEMENTATION. It has three known defects that
// Phase 0 must fix properly rather than carry over -- see
// docs/findings/verified-format-offsets.md, section "Known bugs":
//   1. NPC struct stride is inferred from offset arithmetic and is wrong (-180 here).
//   2. strref == -1 (the protagonist's name) is unhandled.
//   3. The round-trip check is tautological.
// It also uses String.fromCharCodes for TLK strings, which is wrong for cp1252.
//
// A command-line diagnostic tool: printing is the output.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

// ---------------------------------------------------------------------------
// Path resolution
// ---------------------------------------------------------------------------

String get _home =>
    Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';

/// Well-known BG:EE installation roots (the directory holding `chitin.key`).
List<String> get _gameCandidates => [
  // Linux / Steam
  '$_home/.local/share/Steam/steamapps/common/Baldur\'s Gate Enhanced Edition',
  '$_home/.steam/steam/steamapps/common/Baldur\'s Gate Enhanced Edition',
  // macOS / Steam
  '$_home/Library/Application Support/Steam/steamapps/common/Baldur\'s Gate Enhanced Edition',
  // GOG / Beamdog
  '$_home/GOG Games/Baldur\'s Gate - Enhanced Edition',
  '$_home/Games/Baldur\'s Gate - Enhanced Edition',
  // Windows
  r'C:\Program Files (x86)\Steam\steamapps\common\Baldur'
      "'"
      r's Gate Enhanced Edition',
];

/// Well-known save roots (the directory holding the numbered slot folders).
List<String> get _saveCandidates => [
  '$_home/.local/share/Baldur\'s Gate - Enhanced Edition/save',
  '$_home/Documents/Baldur\'s Gate - Enhanced Edition/save',
  '$_home/Library/Application Support/Baldur\'s Gate - Enhanced Edition/save',
];

/// First candidate directory containing [marker], or null.
String? _findDir(List<String> candidates, String marker) {
  for (final c in candidates) {
    if (FileSystemEntity.isFileSync('$c/$marker') ||
        FileSystemEntity.isDirectorySync('$c/$marker')) {
      return c;
    }
  }
  return null;
}

/// Accepts either a single save slot or a save root; returns a slot directory.
///
/// Given a root, picks the most recently modified slot that has a `BALDUR.gam`,
/// which is almost always the one you actually want to look at.
String? _resolveSlot(String dir) {
  if (File('$dir/BALDUR.gam').existsSync()) return dir;
  final d = Directory(dir);
  if (!d.existsSync()) return null;
  final slots = d
      .listSync()
      .whereType<Directory>()
      .where((e) => File('${e.path}/BALDUR.gam').existsSync())
      .toList();
  if (slots.isEmpty) return null;
  slots.sort(
    (a, b) => File('${b.path}/BALDUR.gam').lastModifiedSync().compareTo(
      File('${a.path}/BALDUR.gam').lastModifiedSync(),
    ),
  );
  return slots.first.path;
}

Never _bail(String what, String envVar, List<String> tried) {
  stderr.writeln('spike: could not locate the $what.\n');
  stderr.writeln('Pass it explicitly:');
  stderr.writeln(
    '  dart run tool/spike/gam_cre_tlk_spike.dart <saveSlotDir> <gameDir>\n',
  );
  stderr.writeln('or set \$$envVar.\n');
  stderr.writeln('Looked in:');
  for (final t in tried) {
    stderr.writeln('  $t');
  }
  exit(2);
}

// ---------------------------------------------------------------------------
// Format readers
// ---------------------------------------------------------------------------

class Reader {
  final ByteData d;
  final Uint8List b;
  Reader(this.b) : d = ByteData.sublistView(b);
  int u8(int o) => d.getUint8(o);
  int u16(int o) => d.getUint16(o, Endian.little);
  int i16(int o) => d.getInt16(o, Endian.little);
  int u32(int o) => d.getUint32(o, Endian.little);
  String str(int o, int n) {
    final s = b.sublist(o, o + n);
    final z = s.indexOf(0);
    return String.fromCharCodes(z < 0 ? s : s.sublist(0, z)).trim();
  }
}

/// Minimal TLK: lazy index, strings fetched on demand (dialog.tlk is ~30 MB).
class Tlk {
  final RandomAccessFile f;
  final int count, strBase;
  Tlk._(this.f, this.count, this.strBase);

  static Future<Tlk> open(String path) async {
    final f = await File(path).open();
    final h = Reader(await f.read(18));
    if (h.str(0, 4) != 'TLK') throw 'not a TLK: ${h.str(0, 4)}';
    return Tlk._(f, h.u32(10), h.u32(14));
  }

  Future<String> get(int strref) async {
    if (strref < 0 || strref >= count) return '<invalid $strref>';
    await f.setPosition(18 + strref * 26);
    final e = Reader(await f.read(26));
    final off = e.u32(18), len = e.u32(22);
    if (len == 0) return '';
    await f.setPosition(strBase + off);
    return String.fromCharCodes(await f.read(len));
  }
}

// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  final env = Platform.environment;

  // --- game installation (holds chitin.key) ---
  final gameArg = args.length > 1 ? args[1] : env['BGEE_GAME_DIR'];
  final gameDir = gameArg ?? _findDir(_gameCandidates, 'chitin.key');
  if (gameDir == null || !File('$gameDir/chitin.key').existsSync()) {
    _bail(
      'game installation',
      'BGEE_GAME_DIR',
      gameArg != null ? ['$gameArg  (no chitin.key)'] : _gameCandidates,
    );
  }

  // --- save slot ---
  final saveArg = args.isNotEmpty ? args[0] : env['BGEE_SAVE_DIR'];
  String? saveDir;
  if (saveArg != null) {
    saveDir = _resolveSlot(saveArg);
  } else {
    for (final c in _saveCandidates) {
      saveDir = _resolveSlot(c);
      if (saveDir != null) break;
    }
  }
  if (saveDir == null) {
    _bail(
      'save game',
      'BGEE_SAVE_DIR',
      saveArg != null ? [saveArg] : _saveCandidates,
    );
  }

  print('game dir       : $gameDir');
  print('save slot      : $saveDir');
  print('');

  final g = Reader(await File('$saveDir/BALDUR.gam').readAsBytes());
  print('signature      : ${g.str(0, 4)} ${g.str(4, 4)}');
  print(
    'game time      : ${g.u32(8)} (${(g.u32(8) / 300).toStringAsFixed(1)} h)',
  );
  print('party gold     : ${g.u32(0x18)}');
  print('reputation     : ${g.u32(0x54) / 10}');
  print('current area   : ${g.str(0x58, 8)}');

  final partyOff = g.u32(0x20), partyCnt = g.u32(0x24);
  final invOff = g.u32(0x28);
  final varCnt = g.u32(0x3c);
  final jrnlCnt = g.u32(0x4c);
  final stride = partyCnt > 0 ? (invOff - partyOff) ~/ partyCnt : 0;
  print(
    'party          : $partyCnt members @ 0x${partyOff.toRadixString(16)} '
    'stride=$stride bytes',
  );
  print('globals        : $varCnt   journal entries: $jrnlCnt');

  Tlk? tlk;
  final langRoot = Directory('$gameDir/lang');
  if (langRoot.existsSync()) {
    for (final l in langRoot.listSync().whereType<Directory>()) {
      final p = '${l.path}/dialog.tlk';
      if (File(p).existsSync()) {
        tlk = await Tlk.open(p);
        print(
          'dialog.tlk     : ${l.path.split(Platform.pathSeparator).last}, '
          '${tlk.count} strings',
        );
        break;
      }
    }
  }

  print('\n${'=' * 74}');
  for (var i = 0; i < partyCnt; i++) {
    final n = partyOff + i * stride;
    final creOff = g.u32(n + 4), creSize = g.u32(n + 8);
    final label = g.str(n + 192, 32);
    final resref = g.str(n + 12, 8);

    print(
      '\n[$i] "$label"  (CRE $resref, $creSize bytes @ 0x${creOff.toRadixString(16)})',
    );
    if (creOff == 0 || creOff + creSize > g.b.length) {
      print('    <no embedded CRE>');
      continue;
    }
    final c = Reader(Uint8List.sublistView(g.b, creOff, creOff + creSize));
    if (c.str(0, 4) != 'CRE') {
      print('    <unexpected signature ${c.str(0, 4)}>');
      continue;
    }
    const o = 8; // CRE body starts after 'CRE ' + 'V1.0'
    final nameRef = c.u32(o + 0);
    final name = tlk != null ? await tlk.get(nameRef) : '<no tlk>';
    print('    version      : ${c.str(4, 4)}');
    print('    name         : "$name"  (strref $nameRef)');
    print('    XP           : ${c.u32(o + 16)}      gold: ${c.u32(o + 20)}');
    print('    HP           : ${c.i16(o + 28)} / ${c.i16(o + 30)}');
    print('    reputation   : ${c.u8(o + 60)}       THAC0: ${c.u8(o + 74)}');
    print(
      '    levels       : ${c.u8(o + 556)}/${c.u8(o + 557)}/${c.u8(o + 558)}',
    );
    print(
      '    STR ${c.u8(o + 560)}(${c.u8(o + 561)})  INT ${c.u8(o + 562)}  '
      'WIS ${c.u8(o + 563)}  DEX ${c.u8(o + 564)}  CON ${c.u8(o + 565)}  '
      'CHA ${c.u8(o + 566)}',
    );
  }
  print('\n${'=' * 74}');

  // Round-trip check: re-serialising untouched bytes must be identical.
  final orig = await File('$saveDir/BALDUR.gam').readAsBytes();
  var same = orig.length == g.b.length;
  for (var i = 0; same && i < orig.length; i++) {
    if (orig[i] != g.b[i]) same = false;
  }
  print('round-trip (no edits) byte-identical: $same');
}
