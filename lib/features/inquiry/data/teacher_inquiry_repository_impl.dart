import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/models.dart';
import '../domain/teacher_inquiry_repository.dart';
import 'inquiry_json.dart';

/// 실서버 구현. 경로는 원본 명세 0.5.0(specs/002 contracts/api-usage.md).
class TeacherInquiryRepositoryImpl implements TeacherInquiryRepository {
  TeacherInquiryRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<TeacherInquiryPage> list({
    int page = 0,
    int size = TeacherInquiryRepository.pageSize,
  }) {
    return mapDioErrors(() async {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/inquiries',
        queryParameters: {'page': page, 'size': size},
      );
      return InquiryJson.teacherPage(res.data!);
    });
  }

  @override
  Future<TeacherInquiryDetail> detail(String inquiryId) {
    return mapDioErrors(() async {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/inquiries/$inquiryId',
      );
      return InquiryJson.teacherDetail(res.data!);
    });
  }

  @override
  Future<String> content(String inquiryId) {
    return mapDioErrors(() async {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/inquiries/$inquiryId/content',
      );
      return res.data!['content'] as String;
    });
  }
}
