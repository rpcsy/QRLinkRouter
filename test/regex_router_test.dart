import 'package:flutter_test/flutter_test.dart';
import 'package:qr_link_router/services/regex_router.dart';

void main() {
  group('原有平台规则（回归测试，必须继续通过）', () {
    test('抖音短链', () {
      final r = RegexRouter.match('https://v.douyin.com/iAbCdEf/');
      expect(r, isNotNull);
      expect(r!.appName, '抖音');
      expect(r.scheme, 'douyin://');
    });

    test('微信短链与 mp 链接', () {
      expect(RegexRouter.match('https://mp.weixin.qq.com/s/abcdef')!.scheme,
          'weixin://');
      expect(RegexRouter.match('weixin://dl/scan')!.scheme, 'weixin://');
    });

    test('支付宝', () {
      expect(RegexRouter.match('https://qr.alipay.com/fkx1234567890')!.scheme,
          'alipays://');
    });

    test('淘宝', () {
      expect(RegexRouter.match('https://m.tb.cn/h.abcdef')!.scheme, 'taobao://');
    });

    test('哔哩哔哩', () {
      expect(RegexRouter.match('https://b23.tv/abcdEFG')!.scheme, 'bilibili://');
    });

    test('小红书', () {
      expect(RegexRouter.match('https://xhslink.com/a/AbCdEf')!.scheme, 'xhs://');
    });

    test('拼多多', () {
      expect(
        RegexRouter.match('https://mobile.yangkeduo.com/goods.html?x=1')!.scheme,
        'pinduoduo://',
      );
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
      expect(RegexRouter.match('HTTPS://V.DOUYIN.COM/ABC')!.scheme, 'douyin://');
    });
  });

  group('修改点2：校园类 App 新增规则', () {
    test('企业微信必须优先于微信命中', () {
      final r = RegexRouter.match('https://work.weixin.qq.com/wework_admin/x');
      expect(r, isNotNull);
      expect(r!.appName, '企业微信');
      expect(r.scheme, 'workweixin://');
    });

    test('趣知校园', () {
      final r = RegexRouter.match('https://qzxy.demo.com/invite/abc');
      expect(r!.appName, '趣知校园');
      expect(r.scheme, 'qzxy://');
    });

    test('胖乖生活', () {
      final r = RegexRouter.match('https://www.pangguai.com/activity/1');
      expect(r!.scheme, 'pangguai://');
    });

    test('学习通（超星）', () {
      final r = RegexRouter.match('https://passport.chaoxing.com/login?x=1');
      expect(r!.scheme, 'chaoxing://');
    });

    test('钉钉', () {
      final r = RegexRouter.match('https://www.dingtalk.com/oa/abc');
      expect(r!.scheme, 'dingtalk://');
    });

    test('飞书', () {
      final r = RegexRouter.match('https://www.feishu.cn/invite/xyz');
      expect(r!.scheme, 'lark://');
    });

    test('建行生活', () {
      final r = RegexRouter.match('https://www.ccbhome.cn/act/1');
      expect(r!.scheme, 'ccblife://');
    });

    test('云闪付', () {
      final r = RegexRouter.match('https://www.yunshanfu.cn/pay/1');
      expect(r!.scheme, 'uppay://');
    });

    test('智慧校园', () {
      final r = RegexRouter.match('https://zhxy.demo.edu.cn/index');
      expect(r!.scheme, 'zhxy://');
    });

    test('校园一点通', () {
      final r = RegexRouter.match('https://ydt.demo.edu.cn/home');
      expect(r!.scheme, 'xiaoyuanydt://');
    });
  });

  group('修改点2：日常通用 App 新增规则', () {
    test('QQ 与 QQ音乐顺序：y.qq.com 必须命中 QQ音乐', () {
      final music = RegexRouter.match('https://y.qq.com/n/ryqq/songDetail/abc');
      expect(music!.appName, 'QQ音乐');
      expect(music.scheme, 'qqmusic://');

      final qq = RegexRouter.match('https://www.qq.com/news/1');
      expect(qq!.appName, 'QQ');
      expect(qq.scheme, 'mqq://');
    });

    test('美团', () {
      expect(RegexRouter.match('https://www.meituan.com/deal/1')!.scheme,
          'meituan://');
    });

    test('饿了么', () {
      expect(RegexRouter.match('https://www.ele.me/restapi/x')!.scheme,
          'eleme://');
    });

    test('京东', () {
      expect(RegexRouter.match('https://item.jd.com/100.html')!.scheme, 'jd://');
    });

    test('快手', () {
      expect(RegexRouter.match('https://v.kuaishou.com/abcdef')!.scheme,
          'kwai://');
    });

    test('网易云音乐', () {
      expect(RegexRouter.match('https://music.163.com/#/song?id=1')!.scheme,
          'orpheus://');
    });

    test('高德地图', () {
      expect(RegexRouter.match('https://www.amap.com/poi/1')!.scheme,
          'iosamap://');
    });

    test('百度地图', () {
      expect(RegexRouter.match('https://map.baidu.com/@1,2')!.scheme,
          'baidumap://');
    });

    test('携程', () {
      expect(RegexRouter.match('https://www.ctrip.com/hotels/1')!.scheme,
          'ctrip://');
    });

    test('滴滴', () {
      expect(RegexRouter.match('https://www.didiglobal.com/taxi')!.scheme,
          'diditaxi://');
    });

    test('大众点评使用 dianping:// 规格', () {
      final r = RegexRouter.match('https://www.dianping.com/shop/1');
      expect(r!.appName, '大众点评');
      expect(r.scheme, 'dianping://');
    });

    test('微博', () {
      expect(RegexRouter.match('https://weibo.com/u/123')!.scheme, 'weibo://');
    });

    test('知乎', () {
      expect(RegexRouter.match('https://www.zhihu.com/question/1')!.scheme,
          'zhihu://');
    });

    test('酷狗音乐', () {
      expect(RegexRouter.match('https://www.kugou.com/song/1')!.scheme,
          'kugou://');
    });

    test('招商银行 / 交通银行', () {
      expect(
        RegexRouter.match('https://www.cmbchina.com/personal/1')!.scheme,
        'cmbmobilebank://',
      );
      expect(
        RegexRouter.match('https://www.bankcomm.com/BankCommSite/1')!.scheme,
        'bankcomm://',
      );
    });
  });

  test('规则总数与平台清单', () {
    expect(RegexRouter.ruleCount, greaterThan(30));
    expect(
      RegexRouter.supportedApps,
      containsAll(<String>[
        '抖音', '微信', '支付宝', '淘宝', '哔哩哔哩', '小红书', '拼多多', 'QQ',
        '企业微信', '学习通', '趣知校园', '胖乖生活', '智慧校园', '校园一点通',
        '钉钉', '飞书', '建行生活', '云闪付', '美团', '饿了么', '京东', '快手',
        '网易云音乐', '高德地图', '百度地图', '携程', '滴滴出行', '微博', '知乎',
        '酷狗音乐', 'QQ音乐', '招商银行', '交通银行',
      ]),
    );
  });
}