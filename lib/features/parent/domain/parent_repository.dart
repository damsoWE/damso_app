import 'child.dart';

/// 학부모 계약(contracts/api-usage.md parent).
abstract class ParentRepository {
  Future<List<Child>> listChildren();

  /// 초대 코드로 자녀를 추가 연결한다.
  Future<Child> linkChild(String inviteCode);
}
