# -*- coding: utf-8 -*-
"""虎扑接口探针（纯标准库，无需 pip）

用途：
  1. 验证板块列表 / 帖子详情 / 亮评 三个已知接口是否仍可用
  2. 在指定帖子里扫描「评分」线索（内嵌 JSON、data-* 属性、评分卡图片），
     用来锁定选手评分的数据源

用法：
  python tools/probe_hupu.py                     # 只测板块列表
  python tools/probe_hupu.py 643316699           # 额外拉一篇帖子并扫描评分线索
  python tools/probe_hupu.py 643316699 --raw     # 顺带把原始 HTML/JSON 落盘到 ./_probe/
"""
import json
import os
import re
import sys
import urllib.request

UA = (
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) "
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 "
    "Mobile/15E148 Safari/604.1"
)
HEADERS = {
    "User-Agent": UA,
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,application/json;q=0.8,*/*;q=0.7",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Referer": "https://bbs.hupu.com/",
}

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_probe")


def fetch(url, timeout=20):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.status, r.read()


def dump(name, data):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    with open(path, "wb") as f:
        f.write(data)
    print("    已落盘: %s (%d B)" % (path, len(data)))


def probe_zone(zone="lol", raw=False):
    print("=" * 74)
    print("[1] 板块列表  https://bbs.hupu.com/%s" % zone)
    print("=" * 74)
    try:
        status, body = fetch("https://bbs.hupu.com/%s" % zone)
    except Exception as e:
        print("  ✗ 请求失败:", e)
        return
    print("  HTTP %s / %d B" % (status, len(body)))
    if raw:
        dump("%s.html" % zone, body)

    html = body.decode("utf-8", "replace")
    m = re.search(r'<script[^>]+id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.S)
    if not m:
        print("  ✗ 未找到 __NEXT_DATA__（UA 或页面结构变了）")
        return
    try:
        data = json.loads(m.group(1))
    except Exception as e:
        print("  ✗ __NEXT_DATA__ 解析失败:", e)
        return

    pl = (data.get("props", {}).get("pageProps", {}) or {}).get("postList") or {}
    threads = pl.get("topicThreads") or []
    print("  ✓ 解析成功：count=%s nextCursor=%s 首屏=%d 条"
          % (pl.get("count"), pl.get("nextCursor"), len(threads)))
    for t in threads[:8]:
        title = (t.get("title") or "")[:44]
        mark = "★赛后" if "赛后" in title else "     "
        print("     %s %-12s %s" % (mark, t.get("tid"), title))
    pm = [t for t in threads if "赛后" in (t.get("title") or "")]
    if pm:
        print("  → 发现赛后帖，可继续探评分: python tools/probe_hupu.py %s" % pm[0].get("tid"))
    else:
        print("  → 首屏无赛后帖（赛事间隙），可稍后重试或用已知 tid")


def probe_thread(tid, raw=False):
    print()
    print("=" * 74)
    print("[2] 帖子详情  https://bbs.hupu.com/api/v2/threads?tid=%s" % tid)
    print("=" * 74)
    try:
        status, body = fetch("https://bbs.hupu.com/api/v2/threads?tid=%s" % tid)
    except Exception as e:
        print("  ✗ 请求失败:", e)
        return
    print("  HTTP %s / %d B" % (status, len(body)))
    if raw:
        dump("thread_%s.json" % tid, body)

    try:
        j = json.loads(body.decode("utf-8", "replace"))
    except Exception as e:
        print("  ✗ JSON 解析失败:", e)
        return
    if j.get("code") != 200:
        print("  ✗ 接口返回 code=%s message=%s" % (j.get("code"), j.get("message")))
        return

    data = j.get("data") or {}
    th = data.get("thread") or {}
    lights = data.get("lights") or []
    replies = ((data.get("replies") or {}).get("list")) or []
    print("  ✓ 标题:", (th.get("title") or "")[:56])
    print("    正文 HTML %d 字符 / lights=%s / replies=%s"
          % (len(th.get("content") or ""), th.get("lights"), th.get("replies")))
    print("    data.lights 条数: %d" % len(lights))
    if lights:
        k = lights[0]
        print("    亮评首条键:", list(k.keys())[:12])
        print("    亮评内容:", str(k.get("content"))[:60])
    print("    replies.list 条数: %d" % len(replies))

    print()
    print("=" * 74)
    print("[3] 评分线索扫描（正文内嵌结构）")
    print("=" * 74)
    content = th.get("content") or ""
    patterns = {
        "data-rating 属性": r'data-ratings?\s*=\s*["\']',
        "window.__RATING__": r'window\.__RATING__',
        "评分关键词": r'评分',
        "scoreData": r'scoreData',
        "分数样式（x.x 分）": r'\d{1,2}\.\d\s*分',
        "评分卡图片": r'[^"\']*(score|rating|pingfen)[^"\']*\.(?:png|jpe?g|webp)',
    }
    hit_any = False
    for name, pat in patterns.items():
        found = re.findall(pat, content, re.I)
        if found:
            hit_any = True
            print("  ✓ %-16s 命中 %d 次，样例: %s"
                  % (name, len(found), str(found[:2])[:90]))
    if not hit_any:
        print("  ✗ 正文里没有评分结构 —— 说明评分不在这篇帖子的 HTML 里")
        print("    → 需要在 App 里抓包，或换一篇带评分的赛后帖再试")


SCORE_BASE = "https://games.mobileapi.hupu.com/1/8.2.99/bplcommentapi"


def probe_score(url_or_key):
    """验证评分接口：给评分页 URL 或 'lol_bo:7717' 形式"""
    print()
    print("=" * 74)
    print("[4] 评分接口（免登录）")
    print("=" * 74)

    if "://" in url_or_key:
        q = dict(p.split("=", 1) for p in url_or_key.split("?", 1)[-1].split("&") if "=" in p)
        t, no = q.get("outBizType"), q.get("outBizNo")
    elif ":" in url_or_key:
        t, no = url_or_key.split(":", 1)
    else:
        print("  ✗ 参数格式不对，示例：--score https://m.hupu.com/score/detail.html?outBizType=lol_item&outBizNo=79822")
        return

    if not t or not no:
        print("  ✗ 缺少 outBizType / outBizNo")
        return
    print("  输入: outBizType=%s outBizNo=%s" % (t, no))

    # 1) 非局级节点先反查所属局
    if t != "lol_bo":
        try:
            s, body = fetch("%s/bpl/score_tree/getSelfByBizKey?outBizType=%s&outBizNo=%s"
                            % (SCORE_BASE, t, no))
            j = json.loads(body.decode("utf-8", "replace"))
            links = ((j.get("data") or {}).get("linkNodes")) or []
            found = None
            for e in links:
                bk = e.get("outBizKey") or {}
                if bk.get("outBizType") and bk.get("outBizNo"):
                    found = (bk["outBizType"], bk["outBizNo"], e.get("desc"))
                    break
            if found:
                print("  ✓ 反查到上级节点: %s:%s（%s）" % found)
                t, no = found[0], found[1]
            else:
                print("  · 没有可用的父级节点，直接查自身")
        except Exception as e:
            print("  ✗ 反查失败:", e)

    # 2) 取子节点评分
    try:
        s, body = fetch("%s/bpl/score_tree/getCurAndSubNodeByBizKey"
                        "?relation=CHILD&page=1&pageSize=30&outBizType=%s&outBizNo=%s"
                        % (SCORE_BASE, t, no))
    except Exception as e:
        print("  ✗ 请求失败:", e)
        return

    j = json.loads(body.decode("utf-8", "replace"))
    if j.get("code") != 1:
        print("  ✗ 接口返回 code=%s msg=%s" % (j.get("code"), j.get("msg")))
        return

    data = j.get("data") or {}
    self_node = ((data.get("self") or {}).get("node")) or {}
    lst = ((data.get("pageResult") or {}).get("data")) or []
    print("  ✓ 当前节点: %s | 子节点 %d 条"
          % (self_node.get("name") or "(无)", len(lst)))
    print()
    print("  %-12s %-8s %-8s %-9s %s" % ("name", "type", "teamId", "score", "人数"))
    print("  " + "-" * 58)
    for it in lst:
        n = it.get("node") or {}
        ij = n.get("infoJson") or {}
        tp = (ij.get("type") or [""])[0]
        tm = (ij.get("teamId") or ["-"])[0]
        if tp not in ("player", "coach"):
            continue
        print("  %-12s %-8s %-8s %-9s %s"
              % (str(n.get("name"))[:12], tp, tm, n.get("scoreAvg"),
                 n.get("scorePersonCount")))
    hot = self_node.get("hottestComments") or []
    if hot:
        print()
        print("  热评 %d 条，首条: %s" % (len(hot), str(hot[0])[:60]))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    raw = "--raw" in sys.argv
    score_arg = next((a.split("=", 1)[1] for a in sys.argv[1:]
                      if a.startswith("--score=")), None)
    if score_arg is None and "--score" in sys.argv:
        i = sys.argv.index("--score")
        if i + 1 < len(sys.argv):
            score_arg = sys.argv[i + 1]

    if score_arg:
        probe_score(score_arg)
        return

    probe_zone("lol", raw=raw)
    if args:
        probe_thread(args[0], raw=raw)
    else:
        print()
        print("提示：")
        print("  传 tid 探帖子详情：   python tools/probe_hupu.py 643316699")
        print("  探评分接口：         python tools/probe_hupu.py --score \"https://m.hupu.com/score/detail.html?outBizType=lol_item&outBizNo=79822\"")
        print("                       python tools/probe_hupu.py --score lol_bo:7717")


if __name__ == "__main__":
    main()
