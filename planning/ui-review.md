# UI review — the current application, 2026-08-11

## Why this exists

Inventory is the next feature and the largest surface this app will ever grow: 80 item slots, a
picker over 37,000 indexed resources, an item detail. The decision was taken not to build it on a
visual foundation nobody had inspected. This document is the inspection. Three alternative UI
approaches were spiked separately, in `spikes/ui_spikes/` — **deleted 2026-08-12** once the
chosen one was promoted into `lib/`. The spikes are in git history and in PR #7.

**Nothing here is a matter of taste.** Every finding is anchored to a line in the app and to a line
in the Flutter SDK the app compiles against, a Material 3 design token, or a WCAG success
criterion. Where a claim rests on desktop convention instead, it says so in the finding.

## How it was judged

**The authority is the pinned SDK: `/home/hugo/fvm/versions/3.44.8`.** It is a complete Flutter
checkout, and it carries everything needed:

| Path | What it is |
|---|---|
| `packages/flutter/lib/src/material/` | 184 sources; the dartdoc **is** the widget documentation |
| `dev/tools/gen_defaults/data/` | **62 JSON files — the Material 3 token database, v6_1_0.** The real `md.sys.*` / `md.comp.*` values |
| `dev/tools/gen_defaults/lib/` | 44 templates showing how each `*ThemeData`'s defaults derive from those tokens |
| `examples/api/lib/material/` | 84 dirs of canonical component samples |
| `dev/a11y_assessments/lib/use_cases/` | The SDK's own per-widget accessibility reference |

⚠️ **The ai-context copy of `flutter/flutter` was deliberately not used for API facts.** It is on
`main`, roughly 6,700 commits from a different branch point, and would have judged this app against
an API it does not compile with. It was used only for `flutter/packages`
(`two_dimensional_scrollables`) which the SDK does not contain.

⚠️ **No Material 3 prose is available on this machine.** There is no `flutter/website` clone and no
vendored copy of `m3.material.io`. Token *values* are exact and local; narrative guidance is not.
Findings are therefore anchored to tokens, dartdoc, and the `m3.material.io` URLs the dartdoc
itself cites — and any finding resting on convention is labelled as such.

## What the pictures show

Nobody had ever looked at three of the four tabs. Captures are in
`docs/findings/screens/app/` (gitignored, on disk), taken at the app's own default 1280 × 720.

**Two defects were found by looking, that no amount of reading would have surfaced.**

**⚠️ The helper line — the one thing this project deliberately made always-visible — is itself
being truncated.** On the Character tab it reads `stored 12, +4/level from Constit…`; on Combat,
`what the game calls "Base THA…`. `show-the-arithmetic-keep-the-caveats` settled that a derived
number's arithmetic belongs on screen rather than behind an ⓘ. It is on screen, and cut off. This
is the **third** time the 222-px tile has been too narrow — after 148 truncated
`Exceptional strength` and 190 truncated `Paralysis / Poison / Death`.

**⚠️ The Skills tab prints the same eight labels twice on one screen.** `Lore`, `Open Locks`,
`Find Traps`, `Pick Pockets`, `Move Silently`, `Hide in Shadows`, `Detect Illusion` and `Set Traps`
each appear once under *Points allocated* and again under *What the game shows*, with the helper
text `allocated, + Dexterity + race` repeated verbatim seven times. The stored-versus-displayed
distinction — the app's central idea — is implemented as **two groups with duplicated labels**
where it wants to be two columns of one row.

Also visible: the read-only group is markedly dimmer than the editable one above it (finding **A1**
explains why, and it is worse than it looks); the Character tab leaves roughly 60 % of the window
empty while Combat runs to nearly two viewports; and identity is one concatenated sentence,
`Level 2/1 · Male · Elf · Fighter / Mage · Neutral Good`, where the engine prints four lines.

