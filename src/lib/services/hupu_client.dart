// 虎扑 HTTP 客户端：移动端 UA 伪装 + 超时 + 指数退避重试 + 统一错误抽象
//
// 为什么必须带移动端 UA：
//   实测 https://bbs.hupu.com/lol 在桌面 UA 下返回的 HTML **不含** __NEXT_DATA__，
//   数据抓不到。带 iPhone UA 才有 SSR 数据。

import 'dart:convert';

import 'package:dio/dio.dart';

/// 统一异常：UI 层只处理这一种
class HupuException implements Exception {
  HupuException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() =>
      'HupuException(${statusCode ?? '-'}): $message${cause == null ? '' : ' | $cause'}';
}

class HupuClient {
  HupuClient({Dio? dio, this.maxRetry = 3})
      : _dio = dio ?? Dio(_buildOptions());

  final Dio _dio;
  final int maxRetry;

  /// 实测有效的移动端 UA（iOS Safari）
  static const String mobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 '
      'Mobile/15E148 Safari/604.1';

  static BaseOptions _buildOptions() => BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 12),
        followRedirects: true,
        // 4xx 也当正常返回，交给业务层判断 code 字段
        validateStatus: (s) => s != null && s < 500,
        // 统一拿原始字符串：虎扑部分接口 content-type 与实际内容不符，
        // 让 dio 自动解码反而容易踩坑，这里自己 jsonDecode。
        responseType: ResponseType.plain,
        headers: const {
          'User-Agent': mobileUserAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,application/json;q=0.8,*/*;q=0.7',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Referer': 'https://bbs.hupu.com/',
          'X-Requested-With': 'com.hupu.games',
        },
      );

  /// 取原始文本（HTML 用）
  Future<String> getHtml(String url) async {
    final res = await _request(url);
    return res;
  }

  /// 取 JSON（自动解码 + 校验 code 字段）
  ///
  /// ⚠️ 虎扑不同接口的成功码不一致：
  ///   · bbs.hupu.com/api/v2/…   → code = 200
  ///   · games.mobileapi.hupu.com/bplcommentapi/… → code = 1（失败为 -1）
  /// 所以用 [okCodes] 显式声明，默认只认 200。
  Future<Map<String, dynamic>> getJson(
    String url, {
    Map<String, dynamic>? query,
    Set<int> okCodes = const <int>{200},
  }) async {
    final raw = await _request(url, query: query);
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw HupuException('响应不是合法 JSON', cause: e);
    }
    if (decoded is! Map<String, dynamic>) {
      throw HupuException('响应结构异常（期望 JSON 对象）');
    }
    final code = decoded['code'];
    if (code is int && !okCodes.contains(code)) {
      throw HupuException(
        (decoded['message'] ?? decoded['msg'] ?? '接口返回错误').toString(),
        statusCode: code,
      );
    }
    return decoded;
  }

  Future<String> _request(
    String url, {
    Map<String, dynamic>? query,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt <= maxRetry; attempt++) {
      try {
        final res = await _dio.get<String>(url, queryParameters: query);
        final status = res.statusCode ?? 0;
        if (status >= 400) {
          throw HupuException('HTTP $status', statusCode: status);
        }
        final body = res.data ?? '';
        if (body.trim().isEmpty) {
          throw HupuException('响应为空', statusCode: status);
        }
        return body;
      } on HupuException catch (e) {
        lastError = e;
        // 4xx 不重试（除了 429 限流）
        if (e.statusCode != null && e.statusCode! < 500 && e.statusCode != 429) {
          rethrow;
        }
      } on DioException catch (e) {
        lastError = e;
      }
      // 指数退避：300ms, 600ms, 1200ms
      if (attempt < maxRetry) {
        await Future<void>.delayed(Duration(milliseconds: 300 * (1 << attempt)));
      }
    }
    throw HupuException('请求失败（已重试 $maxRetry 次）', cause: lastError);
  }
}
