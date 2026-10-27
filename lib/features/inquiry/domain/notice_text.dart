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

  // ───────── F3 일반 문의 상세 (specs/003 data-model "고정 문구") ─────────

  static const refinedBadge = '자동 정리';
  static const translationLabel = '번역본';
  static const factsLabel = '사실관계';
  static const requestsLabel = '요청사항';
  static const noRequests = '요청사항이 없어요.';
  static const emotionTitle = '정서강도';
  static const contentViewWillLog = '원문을 열면 열람한 사람과 시각이 기록돼요.';
  static const contentViewedLogged =
      '원문을 열었어요. 열람한 사람과 시각이 기록돼요. 원문은 수정되거나 삭제되지 않아요.';
  static const needsOriginalBadge = '원문 확인 필요';
  static const needsOriginalHeading = '원문을 확인해 주세요';
  static const refinementFailed = '자동 정리에 실패했습니다. 원문을 확인해 주세요';
  static const retryButton = '다시 정리하기 · 1회 남음';
  static const retryLimitReached = '다시 정리하기는 한 번만 할 수 있어요.';
  static const retryingBadge = '다시 정리 중';
  static const retryingHeading = '내용을 다시 정리하고 있어요';
  static const refiningBadge = '정리 중';
  static const refiningHeading = '내용을 정리하고 있어요';
  static const refiningGuide = '정리가 끝나면 다시 확인을 눌러 주세요. 필요하면 원문을 먼저 확인할 수 있어요.';
  static const retryRemainingTitle = '남은 재요청 0회';
  static const retryRemainingNone = '다시 정리하지 못해도 원문으로 확인하고 답변할 수 있어요.';
  static const recheckButton = '다시 확인';

  static String emotionLevel(EmotionLevel level) => switch (level) {
    EmotionLevel.low => '낮음',
    EmotionLevel.medium => '보통',
    EmotionLevel.high => '높음',
  };

  static String emotionLabel(EmotionLabel label) => switch (label) {
    EmotionLabel.anxiety => '불안',
    EmotionLabel.dissatisfaction => '불만',
    EmotionLabel.anger => '분노',
    EmotionLabel.worry => '걱정',
    EmotionLabel.frustration => '답답함',
    EmotionLabel.sadness => '슬픔',
  };
}
