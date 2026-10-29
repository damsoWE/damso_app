import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/models.dart';
import '../domain/parent_inquiry_repository.dart';
import 'inquiry_json.dart';

/// 실서버 구현. 경로는 원본 명세 0.5.0(specs/002 contracts/api-usage.md).
class ParentInquiryRepositoryImpl implements ParentInquiryRepository {
  ParentInquiryRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<InquirySubmitted> submit({
    required String studentId,
    required String content,
    required String idempotencyKey,
  }) {
    return mapDioErrors(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/parent/inquiries',
        data: {'studentId': studentId, 'content': content},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return InquiryJson.submitted(res.data!);
    });
  }

  @override
  Future<List<ParentInquirySummary>> list() {
    return mapDioErrors(() async {
      final res = await _dio.get<List<dynamic>>('/api/v1/parent/inquiries');
      return res.data!
          .cast<Map<String, dynamic>>()
          .map(InquiryJson.parentSummary)
          .toList();
    });
  }

  @override
  Future<ParentInquiryDetail> detail(String inquiryId) {
    return mapDioErrors(() async {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/parent/inquiries/$inquiryId',
      );
      return InquiryJson.parentDetail(res.data!);
    });
  }

  @override
  Future<FollowUpSubmitted> submitFollowUp({
    required String inquiryId,
    required String content,
    required String idempotencyKey,
  }) {
    return mapDioErrors(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/parent/inquiries/$inquiryId/follow-ups',
        data: {'content': content},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return InquiryJson.followUpSubmitted(res.data!);
    });
  }
}
