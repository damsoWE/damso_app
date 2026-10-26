import 'models.dart';

/// 교사 문의(contracts/api-usage.md "inquiry(교사)").
abstract class TeacherInquiryRepository {
  static const pageSize = 20;

  /// 담당 학급 문의, 긴급 먼저 그다음 최신순(서버가 정렬).
  Future<TeacherInquiryPage> list({int page = 0, int size = pageSize});

  Future<TeacherInquiryDetail> detail(String inquiryId);

  /// 원문. 부를 때마다 서버에 열람 기록이 남고, 긴급은 첫 열람 때 "교사 확인"이 된다.
  /// 긴급 문의 상세를 열 때 화면당 한 번만 부른다(research R8).
  Future<String> content(String inquiryId);
}
