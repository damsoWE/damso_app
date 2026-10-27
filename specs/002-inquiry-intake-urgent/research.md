# Research: 문의 접수·긴급 분류 화면 (F2)

**Feature**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md)

## R1. API 계약 기준 — 태그 전 원본 명세 0.5.0

- **Decision**: F2 API는 백엔드 레포 `main`의 `docs/api/openapi.yaml`(`info.version: 0.5.0`, 태그 없음)을 **임시 기준**으로 설계한다. 앱 사본 `docs/api/openapi.yaml`(api-v0.4)은 고치지 않는다. 백엔드가 `api-v0.5` 태그를 올리면 `/fetch-api api-v0.5`로 받아 [contracts/api-usage.md](./contracts/api-usage.md)와 비교하고, 다른 점만 고친다.
- **Rationale**: constitution "Contract-first — 사본은 직접 수정하지 않는다". 원본 명세가 이미 있어 추측으로 만들 필요는 없지만, 태그가 없으면 바뀔 수 있다.
- **Alternatives considered**: 백엔드 spec의 Key Entities만 보고 mock 설계 — 응답 모양(안내 코드·번호 코드·페이지)을 놓쳐 다시 만들게 된다.
- **확인한 원본 명세의 결정**: 안내는 코드(`NoticeCode`, `HotlineCode`)로 주고 문구는 앱이 고정으로 가진다 · 학부모 목록에는 제목 없음 · 교사 목록은 `page`/`size`(기본 20, 최대 50) · 제출은 `Idempotency-Key`(UUID) 헤더 필수 · 원문 열람은 별도 경로(`/content`)이며 열람 기록과 단계 전이를 일으킨다.

## R2. 하단 탭 — `StatefulShellRoute.indexedStack`

- **Decision**: 학부모·교사 각각 `StatefulShellRoute.indexedStack`으로 탭 3개(홈 · 문의 · 마이페이지)를 만든다. 탭마다 자기 `Navigator`를 가져 이동 기록이 따로 남는다(FR-035). 경로는 기존 `/parent`·`/teacher` 아래에 둔다([contracts/routes.md](./contracts/routes.md)).
  - 탭 안에서 이어지는 목록·상세는 탭 Navigator에 쌓는다(탭 바가 보임).
  - 문의 작성·보낸 뒤 안내·긴급 문의 상세·응답 가능 시간 설정처럼 집중해서 끝내는 화면은 **루트 Navigator**(`parentNavigatorKey: rootKey`)에 띄워 탭 바를 가린다. Figma 해당 프레임에 탭 바가 없다.
  - redirect는 지금처럼 `resolveRedirect` 한 곳만 쓴다. 경로 접두사(`/parent`, `/teacher`)로 역할을 가르는 규칙이 그대로 통한다.
- **Rationale**: go_router 17에 이미 있는 기능이라 새 패키지가 필요 없다. 탭별 이동 기록 유지가 IA·Figma의 기대 동작이다.
- **Alternatives considered**: `ShellRoute` + `BottomNavigationBar`에서 `context.go` — 탭을 옮기면 보던 화면이 사라진다. 탭마다 별도 `GoRouter` — redirect 단일 지점이 깨진다.
- **슈퍼 관리자**: 이번에 바꾸지 않는다(Clarifications).

## R3. 중복 제출 방지 — `Idempotency-Key`

- **Decision**: 작성 ViewModel이 **(대상 자녀, 앞뒤 공백을 뺀 본문)** 한 쌍마다 UUID v4 하나를 만든다. 같은 쌍으로 다시 보내면(연타·네트워크 재시도·1분 제한 뒤 재시도) 같은 키를 쓰고, 자녀나 본문이 바뀌면 새 키를 만든다. 접수에 성공하면 키를 버린다. UUID는 `Random.secure()`로 만드는 작은 함수 하나(`lib/core/util/uuid.dart`)로 해결한다.
- **Rationale**: 서버 규칙(같은 키 = 같은 결과, 같은 키 + 다른 내용 = 409)을 그대로 따른다. 보내는 중 버튼 비활성(FR-004)과 함께 쓰면 연타도 막는다.
- **Alternatives considered**: `uuid` 패키지 — 함수 10줄을 위해 의존성을 늘린다. 화면을 열 때 키를 한 번만 만듦 — 실패 뒤 내용을 고쳐 다시 보내면 409가 난다.
- **남는 경우**: 응답을 못 받은 채(시간 초과) 내용을 고쳐 다시 보내면 새 키라 두 건이 될 수 있다. 첫 요청이 서버에 닿았는지 앱은 알 수 없으므로 감수하고, 시간 초과 안내에 "보낸 문의 목록을 먼저 확인해 주세요"를 붙인다.

