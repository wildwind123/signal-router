## 1.0.0-alpha.3

### Behavior changes

- `RouterHistoryKeepSame(count: n)` now keeps the **newest** `n` entries of a
  repeated route. Before, it kept the first entry of the run and replaced only
  the most recent one (with `count: 2`, pushing 1, 2, 3, 4 kept `[1, 4]`; it
  now keeps `[3, 4]`). `count: 1` is unchanged.
- `RouterHistoryKeepSame.query` conditions now also apply to the history
  entries being trimmed, not only to the route being pushed.
- `getParamInt` returns `0` for a non-integer value instead of throwing,
  matching `getQueryInt`. `getQueryCacheInt` no longer throws either.
- `parseRoute` keeps a param segment that has no value (`/item/p___id/`) in
  the route instead of dropping it, and no longer loses the leading slash when
  such a segment comes first.
- Effects run once per `pushPage` / `popPage`, after the route and history
  are both updated (navigation is batched).

### Features

- `rawRoute` and `route` replace `slvRouteRaw` and `slcRoute`. The old names
  still work and are deprecated.
- `canPop`: a computed signal telling whether `popPage` goes back or calls
  `exitApp`.
- `RouteData.navigationType` (`NavigationType.push` or `.pop`) lets hooks tell
  a push from a pop.

### Other

- `getQueryInt` no longer prints to the console.
- `RouteData.withoutChangeRoute` is deprecated; it was never used.
- Rewrite the README to match the actual API, and add a runnable example.

## 1.0.0-alpha.2

### Breaking changes

- Upgrade `alien_signals` from ^1.0.3 to ^2.3.3. Write to `slvRouteRaw` with
  `slvRouteRaw.set(value)` instead of `slvRouteRaw(value)`. Reading is
  unchanged (`slvRouteRaw()`).
- `routerHistory` is now a plain `List<String>` instead of a signal. Use
  `router.routerHistory` instead of `router.routerHistory()`.
- `getStackPages` now takes named parameters:
  `getStackPages(routers: routes)` instead of `getStackPages(routes)`.

### Features

- `getStackPages` accepts an optional `includePathTmpl` callback to skip
  matched route templates from the returned stack.

### Fixes

- Query keys and values are URL-encoded on `pushPage` and decoded by
  `parseRoute`, so they can contain `&`, `=`, `/`, `?`, spaces and non-ASCII
  text. Simple values produce the same URLs as before.
- `parseRoute` no longer crashes on a query item without `=` (`?flag` gives
  `flag` with an empty value), and splits each item at the first `=` only.
- Invalid percent-encoding in a query (for example a raw `%`) is kept as is
  instead of throwing.

### Other

- Add a test suite covering route parsing, navigation, history, hooks,
  reactivity, `getStackPages` and the param and query helpers.

## 1.0.0-alpha.1

- Initial version.
