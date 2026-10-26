import '../../../core/session/role.dart';

/// 내 정보(openapi `MeResponse`). 이메일은 본인 것만 담는다(원칙 I).
class Me {
  const Me({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
  });

  final String userId;
  final String name;
  final String email;
  final Role role;
}
