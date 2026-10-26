import 'models.dart';

/// 문의 화면의 고정 문구(원칙 V). 서버·AI가 만든 문장은 안내로 쓰지 않는다.
/// 안내·번호 문구는 원본 명세 `NoticeCode`·`HotlineCode` 설명과 글자까지 같다.
abstract final class NoticeText {
  static String of(Notice notice) => switch (notice) {
    Notice.received => '문의가 접수되었습니다.',
    Notice.urgentDelivered => '선생님께 바로 전달했어요.',
    Notice.deferred => '선생님 응답 가능 시간에 전달됩니다.',
  };

  static String hotline(Hotline hotline) => switch (hotline) {
    Hotline.suicidePrevention => '자살예방 상담전화 109',
    Hotline.childAbuse => '아동학대 신고 112',
  };

  static String stage(InquiryStage stage) => switch (stage) {
    InquiryStage.received => '접수',
    InquiryStage.delivered => '교사에게 전달됨',
    InquiryStage.refined => '정제',
    InquiryStage.teacherConfirmed => '교사 확인',
    InquiryStage.answered => '답변 완료',
  };

  static const urgentLabel = '긴급 문의';
  static const noHomeroomTeacher = '담임 선생님이 연결된 뒤 문의할 수 있어요.';
  static const composeGuide = '작성한 글은 그대로 보관돼요. 안전과 관련된 긴급한 내용은 선생님께 바로 전달돼요.';
  static const timeoutHint = '보낸 문의 목록에서 접수됐는지 먼저 확인해 주세요.';
  static const discardConfirm = '작성한 내용이 사라집니다. 나갈까요?';
  static const contentViewLogged = '원문을 열람한 기록이 남습니다.';
  static const urgentDetailGuide = '학생 안전과 관련된 내용이라 정리하지 않고 학부모가 쓴 글 그대로 바로 전달했어요.';
  static const pendingDetail = '정리된 내용과 원문 보기는 준비 중입니다.';
}
