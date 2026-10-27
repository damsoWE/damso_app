import '../../../core/error/app_exception.dart';
import '../../../core/error/error_codes.dart';
import '../../../core/util/uuid.dart';
import '../domain/models.dart';

/// 학부모·교사 mock 이 함께 쓰는 메모리 저장소(specs/002 research R14, quickstart "mock 데모 입력").
/// 학부모가 보낸 문의가 교사 목록에 보이고, 교사가 연 긴급 문의는 학부모 쪽 단계도 바뀐다.
/// 문의마다 단계 이력을 한 곳(`_MockInquiry.timeline`)에만 둔다.
class MockInquiryStore {
  MockInquiryStore() {
    _seed();
  }

  /// 담임이 있는 학급(3학년 2반)의 학생. 담임 계정 `teacher`가 이 학급을 맡는다.
  static const _hana = (id: '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e51', name: '김하나');
  static const _seojun = (id: '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e61', name: '박서준');
  static const _doyun = (id: '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e62', name: '이도윤');

  /// 담임이 없는 학생(1학년 1반 김두리).
  static const _noHomeroomStudentIds = {'7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e52'};

  /// 학부모 계정별 자녀(F1 mock 과 같은 ID).
  static const _parentChildren = {
    '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e51': '김하나',
    '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e52': '김두리',
    '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e53': '김새봄',
  };

  /// "권한 확인(데모)" 카드 — 상세를 열면 403(남의 문의를 연 상황 재현).
  static const forbiddenDemoId = '00000000-0000-4000-8000-000000000403';

  static const _generalLimit = Duration(seconds: 60);

  final _inquiries = <_MockInquiry>[];
  final _byKey = <String, ({String studentId, String content, InquirySubmitted result})>{};
  final _lastGeneralAt = <String, DateTime>{};
  int _teacherListCalls = 0;

  // ───────── 학부모 ─────────

  InquirySubmitted submit({
    required String parentAccount,
    required String studentId,
    required String content,
    required String idempotencyKey,
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty || trimmed.runes.length > 2000) {
      throw const AppException(
        message: '문의 내용을 1자 이상 2,000자 이하로 입력해 주세요.',
        code: ErrorCodes.invalidInput,
        statusCode: 400,
      );
    }
    final previous = _byKey[idempotencyKey];
    if (previous != null) {
      if (previous.studentId != studentId || previous.content != trimmed) {
        throw const AppException(
          message: '이미 다른 내용으로 보낸 요청입니다. 다시 시도해 주세요.',
          code: ErrorCodes.conflict,
          statusCode: 409,
        );
      }
      return previous.result;
    }
    final studentName = _parentChildren[studentId];
    if (studentName == null) {
      throw const AppException(
        message: '요청한 대상을 찾을 수 없습니다.',
        code: ErrorCodes.notFound,
        statusCode: 404,
      );
    }
    if (_noHomeroomStudentIds.contains(studentId)) {
      throw const AppException(
        message: '담임 선생님이 아직 연결되지 않았습니다.',
        code: ErrorCodes.noHomeroomTeacher,
        statusCode: 409,
      );
    }

    // 긴급 판정이 1분 제한보다 먼저다(긴급은 제한을 받지 않는다).
    final hotlines = _urgentHotlines(trimmed);
    final urgent = hotlines != null;
    final now = DateTime.now();
    if (!urgent) {
      final last = _lastGeneralAt[parentAccount];
      if (last != null && now.difference(last) < _generalLimit) {
        final left = _generalLimit - now.difference(last);
        throw AppException(
          message: '잠시 후 다시 시도해 주세요.',
          code: ErrorCodes.tooManyAttempts,
          statusCode: 429,
          retryAfter: Duration(seconds: left.inSeconds.clamp(1, 60)),
        );
      }
      _lastGeneralAt[parentAccount] = now;
    }

    final deferred = !urgent && trimmed.contains('밤늦게');
    final inquiry = _MockInquiry(
      id: uuidV4(),
      parentAccount: parentAccount,
      studentId: studentId,
      studentName: studentName,
      urgent: urgent,
      hotlines: hotlines ?? const [],
      notices: urgent
          ? const [Notice.urgentDelivered]
          : [Notice.received, if (deferred) Notice.deferred],
      submittedAt: now,
      timeline: [
        StageEvent(stage: InquiryStage.received, occurredAt: now),
        if (urgent) StageEvent(stage: InquiryStage.delivered, occurredAt: now),
      ],
      refinementStatus: urgent ? null : RefinementStatus.pending,
      title: urgent ? '긴급 문의' : '정리 중',
      content: trimmed,
    );
    _inquiries.add(inquiry);
    final result = InquirySubmitted(
      inquiryId: inquiry.id,
      urgent: urgent,
      stage: inquiry.stage,
      submittedAt: now,
      notices: inquiry.notices,
      hotlines: inquiry.hotlines,
    );
    _byKey[idempotencyKey] = (
      studentId: studentId,
      content: trimmed,
      result: result,
    );
    return result;
  }