*Caveat on the captures: they were taken through a harness that boots the sheet directly, because
nothing on this machine can drive the pointer. In that harness the rules tables fall back to empty,
so unavailable thief skills are not drawn greyed. That is an artifact of the harness, not a defect
in the app.*

---

## The defects, ranked

Eight findings are defects — wrong, broken, or failing a criterion the project set itself.

| # | Defect | Evidence |
|---|---|---|
| **A1** | Every derived number renders at **2.3:1** (light) against the project's own 4.5:1 gate. 38 % alpha makes 3:1 **unreachable by construction** — black on white composites to 2.68:1 | `character_panel.dart:926-976`; `text_field_filled.json` `disabled.input-text.opacity: 0.38`; `planning/architecture.md:259` |
| **A2** | Pip buttons render **22 × 22** — they ask for 30 and `visualDensity: compact` subtracts 8; Linux defaults `materialTapTargetSize` to `shrinkWrap`, so nothing pads it back. **WCAG 2.2 SC 2.5.8 AA failure**, and the spacing exception does not apply because the two buttons abut | `character_panel.dart:1324-1332`; `theme_data.dart:3225`, `:3307-3346`, `:405-408`; `constants.dart:27` |
| **A3** | `enabled: false` does not merely grey a value — it removes it from selection, copy, focus and Tab order, and announces it to assistive tech as *unavailable*. Fifteen computed values, including every number a user would want to quote | `text_field.dart:1180`, `:1282`, `:1803`, `:1807-1808` |
| **A4** | The widest stat label — `Attacks per round (in game)` — ellipsizes at **≈1.21× text scale**. GNOME's "Large Text" is **1.25×**, so it truncates *before* the first accessibility setting a user reaches for. The project's own gate says "usable at increased system font size" | `character_panel.dart:723`; `input_decorator.dart:1034-1041`, `:2405`; `planning/architecture.md:260` |
| **A5** | Exactly **one** `Semantics` widget in the whole app, and `InputDecoration.labelText` never becomes the field's accessible name — so 49 stat fields present as unnamed text fields | `input_decorator.dart:1713-1740`, `:2692-2694`; contrast `dev/a11y_assessments/lib/use_cases/text_field.dart:37-47` |
| **A6** | Hollow pip dots at **1.32:1** light and **1.33:1** dark — a WCAG 1.4.11 failure on a graphic the code itself says exists "to make the ceiling countable at a glance". Against `outlineVariant`'s *own* spec'd background it is **1.22:1** | `character_panel.dart:1298`; `color_light.json`, `color_dark.json` |
| **A7** | `_ReadOnlyStat` builds a `TextEditingController` inside `build()` and never disposes it — up to nine orphaned `ChangeNotifier`s per rebuild, on every edit, undo and party-member switch | `character_panel.dart:961`; contrast `_StatFieldState` at `:1065-1095`, which does it correctly |
| **A8** | No minimum window size in any runner, and the creation flow's fixed-width `Row`s overflow at widths KDE produces by tiling — the Name step tears at **W ≈ 731** | `linux/runner/my_application.cc:55`; `rendering/flex.dart:375-378`, `:1337` |

### ⚠️ Three edits close six of the eight

1. **`enabled: false` → `readOnly: true`** in `_ReadOnlyStat` closes **A1, A3 and A7** at once. It keeps the tile shape and the greyed reading while restoring full opacity, selection, focus and the live ⓘ.
2. **Delete the four size overrides on `_PipButton`** closes **A2**. The justifying comment — "a default `IconButton` is 48 points square, which two of would leave no room for the dots" — is wrong on its premise: the M3 default is 40, not 48. ⚠️ **But it is nearly right on its conclusion, and the margin matters.** Two 48-px buttons fit the tile's 190 px of usable width with **1.1 px to spare** once the pip row is drawn at a *fighter's* real ceiling of five dots (65 px) rather than the three the demo character happens to have. So this fix works, and it works by a pixel — which is another way of saying the tile is the real constraint.
3. **Replace `Wrap` + `SizedBox(width: 222)` with a `Table`** closes **A4** and the two layout weaknesses below, and removes the pressure that created A2 in the first place. Given the margin in (2), this is the fix that actually settles it.

