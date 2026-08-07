# Java semantics notes — the citation ledger

> **Licence.** Originally authored as part of the `near_infinity_flutter` project (Copyright (C)
> 2026 hugo-bluecorn, LGPL-2.1). Relicensed under **Apache-2.0** by its copyright holder for use
> in this project, confirmed 2026-08-07. See `NOTICE` and `planning/decisions.md`, D1.

**Status:** carried over from the `near_infinity_flutter` experiment (seeded 2026-08-05, re-homed
2026-08-07), and **partially superseded by D1** — read the next paragraph before using it.

**⚠️ Its original purpose no longer applies.** This ledger was written when the plan was to read
NearInfinity's Java as a reference for how the formats are parsed and written. **D1 (Apache-2.0)
withdrew that** — codecs are written independently from IESDP, and NearInfinity's Java is not read
at all. So the "Bites in NearInfinity" column is now **historical context, not a working
reference**. See `planning/using-nearinfinity.md` for what *is* permitted.

**What still matters is the Dart column.** Every entry names a way Dart's own binary and string
handling will surprise you, and those hazards are real regardless of where the specification came
from:

- **Entry 1 — byte order.** Infinity Engine formats are little-endian (a format fact, per IESDP).
  Dart's `ByteData` get/set take `Endian` **per call** and default to `Endian.big`, while
  typed-data *views* use host order. That is a per-call-site hazard, not a one-time setting.
- **Entry 2 — unsigned values.** Dart `int` is 64-bit; use `getUint8`/`getUint16`/`getUint32` and
  mask deliberately rather than assuming a width.
- **Entry 3 — encoding. Live on day one.** Dart has **no built-in cp1252 codec**, and `latin1` is
  *not* equivalent for `0x80–0x9F`. TLK strings are affected; the spike's
  `String.fromCharCodes` is wrong for any non-ASCII string.

**Protocol, as revised:** an entry's Dart-side claim must rest on a citation (Dart API docs / the
language spec), not on model memory — *a signature is not a mechanism; neither is a remembered
default*. Do **not** add new entries by reading NearInfinity's Java. Where a Java column is needed
at all, it is only to interpret the **output** of NearInfinity run as a black-box oracle.

| # | Contract | Bites in NearInfinity | Dart-side counterpart | Status |
|---|---|---|---|---|
| 1 | **Byte order** — `ByteBuffer` defaults to BIG_ENDIAN; Infinity Engine formats are little-endian, so codecs must (and do) set `ByteOrder.LITTLE_ENDIAN` | **32 measured `LITTLE_ENDIAN` sites** (2026-08-05 grep) — `resource/key/BIF{,F}Reader.java`, `Effect{,2}.java`, `wed/WedResource.java`, … | `ByteData` get/set take `Endian` **per call**, default `Endian.big`; typed-data *views* use host order — a per-call-site hazard, not a one-time setting | SEEDED |
| 2 | **No unsigned types** — Java emulates unsigned bytes/shorts/ints by masking (`& 0xFF`, …); sign-extension on widening is the trap | the codec family throughout `resource/` + `datatype/` (`DecNumber`, `Unknown`, section counts) | Dart `int` is 64-bit; masks still required but at different widths; `Uint8List`/`ByteData` getUint* solve the byte layer | SEEDED |
| 3 | **Charsets** — which encoding per string field is a per-format contract, not a global | **32 files** touch `Charset`/encodings (2026-08-05 grep); resource names, TLK strings | ⚠️ **Dart has no built-in cp1252 codec** — `latin1` ≠ cp1252 for 0x80–0x9F; if any format field is cp1252, the port needs an explicit table or package | SEEDED |
| 4 | **The EDT** — Swing is single-threaded; all UI mutation via the Event Dispatch Thread (`invokeLater`/`invokeAndWait`); background work via workers/pools | `util/Threading` pooled executor; `AbstractSearcher`/`AbstractChecker` batch ops; every viewer | Flutter main isolate + `compute()`/isolates; no shared-memory UI mutation at all — a *stronger* model, but blocking work must leave the main isolate explicitly | SEEDED |
| 5 | **`java.util.prefs`** — platform backing store (Linux: `~/.java/.userPrefs` XML), node paths are API | `AppOption` registry; the legacy node `org.infinity.gui.BrowserMenuBar` kept deliberately for settings compat | no direct equivalent; settings file or `shared_preferences`; **user-settings migration is a plan-level question** | SEEDED |
| 6 | **Zip as `FileSystem`** — NIO mounts zips and serves `Path`s through them transparently | `DlcManager` mounts DLC zips; `ResourceEntry` reads through | Dart has no zip-mount; `package:archive` reads entries — the transparent-Path abstraction must be rebuilt or designed around | SEEDED |
| 7 | **Case-insensitive path resolution over a case-sensitive FS** — game data is DOS-cased; Java code resolves via a custom layer, not the platform | `util/io/FileManager` + `CaseAwarePathResolver` — the mandatory path hub | same problem, same answer: a custom resolution layer; nothing in `dart:io` provides it | SEEDED |

## Entries verified so far

None — all seven are SEEDED. First verification belongs to whichever leg-J finder, comparison
item, or seed touches the contract first; the verifier updates the row in place (citation URL +
fetch date + measured sites) and moves it below with a dated line.