  List<ParentInquirySummary> listForParent(String parentAccount) {
    final mine = _inquiries.where((i) => i.parentAccount == parentAccount).toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return [for (final i in mine) i.parentSummary];
  }

  ParentInquiryDetail detailForParent(String parentAccount, String inquiryId) {
    if (inquiryId == forbiddenDemoId) {
      throw const AppException(
        message: '접근 권한이 없습니다.',
        code: ErrorCodes.forbidden,
        statusCode: 403,
      );
    }
    final i = _find(inquiryId, (i) => i.parentAccount == parentAccount);
    return ParentInquiryDetail(
      summary: i.parentSummary,
      timeline: List.unmodifiable(i.timeline),
      notices: i.notices,
      hotlines: i.hotlines,
    );
  }

  // ───────── 교사 ─────────

  TeacherInquiryPage listForTeacher({required int page, required int size}) {
    _teacherListCalls++;
    if (_teacherListCalls == 2) _refinePending();
    final visible = _inquiries.where(_inTeacherClass).toList()
      ..sort((a, b) {
        if (a.urgent != b.urgent) return a.urgent ? -1 : 1;
        return b.submittedAt.compareTo(a.submittedAt);
      });
    final start = (page * size).clamp(0, visible.length);
    final end = (start + size).clamp(0, visible.length);
    return TeacherInquiryPage(
      items: [for (final i in visible.sublist(start, end)) i.teacherSummary],
      page: page,
      size: size,
      totalElements: visible.length,
    );
  }

  /// 상세. F3 데모(specs/003 research R10): `refineOnSecondDetailRead` 문의는 자기 상세의
  /// 두 번째 조회에서, 다시 정리하기를 받아들인 문의는 그다음 조회에서 결과가 정해진다.
  TeacherInquiryDetail detailForTeacher(String inquiryId) {
    final i = _find(inquiryId, _inTeacherClass);
    i.detailReads++;
    if (i.refineOnSecondDetailRead && i.detailReads >= 2) {
      i.refineOnSecondDetailRead = false;
      _completeRefinement(i);
    } else if (i.retryPending) {
      i.retryPending = false;
      _completeRefinement(i, success: i.retrySucceeds ?? true);
    }
    return TeacherInquiryDetail(
      summary: i.teacherSummary,
      timeline: List.unmodifiable(i.timeline),
      retryAvailable: i.retryAvailable,
    );
  }

  /// 원문 열람(원본 명세 viewInquiryContent). 긴급은 첫 열람에, "원문 확인 필요" 문의는
  /// 접수 단계에서 첫 열람할 때 "교사 확인"이 된다. 번역본이 있는 문의는 단계가 그대로다.
  String contentForTeacher(String inquiryId) {
    final i = _find(inquiryId, _inTeacherClass);
    i.contentViews++;
    final confirms = i.urgent
        ? i.stage == InquiryStage.delivered
        : i.refinementStatus == RefinementStatus.needsOriginal &&
              i.stage == InquiryStage.received;
    if (confirms) _confirm(i);
    return i.content;
  }

  /// 번역본 열람(원본 명세 viewInquiryRefinement). 정제 단계에서 첫 열람하면 "교사 확인".
  InquiryRefinement refinementForTeacher(String inquiryId) {
    final i = _find(inquiryId, _inTeacherClass);
    final refinement = i.refinement;
    if (i.refinementStatus != RefinementStatus.refined || refinement == null) {
      throw const AppException(
        message: '아직 정리된 내용이 없습니다.',
        code: ErrorCodes.refinementNotReady,
        statusCode: 409,
      );
    }
    if (i.stage == InquiryStage.refined) _confirm(i);
    return refinement;
  }