### ⚠️ Two of these defects are structurally invisible to the test suite

`flutter test` defaults to `TargetPlatform.android`. That flips `materialTapTargetSize` to `padded`,
so **a widget test measures the pip button at 40 × 40 and can never observe the 22 × 22** that
Linux produces. And the suite draws with a font whose every glyph is a full em square, so no
label-width threshold measured there means anything. **A2 and A4 are runtime-on-Linux facts that no
test in this repository can reach** — which is precisely why they survived 697 passing tests, and
why the capture path matters more than another assertion would.

---

## Dimension 1 — the theme, and it has two layers

Flutter's Material theming is application level **and** widget level. `ThemeData` in 3.44.8 carries
**48** non-deprecated component theme slots. `lib/ui/core/theme.dart` is 56 lines and fills **one**
— and that one is net-harmful.

### ⚠️ The root cause of a design decision taken on a false premise

`theme.dart:48-53` sets `cardTheme.shape` to a `RoundedRectangleBorder` **with no `side`**.
`card.dart:264` resolves shape whole-property:

```dart
shape: shape ?? cardTheme.shape ?? defaults.shape,
```

and `_OutlinedCardDefaultsM3.shape` (`card.dart:391-395`) is the **only** thing that draws an
outlined card's border. So in this app `Card.outlined` renders with **no border at all**, not a
faint one. `save_browser_view.dart:704-707` records the observation and the wrong diagnosis — "that
constructor's default outline is invisible against this theme" — and the variant was abandoned,
replaced by a hand-drawn border on a filled card.

**It is worse than a wrong diagnosis: the line that caused it is a no-op.** `md.sys.shape.corner.medium`
is 12.0 and all three `_Card*DefaultsM3` already use `Radius.circular(12.0)`. The only line in the
entire `ThemeData` that changes anything correctly is `clipBehavior: Clip.antiAlias`.

### The colour finding that reaches six surfaces

`colorScheme.outlineVariant` is **specified at 1.0:1 contrast** at the default contrast level.
`MaterialDynamicColors.outlineVariant` carries `ContrastCurve(1, 1, 3, 4.5)`, whose four arguments
map to contrast levels −1.0 / 0.0 / 0.5 / 1.0 — so the app, passing no `contrastLevel`, gets the
**1.0**. Its sibling `outline` carries `ContrastCurve(1.5, 3, 4.5, 7)` and gives 3.0.

Six surfaces ride it, and only one was ever noticed: the party-shell divider, both creation
dividers, the character sheet's `TabBar` underline, `Card.outlined` (above), the portrait frames,
and the hollow proficiency pips (**A6**). In a dense editor the rules and dividers *are* the
layout.

**One parameter fixes it and one other thing:** `ColorScheme.fromSeed(..., contrastLevel: 0.5)`
raises `outlineVariant` to 3.0 and `outline` to 4.5, and simultaneously widens the light-mode
surface ladder, which currently spans only **10 tones across five levels** where dark spans 18.
That narrowness is why `_NewCharacterCard` at `surfaceContainerLowest` on `surface` is tone 100 on
tone 98 in light — effectively no fill — and why its hand-drawn border has to carry the card.

### The seed's chroma is discarded, so the theme does not deliver the intent it documents

`ColorScheme.fromSeed` defaults to `DynamicSchemeVariant.tonalSpot`, and `SchemeTonalSpot` keeps
**only the seed's hue**. Chroma is a hardcoded constant per role — `primary` 36, `secondary` 16,
`tertiary` 24 at hue + 60°, `neutral` 6, `neutralVariant` 8.

