# Data Model: 문의 접수·긴급 분류 화면 (F2)

**Feature**: [spec.md](./spec.md) · 응답 모양의 근거: 백엔드 원본 명세 0.5.0([research R1](./research.md#r1-api-계약-기준--태그-전-원본-명세-050))

모든 모델은 `domain`에 두고 Flutter·dio를 참조하지 않는다. 앱은 이 값을 **메모리에만** 둔다. 문의 본문·원문은 기기 저장소·로그에 남기지 않는다(원칙 III·VI).

## 1. 공통 값 (`lib/features/inquiry/domain/models.dart`)

### InquiryStage

| 값 | 서버 값 | 화면 이름 | 비고 |
|---|---|---|---|
| `received` | `RECEIVED` | 접수 | |
| `delivered` | `DELIVERED` | 교사에게 전달됨 | 긴급만 |
| `refined` | `REFINING` | 정제 | 서버 이름은 REFINING이지만 뜻은 "정제 완료" |
| `teacherConfirmed` | `TEACHER_CONFIRMED` | 교사 확인 | |
| `answered` | `ANSWERED` | 답변 완료 | F4가 채움 |

- 모르는 값이 오면 해석 오류로 보고 일반 안내를 보인다(`mapDioErrors`, F1 리뷰 반영).
- 타임라인에 보일 단계 순서: 일반 `received → refined → teacherConfirmed → answered`, 긴급 `received → delivered → teacherConfirmed → answered`. 아직 오지 않은 단계는 흐리게 표시한다(FR-015).

### StageEvent

| 필드 | 타입 | 출처 |
|---|---|---|
| `stage` | `InquiryStage` | `stage` |
| `occurredAt` | `DateTime`(로컬 시각으로 표시) | `occurredAt` |

### Notice · Hotline (보낸 뒤 안내)

| 모델 | 서버 값 → 앱 고정 문구 |
|---|---|
| `Notice.received` | `RECEIVED` → "문의가 접수되었습니다." |
| `Notice.urgentDelivered` | `URGENT_DELIVERED` → "선생님께 바로 전달했어요." |
| `Notice.deferred` | `DEFERRED_TO_AVAILABLE_HOURS` → "선생님 응답 가능 시간에 전달됩니다." |
| `Hotline.suicidePrevention` | `SUICIDE_PREVENTION_109` → "자살예방 상담전화 109" (전화 `109`) |
| `Hotline.childAbuse` | `CHILD_ABUSE_112` → "아동학대 신고 112" (전화 `112`) |

- 모르는 코드는 버린다. 문구는 `notice_text.dart` 상수 한 곳에만 둔다(원칙 V, FR-012).

### SubmitOutcome (안내 화면 선택, research R5)

```
urgent == true                                → UrgentNotice(hotlines)
notices ∋ DEFERRED_TO_AVAILABLE_HOURS         → DeferredNotice
그 밖                                          → ReceivedNotice

hotlines 정리: 모르는 코드 제거 → (제거 전 비어 있지 않았는데 제거 후 비었으면) [112, 109]
```

| 서버 `hotlines` | 화면 | 프레임 |
|---|---|---|
| `[SUICIDE_PREVENTION_109]` | 109만 | F2-3c |
| `[CHILD_ABUSE_112]` | 112만 | F2-3d |
| `[]` | 번호 없음 | F2-3 |
| `[CHILD_ABUSE_112, SUICIDE_PREVENTION_109]` | 112·109 | F2-3b |
| `[알 수 없는 값]` | 112·109 | F2-3b |

## 2. 학부모 (`ParentInquiryRepository`)

### InquirySubmitted

| 필드 | 타입 | 비고 |
|---|---|---|
| `inquiryId` | `String`(UUID) | |
| `urgent` | `bool` | |
| `stage` | `InquiryStage` | 긴급이면 `delivered` |
| `submittedAt` | `DateTime` | |
| `notices` | `List<Notice>` | |
| `hotlines` | `List<Hotline>` | 일반이면 빈 목록 |

### ParentInquirySummary (목록 카드)

| 필드 | 타입 |
|---|---|
| `inquiryId` | `String` |
| `studentId` | `String` |
| `studentName` | `String` |
| `urgent` | `bool` |
| `stage` | `InquiryStage` |
| `submittedAt` | `DateTime` |

제목 필드는 없다(spec FR-016). 정렬은 서버 순서(최신순)를 따른다.

### ParentInquiryDetail (카드 펼침·긴급 안내 다시 보기)

`ParentInquirySummary` + `timeline: List<StageEvent>`, `notices`, `hotlines`.
응답의 `content`(본인 원문)·`followUps`·`answers`는 F4 화면의 몫이라 이번에는 모델에 담지 않는다.

### ComposeState (작성 ViewModel, autoDispose)

| 필드 | 타입 | 규칙 |
|---|---|---|
| `child` | `Child` | 홈에서 고른 자녀(F1 모델). 담임 없음이면 작성 화면을 열지 않음(FR-003) |
| `length` | `int` | `content.trim().runes.length` (research R4) |
| `canSubmit` | `bool` | `1 ≤ length ≤ 2000` ∧ ¬`isSubmitting` (1분 제한 중에도 막지 않음 — 긴급은 제한 없음, FR-005) |
| `isSubmitting` | `bool` | 보내는 중 버튼 비활성(FR-004) |
| `errorMessage` | `String?` | 서버 `message` 또는 고정 안내 |
| `cooldown` | `Cooldown` | 429 `Retry-After`, F1 `CooldownTimer` 재사용(FR-005) |
| `_idempotencyKey` | `String?` | (child, trimmed content) 쌍이 같으면 재사용, 바뀌면 새로 만듦, 성공하면 버림(research R3) |

본문 자체는 `TextEditingController`에 있다. ViewModel은 보낼 때 인자로 받는다.

상태 전이:

```
editing ──보내기──▶ submitting ──201──▶ (안내 화면으로 교체)
                        │
                        ├─429──▶ editing(cooldown, 내용 유지, 같은 키)
                        ├─409 NO_HOMEROOM_TEACHER / CONFLICT──▶ editing(서버 안내, 내용 유지)
                        ├─네트워크·5xx──▶ editing(안내, 내용 유지, 같은 키)
                        └─401──▶ (인터셉터 갱신·재시도, 실패면 로그인 화면)
```

## 3. 교사 (`TeacherInquiryRepository`)

### TeacherInquirySummary (목록·홈)

| 필드 | 타입 | 비고 |
|---|---|---|
| `inquiryId` | `String` | |
| `studentId` · `studentName` | `String` | 학부모 정보 없음(FR-023) |
| `urgent` | `bool` | |
| `title` | `String` | 서버 값 그대로("긴급 문의"·"정리 중"·"원문 확인 필요"·정리된 제목) |
| `stage` | `InquiryStage` | |
| `refinementStatus` | `RefinementStatus?` | `pending`·`refined`·`needsOriginal`, 긴급은 null |
| `submittedAt` | `DateTime` | |

`isUnconfirmedUrgent` = `urgent && stage == delivered` → 교사 홈 긴급 카드(FR-021).

### TeacherInquiryPage

`items`, `page`, `size`, `totalElements`. `hasMore` = `(page + 1) * size < totalElements`.

### TeacherInquiriesState (목록 ViewModel)

| 필드 | 규칙 |
|---|---|
| `items` | 불러온 페이지를 이어 붙인 목록 |
| `nextPage` | 다음에 부를 페이지(없으면 null) |
| `isLoadingMore` | 다음 페이지 요청 중 |
| `loadMoreError` | 다음 페이지만 실패했을 때 목록 아래 "다시 시도" |

다시 불러오기(열 때·당길 때·알림 수신·앱 복귀, research R7)는 0페이지부터 새로 하며, 그동안 이전 목록을 그대로 보인다.

### UrgentInquiryView (긴급 문의 상세, research R8)

| 필드 | 출처 | 비고 |
|---|---|---|
| `summary` | `GET /teacher/inquiries/{id}` | 학생 이름·접수 시각·타임라인 |
| `content` | `GET /teacher/inquiries/{id}/content` | 화면이 열려 있는 동안 메모리에만. 화면 생존 동안 1회만 호출 |

## 4. 알림 설정 (`NotificationRepository`, `lib/features/notification`)

### NotificationSettings

| 필드 | 타입 | 규칙 |
|---|---|---|
| `generalEnabled` | `bool` | 일반 문의 알림. 긴급 알림 항목은 없다(FR-028) |
| `availability` | `List<AvailabilityWindow>` | 빈 목록 = 언제든 응답 가능(FR-029). 요일당 최대 1개 |

### AvailabilityWindow

| 필드 | 타입 | 검증(FR-027) |
|---|---|---|
| `day` | `DayOfWeek`(월~일) | 같은 요일 중복 금지 |
| `start` | `TimeOfDayValue`(시·분) | `00:00`~`23:59` |
| `end` | `TimeOfDayValue` | `00:01`~`24:00`, `start < end` |

- 화면은 요일마다 "응답 가능" 켜기 + 시작·종료 시각을 고른다. 꺼진 요일은 보내지 않는다.
- 서버 400(`INVALID_INPUT`)의 `fieldErrors`는 해당 요일 아래에 보인다.
- `TimeOfDayValue`는 domain 모델(Flutter의 `TimeOfDay`를 쓰지 않음, domain에 Flutter 금지).

### DeviceRegistration

| 필드 | 값 |
|---|---|
| `token` | FCM 등록 토큰(1~512자). 로그에 남기지 않는다 |
| `platform` | `ANDROID` · `IOS` |

`DeviceRegistrar` 상태:

```
idle ──SignedIn(teacher)──▶ (교사 홈 진입 때 기기 권한이 "정하지 않음"이면 요청) ──허용──▶ registering ──PUT 204──▶ registered
registered ──onTokenRefresh──▶ registering
registered ──로그아웃·탈퇴 직전──▶ DELETE /me/devices/current(실패 무시) ──▶ idle
권한 거부 ──▶ idle (설정 화면에 "기기 알림이 꺼져 있습니다" 안내, FR-031a)
```

## 5. 알림 이동 (`lib/core/push`)

### PushData

| 필드 | 출처(`data`) | 규칙 |
|---|---|---|
| `kind` | `kind` | `URGENT`·`URGENT_REMINDER`·`GENERAL`·`GENERAL_DIGEST`, 그 밖은 `unknown` |
| `inquiryId` | `inquiryId` | UUID 형식일 때만 사용 |

경로 고르기(research R9): 긴급 2종 + 올바른 `inquiryId` → `/teacher/inquiries/{id}/urgent`, 그 밖 → `/teacher/inquiries`.

### PendingNavigation

알림을 눌러 열었는데 로그인이 풀려 있을 때 이동할 경로 하나를 메모리에 둔다. 교사로 로그인하면 `resolveRedirect`가 역할 홈 대신 이 경로로 보내고 비운다. 다른 역할로 로그인하면 버린다.