## R4. 글자 수 — 코드 포인트

- **Decision**: 본문 길이는 `trim()` 뒤 `runes.length`(코드 포인트)로 센다. 1~2,000일 때만 보내기 버튼을 켠다(FR-002). 입력 제한(`maxLength`)은 걸지 않고, 넘치면 안내만 보인다(붙여 넣은 글이 잘리지 않게).
- **Rationale**: 원본 명세 `Content` 설명 — 서버가 코드 포인트로 센다. `String.length`(UTF-16)로 세면 이모지가 2자로 세어져 앱이 먼저 막는다.
- **Alternatives considered**: 문자소(grapheme) 단위 — 서버와 수가 달라진다.

## R5. 보낸 뒤 안내 화면 고르기

- **Decision**: `InquirySubmitted` 응답으로 화면을 고른다.
  1. `urgent == true` → 긴급 전달 안내(F2-3 계열). 번호는 `hotlines`를 앱 고정 문구로 바꾼다. 모르는 코드는 버린다. 버린 뒤 비었는데 원래 목록이 비어 있지 않았으면 기본 안내(112·109)로 바꾼다(FR-010).
  2. `notices`에 `DEFERRED_TO_AVAILABLE_HOURS` → 전달 준비 지연(F2-5a).
  3. 그 밖 → 문의 접수(F2-5).
- 화면의 문구는 모두 앱 상수(`lib/features/inquiry/domain/notice_text.dart`)에서 가져온다. 서버가 문장을 주지 않는다(원칙 V).
- 안내 화면은 `context.go`로 작성 화면을 **교체**해, 뒤로 가기로 작성 화면에 돌아가 같은 내용을 다시 보내지 않게 한다(FR-013). 결과는 경로의 `extra`로 넘긴다. 긴급 안내는 목록의 긴급 카드에서 다시 열 수 있게 상세 응답(`notices`·`hotlines`)으로도 만들 수 있다(FR-018).
- **Rationale**: 원본 명세 `NoticeCode`·`HotlineCode` 정의와 원칙 V.

## R6. 학부모 목록·처리 단계

- **Decision**: `GET /parent/inquiries`(전체, 최신순)를 `ParentInquiriesViewModel`이 가진다. 홈의 문의 영역은 같은 목록을 **선택한 자녀로 걸러** 최근 3건을 보여 준다. 카드를 펼치면 그때 `GET /parent/inquiries/{id}`를 불러 타임라인을 보여 주고, 화면이 살아 있는 동안 메모리에 둔다.
- 다시 불러오기: 화면을 열 때 · 다른 탭에서 문의 탭·홈 탭으로 돌아올 때(탭 셸의 탭 선택 콜백) · 당겨서 새로 고칠 때 · 문의를 보낸 직후(목록 provider 무효화).
- 상세 응답의 `content`(본인 원문)는 이번에 화면에 쓰지 않는다(F4-1 스레드 화면의 몫). 받은 값은 메모리에만 있고 저장·로그하지 않는다.
- **Rationale**: 목록 응답에 타임라인이 없다. 펼칠 때만 부르면 목록이 길어도 요청이 늘지 않는다.
- **Alternatives considered**: 목록을 열 때 상세를 모두 부름 — 요청 수가 문의 수만큼 늘어난다.

## R7. 교사 목록 — 페이지와 다시 불러오기

- **Decision**: `TeacherInquiriesViewModel`이 `page`를 0부터 20건씩 불러 이어 붙인다(목록 끝 근처에 오면 다음 페이지). 다시 불러오기는 0페이지부터 새로 한다. 계기(Clarifications Q2):
  1. 화면을 열 때 · 다른 탭에서 문의 탭·홈 탭으로 돌아올 때(탭 셸이 살아 있어 화면이 다시 만들어지지 않으므로 탭 선택 콜백에서 새로 고침) · 당겨서 새로 고칠 때
  2. 앱이 열려 있을 때 문의 알림을 받았을 때(R9)
  3. 앱이 백그라운드에서 다시 앞으로 왔을 때 — 교사 탭 셸에 `AppLifecycleListener(onResume:)`를 하나 두고 목록·홈 provider를 무효화한다.