Measured through the same library the scheme generator uses, the seed `0xFF8C6A3F` is
**hue 71.5, chroma 24.6, tone 47.3**. So the chroma is replaced with one **46 % higher**, and the
colour actually painted as `primary` is `#815512`, not `#8C6A3F`. Under
`DynamicSchemeVariant.fidelity` — which preserves `sourceColorHct.chroma` — it would be `#78582F`.

`primary` paints the group headings, the new-character card, the filled pips, the selected
portrait frames and the tab indicator. The theme's doc comment says the chrome around the game's
art is "deliberately quiet"; **`tonalSpot` made it louder than the colour that was chosen for
being quiet.**

⚠️ **And the intent itself is unvalidated.** Both the seed and that justification were authored by
Claude Code in one stroke, not chosen by the project owner — so the doc comment records a claim,
not a decision. Worth stating because the claim is also arguable in the other direction: BG:EE's
portrait art is warm, painterly and brown-gold, so *warm* chrome makes the art blend into its
frame, where a cool near-neutral ground would leave the portraits as the only warm thing on
screen. Neither reading has been tested. See [`verify-project-docs-before-trusting-them`].

### The type scale is a phone type scale, and it is what made the tiles 222 px wide

No `TextTheme` is set, so field labels are styled `bodyLarge` — **16 px with 0.5 letter-spacing**,
the M3 2021 phone scale. For the 26-character `Paralysis / Poison / Death`, **13.0 px of the label
is pure tracking**. A desktop editor read at 50 cm wants the opposite trade. Retuning `bodyLarge`
to roughly 14 px / 0.1 tracking recovers about 32 px on each of ~49 tiles.

### Smaller theme findings, each with a concrete cost

| Finding | Cost |
|---|---|
| No `inputDecorationTheme` | Outlined fields take **32 px** of vertical padding and a 48-px floor; `isDense` gives 24 and drops the floor — ~8 px × dozens of fields. And the app has **two** field appearances: the sheet's filled-plus-outlined hybrid (a shape neither token file defines) versus the four dialogs' unfilled underline |
| `tooltipTheme` unset | ⚠️ **`Tooltip.waitDuration` defaults to `Duration.zero`.** A pointer crossing the sheet fires several tooltips a second, and the messages run to four sentences with no `maxWidth` |
| `visualDensity` | ⚠️ **Do not set it** — Linux already resolves to `VisualDensity.compact`. But `IconButton` and `Checkbox` are *explicitly exempt* from density in M3 and stay at 48; that exemption is why `_PipButton` open-codes four properties, and `iconButtonTheme` is the right lever |
| `dialogTheme` unset | `AlertDialog` has **no `maxWidth`** — it grows to `screenWidth − 80`. Four dialogs contain prose that would render as one 2,400-px line on a maximised window |
| `scrollbarTheme` unset | See D3 below |
| `sliderTheme` unset | The thief-skill sliders draw the **superseded 2023** Slider; `year2023: false` is one line |
| `surfaceContainerHighest` collision | It is `Card.filled`'s container colour *and* what `_NoScreenshot` / `_NoPortrait` paint — so the "nothing here" placeholders are invisible inside the cards that contain them |
| Off-scale radii | Three radii in use — 6, 10, 12. `shape.json` offers 0 / 4 / 8 / 12 / 16 / 28 / full. **6 and 10 are on none of them**, and portraits appear at radius 6 in four places while cards use 12 |
| `useMaterial3` | ⚠️ **Leave it unset.** It defaults true and is being deprecated; setting it adds a line that will need deleting |

⚠️ **And the theme is untested by construction.** All five `MaterialApp` constructions in `test/`
pass **no `theme:`**, so 697 tests render against a default `ThemeData` with an empty `cardTheme`.
The `Card.outlined` defect is structurally invisible to the suite.

### The project's own rule has drifted, measurably

