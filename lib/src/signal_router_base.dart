import 'package:alien_signals/alien_signals.dart' as sl;

const String splitSymbol = "___";
const String paramsPrefix = "p$splitSymbol";

/// Last seen query values used by [getQueryCacheInt], keyed by
/// `"<prefix>__<queryName>"`. Shared by all routers; clear it when needed.
final Map<String, String> cacheQueryOldValues = {};

/// How a route change was triggered.
enum NavigationType {
  /// [SignalRouter.pushPage] was called.
  push,

  /// [SignalRouter.popPage] went back to a previous route.
  pop,
}

class RouteInfo {
  String route = "";
  RouteData data = RouteData();
}

/// Limits how many consecutive history entries of the same route are kept.
///
/// When a route is pushed with this option, the entries at the end of the
/// history that have the same route template (and match [query]) are
/// trimmed so that, including the new entry, at most [count] remain. The
/// oldest entries of that run are removed first. A [count] of 0 or less
/// disables trimming.
class RouterHistoryKeepSame {
  int count;

  /// Extra conditions for an entry to count as "the same".
  ///
  /// For each key, both the pushed route and the history entry must have
  /// that query key. If the value is not null, the query value must also be
  /// equal to it.
  Map<String, String?>? query;

  RouterHistoryKeepSame({required this.count, this.query});
}

class RouteData {
  Map<String, String>? params;
  Map<String, String>? query;
  bool? writeOnHistory;
  RouterHistoryKeepSame? routerHistoryKeepSame;

  /// How this navigation was triggered. Set by the router; hooks can read it
  /// to tell a push from a pop.
  NavigationType navigationType;

  @Deprecated('Not used by the router. Will be removed.')
  bool? withoutChangeRoute;

  RouteData({
    this.writeOnHistory,
    this.params,
    this.query,
    this.routerHistoryKeepSame,
    this.navigationType = NavigationType.push,
  });
}

class SignalRouter<T> {
  String mainPath;
  void Function() exitApp;

  /// Called after every route change, including [popPage]. Check
  /// [RouteData.navigationType] to tell a push from a pop.
  List<Function(String routePath, RouteData routeData, String routeRaw)>?
      pushPageHooks;

  SignalRouter({
    required this.mainPath,
    required this.exitApp,
    this.pushPageHooks,
  });

  /// The current route as a raw string, for example
  /// `/root/item/p___id___5/?tab=info`.
  late final sl.WritableSignal<String> rawRoute = sl.signal(mainPath);

  /// The current route parsed into a template and its params and query.
  late final sl.Computed<RouteInfo> route = sl.computed((_) {
    return parseRoute(rawRoute());
  });

  @Deprecated('Use rawRoute instead.')
  sl.WritableSignal<String> get slvRouteRaw => rawRoute;

  @Deprecated('Use route instead.')
  sl.Computed<RouteInfo> get slcRoute => route;

  /// Raw routes of previous pages, oldest first. The current page is the
  /// last entry, unless it was pushed with `writeOnHistory: false`.
  final List<String> routerHistory = [];

  final _historyVersion = sl.signal(0);

  /// Whether [popPage] goes back to a route instead of calling [exitApp].
  late final sl.Computed<bool> canPop = sl.computed((_) {
    _historyVersion();
    return routerHistory.isNotEmpty;
  });

  void _historyChanged() {
    _historyVersion.set(_historyVersion() + 1);
  }

  /// Runs [fn] in a signal batch, so effects run once after the route and
  /// history have both been updated.
  void _batch(void Function() fn) {
    sl.startBatch();
    try {
      fn();
    } finally {
      sl.endBatch();
    }
  }

  void pushPage(String routePath, RouteData routeData) {
    _batch(() => _pushPage(routePath, routeData));
  }

  void _pushPage(String routePath, RouteData routeData) {
    var nV = routePath;
    if (routeData.params != null) {
      for (String key in routeData.params!.keys) {
        nV = nV.replaceAll("/p$splitSymbol$key/",
            "/p$splitSymbol$key$splitSymbol${routeData.params![key]}/");
      }
    }
    if (routeData.query != null) {
      var q = "";
      var i = 0;
      for (String key in routeData.query!.keys) {
        var v = "${Uri.encodeQueryComponent(key)}="
            "${Uri.encodeQueryComponent(routeData.query![key]!)}";
        if (i == 0) {
          q = v;
        } else {
          q = "$q&$v";
        }
        i++;
      }
      nV = "$nV?$q";
    }

    rawRoute.set(nV);
    if (pushPageHooks != null && pushPageHooks!.isNotEmpty) {
      for (var i = 0; i < pushPageHooks!.length; i++) {
        pushPageHooks![i](routePath, routeData, nV);
      }
    }

    if (routeData.writeOnHistory == null || routeData.writeOnHistory!) {
      handleRouterHistoryKeepSame(routePath, routeData);
      routerHistory.add(rawRoute());
      _historyChanged();
    }
  }

  void handleRouterHistoryKeepSame(String routePath, RouteData routeData) {
    final keepSame = routeData.routerHistoryKeepSame;
    if (keepSame == null || keepSame.count <= 0) {
      return;
    }
    if (!_matchesKeepSameQuery(keepSame, routeData.query)) {
      return;
    }

    var sameCount = 0;
    for (var x = routerHistory.length - 1; x >= 0; x--) {
      var pR = parseRoute(routerHistory[x]);
      if (pR.route != routePath ||
          !_matchesKeepSameQuery(keepSame, pR.data.query)) {
        break;
      }
      sameCount++;
    }

    // Keep the newest `count - 1` entries of the run; the new entry is added
    // after this.
    var delCount = sameCount - keepSame.count + 1;
    if (delCount > 0) {
      var start = routerHistory.length - sameCount;
      routerHistory.removeRange(start, start + delCount);
      _historyChanged();
    }
  }

