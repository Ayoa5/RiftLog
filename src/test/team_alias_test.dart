// 队名归一化 + 赛程匹配键的单元测试
//
// 背景：LPL 官方赛程写 MKOI / TLAW，虎扑比赛节点写 KOI / TL，
// 不归一化会导致「明明有评分却显示暂无评分」。

import 'package:flutter_test/flutter_test.dart';
import 'package:hupu_lol/core/team_alias.dart';
import 'package:hupu_lol/models/lpl_models.dart';

void main() {
  group('canonicalTeam', () {
    test('LPL 写法映射到虎扑写法', () {
      expect(canonicalTeam('MKOI'), 'KOI');
      expect(canonicalTeam('TLAW'), 'TL');
      expect(canonicalTeam('FURIA'), 'FUR');
    });

    test('大小写与空格归一', () {
      expect(canonicalTeam(' koi '), 'KOI');
      expect(canonicalTeam('Tlaw'), 'TL');
      expect(canonicalTeam(''), '');
    });

    test('未知队名原样大写', () {
      expect(canonicalTeam('gen'), 'GEN');
      expect(canonicalTeam('T1'), 'T1');
    });
  });

  group('LplMatch.joinKey', () {
    LplMatch build(String a, String b, String date) => LplMatch(
          matchId: 1,
          name: '$a vs $b',
          teamA: a,
          teamB: b,
          scoreA: 0,
          scoreB: 0,
          date: DateTime.parse(date),
          status: 3,
          stage: '瑞士轮',
          round: '第四天',
          bo: 'BO1',
          place: '',
          gameName: '2026全球总决赛',
        );

    test('同一天的同一对阵，队序无关', () {
      final k1 = build('MKOI', 'DK', '2026-10-26 03:00:00').joinKey;
      final k2 = build('DK', 'KOI', '2026-10-26 03:00:00').joinKey;
      expect(k1, k2);
      expect(k1, 'DK|KOI@2026-10-26');
    });

    test('TLAW 与 TL 视为同一队', () {
      final k1 = build('TLAW', 'AL', '2026-10-27 06:00:00').joinKey;
      final k2 = build('TL', 'AL', '2026-10-27 06:00:00').joinKey;
      expect(k1, k2);
    });

    test('不同日期不会误匹配', () {
      final k1 = build('KC', 'MVK', '2026-10-17 02:00:00').joinKey;
      final k2 = build('KC', 'MVK', '2026-10-19 02:00:00').joinKey;
      expect(k1, isNot(k2));
    });

    test('对阵未定（无队伍）返回空键', () {
      final m = LplMatch(
        matchId: 2,
        name: 'D5G1',
        teamA: '',
        teamB: '',
        scoreA: 0,
        scoreB: 0,
        date: DateTime.parse('2026-10-29 04:00:00'),
        status: 1,
        stage: '瑞士轮',
        round: '第五天',
        bo: 'BO3',
        place: '',
        gameName: '2026全球总决赛',
      );
      expect(m.joinKey, '');
    });
  });
}