`planning/architecture.md:258` says "no widget defines its own colours". Half of it holds
handsomely — there is exactly **one literal colour** in 4,506 lines of UI. The other half does not:
**33 widget sites choose a colour role**, 21 choose a type role, 10 combine both via `copyWith`, 6
choose a radius, and ~14 set a property that has a dedicated theme field. Choosing `outlineVariant`
over `outline` *is* defining a colour, and it is the choice that went wrong.

**Restate the rule as something a grep can check** — "no widget names a `ColorScheme` or `TextTheme`
role; both come from a component theme" — which is the standard the rest of this repo holds itself
to.

---

## Dimension 2 — component choice

| In use | Should be | Why |
|---|---|---|
| `TextField(enabled: false)` for 9 derived values | A label→value row, or at minimum `readOnly: true` | **A1/A3/A7.** Also `text_field.dart:619-621` states that a disabled field disables its own `suffixIcon` — which kills the ⓘ that explains the number |
| `Scaffold.bottomNavigationBar` for Back/Next | `Scaffold.persistentFooterButtons` | Wrong slot. The correct one wraps children in an `OverflowBar`, giving a column fallback on a narrow window that the hand-rolled `Row` does not have |
| `CheckboxListTile` with an `InkWell` inside its `title` | `ListTile` + explicit `Checkbox` and `IconButton` | `checkbox_list_tile.dart:34-35`: "The entire list tile is interactive." The design deliberately separates *read the spell* from *learn the spell*, and the component promises the opposite — so the boundary is invisible, and creation has no undo |
| Two `ChoiceChip`s for gender | `SegmentedButton` | `segmented_button.dart:69-71` scopes itself to "only 2-5 options" and its See-also routes >5 to chips. This is exactly 2 — and the chips are padded from a 32-pt token to ~56 to look like the 40-pt component they should have been |
| `TabBar` (primary) inside a detail pane | `TabBar.secondary` | The rail is the primary destination set; `tabs.dart:1046-1047` scopes secondary to "within a content area to further separate related content". Two primary indicators currently compete |
| 30 flat tiles on Combat | `ExpansionTile` per group | ⚠️ The comment closing this question rebuts *automatic hiding when all values are zero* — which is indeed wrong. It does not address user-operated disclosure, which never goes dead. And "the tabs above are the answer" cannot hold: tabs cannot subdivide *within* a tab |
| `AlertDialog` + `SizedBox(640, 520)` | `Dialog` + `ConstrainedBox`, or a side sheet | `dialog.dart:401-407` names the fixed `SizedBox` as the workaround for a lazy grid and says "consider using `Dialog` directly". The app's longest-dwell interaction is in its least flexible container |
| `TextField(labelText: 'Search')` | `SearchBar` — **not** `SearchAnchor` | M3's search field has *supporting text*, not a floating label, so today the word "Search" vanishes into the border exactly when the grid is filtered. ⚠️ `SearchAnchor` is the wrong recommendation here: it manages a suggestion *route*, and this is a live filter over a visible grid |
| `SnackBar` for a name collision | `errorText` on the field | The app already does this correctly one file away in `_ExportDialog`. Creation is the one place that abandons the pattern, and it is where losing the answer costs most — ten answered steps, no undo |
| `' •'` concatenated into the AppBar title | `Badge` | `badge.dart:26-29` names `NavigationRailDestination` explicitly. In a six-member party nothing says *which* member has the pending edit, though `EditSession` knows |
| Paragraphs in `Tooltip.message` | `IconButton` → `MenuAnchor` | `tooltip.dart:26-29` scopes tooltips to "text labels". These run to five lines, are hover-only, and sit on fields that cannot take focus |

**The structural one.** Four tabs today; `planning/decisions.md:171-172` already recorded that
twelve "exceeds comfortable `TabBar` density" and that a secondary rail fits better. Inventory,
spells, effects and appearance are all still to come. Because a rail must itself stay in the 3–5
band, the categories have to be *designed* — a decision worth taking at four destinations, when it
is a refactor of two call sites, rather than at twelve, when it is a redesign.

