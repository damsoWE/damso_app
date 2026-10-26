/// 서버가 알려 주는 역할(openapi `Role`). 기기에 저장하지 않는다(research R2).
enum Role {
  superAdmin('SUPER_ADMIN'),
  teacher('TEACHER'),
  parent('PARENT');

  const Role(this.serverValue);

  final String serverValue;

  /// 로그인 후 진입하는 역할 홈 경로(contracts/routes.md).
  String get homePath => switch (this) {
    Role.parent => '/parent',
    Role.teacher => '/teacher',
    Role.superAdmin => '/admin',
  };

  /// 모르는 값이면 [FormatException]. 호출부는 로그아웃으로 처리한다.
  static Role fromServer(String value) => values.firstWhere(
    (r) => r.serverValue == value,
    orElse: () => throw const FormatException('알 수 없는 역할'),
  );
}
