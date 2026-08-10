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

/// Infinity Engine file format codecs.
///
/// Pure Dart by contract: this package must never import `package:flutter`.
/// Its suite runs under `fvm dart test`, where such an import fails to compile.
/// See `planning/architecture.md`.
library;

export 'src/chr/chr.dart';
export 'src/chr/chr_codec.dart';
export 'src/cre/cre.dart';
export 'src/cre/cre_codec.dart';
export 'src/cre/cre_section.dart';
export 'src/cre/effect.dart';
export 'src/exceptions.dart';
export 'src/gam/gam.dart';
export 'src/gam/gam_codec.dart';
export 'src/gam/gam_npc.dart';
export 'src/io/atomic_file.dart';
export 'src/resource/bif_archive.dart';
export 'src/resource/key_index.dart';
export 'src/spec/chr_v2_0.dart';
export 'src/spec/cre_v1_0.dart';
export 'src/spec/creature_document.dart';
export 'src/spec/format_field.dart';
export 'src/spec/gam_v2_0.dart';
export 'src/tables/ids_map.dart';
export 'src/tables/table_2da.dart';
export 'src/text/fixed_field.dart';
export 'src/tlk/tlk.dart';
