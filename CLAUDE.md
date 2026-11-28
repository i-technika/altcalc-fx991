# 프로젝트: 카시오 fx-991 공학용 계산기 시뮬레이터 (Flutter)

> 이 프로젝트는 초기에 Antigravity(Gemini)로 시작되어 #7까지 진행된 뒤 Claude Code로 이관되었다.
> 이 문서가 프로젝트 규칙의 단일 기준(Single Source of Truth)이다. (구 `gemini.md` 대체)

## 0. 응답 및 작업 언어
- 모든 설명, 계획 수립, 코드 주석, 커밋 메시지 본문, PR/이슈 본문은 **한국어**로 작성한다.
- 현재 진행 단계와 완료 기준은 항상 [milestone.md](milestone.md)와 GitHub 이슈를 기준으로 삼는다.
- **질의 규칙:** 사용자에게 묻는 모든 질의(AskUserQuestion 도구든 본문 문장이든)는 **하나만 고르는 단일 선택(라디오)** 으로 하고,
  가장 나은 선택지를 첫 번째에 두고 그 선택지의 라벨 끝에 `(Recommended)`를 붙인다. 여러 개를 고르는 체크박스(multiSelect)나 "여러 개 가능" 질의는
  하지 않는다 — 그런 결정(예: 후속 이슈 중 무엇을 등록할지)은 Claude가 직접 판단하고 보고에 근거를 적는다 (#112).

## 1. 핵심 아키텍처 및 기술 스택
- **프레임워크:** Flutter (Dart 3.14+) — Android / iOS 크로스 플랫폼
  - SDK 버전은 `pubspec.yaml`의 `environment.flutter`(정확한 버전) 하나로 고정하고 CI도 그 값을 읽는다 (#78). 버전 숫자는 그 파일만 기준으로 삼는다.
    CI의 모든 잡은 `.github/scripts/read-flutter-version.sh`로 값을 읽어 설치 액션의 `flutter-version`에 넘긴다 —
    액션의 `flutter-version-file`은 yq가 필요해(Windows 러너는 Chocolatey 설치) 쓰지 않는다 (#90).
    올릴 때는 README "Flutter SDK 버전 올리기" 절차대로 로컬 SDK·`pubspec.lock`과 함께 바꾼다.
  - CI 워크플로의 모든 `uses:`는 커밋 SHA로 고정하고 같은 줄 끝에 태그를 적는다(`@<sha> # vX.Y.Z`, #88).
    태그(`@v2`)로 되돌리지 않는다. 올리는 방법·시기(마일스톤 착수 때 점검)와 보안 권고 예외(`.github/action-advisories-ignore`)는
    README "CI 액션 고정 버전 올리기"를 따른다.
  - Flutter 3.50부터 Material 위젯은 분리 패키지 `material_ui`로 제공된다.
    **`import 'package:material_ui/material_ui.dart';`** 를 사용한다 (`package:flutter/material.dart` 아님).
    Cupertino 쪽(`CupertinoTheme` 등)도 material_ui가 쓰는 **`package:cupertino_ui/cupertino_ui.dart`** 를 쓴다 —
    `package:flutter/cupertino.dart`의 같은 이름 클래스는 다른 타입이라 지정해도 material_ui 위젯에 효과가 없다 (#107).
- **상태 관리:** `flutter_riverpod` (현재 2.x)
- **수학 연산 엔진:** 커스텀 AST(추상 구문 트리) + `decimal` 패키지. **정밀도는 실물 fx-991EX와 동일하게** 맞춘다 (출처: User's Guide "Calculation Range and Precision").
  - 내부 연산: 유효숫자 **15자리** / LCD 표시: 유효숫자 **10자리** 반올림 (단일 계산 정밀도는 10번째 자리 ±1)
  - 계산 범위: ±1×10⁻⁹⁹ ~ ±9.999999999×10⁹⁹ 또는 0 — 범위를 벗어나면 Math ERROR
  - 상수: π = 3.14159265358980, e = 2.71828182845904 (가이드 기재값)
  - 연산 단계별 반올림 방식·언더플로 처리 등 세부 규칙은 #30에서 실물 대조로 확정한다.
- **2D 자연어 수식 렌더링 (Natural Textbook Display):** `IntrinsicWidth`, `Row`, `Column` 등을 활용한 재귀 위젯 트리(`MathNodeWidget`)로 분수, 루트, 지수, 정적분, 시그마 기호를 렌더링한다.
- **수익화 및 서버리스 인앱결제** (M11, 에픽 #192 — 구매·복원 자리는 M5 설정 팝업, 에픽 #191. 설정 팝업은 ON 자리의 설정 키(SETUP 키 — #190에서 `SETTING`으로 인쇄했고 #253에서 `SETUP`으로 바꿨다) 하나로 여는 일반 앱 같은 팝업이다. SHIFT+MENU(SETUP)로는 열지 않는다 — MENU의 SHIFT 각인 `SETUP`과 AC의 SHIFT 각인 `OFF`는 #253에서 없앴다):
  - 광고 없는 배치(과금 사용자)가 기준이다 (#141). 무과금 사용자의 배너 광고(`google_mobile_ads`)는 그 배치에 넣고 **광고 높이만큼 LCD를 줄인다**.
    LCD가 실물 LCD 세로 63도트에 해당하는 높이를 지키지 못하면 키 높이를 조금씩 줄여 그 높이를 확보한다(2026-11-28 사용자 결정, 구현·dp 기준은 #18).
    광고 자리: 폰 세로는 키패드 아래, 태블릿 가로·펼친 트라이폴드·책 자세는 화면 아래쪽, 가로 접힘선 배치(Fold 가로·Flip)는 접힘선 위 패널.
    키와 광고 사이는 띄운다(AdMob 실수 클릭 안내). 2026-11-26의 "LCD 쪽(화면 맨 위·기록 영역), 활성 LCD는 줄이지 않는다"는 이 결정으로 바뀌었다.
  - 비소모성 인앱결제(`in_app_purchase`, 상품 ID: `remove_ads`) + `shared_preferences` 로컬 캐싱 + 앱 시작 시 백그라운드 `restorePurchases()` 동기화 (백엔드 서버 없음)

## 2. 디렉토리 구조 (`lib/`)
- `core/constants/key_definitions.dart`: 50개 버튼 레이아웃 및 SHIFT/ALPHA 키 매핑 정의, 모드 전용 각인(Complex 보라·Base-N 파랑과 ┌ ┐ 괄호 — 각인 띠의 인쇄 순서는 `CalcKeyDef.bandLegends`, 인쇄만 있고 그 모드의 기능은 각 모드 마일스톤, #266), 배포 기능에 따른 각인 숨김(`KeyFeature`와 배포 목록 `releasedKeyFeatures` 한 곳 — 명세는 실물 인쇄 그대로 두고, 배포되지 않은 기능의 각인은 `shiftLegend`·`bandLegends`에서 빠진다. v1.0은 OPTN의 `QR`과 Base-N 파랑 각인을 숨기고 Base-N은 v1.3에서 목록에 더한다, #267), `key_legend.dart` (각인 구조 — 글자·분수·첨자·위아래 끝(∑)·근호·직접 그리는 칸, 한 줄 표기 `plainText`)
- `core/theme/calc_theme.dart`: 카시오 fx-991EX/CW 색상 팔레트(M2에서 `Classic Dark` 스킨이 될 지금 외관 — 6절 끝. 실물 사진 기준 — 흰 숫자부·파란 DEL/AC·검정 함수부·은색 커서, #156. 모드 전용 각인 색 Complex 보라·Base-N 파랑, #266)·키캡 입체감 비율·키캡 크기(구역 공통 각인 띠, 가로/세로 비 상한, #220)·키 글자 크기 비율(실물 비율, 키 위 각인을 키캡에서 띄우는 거리, #264 — "글자 크기 실물 대조" 절), LCD·키 각인 폰트 스타일(각인은 비례폭 Saira·변수 이탤릭), 기기 고대비 설정에 따른 일반·고대비 팔레트(`CalcPalette`)와 짝인 Material 테마(대화상자·SnackBar·키보드 포커스 테두리)
- `core/theme/font_licenses.dart`: 번들 글꼴 OFL 라이선스를 `LicenseRegistry`에 등록
- `core/theme/high_text_contrast.dart`: Android 접근성 "고대비 텍스트" 켜짐 여부 수신(이벤트 채널, Android 쪽 `HighTextContrastStreamHandler.kt`)과 화면 전달 범위 — `CalcPalette.of`가 `MediaQuery.highContrast`와 함께 쓴다
- `core/layout/form_factor.dart`: 기기 종류(폰·폴더블·태블릿) 판정·방향 고정 규칙, 창 크기·접힘선 기준 배치 판정
- `core/layout/layout_log.dart`: 시작 판정·방향 요청·화면 배치(키패드 화면 위치 포함, #172)·프레임 시각·시스템 인셋과 제스처 영역·키 입력 시점(누를 때 입력·보류·뗄 때 입력·뗌·버림·취소·해제, #118)·여러 창 모드 판정(#137) 진단 로그(진단 빌드 `flutter build apk --release --dart-define=ALTCALC_LAYOUT_LOG=true`의 Android 앱에서만 켜진다 — 실기기에서 `adb logcat -s AltCalc flutter`로 첫 프레임 배치를 읽는다, #158)
- `domain/models/`: `math_node.dart` (수식 AST 노드), `calc_state.dart` (계산기 전체 상태), `lcd_status.dart` (LCD 상태 표시기 스냅샷), `handedness.dart` (손잡이 설정 — 가로형·가로 접힘선 넓은 배열의 숫자부 쪽, 책 자세의 키패드 쪽)
- `domain/engine/`: `cursor_navigator.dart` (방향키 커서 이동), `ast_evaluator.dart` (수식 계산기), `numerical_methods.dart` (수치해석)
- `presentation/providers/`: `calc_provider.dart`, `release_provider.dart` (키패드에 인쇄할 배포 기능 — 값은 `releasedKeyFeatures` 그대로이고 테스트가 override해 배포 뒤 각인·실물 인쇄 전체를 그려 본다. 그리는 각인만 바꾼다(입력 해석·스크린리더는 상수를 따른다), #267), `settings_provider.dart` (`shared_preferences` 앱 설정 — `main()`이 불러와 override. 화면 켜짐 유지 `keepScreenOnProvider`는 LCD ☀ 자리 표시기를 켜며 M1에서는 저장하지 않는다 — 저장·화면 꺼짐 방지는 #234), `device_provider.dart` (폴더블 기기 여부 — `main()`이 시작 판정(Android 쪽 `FoldableDeviceProbe.kt`)과 그 뒤 화면 정보로 기억한 값 `DeviceOrientationLock.foldableDevice`로 override), `iap_provider.dart`
- `presentation/l10n/`: `calc_semantic_strings.dart` (스크린리더 음성 문구 — 키 기능 이름·LCD 표시기 의미, 한국어·영어), `device_locale_scope.dart` (기기 로캘 전달·언어 변경 시 재빌드), `settings_strings.dart` (설정 UI·화면 안내 문구, 한국어·영어)
- `presentation/screens/`: `calculator_screen.dart`
- `presentation/widgets/`: `lcd_display.dart`, `lcd_status_icon.dart` (글자 대신 직접 그리는 LCD 상태 아이콘 →x·√▭✎·‖·👁(☀ 자리의 화면 켜짐 유지, #233)와 반전 상자 글자 S·A·D·R·G), `math_node_widget.dart`, `calc_key_button.dart` (키 하나 — 키캡(윗면 광택·옆면·그림자, #156)·각인 띠, 각인 띠의 SHIFT·ALPHA 각인 좌우 정렬(하나는 키캡 가운데, 둘은 키캡 둥근 모서리 안쪽 좌우 끝, #265 — 기준은 `CalcTheme` "각인 띠 좌우 정렬" 절. 셋인 ENG 키는 사이를 똑같이 띄우고, 모드 전용 각인의 ┌ ┐ 괄호는 `LegendBrackets`가 그린다, #266. 키 위 각인은 키캡 위끝에서 띄워 인쇄하고 키 사이 간격·셀 폭까지 쓴다, #264), 메인 각인을 그린 기준선에서 잉크 가운데로 세로 맞춤(`InkCenteredLabel`, #230 — 기준은 `CalcTheme` "메인 각인 세로 위치" 절), SHIFT·ALPHA·MENU·ON 자리의 설정 키는 원형 버튼, 설정 키는 키보드 포커스, #190. 셀 전체를 터치하는 키는 셀 둘레 키 사이 간격 몫까지 터치·의미 노드 영역, `GapSemantics`, #236), `round_key_face.dart` (실물 SHIFT·ALPHA·MENU·ON 같은 원형 은색 버튼 면), `calc_body_background.dart` (본체 바탕 — 세로 그라데이션·잔무늬·가장자리 선, 고대비에서는 끔, #156), `key_legend_view.dart` (분수·첨자·근호·∑ 위아래 끝·직접 그리는 칸 각인을 실물처럼 2차원으로 그림 — 배치 비율은 `CalcTheme` "2차원 각인 배치" 절), `calc_keypad.dart` (50키 배치·글자 크기 통일, 구역 배열 — 실물 배열과 가로형·가로 접힘선 아래 패널용 넓은 배열 `KeypadArrangement`, 넓은 배열의 손잡이 대칭), `history_panel.dart` (책 자세의 반대쪽 패널에만 남은 빈 계산 기록 영역. 2026-11-28 결정으로 기록 영역은 없애고 LCD와 붙인 넓은 계산 영역으로 바꾼다 — 가로형·가로 접힘선은 #284에서 바꿨고, 책 자세와 이 위젯은 #285. 기록 목록 #145는 하지 않는다), `focus_ring.dart` (키보드 포커스 테두리 — 일반·고대비 모두, 대화상자 선택지·버튼·설정 키), `text_fit.dart` (글자 배율 반영 높이 맞춤), `settings_launcher.dart`·`handedness_dialog.dart` (ON 키(설정 키, #190)로 설정 열기 — 접힘선 기준 대화상자 위치·키패드 위치 선택. 지금은 키패드 위치 대화상자이고, M5(에픽 #191)에서 계산기 SETUP 항목과 앱 설정을 담은 설정 팝업으로 바꾼다. LCD 위 상단 띠·설정 버튼(#41)은 #190에서 없앴다), `screen_coordinate_root.dart` (화면을 흉내 내는 곳에 MediaQuery와 좌표 원점을 함께 제공 — 위젯 배치는 미리보기 기기 틀 전용, 키 버튼이 좌표 변환에 사용), `screen_reader_announcer.dart` (스크린리더 상태 변화 알림 — 루트 Navigator 위에 두어 설정 대화상자 장벽에 막히지 않게 하고, Android는 알린 뒤 `clearDelay`가 지나면 알림 노드를 없앤다, #207)
- 테스트: `test/unit/` (순수 Dart 로직, Flutter 바인딩 없이 저장소 설정 파일을 읽는 구성 검사 포함 — 줄바꿈 속성 검사는 `git` 명령으로 속성을 조회하고, SDK 고정 검사는 CI의 버전 읽기 스크립트를 bash로 실행한다, 액션 고정 스크립트·프로젝트 상태 변경 스크립트(`.claude/scripts/set-project-status.sh`, #250) 검사는 가짜 gh로, 추적 중인 이미지·글꼴 파일과 출처 목록 `.github/tracked-binary-assets`의 대조(#280)는 `git ls-files`로, 릴리스 APK API 격리 검사 스크립트는 가짜 Android SDK와 실제 빌드에서 옮긴 dexdump 표본으로 실행한다), `test/widget/` (위젯 테스트 — 바인딩·`rootBundle`·실제 글꼴을 쓰는 테스트 포함), `test/support/` (테스트 공용 도구: 번들 글꼴 로더, cmap·글리프 잉크 범위 파서, 각인 위젯 찾기, LCD 글자 목록, 키 터치 치수 측정·커서 패드 내접원 기준(#159), 커서 패드 라벨 검사, 엔진 브리지의 터치 탐색 판정 흉내(겹친 시맨틱 노드의 히트 테스트 순서, #203), 스크린리더 읽기 순서(의미 트리 순회, #140), 화면 배치 판정, CI 워크플로 파일 목록·YAML 로더·`uses:` 줄 추출, 셸 스크립트 실행용 bash 찾기, 가짜 APK용 ZIP 작성기)
- Android 단위 테스트: `android/app/src/test/kotlin/` (Kotlin 플랫폼 코드의 JVM 테스트 — Robolectric으로 API 수준별 분기를 기기 없이 검사한다.
  `TestSupport.kt`에 테스트 대상 API 수준 상수·가짜 메신저·시스템 설정 흉내 도구, `MainActivityLifecycleTest`는 Mockito `FlutterJNI` 대역 캐시 엔진으로 생명주기를 돈다. `flutter test`와 따로 Gradle로 돌린다 — README "Android 단위 테스트")
- 개발 도구: `preview/key_preview_main.dart` (실제 `CalculatorScreen`을 기기 크기 프리셋·글자 배율·입력 로그와 함께 띄우는 미리보기 — 실행 방법은 README. `lib/`에서 import 금지, 앱 빌드 제외, CI가 웹 빌드로 확인)
- VS Code: `.vscode/` (실행 구성 `launch.json`·추천 확장 `extensions.json` — 준비 단계·SDK 탐지는 README "VS Code에서 실행". 기기마다 다른 절대경로는 넣지 않으며, 구성과 README 표의 일치와 함께 `test/unit/vscode_config_test.dart`가 검사한다)
- 줄바꿈: `.gitattributes` (Flutter가 다시 쓰는 생성 플러그인 파일을 LF로 고정 — `test/unit/gitattributes_test.dart`가 대상 누락을, CI가 빌드 뒤 작업 트리가 깨끗한지 검사한다. 아래 "로컬 개발 환경 메모" 참조)
- 분석 제외: `analysis_options.yaml`의 `analyzer.exclude` (플랫폼 폴더와 작업 영역 안 워크트리 `.claude/worktrees/**` — 워크트리 항목은 VS Code Dart 확장의 프로젝트 목록 제외용이며, 확장이 폴더 제외로 읽는 표기인지 `test/unit/analysis_options_test.dart`가 검사한다. README "작업 영역 안의 git 워크트리")
- 에셋: `assets/fonts/` (번들 글꼴 Noto Sans Mono/Math, 키 각인용 Saira·Noto Serif Bold Italic 서브셋과 OFL 전문 — 출처·서브셋 재현·글리프 선택 규칙은 `assets/fonts/README.md`)

## 3. 코딩 원칙
- 일반 스마트폰, 폴더블, 태블릿 등 다양한 화면비에서도 키패드 비율이 깨지지 않도록 반응형으로 설계한다.
- 화면 배치는 광고 없는 배치를 기준으로 화면을 다 채운다(#141). 키가 세로로 길어지는 것은 피하고(키패드 가로/세로 비 하한),
  가로로 넓어지는 것은 받아들인다. 키 글자는 키 높이의 실물 비율이고 dp 상한이 없다(#264 — 태블릿은 실물을 확대한 모양이다.
  #141의 글자 크기 상한은 없앴다). 무과금 광고는 LCD 높이를 줄여 넣으며(1절, #18),
  광고 높이가 바뀌어도 키패드가 찌그러지지 않게 한다.
- M2 이후 과제는 아래 6절 "지식재산권 작업 규칙"을 따른다(M1은 대상이 아니다).
- 기본 연산 시 부동소수점 오차(`0.1 + 0.2`) 방지를 위해 일반 `double` 대신 `Decimal`을 사용한다.
- 키 명세·테마 등 상수 데이터에는 반드시 불변식 테스트(키 개수, ID 중복 금지 등)를 함께 둔다.
- 커밋 전 항상 `flutter analyze`(이슈 0건)와 `flutter test`(전부 통과)를 확인한다.
  - Android 플랫폼 코드(`android/`의 Kotlin·Gradle 설정)를 바꿨으면 Android 단위 테스트도 돌린다:
    `cd android && ./gradlew :app:testDebugUnitTest` (Java 21 이상, 먼저 `flutter build apk --debug --config-only`로 래퍼·`local.properties`를 맞춘다 —
    README "Android 단위 테스트"). Kotlin 로직을 추가·변경하면 `android/app/src/test/kotlin`에 테스트를 함께 둔다 (#108).
  - minSdk보다 높은 API 전용 타입·메서드는 `@RequiresApi` 중첩 `object Api<N>`의 `@DoNotInline` 메서드에만 쓴다 (#95).
    R8 뒤에도 격리가 유지되는지 CI가 릴리스 APK의 dex로 검사한다 — 새 격리 object는 `.github/api-isolation-rules`에 더한다
    (README "릴리스 APK의 새 API 격리 검사", #109).

## 4. 로컬 개발 환경 메모
- Flutter SDK가 시스템 PATH에 없을 수 있다. `flutter`를 찾지 못하면 Bash에서
  `export PATH="/c/Users/fmthead/develop/flutter/bin:$PATH"` 후 실행한다.
- 생성 플러그인 파일(`linux/flutter/generated_plugin*`, `windows/flutter/generated_plugin*`,
  `macos/Flutter/GeneratedPluginRegistrant.swift`)은 `.gitattributes`로 LF 고정이라, `flutter pub get`·`test` 뒤에도
  수정됨으로 보이지 않는다 (#67). 그래도 이 파일들이 `M`이면 실제 변경인지 먼저 `git diff`로 본다(줄바꿈만 다르면 비어 있다).
  - 속성이 생기기 전에 체크아웃한 작업 트리는 CRLF로 남아 있어 Flutter가 다시 쓰면 내용 차이 없이 `M`이 된다.
    #67이 들어온 브랜치로 전환·머지한 **뒤** Git Bash에서 `bash .claude/scripts/normalize-generated-eol.sh`로 한 번 정리한다
    (대상은 `.gitattributes`가 정하고, 내용이 실제로 바뀐 파일이 있으면 아무것도 하지 않고 중단한다).
  - #67 이전 브랜치에 있어서 `M` 때문에 전환·머지가 막히면(스크립트가 아직 없다): 위 생성 파일 7개에 대해
    `git diff --stat -- <7개>`가 비어 있음을 확인한 뒤 그 7개만 `git checkout -- <7개>`로 되돌린다.
  - `git checkout -- linux macos windows`처럼 플랫폼 폴더 전체를 되돌리지 않는다 — 진짜 변경까지 지워진다.
- Flutter SDK 폴더는 이 PC의 모든 브랜치·worktree가 함께 쓴다. 고정값(`environment.flutter`)과 다른 SDK로는 `pub get`이 실패하므로,
  SDK를 바꾸면 고정값이 다른 브랜치가 모두 깨진다 — 버전 올리기는 README 절차의 "먼저 알아 둘 점"을 따른다 (#78).
  - 버전 올리기 절차 밖에서 `flutter upgrade`를 실행하지 않는다(새 버전 알림이 떠도 무시한다).
  - 별도 폴더의 새 SDK로 버전을 올리는 동안에는 위 PATH 안내(`~/develop/flutter`)가 옛 SDK를 가리킨다.
    그 브랜치의 서브에이전트·리뷰 지시에는 쓸 SDK 경로를 명시한다.
- git 워크트리는 `.claude/worktrees/` 아래나 저장소 밖(`../altcalc-wt<번호>`)에만 만든다. 저장소 안의 점으로 시작하지 않는
  폴더에 만들면, 저장소 루트를 연 VS Code 창이 떠 있을 때 Dart 확장이 그 워크트리에 묻지 않고 pub get을 돌릴 수 있다.
  `.claude/worktrees/`는 `analysis_options.yaml`의 `analyzer.exclude`로 확장의 프로젝트 목록에서 뺀다(시작 시 pub get 알림,
  오래된 프로젝트가 하나뿐일 때의 자동 실행). 이 목록 제외는 루트 체크아웃의 브랜치에 이 항목이 있을 때만 효과가 있으므로,
  그 전에 분기한 브랜치는 마일스톤 브랜치를 먼저 머지한다 (#66, README "작업 영역 안의 git 워크트리").
- fx-991EX 참고 자료는 이 PC의 `C:\Users\fmthead\Desktop\guide`(Git Bash `/c/Users/fmthead/Desktop/guide`)에 있다 (#185). 폴더가 없으면 사용자에게 묻는다.
  - 쓰임(M2부터, 6절 규칙 1): 조작·계산 결과·설정 항목의 뜻·오류 조건을 확인하는 데 쓰고, 그림·도트 모양·색·세부 비율을 옮기는 근거로 쓰지 않는다.
    M1 과제는 이 제한 없이 외관 대조에도 쓴다(2026-11-28 사용자 결정). 아래 줄들(저장소에 넣지 않기, 웹에서 새로 찾지 않기)은 M1에도 그대로다.
  - User's Guide: `fx-570_991EX_EN.pdf`와 쪽 이미지 `fx-570_991EX_EN/fx-570_991EX_EN_page-NNNN.jpg` — 이미지 번호 = 인쇄 쪽 + 1(예: `page-0005.jpg` = 인쇄 4쪽 표시기 표).
  - Quick Start Guide: `All_CASIO_QuickStartGuide_fx-991EX_fx-570EX.pdf`와 같은 이름 폴더의 쪽 이미지 — `page-0001.jpg`가 제품 정면 사진.
  - `licensed-image.jpg`: 실물 키패드 근접 사진(2048×1363). 모델명이 찍혀 있지 않고 소수점 `,`·GCD·LCM·Int·Intg·RndFix 각인이 있어 EN판과 다르다 — EN 가이드와 다르면 EN을 따른다.
  - `image.avif`: QSG 1쪽과 같은 렌더 이미지의 작은 사본(408×340, 독립 근거가 아니다). AVIF라 Read로 열리지 않으므로 `python3 -P`와 PIL로 변환해 본다.
  - 폴더에 새 파일이 생길 수 있으니 목록부터 본다.
  - 웹에서 fx-991EX 사진·PDF를 새로 찾지 않는다(Casio 사이트는 가져오기가 막힌다). 이전 코드가 근거로 든 Wikimedia Commons 사진·CasioEmu 스프라이트는 이력이라 주석을 그대로 둔다.
  - M2부터는 다른 소프트웨어·에뮬레이터의 스프라이트·소스를 새 근거로 쓰지 않는다(6절 규칙 5 — M1은 6절의 대상이 아니다).
    이 폴더로 판단할 수 없는 자료(특정 표시기가 켜진 실물 사진, 색 샘플 등)는 사용자에게 묻는다.
  - 파일은 저장소에 복사하지 않는다(저작권). 코드 주석과 PR에는 문서 이름(User's Guide / Quick Start Guide)과 인쇄 쪽, 필요하면 쪽 이미지 파일 이름만 적는다
    (예: "User's Guide 4쪽(`page-0005.jpg`)"). 사용자 PC 경로는 적지 않는다.
- GitHub CLI(`gh`)로 이슈/PR/프로젝트를 관리한다. 저장소: `i-technika/altcalc-fx991`
- `gh`에 여러 줄 본문을 넘길 때는 셸 이스케이프 깨짐(과거 이슈 본문의 `\경로\` 깨짐 현상)을 막기 위해
  **반드시 임시 파일 + `--body-file`** 을 사용한다.

## 5. 개발 워크플로우 (스킬)
마일스톤 에픽 → 서브이슈 구조로 진행하며, 아래 프로젝트 스킬을 사용한다 (`.claude/skills/`).

| 명령 | 용도 |
|---|---|
| `/open-ms <에픽번호>` | `main`에서 `milestone/m<N>` 분기 + 마일스톤 Draft PR 생성 |
| `/fix-issue <서브이슈번호>` | 서브이슈 구현 → PR → 적대적 리뷰 1라운드(2026-11-28 사용자 결정 — 예전 2라운드) → 마일스톤 브랜치 머지 → 이슈 Close |
| `/close-ms <에픽번호>` | 마일스톤 PR Ready 전환 → 멀티플랫폼 CI → `main` 머지 |

### 마일스톤 대응 표 (2026-11-27 모드별 재구성 #249, 2026-11-28 M2 삽입 #280)
M 번호(`<N>`), 에픽 이슈 번호, GitHub 마일스톤 번호는 **서로 다르다**. 브랜치·커밋·실기기 규칙의 `M<N>`은 에픽 제목의 `[M<N>]`
(= 마일스톤 제목의 `M<N>:`)에서 읽는다 — 에픽 번호나 `milestone.number`로 정하지 않는다.
M1 뒤에 지식재산권 검토·독자 디자인 전환(M2)이 있고, 수식 AST(M3) 뒤는 MENU 메인 메뉴(M4) → 설정 팝업(M5) → 실물 계산 모드별 마일스톤(모드 12개, Calculate만 둘)이고, v1.0 모드 뒤에 광고·결제(M11)·출시 QA(M12)가 있다. **v1.0은 모드 4개**(Calculate·Complex·Equation/Func·Table)로
M12에서 출시하고, 나머지 모드는 M13부터 버전마다 하나씩 더한다. 구성 원본은 에픽 #5 "마일스톤 구성", 항목별 요구사항은 [milestone.md](milestone.md)다.

| M | 에픽 | GitHub 마일스톤 번호 | 브랜치 | 내용 | 배포 |
|---|---|---|---|---|---|
| M1 | #1 | 1 | `milestone/m1` | UI 셸·키패드 | |
| M2 | #272 | 20 | `milestone/m2` | 라이선스·지식재산권 검토 및 독자 디자인 전환 | |
| M3 | #2 | 2 | `milestone/m3` | 2D 수식 AST·커서 | |
| M4 | #5 | 5 | `milestone/m4` | MENU 메인 메뉴·모드 전환 뼈대 | |
| M5 | #191 | 8 | `milestone/m5` | SETUP 설정 팝업 (SETUP 키) | |
| M6 | #3 | 3 | `milestone/m6` | Calculate — 기본 연산 엔진·메모리·계산 기록 | |
| M7 | #4 | 4 | `milestone/m7` | Calculate — CALC·SOLVE·미적분·Σ, 과학 상수·단위 변환 | |
| M8 | #239 | 10 | `milestone/m8` | Complex | |
| M9 | #240 | 11 | `milestone/m9` | Equation/Func | |
| M10 | #241 | 12 | `milestone/m10` | Table | |
| M11 | #192 | 9 | `milestone/m11` | AdMob·인앱결제 | |
| M12 | #6 | 6 | `milestone/m12` | 출시 QA (실기기 점검·실물 대조·스토어 빌드) | v1.0 |
| M13 | #242 | 13 | `milestone/m13` | Inequality | v1.1 |
| M14 | #243 | 14 | `milestone/m14` | Ratio | v1.2 |
| M15 | #244 | 15 | `milestone/m15` | Base-N | v1.3 |
| M16 | #245 | 16 | `milestone/m16` | Matrix | v1.4 |
| M17 | #246 | 17 | `milestone/m17` | Vector | v1.5 |
| M18 | #34 | 7 | `milestone/m18` | Statistics | v1.6 |
| M19 | #247 | 18 | `milestone/m19` | Distribution | v1.7 |
| M20 | #248 | 19 | `milestone/m20` | Spreadsheet | v1.8 |

마일스톤 이름(`--milestone`에 쓰는 제목)은 번호로 조회한다: `gh api repos/i-technika/altcalc-fx991/milestones/<GitHub 마일스톤 번호> --jq .title`.
- M1 에픽 #1은 GitHub 서브이슈 한도(부모 하나에 100개)에 닿았다. 새 M1 이슈는 에픽 #1 대신 묶음 이슈 **#237**(`[M1]` 제목) 아래에 연결한다(`/fix-issue` 9단계 B 블록의 `EPIC=237`).

옛 M 번호 (이슈·코멘트·커밋·PR 본문은 이력이라 고치지 않는다 — 에픽 번호·GitHub 마일스톤 번호는 세 번의 바뀜에서 그대로였으니 그것으로 찾는다):
- **2026-11-28 M2 삽입(#280) 이전 번호 → 지금 번호: M2~M19 → M3~M20 (M 번호에 1을 더한다)**. M1은 그대로이고, 새 M2는 에픽 #272(GitHub 마일스톤 번호 20)다.
  2026-11-27(#249 뒤)~11-28에 쓴 글의 "M11 출시 QA"는 지금 M12, "M10 광고·결제"는 M11, "M4 설정 팝업"은 M5, "M2 수식"은 M3다.
- 2026-11-27 첫 재구성(#185) 이전의 "M6 실기기·광고·출시 QA"는 지금의 M12(실기기·출시 QA)·M11(광고·결제)이고(그 안의 앱 설정 자리는 지금 M5),
  옛 M7(데이터 분석 앱)은 M18~M20이다. 그때의 M1~M5는 아래 #249 이전 번호와 같다.
- 같은 날 모드별 재구성(#249) 이전 번호 → 지금 번호: M2(수식 AST) → M3, M3(계산 엔진 COMP) → M6, M4(수치해석) → M7, M5(특수 연산 모드) → M4 메뉴 뼈대와 모드별 마일스톤(M8~M10·M13~M17),
  M6(앱 설정, ON 키) → M5 설정 팝업, M7(AdMob·인앱결제) → M11, M8(출시 QA) → M12, M9(데이터 분석 앱) → M18~M20.
  계산기 SETUP(#27)은 옛 M3에서 M5 설정 팝업으로, 과학 상수·단위 변환(#29)은 옛 M3에서 M7로 옮겼다.

### 브랜치/PR 규칙
- 마일스톤 브랜치: `milestone/m<N>` — `<N>`은 위 표의 M 번호 (base: `main`, Draft PR로 유지 → Draft 동안 CI 미실행)
- 서브이슈 브랜치: `issue/<번호>-<영문-키워드>` (base: `milestone/m<N>`)
- 서브이슈 제목에는 순번 접두사(`[M<N>-<순번>]`)를 붙이지 않는다 — 이슈 번호·마일스톤·상위 에픽으로 식별한다 (#112). 에픽 제목의 `[M<N>]`은 유지한다.
  (#112 이전의 커밋 메시지와 머지된 PR·이슈 본문·코멘트에는 `[M1-5]` 같은 순번이 남아 있다 — 이력이라 그대로 두며, 모두 `#번호`가 함께 적혀 있다)
- 서브이슈 PR 제목: `<이슈 제목> (#<이슈번호>)`
- 서브이슈 생성은 어느 단계에서든 `/fix-issue` 9단계의 A(생성)·B(연결) 블록을 따른다 (라벨·마일스톤·프로젝트·상위 에픽 연결·이슈 타입을 함께 지정하고, 생성 실패 시 중복 생성을 막는다)
- Android·iOS(iPhone·iPad) **실기기** 확인은 M12 출시 QA(에픽 #6 "실기기 점검", GitHub 마일스톤 번호 6)에서 한다(v1.0 출시 전 과제인 M1~M11에 한함 — M 구분은 위 대응 표·마일스톤 제목으로 한다. 범위는 2026-11-27 사용자 확인, #185·#249. M2 삽입으로 번호만 하나씩 밀렸다, #280). 실기기가 있어야 하는 부분은 M12·에픽 #6 이슈로 나누고, 에뮬레이터·CI로 되는 부분은 그 과제가 속한 마일스톤에 남긴다. M1~M11 이슈 본문에 있는 실기기 확인 항목도 그 이슈에서 하거나 완료 처리하지 않고 M12로 나눈다(이미 있는 M12 이슈가 있으면 그것을 가리킨다). v1.0 뒤 마일스톤(M13~M20)의 실기기 확인은 M12로 넘기지 않고 그 마일스톤에서 한다(그 버전의 배포 전 점검). iOS 화면·동작 확인은 실기기로 본다(Mac 없음). 실물 계산기·사진 대조는 실기기 확인이 아니다 (#185, 자세히는 `/fix-issue` 1·9단계)
- 담당자(Assignee): 착수하는 이슈(`/open-ms`의 에픽, `/fix-issue`의 서브이슈)와 생성하는 PR은 `i-technika`로 지정한다 (미착수 후속 이슈는 지정하지 않음)
- 라벨: 에픽 `milestone`, 서브이슈 `sub-issue` / 프로젝트: `AltCalc FX-991` (#7)
- 서브이슈 PR은 기본 브랜치가 아닌 마일스톤 브랜치로 머지되므로 `Closes #N`으로 **이슈가 자동 Close되지 않는다.** 머지 후 직접 `gh issue close`한다.
- CI: 마일스톤 브랜치 대상 PR → `Sub-issue Linux CI`, `main` 대상 PR(Ready) → `Milestone Full Multi-Platform CI`
  (`Sub-issue Linux CI`는 마일스톤 브랜치 push에서도 돌아 그 브랜치 범위에 캐시를 만든다 — 다음 서브이슈 PR들이 그 캐시를 쓴다, #108)

### GitHub Project #7 (AltCalc FX-991) 식별자
- Project ID: `PVT_kwHOBMwL0c4BsMze` / Owner: `i-technika`
- Status 필드 ID: `PVTSSF_lAHOBMwL0c4BsMzezhqcBOI`
  - Todo `f75ad846` / In Progress `47fc9ee4` / Done `98236657`

## 6. 지식재산권 작업 규칙
> 원본은 에픽 #272 "지식재산권 작업 규칙"이다(2026-11-28 사용자 결정). 원본이 바뀌면 이 절을 맞춘다. 위험을 줄이기 위한 작업 기준이며 법률 판단은 아니다 —
> 판단이 필요한 것은 전문가 자문 안건(#273)에 더한다.

**적용 범위**: M2부터 모든 마일스톤·이슈에 적용한다. **M1(에픽 #1, 묶음 #237)의 개발 사항은 대상이 아니다**(2026-11-28 사용자 결정) —
M1의 남은 과제는 지금 외관(M2에서 `Classic Dark` 스킨이 될 몫)을 기존 M1 기준대로 마무리한다. 4절의 참고 자료 규칙(저장소에 넣지 않기 등)은 M1에도 그대로다.

1. **참고 자료의 쓰임**: 실물 계산기와 User's Guide는 "무엇을 하는지"(키 순서, 계산 결과, 설정 항목의 뜻, 오류가 나는 조건)를 확인하는 데 쓴다.
   "어떻게 생겼는지"(그림, 도트 모양, 색, 세부 비율)를 옮기는 근거로 쓰지 않는다.
2. **그림**: 아이콘, LCD 표시기, 메뉴·표·그래프 화면, 각인 그림은 모두 독자 도안을 코드로 그린다. 실물 화면, 가이드의 그림, 다른 앱·에뮬레이터의
   화면을 따라 그리거나(덧그리기, 도트 단위 재현) 캡처를 넣지 않는다.
3. **글**: 가이드의 설명 문장, 예제, 표를 앱 문구·도움말·스토어 설명·문서에 옮겨 적지 않는다. 기능 이름, 설정 항목 이름, 오류 이름 같은 짧은 표기는
   조작 호환을 위해 쓸 수 있다. 그보다 긴 안내·확인·도움말 문구는 직접 쓴다(한국어·영어).
4. **데이터**: 과학 상수, 단위 환산 계수 같은 값은 1차 출처(CODATA, NIST 등)에서 가져오고 출처를 적는다. 가이드의 표에서 옮기지 않는다.
   번호·분류는 키 순서 호환에 필요한 만큼만 맞춘다.
5. **코드**: 다른 계산기 소프트웨어·에뮬레이터의 소스, ROM·펌웨어 덤프, 역어셈블 결과를 보거나 옮기지 않는다. 알고리즘은 공개된 수학·수치해석
   자료를 근거로 직접 구현하고, 실물과 같은지는 입력과 출력의 비교(결과 대조)로만 확인한다.
6. **외부 구성 요소**: 패키지, 글꼴, 아이콘, 소리를 새로 넣기 전에 라이선스를 확인하고 출처 기록(#279)에 올린다. GPL·AGPL·LGPL 계열, 비상업 조건,
   출처를 알 수 없는 것은 넣지 않는다.
7. **이름**: 사용자에게 보이는 곳(앱 문구, 스크린리더 문구, 아이콘, 스토어 자료)에 다른 회사의 상호, 제품 계열 이름, 모델명, 기능 이름 상표를
   쓰지 않는다. 개발 문서에서 근거를 밝힐 때는 문서 이름과 쪽 번호로 가리킨다.
8. **공개되는 곳**: 이슈, PR, 코멘트, 브랜치에 참고 자료의 사진, 쪽 이미지, 그것을 잘라낸 조각을 올리지 않는다. 비교가 필요하면 앱 화면만 올리고
   참고 자료는 문서 이름과 쪽 번호로 가리킨다. 권리 조사의 상세 결과와 자문 내용도 올리지 않는다.
9. **외관**: 기본 스킨은 독자 명세(#275)가 기준이다. 외관을 실물에 더 가깝게 다듬는 작업은 하지 않는다.
10. **이력**: 커밋, 이슈, PR, 코멘트는 지우거나 고쳐 쓰지 않는다.
11. **막히면 멈춘다**: 이슈의 요구사항이 이 규칙과 부딪치거나 판단이 서지 않으면 구현하기 전에 사용자에게 묻는다(단일 선택).

스킬에서 이 규칙을 쓰는 곳: `/fix-issue` 1단계(점검)·3단계(구현)·4단계(PR 이미지)·5단계(리뷰 점검 항목)·9단계(후속 이슈), `/open-ms` 1단계, `/close-ms` 2단계.
자동 검사(#280, 위 규칙 원문에는 없는 저장소 장치): 이미지·글꼴·소리·PDF 파일은 `.github/tracked-binary-assets`에 출처와 함께 적는다 —
`test/unit/binary_assets_test.dart`가 추적 파일·추가 전 파일과 대조한다. 참고 자료가 실수로 들어오는 것(4절)을 막는 장치라 M1에서도 목록을 갱신한다.
외관 방침(에픽 #272): 실물 대조의 대상은 키 배열·각인 내용·조작·계산 결과이고, 외관(색·모양·질감)은 독자 명세가 기준이다. 2절의 `calc_theme.dart`·위젯 설명에
"실물 사진 기준"으로 적힌 외관은 M2에서 `Classic Dark` 스킨이 될 지금 외관의 설명이다(스킨 구조의 설명은 #276·#277에서 고친다).
