/// 접수 시각 표시(예: 10/13 09:30). 날짜 패키지 없이 로컬 시각으로 만든다.
String formatDateTime(DateTime at) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}';
}