---

## Dimension 3 — desktop affordances

This is a document editor with an undo stack, a dirty marker and a `PopScope` guard.

**D1 — It binds no keyboard shortcut at all.** Zero occurrences of `Shortcuts`, `Actions`, `Intent`
or `CallbackShortcuts` in `lib/`. **Undo, redo and save exist only as toolbar buttons.** A user
editing thirty numeric fields must leave the keyboard for every undo.

⚠️ **And there is a trap in the fix.** On Linux, `Ctrl+Z` is already bound to `UndoTextIntent` for
a focused text field, and `DefaultTextEditingShortcuts` sits *below* the root `Shortcuts` — so a
`Shortcuts` at or above `MaterialApp` is shadowed whenever a stat field has focus, which is most of
the time here. The route through is **`ShortcutRegistry`**, which `WidgetsApp` already installs and
which nests *inside* the text-editing shortcuts. `MenuBar`'s own dartdoc nominates exactly this.

**D2 — No menu bar**, so there is nowhere a shortcut can be discovered and no home for Export,
Empty deleted items or refresh. Note the division the dartdoc insists on: the menu is the
*discovery* surface, the registry is the *handling* one — doing D1 without D2 leaves shortcuts
nobody can find. (`PlatformMenuBar` is macOS-only; Material's `MenuBar` is the cross-platform one.)
*Convention, not spec.*

**D3 — Scrollbars exist, but are transient.** ⚠️ **Correcting a belief held earlier in this
review:** `MaterialScrollBehavior.buildScrollbar` wraps every vertical `Scrollable` in a
`Scrollbar` on Linux, macOS and Windows (`app.dart:857-875`), and `widgets/scrollbar.dart:918-921`
states it as policy. The app is fine. What remains is smaller but real: `thumbVisibility` defaults
false and the thumb fades after 600 ms, so a Combat tab with 30 tiles below the fold looks, at
rest, identical to one that ends at the fold. Two lines of `scrollbarTheme` fix it everywhere.

**D4 — Nothing on any screen can be selected or copied.** No `SelectionArea`, no `SelectableText`.
The unselectable set is precisely what a user would want to quote — every in-game value, every
arithmetic helper line, every error message. This project's own workflow is comparing an app number
against a number the engine printed.

**D5 — No minimum window size** (**A8**), and the failure is not hypothetical: KDE half-tiles a
1366-px display at 683 px, where the creation flow's Name, Proficiencies and Abilities steps are
all broken.

| Step | Fixed width | Overflows below |
|---|---|---|
| Name | 462 | **W ≈ 731** |
| Proficiencies | ~426 | W ≈ 695 |
| Abilities | ~362 | W ≈ 631 |
| Spells | 349 | W ≈ 618 |
| Race / Class / Kit / Alignment | 284 | W ≈ 553 |

**D6 — `CLAUDE.md:21` claims "Material 3, adaptive desktop layout".** `MediaQuery` appears **zero**
times in `lib/`; `LayoutBuilder` zero. The one responsive construct is a `SliverLayoutBuilder`
sizing the browser's card grid. The app is a **fixed desktop layout with one responsive grid**, and
saying so is both honest and harmless. ⚠️ Note there is **no breakpoint helper in Flutter core** —
the SDK's own gallery reaches for a third-party package.

**D7 — And that one responsive construct violates its own minimum.** It picks the column count from
the raw extent, then subtracts 32 px of padding and the gaps — so at the default 1280 window the
characters grid picks 7 columns and hands each card ~165 px, below the 169 px its comment says the
number exists to preserve.

**Smaller:** the party rail's width is dictated without limit by the longest character name, so one
long name can drop the sheet a whole tile-column; the portrait grid's hard `crossAxisCount: 5`
draws the same faces at 122 px in the dialog and 324 px in creation; portrait tiles have no hover
state, for the same opaque-image reason the rail already documented and fixed; the browser's
selection is a mobile selection-mode with no Ctrl-click, Shift-range, Delete key or right-click;
and on KDE Wayland the GTK header bar and the Material `AppBar` **stack two title bars**, the upper
one permanently stale.

---

## Dimension 4 — accessibility and the mechanics of the layout

The eight defects above are mostly this dimension. Two layout weaknesses remain, both quantitative.

**L1 — 19.3 % of every row is dead, and five columns are missed by 2.6 px.** At the default window
the usable `Wrap` width is 1145 px; four 222-px tiles plus gaps use 924, leaving **221 px** —
almost exactly one more tile — as slack, on every row of every tab, because `Wrap` neither
justifies nor stretches. Five columns need a tile of ≤ 219.4 px. The tile is 222.

⚠️ **One input to that chain is a floor, not a width.** The party rail's 86 px is a `minWidth`
inside a `Row` child with no upper bound, so a character name past about eleven characters widens
the rail and moves every figure downstream — `Halfling Start` would make it 92.9. The slack is real
at the default; the exact number is not a constant.

**L2 — The tile is the wrong primitive.** `Resist Fire` holds a two-character value and
`Paralysis / Poison / Death` a 26-character label; both get a 222 × ~76 box — one number per
~16,900 px². The Combat tab is ~1.9 viewports at the shipped window size and cannot be seen at
once. A `Table` with `IntrinsicColumnWidth` for labels and a fixed narrow numeric column is roughly
**3.3× denser** and would fit all thirty numbers in half a viewport with no scroll.

⚠️ **And opacity is currently carrying three different meanings** — "computed, not editable", "your
class cannot have this", and "meaningless for this character" all look identical.

---

## What a redesign must fix

**★ = required. The rest is the difference between working and native-feeling.**

**Legibility and semantics**
- ★ No read-only value rendered as a disabled control. Everything the app computes is full-opacity, selectable and copyable.
- ★ Every interactive element has an accessible name; group headings are real headings.
- ★ Nothing truncates at 1.25× text scale — labels wrap or their column grows.
- ★ Structural lines clear 3:1; text clears 4.5:1. Do not use `outlineVariant` for anything load-bearing.
- Editable / computed / unavailable are three distinct visual states, not three uses of opacity.

**Targets and input**
- ★ Every hit target ≥ 24 × 24 with spacing, and 48 × 48 wherever it fits.
- ★ `Ctrl+S`, `Ctrl+Z`, `Ctrl+Shift+Z` via `ShortcutRegistry` so they beat the field-level text-editing bindings.
- A menu bar carrying every command that has a shortcut, so shortcuts are discoverable.
- Arrow-key increment on numeric and pip fields; a focused starting point on route entry; `FocusTraversalGroup` per region.
- Right-click context menus; Ctrl/Shift multi-select in the browser; visible hover on every clickable surface, including those covered by an opaque image.

**Layout**
- ★ A minimum window size in all three runners, at or above the widest layout's floor (≥ 900 × 600 today).
- ★ No fixed-width `Row` whose children sum past the viewport within the permitted range.
- Heterogeneous label→value pairs get a primitive that sizes to content, not a uniform box.
- A navigation structure that holds twelve categories, decided at four.
- Persistent scrollbar thumb; a maximum content measure on wide windows.

**Theme**
- ★ Both layers. An application-level scheme, type scale and shape strategy, **and** a component theme for every family the design leans on.
- ★ No widget names a colour or type role for styling — that is what a component theme is.
- A test that renders against the real theme, so a theme defect is visible to the suite at all.

---

## Correctly chosen — do not let a later pass "fix" these

- **`MenuAnchor` over `PopupMenuButton`** — `popup_menu.dart:1259-1262` says `MenuAnchor` "is preferred for applications that are configured for Material 3".
- **`InputDecorator` around the pip stepper** — `input_decorator.dart:1851-1852` describes this use verbatim.
- **`RadioGroup`** over per-tile `groupValue` — required in 3.44.8.
- **`SliverGrid` + `SliverLayoutBuilder`** over a nested `GridView` — two grids in one `CustomScrollView` cannot both own viewports.
- **`NavigationRail` for the party**, and **not** for the creation flow — eleven sequential steps are outside what the component documents itself for, so the hand-rolled step rail is the right call.
- **No `Stepper`** — it is M2-archive and brings its own button pair, which would duplicate the footer.
- **Reading-order focus traversal** inside the `Wrap` — it already matches the visual order.
- **Cursor feedback** — `InkWell` defaults to `adaptiveClickable`, so every clickable surface already gives a pointer cursor with no `MouseRegion` anywhere. Tooltips on icon-only controls are thorough.
- **The `_CardGrid` text-height budget** — the comment earned its place; the card survives to ~3.7× text scale.
- **Exactly one literal colour in 4,506 lines of UI.**

## Corrections to beliefs held while writing this

Recorded because they were each stated confidently before being checked.

1. **"No `Scrollbar` anywhere."** Wrong — Flutter supplies one on Linux automatically. The finding is transience, not absence.
2. **"`ThemeData` has 51 component theme slots."** It has **48**: 46 in the `// COMPONENT THEMES`
   block plus `inputDecorationTheme` and `scrollbarTheme` under general configuration. ⚠️ The
   *explanation* first offered for the discrepancy — "51 counts the deprecated ones" — is also
   wrong, and was caught in verification: there is exactly **one** deprecated theme-typed field.
   Reaching 51 needs a different taxonomy, not deprecation.
3. **"`Card.outlined`'s outline is invisible against this theme."** Recorded in the app's own
   source. Wrong: the app's `cardTheme.shape` *erases* it, and the line that does so is otherwise a
   no-op.
4. **"The pip buttons are 30 × 30."** They ask for 30 and render at **22**.
5. **"Labels truncate at 1.26× text scale."** Wrong twice over, and the truth is worse. The
   threshold for `Paralysis / Poison / Death` is ≈**1.30×**, not 1.26 — but that label is **not the
   widest**. `Attacks per round (in game)` truncates at ≈**1.21×**, below GNOME's 1.25. The
   arithmetic error was assuming `letterSpacing` scales with `textScaler`; `text_style.dart:1346-1364`
   scales `fontSize` and passes letter-spacing through untouched.
6. **"Two 48-px pip buttons fit with ~60 px to spare."** The 190 px budget is right; the spare is
   **66 px against a three-pip ceiling and 1.1 px against a fighter's real five**. The conclusion
   holds by about a pixel, which is not what "60 px to spare" conveys.

⚠️ **Every figure in this document that is computed rather than quoted was independently
re-derived by a verification pass instructed to refute rather than confirm.** Four survived
unchanged, four did not, and the four above are the corrections. Two claims are marked in that
pass as resting on a glyph measurement that cannot be made without a font engine — the text-scale
thresholds — and are good to roughly ±0.015; the *mechanism* is exact, the third digit is not.

## One thing to check that is outside this review's scope

The verification pass observed, while computing the pip-row budget, that `character_sheet.dart:148-149`
appears to return `weapprof`'s raw column value, while the `min(profsmax.FIRST_LEVEL, …)` cap lives
in `creation_viewmodel.dart:305-314`. If that reading is right, the pip ceiling closed on
2026-08-11 is enforced in the creation flow but **not** on the character sheet — which `CLAUDE.md`
records as "implemented in creation and on the character sheet alike". **I have not verified this
myself and it is not a finding of this review.** It is written down because it would be a rules
defect rather than a UI one, and because a number noticed in passing is exactly how the last four
of those were found.