  bool _matchesKeepSameQuery(
      RouterHistoryKeepSame keepSame, Map<String, String>? query) {
    if (keepSame.query == null) {
      return true;
    }
    if (query == null) {
      return false;
    }
    for (var entry in keepSame.query!.entries) {
      if (!query.containsKey(entry.key)) {
        return false;
      }
      if (entry.value != null && entry.value != query[entry.key]) {
        return false;
      }
    }
    return true;
  }

  void popPage() {
    _batch(_popPage);
  }

  void _popPage() {
    var p = "";
    if (routerHistory.length == 1) {
      p = mainPath;
      routerHistory.removeLast();
    } else if (routerHistory.isEmpty) {
      exitApp();
      return;
    } else {
      routerHistory.removeLast();
      p = routerHistory.last;
    }
    _historyChanged();
    var pRoute = parseRoute(p);
    pRoute.data.writeOnHistory = false;
    pRoute.data.navigationType = NavigationType.pop;
    _pushPage(pRoute.route, pRoute.data);
  }

  List<T> getStackPages(
      {required Map<String, T> routers,
      bool Function(String pathTmpl)? includePathTmpl}) {
    List<T> list = [];
    // Split the path and remove empty elements
    List<String> parts =
        route().route.split("/").where((part) => part.isNotEmpty).toList();

    // Build cumulative paths
    List<String> result = [];
    String currentPath = "";
    for (String part in parts) {
      currentPath += "/$part";
      result.add("$currentPath/");
    }

    for (var i = 0; i < result.length; i++) {
      if (routers.containsKey(result[i])) {
        if (includePathTmpl != null && !includePathTmpl(result[i])) {
          continue;
        }
        list.add(routers[result[i]] as T);
      }
    }
    return list;
  }
}

RouteInfo parseRoute(String rawRoute) {
  var rI = RouteInfo();

  var v = rawRoute.split("/").where((part) => part.isNotEmpty).toList();
  var routeParts = <String>[];

  for (var x = 0; x < v.length; x++) {
    var rV = v[x];
    if (v[x].startsWith(paramsPrefix)) {
      var l = splitCustom(v[x]);
      if (l.length == 3) {
        rV = "${l[0]}$splitSymbol${l[1]}";
        rI.data.params ??= {};
        rI.data.params![l[1]] = l[2];
      }
      // A param segment without a value (a template) is kept as is.
    } else if (v.length - 1 == x && v[x].startsWith("?")) {
      var q = v[x].replaceRange(0, 1, '');
      var qList = q.split("&").where((part) => part.isNotEmpty).toList();
      for (var s = 0; s < qList.length; s++) {
        var eq = qList[s].indexOf("=");
        var key = eq == -1 ? qList[s] : qList[s].substring(0, eq);
        var value = eq == -1 ? "" : qList[s].substring(eq + 1);
        rI.data.query ??= {};
        rI.data.query![_decodeQuery(key)] = _decodeQuery(value);
      }
      break;
    }
    routeParts.add(rV);
  }

  rI.route = routeParts.isEmpty ? "" : "/${routeParts.join("/")}/";
  return rI;
}

/// Decodes a query key or value, returning it unchanged when it is not
/// valid encoding (for example a hand-written route containing a raw "%").
String _decodeQuery(String value) {
  try {
    return Uri.decodeQueryComponent(value);
  } catch (_) {
    return value;
  }
}

List<String> splitCustom(String text) {
  // Split by underscore
  List<String> parts = text.split(splitSymbol);

  // If there are 3 or fewer parts, return as is
  if (parts.length <= 3) {
    return parts;
  }

  // Otherwise, take first two parts and combine the rest
  return [
    parts[0], // "p"
    parts[1], // "id"
    parts.sublist(2).join(splitSymbol) // Join remaining parts with "_"
  ];
}

String getParamString(RouteInfo? routeInfo, String paramName) {
  if (routeInfo?.data.params == null ||
      !routeInfo!.data.params!.containsKey(paramName)) {
    return "";
  }

  return routeInfo.data.params![paramName]!;
}

/// Returns the param as an int, or 0 when it is missing or not an integer.
int getParamInt(RouteInfo? routeInfo, String paramName) {
  return int.tryParse(getParamString(routeInfo, paramName)) ?? 0;
}

String getQueryString(RouteInfo? routeInfo, String queryName) {
  if (routeInfo?.data.query == null ||
      !routeInfo!.data.query!.containsKey(queryName)) {
    return "";
  }

  return routeInfo.data.query![queryName]!;
}

/// Returns the query value as an int, or 0 when it is missing or not an
/// integer.
int getQueryInt(RouteInfo? routeInfo, String queryName) {
  return int.tryParse(getQueryString(routeInfo, queryName)) ?? 0;
}

/// Like [getQueryInt], but when the query value is missing it returns the
/// last value seen for the same [prefix] and [queryName]. Non-integer values
/// are ignored.
int getQueryCacheInt(RouteInfo? routeInfo, String prefix, String queryName) {
  var cacheKey = "${prefix}__$queryName";
  var v = int.tryParse(getQueryString(routeInfo, queryName));

  if (v == null) {
    return int.tryParse(cacheQueryOldValues[cacheKey] ?? "") ?? 0;
  }
  cacheQueryOldValues[cacheKey] = "$v";
  return v;
}
