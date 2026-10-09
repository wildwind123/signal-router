import 'package:alien_signals/alien_signals.dart' as sl;
import 'package:signal_router/signal_router.dart';
import 'package:test/test.dart';

class RouteTmplPath {
  static const root = "/root/";
  static const page1 = "/root/page1/";
  static const page1subPage1 = "/root/page1/sub_page1_1/";
  static const page1subPage2 = "/root/page1/sub_page1_2/";
  static const page2 = "/root/page2/";
  static const item = "/root/item/p___id/";
}

var routes = {
  RouteTmplPath.root: "fakePage_root",
  RouteTmplPath.page1: "fakePage_page1",
  RouteTmplPath.page1subPage1: "fakePage_page1subPage1",
  RouteTmplPath.page1subPage2: "fakePage_page1subPage2",
  RouteTmplPath.page2: "fakePage_page2",
};

SignalRouter<String> newRouter({
  String mainPath = RouteTmplPath.root,
  void Function()? exitApp,
  List<Function(String routePath, RouteData routeData, String routeRaw)>? hooks,
}) {
  return SignalRouter<String>(
    mainPath: mainPath,
    exitApp: exitApp ?? () {},
    pushPageHooks: hooks,
  );
}

void main() {
  group('main', () {
    test('test_getStackPages', () {
      final sr = SignalRouter(
        mainPath: "/root/page1/sub_page1_2/",
        exitApp: () {},
      );
      var pages = sr.getStackPages(routers: routes);
      expect(pages[0], "fakePage_root");
      expect(pages[1], "fakePage_page1");
      expect(pages[2], "fakePage_page1subPage2");
      expect(3, pages.length);

      pages = sr.getStackPages(
        routers: routes,
        includePathTmpl: (pathTmpl) {
          if (pathTmpl.startsWith(RouteTmplPath.page1) &&
              pathTmpl != RouteTmplPath.page1) {
            return false;
          }
          return true;
        },
      );
      expect(pages[0], "fakePage_root");
      expect(pages[1], "fakePage_page1");
      expect(2, pages.length);
    });
  });

  group('parseRoute', () {
    test('plain route is normalized with leading and trailing slash', () {
      expect(parseRoute("/root/page1/").route, "/root/page1/");
      expect(parseRoute("root/page1").route, "/root/page1/");
      expect(parseRoute("//root//page1//").route, "/root/page1/");
    });

    test('plain route has no params or query', () {
      final r = parseRoute("/root/page1/");
      expect(r.data.params, isNull);
      expect(r.data.query, isNull);
    });

    test('empty route', () {
      expect(parseRoute("").route, "");
      expect(parseRoute("/").route, "");
    });

    test('params are extracted and route keeps the template', () {
      final r = parseRoute("/root/item/p___id___42/");
      expect(r.route, RouteTmplPath.item);
      expect(r.data.params, {"id": "42"});
    });

    test('multiple params', () {
      final r = parseRoute("/root/p___a___1/sub/p___b___2/");
      expect(r.route, "/root/p___a/sub/p___b/");
      expect(r.data.params, {"a": "1", "b": "2"});
    });

    test('param value containing the split symbol is kept intact', () {
      final r = parseRoute("/root/p___id___x___y/");
      expect(r.route, "/root/p___id/");
      expect(r.data.params, {"id": "x___y"});
    });

    test('query is extracted from last segment', () {
      final r = parseRoute("/root/page1/?a=1&b=two");
      expect(r.route, "/root/page1/");
      expect(r.data.query, {"a": "1", "b": "two"});
    });

    test('empty query segment yields no query', () {
      final r = parseRoute("/root/?");
      expect(r.route, "/root/");
      expect(r.data.query, isNull);
    });

    test('params and query together', () {
      final r = parseRoute("/root/item/p___id___7/?tab=info");
      expect(r.route, RouteTmplPath.item);
      expect(r.data.params, {"id": "7"});
      expect(r.data.query, {"tab": "info"});
    });
  });

  group('query encoding', () {
    RouteInfo roundTrip(Map<String, String> query) {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.page1, RouteData(query: query));
      return sr.slcRoute();
    }

    test('simple values produce the same URL as before', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.page1, RouteData(query: {"page": "2"}));
      expect(sr.slvRouteRaw(), "/root/page1/?page=2");
    });

    test('value with ampersand', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.page1, RouteData(query: {"q": "x&y"}));
      expect(sr.slvRouteRaw(), "/root/page1/?q=x%26y");
      expect(sr.slcRoute().data.query, {"q": "x&y"});
    });

    test('value with equals sign', () {
      expect(roundTrip({"q": "a=b"}).data.query, {"q": "a=b"});
    });

    test('value with slash keeps route intact', () {
      final r = roundTrip({"q": "a/b/c"});
      expect(r.route, RouteTmplPath.page1);
      expect(r.data.query, {"q": "a/b/c"});
    });

    test('value with question mark, plus, space, hash and percent', () {
      const v = "a?b+c d#e%f";
      expect(getQueryString(roundTrip({"q": v}), "q"), v);
    });

    test('value with unicode', () {
      expect(getQueryString(roundTrip({"q": "привет 日本"}), "q"), "привет 日本");
    });

    test('key with reserved characters', () {
      expect(roundTrip({"a&b=c": "1"}).data.query, {"a&b=c": "1"});
    });

    test('empty value', () {
      expect(roundTrip({"q": ""}).data.query, {"q": ""});
    });

    test('item without "=" gives empty value instead of crashing', () {
      expect(parseRoute("/root/?flag&a=1").data.query, {"flag": "", "a": "1"});
    });

    test('hand-written value split at first "=" only', () {
      expect(parseRoute("/root/?q=a=b").data.query, {"q": "a=b"});
    });

    test('invalid percent encoding is kept as is', () {
      expect(getQueryString(parseRoute("/root/?q=50%zz"), "q"), "50%zz");
    });

    test('popPage restores encoded query', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.page1, RouteData(query: {"q": "x&y=z/w"}));
      sr.pushPage(RouteTmplPath.page2, RouteData());
      sr.popPage();
      expect(getQueryString(sr.slcRoute(), "q"), "x&y=z/w");
      expect(sr.routerHistory.last, sr.slvRouteRaw());
    });

    test('getStackPages ignores encoded query', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.page1, RouteData(query: {"q": "a/b"}));
      expect(sr.getStackPages(routers: routes),
          ["fakePage_root", "fakePage_page1"]);
    });
  });

  group('splitCustom', () {
    test('three or fewer parts are returned as is', () {
      expect(splitCustom("p___id___5"), ["p", "id", "5"]);
      expect(splitCustom("p___id"), ["p", "id"]);
      expect(splitCustom("abc"), ["abc"]);
    });

    test('extra parts are joined into the third element', () {
      expect(splitCustom("p___id___a___b___c"), ["p", "id", "a___b___c"]);
    });
  });

  group('SignalRouter initial state', () {
    test('route starts at mainPath with empty history', () {
      final sr = newRouter(mainPath: RouteTmplPath.page2);
      expect(sr.slvRouteRaw(), RouteTmplPath.page2);
      expect(sr.slcRoute().route, RouteTmplPath.page2);
      expect(sr.routerHistory, isEmpty);
    });
  });

  group('pushPage', () {
    test('plain route updates signal and history', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.page1, RouteData());
      expect(sr.slvRouteRaw(), RouteTmplPath.page1);
      expect(sr.slcRoute().route, RouteTmplPath.page1);
      expect(sr.routerHistory, [RouteTmplPath.page1]);
    });

    test('params are substituted into the template', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.item, RouteData(params: {"id": "5"}));
      expect(sr.slvRouteRaw(), "/root/item/p___id___5/");
      expect(sr.slcRoute().route, RouteTmplPath.item);
      expect(getParamInt(sr.slcRoute(), "id"), 5);
    });

    test('query is appended in insertion order', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.page1, RouteData(query: {"a": "1", "b": "2"}));
      expect(sr.slvRouteRaw(), "/root/page1/?a=1&b=2");
      expect(sr.slcRoute().data.query, {"a": "1", "b": "2"});
    });

    test('params and query round-trip through parseRoute', () {
      final sr = newRouter();
      sr.pushPage(
        RouteTmplPath.item,
        RouteData(params: {"id": "9"}, query: {"tab": "x"}),
      );
      final r = sr.slcRoute();
      expect(r.route, RouteTmplPath.item);
      expect(r.data.params, {"id": "9"});
      expect(r.data.query, {"tab": "x"});
    });

    test('writeOnHistory false does not record history', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.page1, RouteData(writeOnHistory: false));
      expect(sr.slvRouteRaw(), RouteTmplPath.page1);
      expect(sr.routerHistory, isEmpty);
    });

    test('writeOnHistory true records history', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.page1, RouteData(writeOnHistory: true));
      expect(sr.routerHistory, [RouteTmplPath.page1]);
    });

    test('hooks receive template, data and raw route', () {
      final calls = <List<Object>>[];
      final sr = newRouter(hooks: [
        (path, data, raw) => calls.add(["h1", path, data, raw]),
        (path, data, raw) => calls.add(["h2", path, data, raw]),
      ]);
      final data = RouteData(params: {"id": "3"});
      sr.pushPage(RouteTmplPath.item, data);

      expect(calls, hasLength(2));
      expect(
          calls[0], ["h1", RouteTmplPath.item, data, "/root/item/p___id___3/"]);
      expect(calls[1][0], "h2");
    });

    test('empty hook list is fine', () {
      final sr = newRouter(hooks: []);
      sr.pushPage(RouteTmplPath.page1, RouteData());
      expect(sr.slvRouteRaw(), RouteTmplPath.page1);
    });
  });

  group('popPage', () {
    test('returns to previous page without growing history', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.page1, RouteData());
      sr.pushPage(RouteTmplPath.page2, RouteData());
      sr.popPage();
      expect(sr.slvRouteRaw(), RouteTmplPath.page1);
      expect(sr.routerHistory, [RouteTmplPath.page1]);
    });

    test('last entry pops back to mainPath', () {
      final sr = newRouter(mainPath: RouteTmplPath.root);
      sr.pushPage(RouteTmplPath.page1, RouteData());
      sr.popPage();
      expect(sr.slvRouteRaw(), RouteTmplPath.root);
      expect(sr.routerHistory, isEmpty);
    });

    test('empty history calls exitApp and keeps route', () {
      var exited = 0;
      final sr = newRouter(exitApp: () => exited++);
      sr.pushPage(RouteTmplPath.page1, RouteData(writeOnHistory: false));
      sr.popPage();
      expect(exited, 1);
      expect(sr.slvRouteRaw(), RouteTmplPath.page1);
    });

    test('full back navigation ends with exitApp', () {
      var exited = 0;
      final sr = newRouter(exitApp: () => exited++);
      sr.pushPage(RouteTmplPath.page1, RouteData());
      sr.pushPage(RouteTmplPath.page2, RouteData());

      sr.popPage();
      expect(sr.slvRouteRaw(), RouteTmplPath.page1);
      sr.popPage();
      expect(sr.slvRouteRaw(), RouteTmplPath.root);
      expect(exited, 0);
      sr.popPage();
      expect(exited, 1);
    });

    test('restores params and query of previous page', () {
      final sr = newRouter();
      sr.pushPage(
        RouteTmplPath.item,
        RouteData(params: {"id": "1"}, query: {"tab": "a"}),
      );
      sr.pushPage(RouteTmplPath.page2, RouteData());
      sr.popPage();
      expect(sr.slvRouteRaw(), "/root/item/p___id___1/?tab=a");
      expect(getParamInt(sr.slcRoute(), "id"), 1);
      expect(getQueryString(sr.slcRoute(), "tab"), "a");
    });

    test('triggers hooks with writeOnHistory false', () {
      final seen = <RouteData>[];
      final sr = newRouter(hooks: [(_, data, __) => seen.add(data)]);
      sr.pushPage(RouteTmplPath.page1, RouteData());
      sr.pushPage(RouteTmplPath.page2, RouteData());
      sr.popPage();
      expect(seen, hasLength(3));
      expect(seen.last.writeOnHistory, isFalse);
    });
  });

  group('routerHistoryKeepSame', () {
    RouteData itemData(String id, {int count = 1, Map<String, String?>? q}) {
      return RouteData(
        params: {"id": id},
        routerHistoryKeepSame: RouterHistoryKeepSame(count: count, query: q),
      );
    }

    test('without option, repeated pushes all go to history', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.item, RouteData(params: {"id": "1"}));
      sr.pushPage(RouteTmplPath.item, RouteData(params: {"id": "2"}));
      sr.pushPage(RouteTmplPath.item, RouteData(params: {"id": "3"}));
      expect(sr.routerHistory, hasLength(3));
    });

    test('count 1 keeps only the newest entry of the same route', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.page1, RouteData());
      sr.pushPage(RouteTmplPath.item, itemData("1"));
      sr.pushPage(RouteTmplPath.item, itemData("2"));
      sr.pushPage(RouteTmplPath.item, itemData("3"));
      expect(sr.routerHistory, [
        RouteTmplPath.page1,
        "/root/item/p___id___3/",
      ]);
    });

    // Entries are removed from the end, so the first entry of the run
    // is kept and only the most recent one is replaced.
    test('count 2 keeps the first and the newest entry', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.page1, RouteData());
      for (final id in ["1", "2", "3", "4"]) {
        sr.pushPage(RouteTmplPath.item, itemData(id, count: 2));
      }
      expect(sr.routerHistory, [
        RouteTmplPath.page1,
        "/root/item/p___id___1/",
        "/root/item/p___id___4/",
      ]);
    });

    test('count 0 disables collapsing', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.item, itemData("1", count: 0));
      sr.pushPage(RouteTmplPath.item, itemData("2", count: 0));
      expect(sr.routerHistory, hasLength(2));
    });

    test('only consecutive entries at the end are collapsed', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.item, itemData("1"));
      sr.pushPage(RouteTmplPath.page1, RouteData());
      sr.pushPage(RouteTmplPath.item, itemData("2"));
      sr.pushPage(RouteTmplPath.item, itemData("3"));
      expect(sr.routerHistory, [
        "/root/item/p___id___1/",
        RouteTmplPath.page1,
        "/root/item/p___id___3/",
      ]);
    });

    test('query key condition: collapses when pushed query has the key', () {
      final sr = newRouter();
      RouteData d(String tab) => RouteData(
            query: {"tab": tab},
            routerHistoryKeepSame:
                RouterHistoryKeepSame(count: 1, query: {"tab": null}),
          );
      sr.pushPage(RouteTmplPath.page1, d("a"));
      sr.pushPage(RouteTmplPath.page1, d("b"));
      expect(sr.routerHistory, ["/root/page1/?tab=b"]);
    });

    test('query key condition: no collapse when pushed query lacks the key',
        () {
      final sr = newRouter();
      final keep = RouterHistoryKeepSame(count: 1, query: {"tab": null});
      sr.pushPage(RouteTmplPath.page1, RouteData(routerHistoryKeepSame: keep));
      sr.pushPage(
        RouteTmplPath.page1,
        RouteData(query: {"other": "1"}, routerHistoryKeepSame: keep),
      );
      expect(sr.routerHistory, hasLength(2));
    });

    test('query value condition: no collapse when value differs', () {
      final sr = newRouter();
      final keep = RouterHistoryKeepSame(count: 1, query: {"tab": "a"});
      sr.pushPage(RouteTmplPath.page1,
          RouteData(query: {"tab": "a"}, routerHistoryKeepSame: keep));
      sr.pushPage(RouteTmplPath.page1,
          RouteData(query: {"tab": "b"}, routerHistoryKeepSame: keep));
      expect(sr.routerHistory, hasLength(2));
    });

    test('query value condition: collapses when value matches', () {
      final sr = newRouter();
      final keep = RouterHistoryKeepSame(count: 1, query: {"tab": "a"});
      sr.pushPage(
          RouteTmplPath.page1,
          RouteData(
              query: {"tab": "a", "n": "1"}, routerHistoryKeepSame: keep));
      sr.pushPage(
          RouteTmplPath.page1,
          RouteData(
              query: {"tab": "a", "n": "2"}, routerHistoryKeepSame: keep));
      expect(sr.routerHistory, ["/root/page1/?tab=a&n=2"]);
    });
  });

  group('reactivity', () {
    test('computed route updates and effects re-run on push', () {
      final sr = newRouter();
      final seen = <String>[];
      final stop = sl.effect(() {
        seen.add(sr.slcRoute().route);
      });

      sr.pushPage(RouteTmplPath.page1, RouteData());
      sr.pushPage(RouteTmplPath.page2, RouteData());
      sr.popPage();
      stop();
      sr.pushPage(RouteTmplPath.root, RouteData());

      expect(seen, [
        RouteTmplPath.root,
        RouteTmplPath.page1,
        RouteTmplPath.page2,
        RouteTmplPath.page1,
      ]);
    });
  });

  group('getStackPages', () {
    test('returns empty list when no templates match', () {
      final sr = newRouter(mainPath: "/other/path/");
      expect(sr.getStackPages(routers: routes), isEmpty);
    });

    test('skips intermediate paths missing from routers', () {
      final sr = newRouter(mainPath: "/root/missing/");
      expect(sr.getStackPages(routers: routes), ["fakePage_root"]);
    });

    test('follows route changes', () {
      final sr = newRouter();
      expect(sr.getStackPages(routers: routes), ["fakePage_root"]);
      sr.pushPage(RouteTmplPath.page2, RouteData());
      expect(sr.getStackPages(routers: routes),
          ["fakePage_root", "fakePage_page2"]);
    });

    test('matches param templates', () {
      final sr = newRouter();
      final r = {
        RouteTmplPath.root: "root",
        "/root/item/": "items",
        RouteTmplPath.item: "item",
      };
      sr.pushPage(RouteTmplPath.item, RouteData(params: {"id": "1"}));
      expect(sr.getStackPages(routers: r), ["root", "items", "item"]);
    });

    test('ignores query when building stack', () {
      final sr = newRouter();
      sr.pushPage(RouteTmplPath.page1, RouteData(query: {"a": "1"}));
      expect(sr.getStackPages(routers: routes),
          ["fakePage_root", "fakePage_page1"]);
    });
  });

  group('param helpers', () {
    final r = parseRoute("/root/p___id___12/p___name___bob/");

    test('getParamString', () {
      expect(getParamString(r, "name"), "bob");
      expect(getParamString(r, "missing"), "");
      expect(getParamString(null, "name"), "");
      expect(getParamString(parseRoute("/root/"), "name"), "");
    });

    test('getParamInt', () {
      expect(getParamInt(r, "id"), 12);
      expect(getParamInt(r, "missing"), 0);
      expect(getParamInt(null, "id"), 0);
    });

    test('getParamInt throws on non-integer value', () {
      expect(() => getParamInt(r, "name"), throwsFormatException);
    });
  });

  group('query helpers', () {
    final r = parseRoute("/root/?page=3&name=bob");

    test('getQueryString', () {
      expect(getQueryString(r, "name"), "bob");
      expect(getQueryString(r, "missing"), "");
      expect(getQueryString(null, "name"), "");
      expect(getQueryString(parseRoute("/root/"), "name"), "");
    });

    test('getQueryInt', () {
      expect(getQueryInt(r, "page"), 3);
      expect(getQueryInt(r, "missing"), 0);
      expect(getQueryInt(null, "page"), 0);
    });

    test('getQueryInt returns 0 on non-integer value', () {
      expect(getQueryInt(r, "name"), 0);
    });

    test('getQueryCacheInt remembers last value per prefix', () {
      const prefix = "test_cache_remember";
      expect(getQueryCacheInt(parseRoute("/root/"), prefix, "page"), 0);
      expect(getQueryCacheInt(parseRoute("/root/?page=5"), prefix, "page"), 5);
      expect(getQueryCacheInt(parseRoute("/root/"), prefix, "page"), 5);
      expect(getQueryCacheInt(null, prefix, "page"), 5);
      expect(getQueryCacheInt(parseRoute("/root/?page=8"), prefix, "page"), 8);
      expect(getQueryCacheInt(parseRoute("/root/"), prefix, "page"), 8);
    });

    test('getQueryCacheInt keeps prefixes isolated', () {
      getQueryCacheInt(parseRoute("/root/?page=1"), "test_cache_a", "page");
      getQueryCacheInt(parseRoute("/root/?page=2"), "test_cache_b", "page");
      expect(getQueryCacheInt(null, "test_cache_a", "page"), 1);
      expect(getQueryCacheInt(null, "test_cache_b", "page"), 2);
    });
  });
}
