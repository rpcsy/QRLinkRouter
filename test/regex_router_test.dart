import 'package:flutter_test/flutter_test.dart';
import 'package:qr_link_router/services/regex_router.dart';

void main() {
  group('RegexRouter 平台匹配', () {
    test('抖音短链', () {
      final result = RegexRouter.match('https://v.douyin.com/iAbCdEf/');
      expect(result, isNotNull);
      expect(result!.appName, '抖音');
      expect(result.scheme, 'douyin://');
    });

    test('微信短链与 mp 链接', () {
      expect(RegexRouter.match('https://mp.weixin.qq.com/s/abcdef')!.scheme,
          'weixin://');
      expect(RegexRouter.match('weixin://dl/scan')!.scheme, 'weixin://');
    });

    test('支付宝', () {
      final result =
          RegexRouter.match('https://qr.alipay.com/fkx1234567890');
      expect(result!.scheme, 'alipays://');
    });

    test('淘宝', () {
      final result = RegexRouter.match('https://m.tb.cn/h.abcdef');
      expect(result!.scheme, 'taobao://');
    });

    test('B站', () {
      final result = RegexRouter.match('https://b23.tv/abcdEFG');
      expect(result!.scheme, 'bilibili://');
    });

    test('小红书', () {
      final result = RegexRouter.match('https://xhslink.com/a/AbCdEf');
      expect(result!.scheme, 'xhs://');
    });

    test('拼多多', () {
      final result =
          RegexRouter.match('https://mobile.yangkeduo.com/goods.html?x=1');
      expect(result!.scheme, 'pinduoduo://');
    });

    test('未命中返回 null', () {
      expect(RegexRouter.match('https://example.com/hello'), isNull);
      expect(RegexRouter.match('随便一段文字'), isNull);
    });

    test('空文本返回 null', () {
      expect(RegexRouter.match(''), isNull);
      expect(RegexRouter.match('    '), isNull);
    });

    test('大小写不敏感', () {
      final result = RegexRouter.match('HTTPS://V.DOUYIN.COM/ABC');
      expect(result, isNotNull);
      expect(result!.scheme, 'douyin://');
    });
  });

  test('支持平台清单完整', () {
    expect(
      RegexRouter.supportedApps,
      containsAll(<String>['抖音', '微信', '支付宝', '淘宝', 'B站', '小红书', '拼多多']),
    );
  });
}