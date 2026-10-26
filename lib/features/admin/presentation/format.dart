import '../domain/models.dart';

/// 기기 현지 시간 `yyyy.MM.dd HH:mm`(새 패키지 없이 직접 포맷).
String formatDateTime(DateTime time) {
  final t = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}.${two(t.month)}.${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

String inviteStateLabel(InviteCodeState state) => switch (state) {
  InviteCodeState.unused => '미사용',
  InviteCodeState.used => '사용됨',
  InviteCodeState.expired => '만료',
  InviteCodeState.revoked => '무효',
};

String classroomLabel(int grade, int classNumber) => '$grade학년 $classNumber반';
