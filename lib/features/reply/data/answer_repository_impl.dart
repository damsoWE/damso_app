import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/answer_repository.dart';
import '../domain/models.dart';

/// 실서버 구현. 경로는 앱 사본 api-v0.6(specs/004 contracts/api-usage.md).
class AnswerRepositoryImpl implements AnswerRepository {
  AnswerRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<AnswerReview> review(String inquiryId, String content) {
    return mapDioErrors(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/inquiries/$inquiryId/answer-reviews',
        data: {'content': content},
      );
      final j = res.data!;
      return AnswerReview(
        available: j['available'] as bool,
        highlights: [
          for (final h in (j['highlights'] as List).cast<Map<String, dynamic>>())
            Highlight(
              excerpt: h['excerpt'] as String,
              reason: h['reason'] as String,
              suggestion: h['suggestion'] as String,
            ),
        ],
      );
    });
  }

  @override
  Future<AnswerSent> send(String inquiryId, String content, {required bool reviewed}) {
    return mapDioErrors(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/inquiries/$inquiryId/answers',
        data: {'content': content, 'reviewed': reviewed},
      );
      final j = res.data!;
      return AnswerSent(
        answerId: j['answerId'] as String,
        inquiryId: j['inquiryId'] as String,
        sentAt: DateTime.parse(j['sentAt'] as String),
      );
    });
  }
}