- 다시 불러오는 동안 보던 목록은 그대로 둔다(`AsyncValue`의 이전 값 유지, 화면은 상단 얇은 진행 표시만).
- 교사 홈의 긴급 카드: 0페이지에서 `urgent && stage == DELIVERED`(교사 확인 전)인 문의. 서버가 긴급을 먼저 정렬하므로 0페이지만 봐도 된다.
- **Rationale**: 일정 간격 조회는 하지 않는다(Clarifications Q2). 원본 명세의 정렬 규칙(긴급 먼저, 최신순)을 그대로 쓴다.

## R8. 교사 긴급 문의 상세와 원문 열람

- **Decision**: 긴급 문의 상세(F3-5)는 화면을 열 때 `GET /teacher/inquiries/{id}`(타임라인)과 `GET /teacher/inquiries/{id}/content`(원문)를 **한 번씩** 부른다. 원문 호출이 열람 기록과 "교사 확인" 전이를 일으키므로, 화면이 다시 그려져도 원문을 다시 부르지 않는다(ViewModel이 한 번만 부르고 결과를 메모리에 둔다). 화면을 닫으면 원문은 버린다. 다녀오면 목록·홈 provider를 무효화해 단계를 새로 보인다.
- 일반 문의(정리 중·정리 완료·원문 확인 필요)를 누르면 "준비 중" 안내만 보인다(FR-024, F3 범위). 원문 호출을 하지 않는다 — 열람 기록이 생기기 때문이다.
- **Rationale**: 원칙 III(열람 감사)·원칙 VI. 원문은 기기에 저장하지 않는다.

## R9. 기기 알림 — Firebase Cloud Messaging

- **Decision**: `firebase_core ^4.15.0`, `firebase_messaging ^16.7.0`을 추가한다. 앱 코드는 `lib/core/push/push_messaging.dart`의 인터페이스만 알고, 구현은 둘이다.
  - `FcmPushMessaging`: 실제 FCM.
  - `NoopPushMessaging`: mock 실행·테스트·Firebase 설정이 없는 빌드. 등록·수신이 아무 일도 하지 않는다.
  - provider 한 곳(`pushMessagingProvider`)에서 `USE_MOCK`·설정 유무로 고른다(constitution 아키텍처 규칙과 같은 방식).
- **교사만 등록** (spec FR-031): 세션이 `SignedIn(teacher)`가 되면(로그인·세션 복구) `DeviceRegistrar`가 ① 교사 홈에 들어왔을 때 기기 권한이 아직 "정하지 않음"이면 권한 요청(이미 허용·거부했으면 묻지 않음, 앱은 요청 여부를 저장하지 않음) ② 토큰을 받아 `PUT /me/devices` ③ `onTokenRefresh`마다 다시 `PUT`. 로그아웃·탈퇴 직전에 `DELETE /me/devices/current`를 부르고 실패는 무시한다(서버는 세션이 끝나면 어차피 보내지 않는다 — 백엔드 research R9).
- **알림 내용**: 서버가 고정 제목·본문과 `data`(`kind`, `inquiryId` 또는 `count`)만 보낸다. 앱은 `data`를 화면 이동에만 쓰고 저장·로그하지 않는다(FR-031c).
  - `kind = URGENT | URGENT_REMINDER` → `/teacher/inquiries/{inquiryId}/urgent`
  - `kind = GENERAL | GENERAL_DIGEST` → `/teacher/inquiries`
  - 모르는 `kind`·UUID 형식이 아닌 `inquiryId` → `/teacher/inquiries`
