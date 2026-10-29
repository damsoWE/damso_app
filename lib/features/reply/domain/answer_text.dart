/// 답변 작성·점검·스레드 화면의 고정 문구(specs/004 data-model §5, Figma 2026-10-27).
/// 서버·AI가 만든 문장은 안내로 쓰지 않는다(원칙 V). 점검 결과의 이유·고쳐 쓴 문장만 서버 값이다.
abstract final class AnswerText {
  // ───────── 작성(F4-2a·2a-2) ─────────
  static const composeTitle = '답변 작성';
  static const requestsLabel = '요청사항';
  static const answerLabel = '답변';
  static const writtenLabel = '작성한 답변';
  static const placeholder = '학부모에게 보낼 답변을 작성해 주세요.';
  static const notSentHint = '작성한 답변은 직접 전송하기 전까지 전달되지 않아요.';
  static const reviewButton = '답변 점검';
  static const discardConfirm = '작성한 내용이 사라집니다. 나갈까요?';
  static const discardCancel = '계속 작성';
  static const discardLeave = '나가기';
  static const sessionExpiredDraftLost = '로그인이 만료되어 작성 중인 답변이 저장되지 않았어요.';

  static String recipient(String studentName) => '$studentName 학부모에게';

  // ───────── 점검 중(F4-2b) ─────────
  static const reviewingTitle = '답변 점검';
  static const reviewingGuide = '표현과 요청사항에 빠진 부분이 있는지 확인해요.';
  static const reviewingNotice = '답변을 점검하고 있어요. 작성한 내용은 그대로 유지돼요.';
  static const reviewingButton = '점검 중…';

  // ───────── 점검 결과(F4-2c·2c-1·2e) ─────────
  static const resultTitle = '점검 결과';
  static const rewrittenLabel = '고쳐 쓴 문장';
  static const appliedLabel = '바꾼 문장';
  static const applyButton = '바꾸기';
  static const undoButton = '되돌리기';
  static const resultHint = '바꿔도 바로 전송되지 않아요. 전송은 선생님이 직접 해요.';
  static const appliedHint = '바뀐 답변을 한 번 더 확인하고 직접 전송해 주세요.';
  static const noSuggestionBadge = '점검 완료';
  static const noSuggestion = '추가로 제안할 내용이 없어요. 보내기 전에 한 번 더 확인해 주세요.';

  static String suggestionCount(int n) => '확인할 제안 $n개';
  static String appliedCount(int n) => '제안 $n개 적용함';

  /// 제안 카드 제목. 서버가 분류 제목을 주지 않아 순번만 쓴다(Clarifications Q2).
  static String suggestionTitle(int n, {required bool applied}) =>
      applied ? '제안 $n · 바꿈' : '제안 $n';

  // ───────── 점검 실패(F4-2f) ─────────
  static const reviewFailed = '지금은 답변을 점검할 수 없어요. 작성한 내용은 그대로 남아 있어요.';
  static const reviewFailedGuide = '다시 점검하거나, 내용을 직접 확인한 후 전송할 수 있어요.';

  // ───────── 수정(F4-2d) ─────────
  static const editTitle = '답변 수정';
  static const editedLabel = '직접 수정한 답변';
  static const editedNotice = '답변이 수정됐어요. 바뀐 내용을 다시 점검할 수 있어요.';
  static const editButton = '답변 수정';
  static const recheckButton = '다시 점검';

  // ───────── 전송(F4-2g·2h) ─────────
  static const sendButton = '직접 전송';
  static const sendEditedButton = '수정한 답변 직접 전송';
  static const sendAfterCheckButton = '직접 확인 후 전송';
  static const sendingTitle = '답변 전송';
  static const sendingHeading = '답변을 보내고 있어요';
  static const sendingGuide = '전송이 끝날 때까지 잠시 기다려 주세요.';
  static const recipientLabel = '받는 분';
  static const sendOnceNotice = '버튼을 다시 누르지 않아도 돼요. 답변은 한 번만 보내져요.';
  static const sendingButton = '전송 중…';
  static const sendFailedHeading = '답변을 보내지 못했어요';
  static const sendFailedGuide = '작성한 답변은 그대로 남아 있어요.';
  static const unsentLabel = '보내지 못한 답변';
  static const sendFailedHint = '연결 상태를 확인하고 다시 보내 주세요.';
  static const maybeSentHint = '보내졌을 수 있어요. 스레드에서 먼저 확인해 주세요.';
  static const resendButton = '다시 보내기';

  static String recipientLine(String studentName, String title) =>
      '$studentName 학부모 · $title';

  // ───────── 쓰는 동안 온 재문의(409 NEW_FOLLOW_UP, api-v0.11) ─────────
  static const newFollowUpHeading = '새 재문의가 왔어요';
  static const newFollowUpGuide = '답변은 아직 보내지 않았어요. 재문의를 확인한 뒤 다시 보내 주세요.';
  static const newFollowUpLabel = '새 재문의';

  /// `M/d HH:mm 접수 · 눌러서 확인`. [at]은 화면 형식 문자열.
  static String newFollowUpHint(String at) => '$at 접수 · 눌러서 확인';

  // ───────── 스레드(F4-3) ─────────
  static const sentNotice = '답변을 보냈어요. 문의와 답변은 기록으로 보관돼요.';
  static const answeredTag = '답변 완료';
  static const toListButton = '문의 목록으로';
  static const viewOriginalButton = '원문 보기';
  static const writeAnswerButton = '답변 작성';

  static String parentCardTitle(String studentName, {required bool followUp}) =>
      '$studentName 학부모 · ${followUp ? '재문의' : '요청사항'}';

  static String answerCardTitle(String? displayName) =>
      displayName == null || displayName.isEmpty
      ? '선생님 · 직접 전송'
      : '$displayName 선생님 · 직접 전송';

  /// `시각 · 전송 완료`. [at]은 이미 화면 형식(M/d HH:mm)으로 만든 문자열.
  static String sentAt(String at) => '$at · 전송 완료';

  /// 아직 답하지 않은 재문의 표시.
  static String followUpHint(String at) => '$at · 재문의 받음 · 눌러서 확인';

  // ───────── 재문의 상세(research R13) ─────────
  static const followUpNotRefined = '아직 정리되지 않았어요. 원문 보기로 내용을 확인할 수 있어요.';

  static String followUpTitle(String rootTitle) => '$rootTitle - 재문의';

  /// `학생 학부모 · M/d HH:mm 접수`. [at]은 화면 형식 문자열.
  static String followUpHeader(String studentName, String at) =>
      '$studentName 학부모 · $at 접수';
}
