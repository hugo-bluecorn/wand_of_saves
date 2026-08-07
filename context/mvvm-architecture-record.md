# Flutter MVVM Architecture — the layering record

> Source: https://docs.flutter.dev/app-architecture/guide (official Flutter architecture guidance)
> Fetched: 2026-08-05 · This is a **distillation**, not a verbatim pin — quoted phrases are the
> guide's own wording. The guide is state-solution-agnostic; the Riverpod mapping is **ours**, via
> the declared deviations in `planning/decisions.md` — D2 (Riverpod, no codegen) and D7 (DI through
> providers). **Re-homed 2026-08-07:** this line previously pointed at
> `nearinfinity-port-contract.md`, a document of the earlier `near_infinity_flutter` experiment that
> does not exist in this repository.

---

## The layers

Four core layers, one optional:

| Layer | Group | One-line charter |
|---|---|---|
| **View** | UI layer | "Describes how to present application data to the user" — widget compositions |
| **ViewModel** | UI layer | "Exposes the application data necessary to render a view"; most app logic lives here |
| **Repository** | Data layer | "Source of truth for your model data"; transforms raw service data into **domain models** |
| **Service** | Data layer | "Wrap API endpoints and expose asynchronous response objects" — stateless |
| **Use-Case** *(optional)* | Domain layer | Encapsulates logic that merges repositories, is exceedingly complex, or is reused across ViewModels |

Using MVVM language: "services and repositories make up your _model layer_."

## Per-layer rules

**View** — MAY: simple show/hide conditionals on ViewModel flags · animation logic · layout logic
from device info · simple routing. MAY NOT: contain business logic or data logic; it "should be
passed all data they need to render from the view model."

**ViewModel** — retrieves from repositories and transforms for presentation (filter/sort/aggregate)
· maintains the view's current state so rebuilds don't lose it · exposes **commands** (member
functions the view's gesture handlers call). Depends on repositories (and optionally use-cases).

**Repository** — one repository class per data type · owns business logic (caching, error handling,
retry, refresh, polling) · outputs **domain models** · holds app-wide session state.
**"Repositories should never be aware of each other."** Cross-repository logic goes in the
ViewModel or the domain layer.

**Service** — one service class per data source (platform APIs, REST endpoints, **local files**) ·
"they hold no state" · exposes `Future`/`Stream`.

## Dependency and cardinality rules

- **Unidirectional:** View → ViewModel → (Use-Case →) Repository → Service. Never backwards.
- **View : ViewModel = 1 : 1** — and "one view doesn't equal one widget"; a ViewModel pairs with a
  *collection* of widgets. "Every instance of a paired _view_ and _view model_ defines one feature."
- **ViewModel : Repository = many : many** · **Repository : Service = many : many**.

## State ownership

| Where | What lives there |
|---|---|
| View | pure UI state (animation, layout) |
| ViewModel | presentation state — transformed, UI-ready, survives rebuilds |
| Repository | source-of-truth data + app-wide lifecycle state |
| Service | **nothing** — stateless by rule |

## The Riverpod mapping — SETTLED 2026-08-07

Previously listed here as open "oracle-leg work against the pinned Riverpod **3.3.2** sources". That
version is stale — this project resolves **3.4.2** — and the questions are now answered. The mapping
lives in `planning/architecture.md` §The provider graph; the decisions behind it are D2 (manual
declaration, no codegen) and D7 (DI through providers).

| Question | Answer |
|---|---|
| Which types realize a ViewModel | `NotifierProvider` / `AsyncNotifierProvider`; commands are members on the notifier |
| How Views bind | `ConsumerWidget` + `ref.watch`, one ViewModel per view, preserving the 1 : 1 rule |
| How Repositories and Services are provided | `Provider`, declared by hand in `lib/config/` (D7) |
| Codegen | None, ever (D2) — manual declaration style only |

Verified against the Riverpod 3.4.2 sources: `Provider`, `FutureProvider`, `NotifierProvider` and
`AsyncNotifierProvider` are all current API. `StateProvider` and `StateNotifierProvider` are the
ones Riverpod 3.x treats as legacy — do not use them.
