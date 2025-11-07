# signal_router

A lightweight, signal-based routing library for Dart/Flutter apps. Enables reactive navigation with history stacks, parameterized routes, query params, and customizable hooks.

## Features
- **Reactive Routing**: Uses signals for automatic UI updates on navigation.
- **History Management**: Built-in back/forward stack with optional deduping.
- **Parameterized Paths**: Support for `/user/:id/` style routes.
- **Hooks**: Pre/post-navigation callbacks for analytics or guards.
- **Generic Pages**: Type-safe `SignalPage<T>` for custom data.

## Installation
```yaml
dependencies:
  signal_router: ^1.0.0-alpha.1
```