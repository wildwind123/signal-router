import 'package:signal_router/signal_router.dart';
import 'package:test/test.dart';

class RouteTmplPath {
  static const root = "/root/";
  static const page1 = "/root/page1/";
  static const page1subPage1 = "/root/page1/sub_page1_1/";
  static const page1subPage2 = "/root/page1/sub_page1_2/";
  static const page2 = "/root/page2/";
}

var routes = {
  RouteTmplPath.root: "fakePage_root",
  RouteTmplPath.page1: "fakePage_page1",
  RouteTmplPath.page1subPage1: "fakePage_page1subPage1",
  RouteTmplPath.page1subPage2: "fakePage_page1subPage2",
  RouteTmplPath.page2: "fakePage_page2",
};

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

      
      pages = sr.getStackPages(routers: routes, includePathTmpl: (pathTmpl) {
        if (pathTmpl.startsWith(RouteTmplPath.page1) && pathTmpl != RouteTmplPath.page1) {
          return false;
        }
        return true;
      },);
      expect(pages[0], "fakePage_root");
      expect(pages[1], "fakePage_page1");
      expect(2, pages.length);
    });
  });
}
