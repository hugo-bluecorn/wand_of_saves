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

/// Substitutes the tokens the engine leaves in its own descriptive text.
///
/// ⚠️ **The game's descriptions are not finished sentences.** `clastext.2da`'s
/// entry for the Fighter reads *"a champion, swords`<PRO_MANWOMAN>`, soldier"*,
/// and the Archer's *"the ultimate marks`<PRO_MANWOMAN>` … `<PRO_HISHER>`
/// proficiency"*. The engine fills those in from the character's gender; text
/// shown without doing the same prints markup at the player.
///
/// This is the reason gender is the flow's **first** question rather than a
/// detail near the end: every description after it needs the answer.
library;

/// The tokens this build knows, as (masculine, feminine).
///
/// Only the ones actually found in the tables these screens show. An unknown
/// token is left alone rather than guessed at or deleted — deleting one would
/// silently drop a word out of the middle of a sentence.
///
/// ⚠️ **D13 — written here, and no table answers it.** The substitution is the
/// engine's own, not a data file's: every `2DA` whose name suggested it was
/// opened (`statdesc`, `statval`, `racetext`, `clastext`, `kitlist`) and none
/// carries the token vocabulary. The strings that *contain* the tokens come
/// from the talk table; what to put in their place does not.
const Map<String, (String, String)> genderedTokens = {
  '<PRO_MANWOMAN>': ('man', 'woman'),
  '<PRO_HISHER>': ('his', 'her'),
  '<PRO_HESHE>': ('he', 'she'),
  '<PRO_HIMHER>': ('him', 'her'),
  '<PRO_BOYGIRL>': ('boy', 'girl'),
  '<PRO_BROTHERSISTER>': ('brother', 'sister'),
  '<PRO_SonDaughter>': ('son', 'daughter'),
  '<PRO_LADYLORD>': ('lord', 'lady'),
  '<PRO_SIRMAAM>': ('sir', 'maam'),
  '<PRO_MALEFEMALE>': ('male', 'female'),
};

/// `GENDER.IDS` id for a female character.
const int femaleGenderId = 2;

/// [text] with its pronoun tokens filled in for [genderId].
///
/// Also replaces `<CHARNAME>` with [name] when one is known — the game uses it
/// in biographies, and a creation flow has the name only at the last step.
///
/// Case is preserved for a token written in capitals at the start of a
/// sentence, which `<PRO_HESHE>` is in several class descriptions.
String substituteTokens(
  String text, {
  required int? genderId,
  String? name,
}) {
  final feminine = genderId == femaleGenderId;
  var out = text;
  for (final MapEntry(key: token, value: (masculine, feminineWord))
      in genderedTokens.entries) {
    final word = feminine ? feminineWord : masculine;
    out = out.replaceAll(token, word);
    // The tables spell one of these `<PRO_SonDaughter>`, so a case-sensitive
    // pass alone misses it in the files that shout it.
    out = out.replaceAll(token.toUpperCase(), word);
  }
  if (name != null && name.isNotEmpty) {
    out = out.replaceAll('<CHARNAME>', name);
  }
  return out;
}
