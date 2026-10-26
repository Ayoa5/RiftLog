// 纯单元测试：评分页链接解析（不依赖网络与 Widget）
//
// 放在仓库里是为了让 flutter analyze / flutter test 有真实可校验的内容；
// flutter create 在 CI 里生成的 test/widget_test.dart 引用的是默认 MyApp，
// 与本项目不符，CI 中会先删除它。

import 'package:flutter_test/flutter_test.dart';
import 'package:hupu_lol/services/hupu_rating_service.dart';

void main() {
  group('HupuRatingService.parseScoreUrl', () {
    test('解析选手级评分页链接', () {
      final r = HupuRatingService.parseScoreUrl(
        'https://m.hupu.com/score/detail.html?outBizType=lol_item&outBizNo=79822',
      );
      expect(r, isNotNull);
      expect(r!.type, 'lol_item');
      expect(r.no, '79822');
    });

    test('解析局级评分页链接', () {
      final r = HupuRatingService.parseScoreUrl(
        'https://m.hupu.com/score/detail.html?outBizNo=7717&outBizType=lol_bo',
      );
      expect(r, isNotNull);
      expect(r!.type, 'lol_bo');
      expect(r.no, '7717');
    });

    test('缺少参数返回 null', () {
      expect(
        HupuRatingService.parseScoreUrl(
          'https://m.hupu.com/score/detail.html',
        ),
        isNull,
      );
      expect(
        HupuRatingService.parseScoreUrl(
          'https://m.hupu.com/score/detail.html?outBizType=lol_item',
        ),
        isNull,
      );
    });

    test('空串与非法输入返回 null', () {
      expect(HupuRatingService.parseScoreUrl(''), isNull);
      expect(HupuRatingService.parseScoreUrl('not a url'), isNull);
    });
  });
}
