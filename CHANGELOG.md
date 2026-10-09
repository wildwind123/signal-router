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
