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

/// The app's routes, declared in one place.
///
/// `go_router` per `planning/architecture.md` §UI. Two screens do not need a
/// router on their own; it is here because the editor categories arriving next
/// nest *inside* the party shell, and retrofitting nested routing later costs
/// more than declaring it now.
library;

import 'package:go_router/go_router.dart';
import 'package:wand_of_saves/ui/party/party_view.dart';
import 'package:wand_of_saves/ui/saves/save_browser_view.dart';

/// Route names, so no screen builds a path out of string fragments.
abstract final class Routes {
  /// The save browser, and the app's start.
  static const String browser = '/';

  /// The party shell for one savegame, relative to [browser].
  ///
  /// Carries the slot **directory name** rather than its absolute path: it
  /// needs no escaping, it is stable across machines, and the repository can
  /// resolve it from scratch, so a reload lands on the same save.
  ///
  /// Declared as a *child* of the browser, which is what makes `go` build a
  /// stack of [browser, party] and gives the party shell a working back
  /// button rather than a dead end.
  static const String party = 'save/:$slotParameter';

  /// The path parameter naming a save slot directory.
  static const String slotParameter = 'slot';

  /// The party shell's path for the slot directory named [directoryName].
  ///
  /// Encoded on the way out; `go_router` decodes path parameters on the way
  /// in (`go_router-17.4.0/lib/src/match.dart:202`), so the two are symmetric.
  static String partyFor(String directoryName) =>
      '/save/${Uri.encodeComponent(directoryName)}';
}

/// The application's router.
GoRouter buildRouter() => GoRouter(
  routes: [
    GoRoute(
      path: Routes.browser,
      builder: (context, state) => const SaveBrowserView(),
      routes: [
        GoRoute(
          path: Routes.party,
          builder: (context, state) => PartyView(
            slotDirectoryName: state.pathParameters[Routes.slotParameter] ?? '',
          ),
        ),
      ],
    ),
  ],
);
