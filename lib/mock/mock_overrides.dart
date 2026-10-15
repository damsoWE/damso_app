import 'package:flutter_riverpod/misc.dart';

import '../features/auth/data/auth_repository_impl.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/inquiry/data/inquiry_repository_impl.dart';
import '../features/inquiry/domain/inquiry_repository.dart';

/// mock Repository 로 교체하는 override 모음. main_mock.dart 에서만 사용한다.
/// 정상 응답뿐 아니라 401 갱신, 403, 정제 진행 중→완료, "원문 확인 필요",
/// 긴급 표시 같은 예외 케이스도 여기에 담는다(openapi.yaml 확정 후 확장).
final mockOverrides = <Override>[
  authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
  inquiryRepositoryProvider.overrideWithValue(_MockInquiryRepository()),
];

class _MockAuthRepository implements AuthRepository {
  @override
  Future<void> login({required String email, required String password}) async {}

  @override
  Future<void> logout() async {}
}

class _MockInquiryRepository implements InquiryRepository {
  @override
  Future<List<Inquiry>> list() async => const [
        Inquiry(
          id: '00000000-0000-4000-8000-000000000001',
          status: InquiryStatus.refined,
          summary: '정제 완료된 문의 예시',
        ),
        Inquiry(
          id: '00000000-0000-4000-8000-000000000002',
          status: InquiryStatus.refining,
          summary: '정제 진행 중인 문의 예시',
        ),
        Inquiry(
          id: '00000000-0000-4000-8000-000000000003',
          status: InquiryStatus.needsOriginalCheck,
          summary: '원문 확인 필요',
        ),
        Inquiry(
          id: '00000000-0000-4000-8000-000000000004',
          status: InquiryStatus.refined,
          summary: '긴급 문의 예시',
          urgent: true,
        ),
      ];
}
