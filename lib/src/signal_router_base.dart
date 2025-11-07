import 'package:alien_signals/alien_signals.dart' as sl;

const String splitSymbol = "___";
const String paramsPrefix = "p$splitSymbol";

final Map<String, String> cacheQueryOldValues = {};

class RouteInfo {
  String route = "";
  RouteData data = RouteData();
}

class RouterHistoryKeepSame {
  int count;
  Map<String, String?>? query;
  RouterHistoryKeepSame({required this.count, this.query});
}

class RouteData {
  Map<String, String>? params;
  Map<String, String>? query;
  bool? writeOnHistory;
  RouterHistoryKeepSame? routerHistoryKeepSame;
  bool? withoutChangeRoute;

  RouteData({
    this.writeOnHistory,
    this.params,
    this.query,
    this.routerHistoryKeepSame,
  });
}

class SignalRouter<T> {
  String mainPath;
  void Function() exitApp;
  List<Function(String routePath, RouteData routeData, String routeRaw)>?
      pushPageHooks;

  SignalRouter({
    required this.mainPath,
    required this.exitApp,
    this.pushPageHooks,
  });

  late final slvRouteRaw = sl.signal(mainPath);

  late final slcRoute = sl.computed((_) {
    return parseRoute(slvRouteRaw());
  });

  final routerHistory = sl.signal<List<String>>([]);

  void pushPage(String routePath, RouteData routeData) {
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
        var v = "$key=${routeData.query![key]}";
        if (i == 0) {
          q = v;
        } else {
          q = "$q&$v";
        }
        i++;
      }
      nV = "$nV?$q";
    }

    slvRouteRaw(nV);
    // print("-----------push route $nV");
    if (pushPageHooks != null && pushPageHooks!.isNotEmpty) {
      for (var i = 0; i < pushPageHooks!.length; i++) {
        pushPageHooks![i](routePath, routeData, nV);
      }
    }

    if (routeData.writeOnHistory == null || routeData.writeOnHistory!) {
      handleRouterHistoryKeepSame(routePath, routeData);
      routerHistory().add(slvRouteRaw());
    }
  }

  void handleRouterHistoryKeepSame(String routePath, RouteData routeData) {
    if (routeData.routerHistoryKeepSame != null &&
        routeData.routerHistoryKeepSame!.count > 0) {
      var deleteLast = 0;

      outerloop:
      for (var x = routerHistory().length - 1; x >= 0; x--) {
        var pR = parseRoute(routerHistory()[x]);
        if (pR.route != routePath) {
          break outerloop;
        }
        if (routeData.routerHistoryKeepSame!.query != null) {
          if (routeData.query == null) {
            break outerloop;
          }
          for (var entry in routeData.routerHistoryKeepSame!.query!.entries) {
            if (!routeData.query!.containsKey(entry.key)) {
              break outerloop;
            }
            if (routeData.routerHistoryKeepSame!.query![entry.key] != null) {
              if (routeData.routerHistoryKeepSame!.query![entry.key] !=
                  routeData.query![entry.key]) {
                break outerloop;
              }
            }
          }
        }
        deleteLast++;
      }
      if (deleteLast > 0) {
        var delCount = deleteLast - routeData.routerHistoryKeepSame!.count + 1;
        if (delCount > 0) {
          for (var x = 0; x < delCount; x++) {
            if (routerHistory().isNotEmpty) {
              routerHistory().removeLast();
            }
          }
        }
      }
    }
  }

  void popPage() {
    var p = "";
    if (routerHistory().length == 1) {
      p = mainPath;
      routerHistory().removeLast();
    } else if (routerHistory().isEmpty) {
      exitApp();
      return;
    } else {
      routerHistory().removeLast();
      p = routerHistory().last;
    }
    var pRoute = parseRoute(p);
    pRoute.data.writeOnHistory = false;
    pushPage(pRoute.route, pRoute.data);
  }

  List<T> getStackPages(Map<String, T> routers) {
    List<T> list = [];
    // Split the path and remove empty elements
    List<String> parts = slcRoute()
            .route
            .split("/")
            .where((part) => part.isNotEmpty)
            .toList();

    // Build cumulative paths
    List<String> result = [];
    String currentPath = "";
    for (String part in parts) {
      currentPath += "/$part";
      result.add("$currentPath/");
    }

    for (var i = 0; i < result.length; i++) {
      if (routers.containsKey(result[i])) {
        list.add(routers[result[i]]!);
      }
    }
    return list;
  }
}


RouteInfo parseRoute(String rawRoute) {
  var rI = RouteInfo();

  var v = rawRoute.split("/").where((part) => part.isNotEmpty).toList();
  var currentRoute = "";

  for (var x = 0; x < v.length; x++) {
    var rV = v[x];
    if (v[x].startsWith(paramsPrefix)) {
      var l = splitCustom(v[x]);
      if (l.length != 3) {
        continue;
      }
      rV = "${l[0]}$splitSymbol${l[1]}";
      rI.data.params ??= {};
      rI.data.params![l[1]] = l[2];
    } else if (v.length - 1 == x && v[x].startsWith("?")) {
      var q = v[x].replaceRange(0, 1, '');
      var qList = q.split("&").where((part) => part.isNotEmpty).toList();
      for (var s = 0; s < qList.length; s++) {
        var sp = qList[s].split("=");
        rI.data.query ??= {};
        rI.data.query![sp[0]] = sp[1];
      }
      break;
    }
    if (x == 0) {
      currentRoute = "/$rV/";
    } else {
      currentRoute = "$currentRoute$rV/";
    }
  }

  rI.route = currentRoute;
  return rI;
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

String getParamsString(RouteInfo? routeInfo, String paramName) {
  if (routeInfo?.data.params == null ||
      !routeInfo!.data.params!.containsKey(paramName)) {
    return "";
  }

  return routeInfo.data.params![paramName]!;
}

int getParamsInt(RouteInfo? routeInfo, String paramName) {
  var v = getParamsString(routeInfo, paramName);
  if (v == "") {
    return 0;
  }

  return int.parse(v);
}

String getQueryString(RouteInfo? routeInfo, String queryName) {
  if (routeInfo?.data.query == null ||
      !routeInfo!.data.query!.containsKey(queryName)) {
    return "";
  }

  return routeInfo.data.query![queryName]!;
}

int getQueryInt(RouteInfo? routeInfo, String queryName) {
  if (routeInfo?.data.query == null ||
      !routeInfo!.data.query!.containsKey(queryName)) {
    return 0;
  }
  var vd = 0;
  try {
    vd = int.parse(routeInfo.data.query![queryName]!);
  } catch (_) {
    print("--ERROR-- cant getQueryInt queryName: $queryName");
  }

  return vd;
}

int getQueryCacheInt(RouteInfo? routeInfo, String prefix, String queryName) {
  var v = getQueryString(routeInfo, queryName);
  var cacheKey = "${prefix}__$queryName";

  if (v == "") {
    if (cacheQueryOldValues.containsKey(cacheKey)) {
      return int.parse(cacheQueryOldValues[cacheKey]!);
    }
    return 0;
  }
  cacheQueryOldValues[cacheKey] = v;
  return int.parse(v);
}
