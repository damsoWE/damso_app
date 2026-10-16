import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/inquiry_repository.dart';

/// 실서버 구현. 응답 스키마는 docs/api/openapi.yaml 확정 후 맞춘다(현재 임시 값).
class InquiryRepositoryImpl implements InquiryRepository {
  InquiryRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<Inquiry>> list() {
    return mapDioErrors(() async {
      final res = await _dio.get<List<dynamic>>('/inquiries');
      return [
        for (final j in res.data!.cast<Map<String, dynamic>>())
          Inquiry(
            id: j['id'] as String,
            status: InquiryStatus.values.byName(j['status'] as String),
            summary: j['summary'] as String,
            urgent: j['urgent'] as bool? ?? false,
          ),
      ];
    });
  }
}