- **앱이 열려 있을 때**(`onMessage`): 시스템 알림이 뜨지 않으므로 앱 안 배너(`MaterialBanner`)로 같은 고정 문구와 "보기" 버튼을 보이고, 교사 목록·홈을 다시 불러온다(R7).
- **알림을 눌러 열 때**(`getInitialMessage`, `onMessageOpenedApp`): 이동할 경로를 `PendingNavigation`(메모리)에 넣는다. 로그인 상태면 바로 이동하고, 로그인이 풀려 있으면 로그인 뒤 `resolveRedirect`가 역할 홈 대신 그 경로로 보낸다(같은 역할일 때만, SC-013).
- **Android**: 긴급 알림이 화면 위로 뜨도록 중요도 높음 알림 채널(`damso_urgent`)을 `MainActivity.kt`에서 만들고, 매니페스트의 `default_notification_channel_id`로 지정한다(코드 몇 줄, 새 패키지 없음). Android 13+ 알림 권한은 `requestPermission()`으로 요청한다.
- **iOS**: Xcode에서 Push Notifications·Background Modes(remote notifications) 켜기, APNs 키를 Firebase 콘솔에 등록. Windows에서는 iOS 빌드·확인을 할 수 없으므로 iOS 확인은 Mac 환경 작업으로 따로 둔다(리스크).
- **Rationale**: 백엔드가 FCM으로 정했다(백엔드 R8). 인터페이스를 두면 위젯 테스트와 mock 실행이 Firebase 없이 돈다.
- **Alternatives considered**: `flutter_local_notifications`로 앱 안 알림을 시스템 알림처럼 띄움 — 패키지가 하나 더 늘고, 앱 안 배너로 충분하다. 최신 메이저(`firebase_core 5.x`, `firebase_messaging 17.x`) — 공개된 지 2주가 안 됐다. 4.15·16.7은 한 달 넘게 쓰였고 현재 Flutter 3.38과 맞는 것을 확인했다(`flutter pub add --dry-run`).

## R10. Firebase 설정 값 보관 — 원칙 VIII와의 관계

- **Decision**: Firebase 연결 설정(프로젝트 ID·앱 ID·발신자 ID·API 키)은 **저장소에 넣지 않는다.**
  - 개발자 PC와 CI는 git이 무시하는 `secrets/firebase.json`에 값을 두고 `--dart-define-from-file=secrets/firebase.json`으로 빌드한다. 저장소에는 빈 값의 `secrets/firebase.example.json`만 둔다. `env/*.json`에는 넣지 않는다(constitution "앱 코드·`env/*.json`·에셋에 넣지 않는다").
  - 앱은 `Firebase.initializeApp(options: FirebaseOptions(...))`로 Dart에서 값을 넘긴다. 그래서 `google-services.json`·`GoogleService-Info.plist`·`firebase_options.dart`를 만들지 않는다.
  - 값이 비어 있으면 Firebase를 켜지 않고 `NoopPushMessaging`을 쓴다. 이 경우에도 앱은 정상 동작한다(알림만 없음).
- **남는 문제(Complexity Tracking)**: 빌드된 앱 안에는 이 값이 들어간다. 클라이언트 SDK는 이 값 없이 동작할 수 없다. Firebase의 API 키는 비밀번호가 아니라 프로젝트를 가리키는 식별자다(Google 문서). 그래서 서버 쪽에서 막는다. Google Cloud 콘솔에서 이 키를 Android 패키지 이름·iOS 번들 ID로 제한하고 FCM 등록에 필요한 API만 허용한다(팀 작업). 서버 발송 권한(서비스 계정)은 백엔드 시크릿 `DAMSO_FCM_CREDENTIALS`에만 있고 앱에는 없다.
- **Rationale**: 저장소와 Gitleaks 검사(`AIza…` 패턴)를 깨끗하게 유지하고, 원칙 VIII의 "시크릿을 코드·설정 파일에 하드코딩하지 않는다"를 지킨다.
- **Alternatives considered**: `google-services.json`을 커밋 — Gitleaks가 막고, 원칙 문구와 맞지 않는다. `google-services.json`을 git에서 빼고 Gradle 플러그인을 조건부 적용 — Android·iOS가 서로 다른 방식이 되고 iOS는 Xcode 프로젝트에 파일 참조가 남는다.

## R11. 109·112 전화 걸기 화면

- **Decision**: `url_launcher ^6.3.2`를 추가한다. 6.3.3은 Flutter 3.41 이상이 필요해 현재 3.38과 맞지 않는다. 번호 버튼은 `launchUrl(Uri(scheme: 'tel', path: '109'))`로 기기의 전화 걸기 화면만 연다. 전화를 바로 걸지는 않는다(Clarifications Q3).
  - Android 11+는 `AndroidManifest.xml`의 `<queries>`에 `tel` 스킴(`ACTION_DIAL`)을 선언해야 `canLaunchUrl`이 맞게 답한다. iOS는 `Info.plist`의 `LSApplicationQueriesSchemes`에 `tel`.
  - `canLaunchUrl`이 거짓이면(전화 기능 없는 태블릿) 번호를 글자로만 보여 주고 버튼을 비활성으로 둔다(FR-010a).
  - `CALL_PHONE` 권한은 추가하지 않는다(다이얼 화면만 열기 때문).