  /// 다시 정리하기(원본 명세 retryInquiryRefinement). 1건당 1회, 결과는 다음 상세 조회에서.
  RefinementStatus retryForTeacher(String inquiryId) {
    final i = _find(inquiryId, _inTeacherClass);
    if (i.urgent ||
        !i.retryAvailable ||
        i.refinementStatus != RefinementStatus.needsOriginal) {
      throw const AppException(
        message: '다시 정리할 수 없는 문의입니다.',
        code: ErrorCodes.refinementRetryUnavailable,
        statusCode: 409,
      );
    }
    i
      ..retryAvailable = false
      ..retryPending = true
      ..refinementStatus = RefinementStatus.pending
      ..title = '정리 중';
    return RefinementStatus.pending;
  }

  /// 테스트용: 원문 열람 횟수.
  int contentViewsOf(String inquiryId) =>
      _inquiries.firstWhere((i) => i.id == inquiryId).contentViews;

  // ───────── 내부 ─────────

  /// 담임 계정 `teacher`가 맡은 3학년 2반 학생의 문의인지. 데모 403 카드는 제외한다.
  static bool _inTeacherClass(_MockInquiry i) =>
      i.id != forbiddenDemoId && _classStudentIds.contains(i.studentId);

  static final _classStudentIds = {_hana.id, _seojun.id, _doyun.id};

  static const _otherParents = '__other__';

  /// 본문 단어 → 긴급 번호(quickstart). null 이면 일반 문의.
  static List<Hotline>? _urgentHotlines(String content) {
    if (content.contains('자해')) return const [Hotline.suicidePrevention];
    if (content.contains('학대')) return const [Hotline.childAbuse];
    if (content.contains('위험')) return const [];
    if (content.contains('긴급')) {
      return const [Hotline.childAbuse, Hotline.suicidePrevention];
    }
    return null;
  }

  /// "정리 중" 데모 문의(F2 `…0003`·학부모가 새로 보낸 문의)를 정리 완료로 바꾼다
  /// (교사 두 번째 목록 조회 때, specs/002 US8-2). F3 데모 `…000a`는 건드리지 않는다.
  void _refinePending() {
    for (final i in _inquiries.where((i) => i.refinePending)) {
      i.refinePending = false;
      _completeRefinement(i);
    }
  }

  /// 정리 확정. 성공이면 번역본을 넣고, 단계가 접수에 머물러 있을 때만 "정제"를 더한다
  /// (교사가 이미 원문을 열어 "교사 확인"이면 단계는 앞으로만 가므로 더하지 않는다, specs/003 Edge).
  void _completeRefinement(_MockInquiry i, {bool success = true}) {
    if (!success) {
      i
        ..refinementStatus = RefinementStatus.needsOriginal
        ..title = '원문 확인 필요';
      return;
    }
    final refinement = _refinementOf(i.id, title: '친구 관계 관련 문의');
    i
      ..refinementStatus = RefinementStatus.refined
      ..refinement = refinement
      ..title = refinement.title;
    if (i.stage == InquiryStage.received) {
      i.timeline.add(StageEvent(stage: InquiryStage.refined, occurredAt: DateTime.now()));
    }
  }

  static void _confirm(_MockInquiry i) => i.timeline.add(
    StageEvent(stage: InquiryStage.teacherConfirmed, occurredAt: DateTime.now()),
  );

  static InquiryRefinement _refinementOf(
    String id, {
    required String title,
    String facts = '학생이 쉬는 시간에 친구와 다툰 뒤 속상해하며 귀가했다고 보호자가 전했어요.',
    String requests = '사실 확인과 이번 주 안 회신을 요청했어요.',
    EmotionLevel level = EmotionLevel.medium,
    List<EmotionLabel> labels = const [EmotionLabel.worry],
  }) => InquiryRefinement(
    inquiryId: id,
    title: title,
    facts: facts,
    requests: requests,
    emotionLevel: level,
    emotionLabels: labels,
    refinedAt: DateTime.now(),
  );

