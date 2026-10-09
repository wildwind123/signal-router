import 'package:alien_signals/alien_signals.dart';
import 'package:signal_router/signal_router.dart';

/// Route templates. A `p___<name>` segment is a param.
class Routes {
  static const home = "/home/";
  static const products = "/home/products/";
  static const product = "/home/products/p___id/";
  static const settings = "/home/settings/";
}

/// Anything can be a "page": widgets in Flutter, strings here.
const pages = {
  Routes.home: "HomePage",
  Routes.products: "ProductListPage",
  Routes.product: "ProductPage",
  Routes.settings: "SettingsPage",
};

void main() {
  final router = SignalRouter<String>(
    mainPath: Routes.home,
    exitApp: () => print("exitApp() called"),
    pushPageHooks: [
      (routePath, routeData, routeRaw) =>
          print("[${routeData.navigationType.name}] $routeRaw"),
    ],
  );

  // Re-runs on every route change. In Flutter, rebuild your UI here.
  final stop = effect(() {
    final route = router.route();
    final stack = router.getStackPages(routers: pages);
    print("  route:   ${route.route}");
    print("  id:      ${getParamInt(route, "id")}");
    print("  tab:     ${getQueryString(route, "tab")}");
    print("  stack:   $stack");
    print("  canPop:  ${router.canPop()}");
  });

  router.pushPage(Routes.products, RouteData());
  router.pushPage(
    Routes.product,
    RouteData(params: {"id": "42"}, query: {"tab": "reviews"}),
  );

  // Opening several products in a row keeps only the newest one in history.
  for (final id in ["43", "44"]) {
    router.pushPage(
      Routes.product,
      RouteData(
        params: {"id": id},
        routerHistoryKeepSame: RouterHistoryKeepSame(count: 1),
      ),
    );
  }
  print("history: ${router.routerHistory}");

  router.popPage(); // back to the product list
  router.popPage(); // back to home (mainPath)
  router.popPage(); // nothing left: exitApp()

  stop();
}
