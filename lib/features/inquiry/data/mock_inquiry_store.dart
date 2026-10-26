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

  TeacherInquiryDetail detailForTeacher(String inquiryId) {
    final i = _find(inquiryId, _inTeacherClass);
    return TeacherInquiryDetail(
      summary: i.teacherSummary,
      timeline: List.unmodifiable(i.timeline),
    );
  }

  /// 원문 열람. 긴급은 첫 열람에 "교사 확인"이 된다(원본 명세 viewInquiryContent).
  String contentForTeacher(String inquiryId) {
    final i = _find(inquiryId, _inTeacherClass);
    i.contentViews++;
    if (i.urgent && i.stage == InquiryStage.delivered) {
      i.timeline.add(
        StageEvent(stage: InquiryStage.teacherConfirmed, occurredAt: DateTime.now()),
      );
    }
    return i.content;
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

  /// "정리 중" 데모 문의를 정리 완료로 바꾼다(교사 두 번째 조회 때, US8-2).
  void _refinePending() {
    for (final i in _inquiries.where((i) => i.refinePending)) {
      i
        ..refinePending = false
        ..refinementStatus = RefinementStatus.refined
        ..title = '친구 관계 관련 문의'
        ..timeline.add(
          StageEvent(stage: InquiryStage.refined, occurredAt: DateTime.now()),
        );
    }
  }

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
    }) {
      final at = ago(age);
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
      make(
        id: 'a1000000-0000-4000-8000-000000000004',
        parentAccount: _otherParents,
        student: _seojun,
        age: const Duration(hours: 5),
        status: RefinementStatus.needsOriginal,
        title: '원문 확인 필요',
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