  _MockInquiry _find(String id, bool Function(_MockInquiry) allowed) {
    for (final i in _inquiries) {
      if (i.id == id && allowed(i)) return i;
    }
    throw const AppException(
      message: '요청한 대상을 찾을 수 없습니다.',
      code: ErrorCodes.notFound,
      statusCode: 404,
    );
  }

  void _seed() {
    final now = DateTime.now();
    DateTime ago(Duration d) => now.subtract(d);

    _MockInquiry make({
      required String id,
      required String parentAccount,
      required ({String id, String name}) student,
      required Duration age,
      bool urgent = false,
      bool confirmed = false,
      RefinementStatus? status,
      String? title,
      bool refinePending = false,
      bool refineOnSecondDetailRead = false,
      bool retryAvailable = false,
      bool? retrySucceeds,
      String? requests,
      EmotionLevel level = EmotionLevel.medium,
      List<EmotionLabel> labels = const [EmotionLabel.worry],
    }) {
      final at = ago(age);
      final refined = status == RefinementStatus.refined;
      return _MockInquiry(
        id: id,
        parentAccount: parentAccount,
        studentId: student.id,
        studentName: student.name,
        urgent: urgent,
        hotlines: urgent
            ? const [Hotline.childAbuse, Hotline.suicidePrevention]
            : const [],
        notices: urgent ? const [Notice.urgentDelivered] : const [Notice.received],
        submittedAt: at,
        timeline: [
          StageEvent(stage: InquiryStage.received, occurredAt: at),
          if (urgent) StageEvent(stage: InquiryStage.delivered, occurredAt: at),
          if (status == RefinementStatus.refined)
            StageEvent(
              stage: InquiryStage.refined,
              occurredAt: at.add(const Duration(minutes: 3)),
            ),
          if (confirmed)
            StageEvent(
              stage: InquiryStage.teacherConfirmed,
              occurredAt: at.add(const Duration(minutes: 20)),
            ),
        ],
        refinementStatus: urgent ? null : status,
        title: title ?? (urgent ? '긴급 문의' : '정리 중'),
        content: '(mock) 데모 문의 원문입니다.',
        refinePending: refinePending,
        refineOnSecondDetailRead: refineOnSecondDetailRead,
        retryAvailable: retryAvailable,
        retrySucceeds: retrySucceeds,
        refinement: refined
            ? _refinementOf(
                id,
                title: title ?? '정리된 문의',
                requests: requests ?? '사실 확인과 이번 주 안 회신을 요청했어요.',
                level: level,
                labels: labels,
              )
            : null,
      );
    }

    _inquiries.addAll([
      make(
        id: 'a1000000-0000-4000-8000-000000000001',
        parentAccount: _otherParents,
        student: _seojun,
        age: const Duration(minutes: 30),
        urgent: true,
      ),
      make(
        id: 'a1000000-0000-4000-8000-000000000002',
        parentAccount: _otherParents,
        student: _doyun,
        age: const Duration(days: 2),
        urgent: true,
        confirmed: true,
      ),
      make(
        id: 'a1000000-0000-4000-8000-000000000003',
        parentAccount: 'parent',
        student: _hana,
        age: const Duration(hours: 2),
        status: RefinementStatus.pending,
        refinePending: true,
      ),
      // ── F3 데모(specs/003 research R10) ──
      // 원문 확인 필요 · 다시 정리하기 성공
      make(
        id: 'a1000000-0000-4000-8000-000000000004',
        parentAccount: _otherParents,
        student: _seojun,
        age: const Duration(hours: 5),
        status: RefinementStatus.needsOriginal,
        title: '원문 확인 필요',
        retryAvailable: true,
        retrySucceeds: true,
      ),
      // 원문 확인 필요 · 다시 정리하기 실패
      make(
        id: 'a1000000-0000-4000-8000-000000000006',
        parentAccount: _otherParents,
        student: _doyun,
        age: const Duration(hours: 6),
        status: RefinementStatus.needsOriginal,
        title: '원문 확인 필요',
        retryAvailable: true,
        retrySucceeds: false,
      ),
      // 원문 확인 필요 · 다시 정리하기를 이미 씀
      make(
        id: 'a1000000-0000-4000-8000-000000000007',
        parentAccount: _otherParents,
        student: _seojun,
        age: const Duration(days: 1),
        status: RefinementStatus.needsOriginal,
        title: '원문 확인 필요',
      ),
      // 정리 완료(정제) · 정서 높음 · 분노·답답함
      make(
        id: 'a1000000-0000-4000-8000-000000000008',
        parentAccount: _otherParents,
        student: _doyun,
        age: const Duration(hours: 1),
        status: RefinementStatus.refined,
        title: '친구와 다툰 일 관련 문의',
        level: EmotionLevel.high,
        labels: const [EmotionLabel.anger, EmotionLabel.frustration],
      ),
      // 정리 완료(정제) · 요청사항 없음 · 라벨 없음 · 낮음
      make(
        id: 'a1000000-0000-4000-8000-000000000009',
        parentAccount: 'parent',
        student: _hana,
        age: const Duration(hours: 4),
        status: RefinementStatus.refined,
        title: '체험학습 신청 관련 문의',
        requests: '',
        level: EmotionLevel.low,
        labels: const [],
      ),
      // 정리 중 · 자기 상세의 두 번째 조회(다시 확인)에서 정리 완료
      make(
        id: 'a1000000-0000-4000-8000-00000000000a',
        parentAccount: 'parent',
        student: _hana,
        age: const Duration(hours: 3),
        status: RefinementStatus.pending,
        refineOnSecondDetailRead: true,
      ),
      make(
        id: 'a1000000-0000-4000-8000-000000000005',
        parentAccount: 'parent',
        student: _hana,
        age: const Duration(days: 3),
        status: RefinementStatus.refined,
        title: '준비물 관련 문의',
        confirmed: true,
      ),
      for (var n = 0; n < 25; n++)
        make(
          id: 'b2000000-0000-4000-8000-${(n + 1).toString().padLeft(12, '0')}',
          parentAccount: _otherParents,
          student: n.isEven ? _doyun : _seojun,
          age: Duration(days: 4 + n),
          status: RefinementStatus.refined,
          title: '지난 문의 ${n + 1}',
          confirmed: true,
        ),
      make(
        id: forbiddenDemoId,
        parentAccount: 'parent',
        student: (id: _hana.id, name: '권한 확인(데모)'),
        age: const Duration(days: 40),
        status: RefinementStatus.refined,
      ),
    ]);
  }
}

