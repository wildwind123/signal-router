# signal_router

A small, signal-based router for Dart and Flutter. The whole navigation state
is one reactive string, so routing is plain state: easy to observe, persist,
log and test, with no dependency on Flutter's `Navigator`.

Built on [alien_signals](https://pub.dev/packages/alien_signals). Pure Dart, so
it works with any UI layer.

> **Alpha.** The API may still change between versions.

## Features

- **Reactive state:** `route` is a computed signal; effects re-run on every
  navigation, once per change.
- **Back history:** `pushPage` / `popPage`, with `exitApp` called when there
  is nothing left to go back to.
- **Params and query:** path params via `p___<name>` segments, and URL-encoded
  query values.
- **Page stacks:** `getStackPages` turns `/a/b/c/` into the pages for `/a/`,
  `/a/b/` and `/a/b/c/`, for nested or stacked layouts.
- **History trimming:** keep only the newest N entries when the same route is
  opened repeatedly.
- **Hooks:** callbacks after every navigation (for analytics or logging), with
  `navigationType` telling push from pop.

## Installation

```yaml
dependencies:
  signal_router: ^1.0.0-alpha.3
```

## Route format

Routes are paths with a leading and trailing slash. A segment named
`p___<name>` is a param:

| Template                  | Pushed with                        | Raw route                                |
| ------------------------- | ---------------------------------- | ---------------------------------------- |
| `/home/products/`         | `RouteData()`                      | `/home/products/`                        |
| `/home/products/p___id/`  | `params: {"id": "42"}`             | `/home/products/p___id___42/`            |
| `/home/products/p___id/`  | `params: {"id": "42"}, query: {"tab": "a b"}` | `/home/products/p___id___42/?tab=a+b` |

`router.route()` always gives back the template (`/home/products/p___id/`)
plus the parsed params and query, so you can match on the template.

## Usage

```dart
import 'package:alien_signals/alien_signals.dart';
import 'package:signal_router/signal_router.dart';

class Routes {
  static const home = "/home/";
  static const products = "/home/products/";
  static const product = "/home/products/p___id/";
}

final router = SignalRouter<String>(
  mainPath: Routes.home,
  exitApp: () => print("exit"),
);

void main() {
  effect(() {
    final route = router.route();
    print("${route.route} id=${getParamInt(route, "id")}");
  });

  router.pushPage(Routes.products, RouteData());
  router.pushPage(Routes.product, RouteData(params: {"id": "42"}));
  router.popPage(); // back to /home/products/
}
```

See [example/signal_router_example.dart](example/signal_router_example.dart)
for a complete runnable example.

### With Flutter

Rebuild from an `effect` and map templates to widgets with `getStackPages`:

```dart
final pages = <String, Widget>{
  Routes.home: const HomePage(),
  Routes.products: const ProductListPage(),
  Routes.product: const ProductPage(),
};

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final Effect _effect;
  List<Widget> _stack = [];

  @override
  void initState() {
    super.initState();
    var firstRun = true;
    _effect = effect(() {
      final stack = router.getStackPages(routers: pages);
      // The first run happens synchronously, before the first build.
      if (firstRun) {
        firstRun = false;
        _stack = stack;
      } else {
        setState(() => _stack = stack);
      }
    });
  }

  @override
  void dispose() {
    _effect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => router.popPage(),
      child: Stack(children: _stack),
    );
  }
}
```

Pages read their params with `router.route()`:

```dart
final id = getParamInt(router.route(), "id");
```

## API

### `SignalRouter<T>`

| Member | Description |
| --- | --- |
| `SignalRouter({mainPath, exitApp, pushPageHooks})` | `mainPath` is the start route and the route `popPage` returns to last. `exitApp` is called by `popPage` when the history is empty. |
| `rawRoute` | `WritableSignal<String>` with the current raw route. |
| `route` | `Computed<RouteInfo>`: the current template, params and query. |
| `canPop` | `Computed<bool>`: whether `popPage` goes back instead of calling `exitApp`. |
| `routerHistory` | `List<String>` of raw routes, oldest first. |
| `pushPage(template, RouteData)` | Navigates to a template, filling in params and query. |
| `popPage()` | Goes back one entry, then to `mainPath`, then calls `exitApp`. |
| `getStackPages(routers:, includePathTmpl:)` | Returns the values in `routers` whose keys are prefixes of the current template, shortest first. `includePathTmpl` can skip templates. |
| `pushPageHooks` | Called after every navigation with `(template, routeData, rawRoute)`. |

### `RouteData`

| Field | Description |
| --- | --- |
| `params` | Values for `p___<name>` segments. |
| `query` | Query values; keys and values are URL-encoded. |
| `writeOnHistory` | `false` to navigate without adding a history entry. Default: `true`. |
| `routerHistoryKeepSame` | Trims repeated entries of the same route; see below. |
| `navigationType` | `push` or `pop`, set by the router. |

### `RouterHistoryKeepSame`

When pushing with `RouterHistoryKeepSame(count: n)`, the entries at the end of
the history with the same template are trimmed so that at most `n` remain,
including the new one. The oldest are removed first.

```dart
// Opening product 1, 2, 3 in a row keeps only product 3 in the history.
router.pushPage(
  Routes.product,
  RouteData(
    params: {"id": "3"},
    routerHistoryKeepSame: RouterHistoryKeepSame(count: 1),
  ),
);
```

`query` narrows what counts as "the same": for each key, both the pushed route
and the history entry must have that query key, and if a value is given, the
same value.

### Helpers

| Function | Returns |
| --- | --- |
| `getParamString(route, name)` / `getParamInt(route, name)` | The param, or `""` / `0` when missing or not an integer. |
| `getQueryString(route, name)` / `getQueryInt(route, name)` | The query value, or `""` / `0`. |
| `getQueryCacheInt(route, prefix, name)` | Like `getQueryInt`, but returns the last value seen for `prefix` when the query is missing. |
| `parseRoute(raw)` | Parses a raw route into a `RouteInfo`. |

## Limitations

- Param values must not contain `/`.
- Param names must not contain `_`.
- There is no integration with the browser URL or the platform back button;
  connect them yourself (for example with `PopScope`, as above).
- No redirects or guards: hooks run after navigation and cannot cancel it.

## License

See [LICENSE](LICENSE).