- **Alternatives considered**: 플랫폼 채널 직접 구현 — 두 플랫폼 코드를 직접 관리해야 한다.

## R12. 작성 중인 본문

- **Decision**: 본문은 `TextEditingController`와 작성 ViewModel(autoDispose)에만 있다. 화면을 떠나면 사라진다. 기기 저장소·클립보드 자동 복사·로그에 남기지 않는다(FR-007, 원칙 III·VI). 내용이 있는 채로 뒤로 가면 `PopScope`로 "작성한 내용이 사라집니다" 확인을 받는다.
- 입력란은 `enableSuggestions`·`autocorrect`를 기기 기본값으로 둔다. 키보드 학습을 끄면 한글 입력이 불편해지고, 원문은 어차피 사용자가 쓴 글이다.

## R13. 기존 문의 뼈대 정리

- **Decision**: `lib/features/inquiry`(뼈대 목록)·`reply`·`history`와 `/inquiries` 경로를 지운다. 그 자리에 새 `inquiry`(학부모·교사 문의)와 `notification`(설정·기기 등록) 기능을 만든다. 지우기 전에 사용자 승인을 받는다(CLAUDE.md "파일 삭제는 승인 후").
- **Rationale**: 뼈대는 옛 API(`/inquiries` 단일 목록)를 가정해 원본 명세와 맞지 않고, F2-4·F3-1이 그 역할을 대신한다(FR-032). `reply`·`history`는 F4·F5에서 원본 명세에 맞춰 새로 만든다.

## R14. mock 데모 규칙

- **Decision**: mock은 본문에 든 단어로 결과를 고른다(구체 입력표는 [quickstart.md](./quickstart.md)).
  - 긴급: "자해" → 109만 · "학대" → 112만 · "위험" → 번호 없음 · "긴급" → 112·109(분류 안 됨)
  - 지연: "밤늦게" → `DEFERRED_TO_AVAILABLE_HOURS`
  - 1분 제한: 일반 문의를 60초 안에 두 번 → 429 `Retry-After: 60 - 경과초`(긴급은 제외)
  - 담임 없는 자녀(F1 mock의 김두리) → 409 `NO_HOMEROOM_TEACHER`
  - 교사 목록: 긴급(교사 확인 전·후) · "정리 중"이 두 번째 조회부터 정리 완료로 · "원문 확인 필요" · 25건 이상(페이지 확인용)
  - 남의 문의: 데모 문의 ID 하나는 403 `FORBIDDEN`
  - 접근 권한 만료 → 갱신: F1의 `refresh@damso.test` 방식을 문의 목록 첫 조회에도 적용
- mock 기기 알림은 없다(`NoopPushMessaging`). 알림 수신·이동은 가짜 `PushMessaging`을 넣은 위젯 테스트로 확인한다.
- **Rationale**: constitution "mock에는 정상 응답만 넣지 않는다" + FR-033.

## R15. 테스트

- **ViewModel 단위**: 작성(글자 수·키 재사용·429·409·실패 시 내용 유지) · 안내 고르기(R5 규칙 표 전부) · 교사 목록 페이지·다시 불러오기 · 긴급 상세 원문 1회 호출 · 설정 저장 검증.
- **위젯**: 하단 탭 이동 기록 유지 · 작성 → 안내 → 목록 흐름 · 긴급 안내 번호 버튼(가짜 런처) · 화면에 학부모 이메일 없음.
- **알림**: 가짜 `PushMessaging`으로 열린 상태 수신 → 배너·목록 새로 고침, 알림 열기 → 경로 이동, 로그아웃 시 해제 호출.
- **실서버 계약**: 가짜 `HttpClientAdapter`로 `Idempotency-Key` 헤더·응답 해석(안내 코드·모르는 코드) 확인.
- F1처럼 위젯 테스트는 `testApp()` 헬퍼에 mock Repository와 가짜 `PushMessaging`·`DialLauncher`를 넣는다.
