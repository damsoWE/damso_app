import '../../../core/error/app_exception.dart';
import '../../../core/storage/token_store.dart';
import '../domain/models.dart';
import '../domain/parent_inquiry_repository.dart';
import 'mock_inquiry_store.dart';

/// mock 구현. 결과 규칙은 [MockInquiryStore](quickstart "mock 데모 입력").
/// 데모 계정은 F1 처럼 `TokenStore.accessToken`(`mock:<계정>`)으로 구분한다.
/// refresh 계정은 첫 목록 조회만 갱신 지연을 흉내 낸다(토큰 갱신은 AuthInterceptor 몫).
class MockParentInquiryRepository implements ParentInquiryRepository {
  MockParentInquiryRepository(this._tokens, this._store);

  final TokenStore _tokens;
  final MockInquiryStore _store;

  static const _delay = Duration(milliseconds: 300);
  bool _refreshSimulated = false;

  /// 가입 직후 계정·refresh 계정도 parent 와 같은 데모 데이터를 본다.
  String get _account {
    final account = (_tokens.accessToken ?? '').replaceFirst('mock:', '');
    return const {'signup-parent', 'refresh'}.contains(account) ? 'parent' : account;
  }

  @override
  Future<InquirySubmitted> submit({
    required String studentId,
    required String content,
    required String idempotencyKey,
  }) async {
    await Future<void>.delayed(_delay);
    return _store.submit(
      parentAccount: _account,
      studentId: studentId,
      content: content,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<List<ParentInquirySummary>> list() async {
    await Future<void>.delayed(_delay);
    if (_tokens.accessToken == 'mock:refresh' && !_refreshSimulated) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _refreshSimulated = true;
    }
    return _store.listForParent(_account);
  }

  @override
  Future<ParentInquiryDetail> detail(String inquiryId) async {
    await Future<void>.delayed(_delay);
    return _store.detailForParent(_account, inquiryId);
  }

  /// mock 시나리오 없음(specs/007 research R9) — 실서버로만 확인한다.
  @override
  Future<FollowUpSubmitted> submitFollowUp({
    required String inquiryId,
    required String content,
    required String idempotencyKey,
  }) async {
    throw const AppException(message: '이 실행에서는 지원하지 않습니다.');
  }
}