class _MockInquiry {
  _MockInquiry({
    required this.id,
    required this.parentAccount,
    required this.studentId,
    required this.studentName,
    required this.urgent,
    required this.hotlines,
    required this.notices,
    required this.submittedAt,
    required this.timeline,
    required this.refinementStatus,
    required this.title,
    required this.content,
    this.refinePending = false,
    this.refineOnSecondDetailRead = false,
    this.retryAvailable = false,
    this.retrySucceeds,
    this.refinement,
  });

  final String id;
  final String parentAccount;
  final String studentId;
  final String studentName;
  final bool urgent;
  final List<Hotline> hotlines;
  final List<Notice> notices;
  final DateTime submittedAt;
  final List<StageEvent> timeline;
  RefinementStatus? refinementStatus;
  String title;
  final String content;
  bool refinePending;
  bool refineOnSecondDetailRead;
  bool retryAvailable;

  /// 다시 정리하기 결과(데모에서 미리 정함). null 이면 성공.
  final bool? retrySucceeds;

  /// 다시 정리하기를 받아들였고 결과가 아직 정해지지 않았다(다음 상세 조회에서 정함).
  bool retryPending = false;
  InquiryRefinement? refinement;
  int detailReads = 0;
  int contentViews = 0;

  InquiryStage get stage => timeline.last.stage;

  ParentInquirySummary get parentSummary => ParentInquirySummary(
    inquiryId: id,
    studentId: studentId,
    studentName: studentName,
    urgent: urgent,
    stage: stage,
    submittedAt: submittedAt,
  );

  TeacherInquirySummary get teacherSummary => TeacherInquirySummary(
    inquiryId: id,
    studentId: studentId,
    studentName: studentName,
    urgent: urgent,
    title: title,
    stage: stage,
    refinementStatus: refinementStatus,
    submittedAt: submittedAt,
  );
}
